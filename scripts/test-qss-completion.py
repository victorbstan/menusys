"""Render QSS native intermission from an isolated protocol-15 demo.
External inputs remain local; the generated demo exercises native engine drawing,
not a QC replacement. Requires Windows, Pillow and NumPy.
"""
import argparse, ctypes, json, re, shutil, struct, subprocess, time
from pathlib import Path
import numpy as np
from PIL import Image

def pak_files(data):
    files = {}
    for pak in sorted(Path(data).glob("pak*.pak")):
        blob = pak.read_bytes()
        magic, offset, length = struct.unpack_from("<4sii", blob)
        assert magic == b"PACK"
        for pos in range(offset, offset + length, 64):
            name, start, size = struct.unpack_from("<56sii", blob, pos)
            files[name.split(b"\0")[0].decode()] = blob[start:start+size]
    return files

def demo(files, scores=True):
    # Retain the dataset's valid startup/signon, then inject svc_intermission.
    # This exercises the engine's real native overlay with its own artwork.
    source=files["demo1.dem"];pos=source.index(b"\n")+1;prefix=source[:pos]
    last_time=0;timed=0
    while timed<30:
        length=struct.unpack_from("<i",source,pos)[0]
        end=pos+16+length;payload=source[pos+16:end]
        prefix+=source[pos:end];pos=end
        if payload[0]==7:
            last_time=struct.unpack_from("<f",payload,1)[0];timed+=1
    def frame(payload):
        return struct.pack("<i3f",len(payload),0,0,0)+payload
    packet=b"\x07"+struct.pack("<f",last_time+.01)
    for index,value in [(11,4),(12,26),(13,0),(14,25)]:
        packet+=b"\x03"+struct.pack("<Bi",index,value)
    packet+=b"\x1e" if scores else b"\x1aZOOM CHECK\0"
    return prefix+frame(packet)+b"".join(frame(b"\x07"+struct.pack("<f",last_time+i/60)) for i in range(1,7201))

user = ctypes.windll.user32
user.SetThreadDpiAwarenessContext(ctypes.c_void_p(-4))
user.GetClientRect.argtypes = [ctypes.c_void_p, ctypes.c_void_p]
user.GetWindowRect.argtypes = [ctypes.c_void_p, ctypes.c_void_p]
user.SetWindowPos.argtypes = [ctypes.c_void_p, ctypes.c_void_p, ctypes.c_int, ctypes.c_int, ctypes.c_int, ctypes.c_int, ctypes.c_uint]
user.PostMessageW.argtypes = [ctypes.c_void_p, ctypes.c_uint, ctypes.c_size_t, ctypes.c_ssize_t]
user.GetWindowThreadProcessId.argtypes = [ctypes.c_void_p, ctypes.c_void_p]
user.GetClassNameW.argtypes = [ctypes.c_void_p, ctypes.c_void_p, ctypes.c_int]
class Rect(ctypes.Structure):
    _fields_ = [(n,ctypes.c_long) for n in ("left","top","right","bottom")]

def window(pid):
    result=[]
    callback=ctypes.WINFUNCTYPE(ctypes.c_bool,ctypes.c_void_p,ctypes.c_void_p)
    def visit(hwnd,_):
        owner=ctypes.c_ulong();user.GetWindowThreadProcessId(hwnd,ctypes.byref(owner))
        name=ctypes.create_unicode_buffer(100);user.GetClassNameW(hwnd,name,100)
        if owner.value==pid and name.value=="SDL_app":result.append(hwnd)
        return True
    user.EnumWindows(callback(visit),0)
    return result[0] if result else None

def resize(hwnd,w,h):
    c=Rect();r=Rect();user.GetClientRect(hwnd,ctypes.byref(c));user.GetWindowRect(hwnd,ctypes.byref(r))
    assert user.SetWindowPos(hwnd,0,0,0,w+r.right-r.left-c.right,h+r.bottom-r.top-c.bottom,0x14), (hwnd,c.right,c.bottom,r.right,r.bottom,user.IsWindow(ctypes.c_void_p(hwnd)))

