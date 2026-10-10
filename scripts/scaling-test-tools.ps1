Add-Type -AssemblyName System.Drawing
function Get-ScalingErrors($Logs,[bool] $LibreQss){
    # LibreQuake 0.09-beta default.cfg contains options unsupported by QSS 2021.
    # Only allow this exact upstream startup baseline before fixture checkpoints.
    $known='if|vid_fsaamode|scr_pixelaspect|sv_autoload|cl_fakeshaft|gl_texturemode_viewmodels|r_lerpmuzzlehack|gl_texturemode_sky|gl_texturemode_hud|gl_overbright_model|gl_smoothfont|cl_stainmaps|cl_decals|cl_particles_quake|cl_beams_polygons|r_font_postprocess_mono|r_waterscroll'
    foreach($log in $Logs){
        $checkpoint=Select-String -LiteralPath $log.FullName -Pattern 'SCALE checked|SCALE LIVE|PREF native' | Select-Object -First 1
        foreach($error in @(Select-String -LiteralPath $log.FullName -Pattern 'SCALE FAIL|Unknown command|unimplemented builtin|Host_Error|Menu_Abort|PF_strunzone:|W_GetLumpName:.*not found|Cvar_Set: variable .* not found')){
            if($LibreQss -and $checkpoint -and $error.LineNumber -lt $checkpoint.LineNumber -and $error.Line -match ('^Unknown command "('+ $known +')"$')){
                Add-Content -LiteralPath (Join-Path $log.DirectoryName 'startup-warnings.txt') -Value $error.Line
            }else{$error.Line}
        }
    }
}
if(-not ('ScalingPixels' -as [type])){
Add-Type -TypeDefinition @'
using System;
public static class ScalingPixels {
    public static int[] Marker(byte[] pixels, int width, int height, int stride) {
            int left=width, top=height, right=-1, bottom=-1;
            for(int y=0;y<height;y++)
            for(int x=0;x<width;x++) {
                int p=y*stride+x*4;
                if(pixels[p+2]>240 && pixels[p+1]<15 && pixels[p]>240) {
                    left=Math.Min(left,x);top=Math.Min(top,y);
                    right=Math.Max(right,x);bottom=Math.Max(bottom,y);
                }
            }
            return new int[]{left,top,right-left+1,bottom-top+1};
    }
}
'@
}
function Get-TestZoom([double] $Width,[double] $Height,[double] $Zoom){
    if($Zoom -gt 0){return [Math]::Min($Zoom,[Math]::Min($Width/320.0,$Height/200.0))}
    return [Math]::Min($Width/640.0,$Height/400.0)
}
function Measure-Marker([string] $Path,[double] $Zoom=0){
    $bitmap=[Drawing.Bitmap]::new($Path)
    try{
        $limit=[int][Math]::Ceiling(44*(Get-TestZoom $bitmap.Width $bitmap.Height $Zoom))+4
        $rectangle=[Drawing.Rectangle]::new(0,0,[Math]::Min($bitmap.Width,$limit),[Math]::Min($bitmap.Height,$limit))
        $bits=$bitmap.LockBits($rectangle,[Drawing.Imaging.ImageLockMode]::ReadOnly,[Drawing.Imaging.PixelFormat]::Format32bppArgb)
        try{
            $pixels=New-Object byte[] ($bits.Stride*$bits.Height)
            [Runtime.InteropServices.Marshal]::Copy($bits.Scan0,$pixels,0,$pixels.Length)
            return @($bitmap.Width,$bitmap.Height)+[ScalingPixels]::Marker($pixels,$bits.Width,$bits.Height,$bits.Stride)
        }finally{$bitmap.UnlockBits($bits)}
    }finally{$bitmap.Dispose()}
}