def capture(hwnd,game):
    before=set(game.glob("spasm*.png"))
    user.PostMessageW(hwnd,0x100,0x7B,0x580001);user.PostMessageW(hwnd,0x101,0x7B,0xC0580001)
    deadline=time.monotonic()+20
    while time.monotonic()<deadline:
        shots=set(game.glob("spasm*.png"))-before
        if shots:
            shot=next(iter(shots))
            try:
                with Image.open(shot) as im:im.load()
                return shot
            except OSError:pass
        time.sleep(.1)
    raise AssertionError("Screenshot timed out")

def check(shot,files,zoom):
    im=np.array(Image.open(shot).convert("RGB"));h,w=im.shape[:2]
    scale=min(max(1,zoom),w/320,h/200)
    palette=np.frombuffer(files["gfx/palette.lmp"],dtype=np.uint8).reshape(256,3)
    matches=0;total=0
    for name,x,y in [("complete",64,24),("inter",0,56)]:
        blob=files["gfx/"+name+".lmp"];pw,ph=struct.unpack_from("<ii",blob)
        pixels=np.frombuffer(blob[8:],dtype=np.uint8).reshape(ph,pw)
        # Sample opaque interior texels at expected physical coordinates.
        for sy in range(2,ph-2,3):
            for sx in range(2,pw-2,3):
                index=pixels[sy,sx]
                if index==255:continue
                px=int((w-320*scale)/2+(x+sx+.5)*scale)
                py=int((h-200*scale)/2+(y+sy+.5)*scale)
                total+=1
                # Allow bilinear filtering of the original palette artwork.
                matches+=bool(np.max(np.abs(im[py,px].astype(int)-palette[index].astype(int)))<=32)
    ratio=matches/total
    assert ratio>.80, f"Native artwork scale/centering mismatch: {shot}: {ratio:.3f}"
    return dict(capture=str(shot),width=w,height=h,scale=scale,matched=ratio)

def key(hwnd, vk, scan):
    user.PostMessageW(hwnd,0x100,vk,(scan<<16)|1)
    user.PostMessageW(hwnd,0x101,vk,0xC0000001|(scan<<16))

def check_message(shot,files,zoom):
    im=np.array(Image.open(shot).convert("RGB"));h,w=im.shape[:2]
    scale=min(max(1,zoom),w/320,h/200)
    palette=np.frombuffer(files["gfx/palette.lmp"],dtype=np.uint8).reshape(256,3)
    wad=files["gfx.wad"];_,count,offset=struct.unpack_from("<4sii",wad)
    font=None
    for i in range(count):
        start,size,_,_,_,_,name=struct.unpack_from("<iiiBBH16s",wad,offset+i*32)
        if name.split(b"\0")[0].lower()==b"conchars":font=np.frombuffer(wad[start:start+size],dtype=np.uint8).reshape(128,128)
    assert font is not None
    total=0;matches=0;message="ZOOM CHECK"
    for letter,c in enumerate(message):
        glyph=font[(ord(c)//16)*8:(ord(c)//16+1)*8,(ord(c)%16)*8:(ord(c)%16+1)*8]
        for sy in range(8):
            for sx in range(8):
                index=glyph[sy,sx]
                if index==0:continue
                px=int((w-320*scale)/2+(160-len(message)*4+letter*8+sx+.5)*scale)
                py=int((h-200*scale)/2+(70+sy+.5)*scale)
                # Allow one physical pixel of font rasterization rounding at fractional scales.
                total+=1
                neighbors=im[max(0,py-1):py+2,max(0,px-1):px+2]
                matches+=bool(np.any(np.max(np.abs(neighbors.astype(int)-palette[index].astype(int)),axis=2)<=48))
    ratio=matches/total
    assert ratio>.80,f"Message scale/centering mismatch: {shot}: {ratio:.3f}"
    return dict(capture=str(shot),width=w,height=h,scale=scale,matched=ratio)

def main():
    p=argparse.ArgumentParser();p.add_argument("--engine",required=True);p.add_argument("--data",required=True);p.add_argument("--module",required=True);p.add_argument("--output",required=True);p.add_argument("--messages",action="store_true")
    a=p.parse_args();base=Path(a.output).resolve();base.mkdir(parents=True,exist_ok=False)
    game=base/"menusys_test";game.mkdir();id1=base/"id1";id1.mkdir()
    for name in ("pak0.pak","pak1.pak"):shutil.copy2(Path(a.data)/name,id1/name)
    shutil.copy2(a.module,game/"menu.dat");files=pak_files(a.data);(game/"completion.dem").write_bytes(demo(files,not a.messages))
    (game/"quake.rc").write_text("exec default.cfg\nexec config.cfg\nexec autoexec.cfg\nm_textscale\nstuffcmds\n")
    (game/"autoexec.cfg").write_text('alias startdemos ""\nhost_maxfps 60\ncrosshair 0\nscr_centertime 1000\nbind F12 "screenshot png"\nm_main\ntogglemenu\nplaydemo completion\n')
    (game/"config.cfg").write_text('seta menu_messageauto 1\nscr_menuscale 100\nseta menu_zoom 0\n')
    results=[]
    for phase,zoom in [("automatic",0),("restart",0),("fixed",3),("automatic-return",0)]:
        if phase in ("fixed","automatic-return"):
            with (game/"config.cfg").open("a") as f:f.write(f'\nseta menu_zoom {zoom}\nscr_sbarscale 4\nseta menu_consoleauto 0\nscr_conwidth 0\nscr_conscale 3\n')
        startup=subprocess.STARTUPINFO();startup.dwFlags=subprocess.STARTF_USESHOWWINDOW;startup.wShowWindow=0
        proc=subprocess.Popen([a.engine,"-basedir",str(base),"-game","menusys_test","-window","-width","960","-height","600","-condebug"],cwd=base,startupinfo=startup)
        try:
            deadline=time.monotonic()+15;hwnd=None
            while not hwnd and time.monotonic()<deadline:hwnd=window(proc.pid);time.sleep(.1)
            assert hwnd,"Engine window missing"
            time.sleep(4)
            assert proc.poll() is None, f"Engine exited: {proc.returncode}"
            hwnd=window(proc.pid)
            assert hwnd, "Window disappeared after initialization"
            for w,h in [(960,600),(400,300),(1920,1080),(3840,2070),(600,960)]:
                resize(hwnd,w,h);time.sleep(.4)
                shot=capture(hwnd,game)
                with Image.open(shot) as im:
                    assert im.size==(w,h), f"Requested window size not reached: {im.size} != {(w,h)}"
                nativezoom=zoom or (max(1,min(w/640,h/400)) if a.messages else 1.5)
                verify=check_message if a.messages else check
                results.append(dict(phase=phase,**verify(shot,files,nativezoom)))
            if not a.messages:
                # Opening MenuQC refreshes native scaling; closing restores scores.
                key(hwnd,0x1B,1);time.sleep(.5);key(hwnd,0x1B,1);time.sleep(.5)
                nativezoom=zoom or 1
                results.append(dict(phase=phase+"-menu-refresh",**check(capture(hwnd,game),files,nativezoom)))
            # Request graceful shutdown so QSS writes the persistent config.
            user.PostMessageW(hwnd,0x10,0,0);proc.wait(timeout=10)
            cfg=(game/"config.cfg").read_text()
            assert f'seta menu_zoom "{zoom:g}"' in cfg
            assert f'scr_menuscale "{nativezoom:g}"' in cfg
            shutil.copy2(game/"config.cfg",base/(phase+".cfg"))
            log=(base/"qconsole.log").read_text(errors="replace")
            (base/(phase+".log")).write_text(log)
            assert not re.search(r"Host_Error|PR_RunError|Bad server message|Program error",log), "Engine/VM error"
            # LibreQuake's default.cfg contains these unsupported QSS 2021 commands.
            baseline=set("if vid_fsaamode scr_pixelaspect sv_autoload cl_fakeshaft gl_texturemode_viewmodels r_lerpmuzzlehack gl_texturemode_sky gl_texturemode_hud gl_overbright_model gl_smoothfont cl_stainmaps cl_decals cl_particles_quake cl_beams_polygons r_font_postprocess_mono r_waterscroll".split())
            unknown=set(re.findall(r'Unknown command "([^"\n]+)"',log))
            assert not unknown-baseline, f"Unexpected commands: {unknown-baseline}"
        finally:
            if proc.poll() is None:proc.terminate();proc.wait(timeout=10)
    (base/"results.json").write_text(json.dumps(results,indent=2))
    print(f"PASS: {len(results)} native overlay captures; automatic/fixed zoom, restart, independent HUD/console and live resizing")
if __name__=="__main__":main()
