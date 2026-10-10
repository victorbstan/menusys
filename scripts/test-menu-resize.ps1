[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string] $Compiler,
    [Parameter(Mandatory=$true)][string] $Fte,
    [Parameter(Mandatory=$true)][string] $Qss,
    [Parameter(Mandatory=$true)][string] $QuakeData,
    [Parameter(Mandatory=$true)][string] $LibreQuakeData,
    [Parameter(Mandatory=$true)][string] $SupportDirectory,
    [ValidateRange(0,4)][double] $MenuZoom = 0,
    [switch] $CheckNativeZooms,
    [string] $TestName = 'issue6-resize',
    [ValidateSet('fte-id1','fte-librequake','qss-id1','qss-librequake')][string[]] $Cases = @('fte-id1','fte-librequake','qss-id1','qss-librequake')
)
$ErrorActionPreference='Stop'
if($TestName -notmatch '^[a-zA-Z0-9_-]+$'){throw 'Invalid test name'}
$root=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$output=Join-Path $root "dist/runtime/$TestName"
if(Test-Path -LiteralPath $output){throw "Output already exists: $output"}
[void](New-Item -ItemType Directory -Path $output)
$build=Join-Path $root 'dist/build'
[void](New-Item -ItemType Directory -Force -Path $build)
[IO.File]::WriteAllText((Join-Path $build 'resize.src'),"#include `"../../tests/menu-scaling.src`"`n#pragma progs_dat `"resize-menu.dat`"`n")
Push-Location $build
try{
    $compile=@(& $Compiler -srcfile resize.src)
    $compile | Set-Content (Join-Path $output 'compiler.log')
    if($LASTEXITCODE -ne 0 -or ($compile -match 'warning:|warning Q|[1-9][0-9]* warnings').Count){throw 'Fixture must compile with zero warnings'}
}finally{Pop-Location}
. (Join-Path $PSScriptRoot 'scaling-test-tools.ps1')
if(-not ('ScalingWindow' -as [type])){
Add-Type -TypeDefinition @'
using System;
using System.Text;
using System.Runtime.InteropServices;
public static class ScalingWindow {
    public delegate bool EnumProc(IntPtr h, IntPtr l);
    [StructLayout(LayoutKind.Sequential)] public struct Rect { public int L,T,R,B; }
    [DllImport("user32.dll")] static extern bool EnumWindows(EnumProc cb,IntPtr l);
    [DllImport("user32.dll")] static extern uint GetWindowThreadProcessId(IntPtr h,out uint p);
    [DllImport("user32.dll")] static extern bool GetClientRect(IntPtr h,out Rect r);
    [DllImport("user32.dll")] static extern bool GetWindowRect(IntPtr h,out Rect r);
    [DllImport("user32.dll")] static extern int GetClassName(IntPtr h,StringBuilder s,int n);
    [DllImport("user32.dll")] static extern bool SetWindowPos(IntPtr h,IntPtr after,int x,int y,int w,int height,uint f);
    [DllImport("user32.dll")] static extern IntPtr SetThreadDpiAwarenessContext(IntPtr context);
    public static IntPtr Find(int pid) {
        SetThreadDpiAwarenessContext((IntPtr)(-4));
        IntPtr result=IntPtr.Zero;
        EnumWindows((h,l)=> { uint p; Rect r; GetWindowThreadProcessId(h,out p);
            var name=new StringBuilder(100);GetClassName(h,name,100);
            if(p==(uint)pid && (name.ToString()=="SDL_app" || name.ToString()=="FTEGLQuake") && GetClientRect(h,out r) && r.R>100 && r.B>100) result=h;
            return true;
        },IntPtr.Zero);
        return result;
    }
    public static void Resize(IntPtr h,int w,int height) {
        SetThreadDpiAwarenessContext((IntPtr)(-4));
        Rect c,r;GetClientRect(h,out c);GetWindowRect(h,out r);
        if(!SetWindowPos(h,IntPtr.Zero,0,0,w+r.R-r.L-c.R,height+r.B-r.T-c.B,0x14)) throw new Exception("Resize failed");
    }
}
'@
}
$results=@()
foreach($case in $Cases){
    $isQss=$case.StartsWith('qss');$engine=if($isQss){$Qss}else{$Fte}
    $data=if($case.EndsWith('librequake')){$LibreQuakeData}else{$QuakeData}
    $base=Join-Path $output $case;$game=Join-Path $base 'menusys_test';$id1=Join-Path $base 'id1'
    [void](New-Item -ItemType Directory -Force -Path $game,$id1)
    foreach($name in @('pak0.pak','pak1.pak')){Copy-Item -LiteralPath (Join-Path $data $name) -Destination $id1}
    Copy-Item -LiteralPath (Join-Path $SupportDirectory 'menugfx') -Destination $game -Recurse
    Copy-Item -LiteralPath (Join-Path $build 'resize-menu.dat') -Destination (Join-Path $game 'menu.dat')
    [IO.File]::WriteAllLines((Join-Path $game 'quake.rc'),@('exec default.cfg','exec autoexec.cfg'))
    $commands=@('developer 1','alias startdemos ""','cl_cursor ""',"seta menu_zoom $MenuZoom")
    if($CheckNativeZooms){$commands+=@('seta scaling_test_nativezoom 1','seta menu_consoleauto 1','seta menu_fteconsolezoom 0','seta menu_hudauto 1')}
    if($isQss){$commands+='host_maxfps 60'}
    else{$commands+=@('cl_maxfps 60','cl_maxidlefps 60','vid_resizable 1','in 1 forceqmenu 0','in 1 menu_restart','in 1.5 scale_open main','in 1.6 scale_live')}
    if($isQss){$commands+=(('wait;'*30)+'scale_open main;scale_live')}
    [IO.File]::WriteAllLines((Join-Path $game 'autoexec.cfg'),$commands)
    $arguments=@('-basedir',('"'+$base+'"'),'-game','menusys_test','-window','-width','960','-height','600','-condebug')
    if(-not $isQss){$arguments=@('-nohome','+set','vid_fullscreen','0')+$arguments}
    [IO.File]::WriteAllText((Join-Path $game 'scale-request.txt'),'0')
    $process=Start-Process -FilePath $engine -ArgumentList $arguments -WorkingDirectory $base -WindowStyle Hidden -PassThru
    $errors=@()
    try{
        $handle=[IntPtr]::Zero;$deadline=[DateTime]::UtcNow.AddSeconds(10)
        while($handle -eq [IntPtr]::Zero -and [DateTime]::UtcNow -lt $deadline){Start-Sleep -Milliseconds 100;$handle=[ScalingWindow]::Find($process.Id)}
        if($handle -eq [IntPtr]::Zero){throw 'Missing engine window'}
        $sizes=@(@(960,600),@(600,960),@(1920,1080),@(1920,1080))
        for($step=1;$step -le 4;$step++){
            $w=$sizes[$step-1][0];$h=$sizes[$step-1][1]
            if($step -lt 4){[ScalingWindow]::Resize($handle,$w,$h)}
            else{
                # The fixture injects engine-space pointer input at a known
                # physical point and runs production hover/click handling.
            }
            [IO.File]::WriteAllText((Join-Path $game 'scale-request.txt'),[string]$step)
            $filename=if($isQss){'spasm{0:d4}.png' -f ($step-1)}else{"live$step.png"}
            $path=Join-Path $game $filename
            # Allow high-resolution PNG writes to finish after pointer activation.
            $deadline=[DateTime]::UtcNow.AddSeconds(20)
            $complete=$false
            while(-not $complete -and [DateTime]::UtcNow -lt $deadline -and -not $process.HasExited){
                Start-Sleep -Milliseconds 100
                if(Test-Path -LiteralPath $path){
                    try{
                        $bytes=[IO.File]::ReadAllBytes($path)
                        $complete=$bytes.Length -gt 12 -and [Text.Encoding]::ASCII.GetString($bytes,$bytes.Length-8,4) -eq 'IEND'
                    }catch [IO.IOException]{}
                }
            }
            if(-not $complete){throw "Missing or incomplete live checkpoint $step"}
            $m=Measure-Marker $path $MenuZoom;$expected=32*(Get-TestZoom $w $h $MenuZoom)
            if($m[0] -ne $w -or $m[1] -ne $h){$errors+="Stale drawable size at $step : $($m[0])x$($m[1])"}
            if([Math]::Abs($m[4]-$m[5]) -gt 1 -or [Math]::Abs($m[4]-$expected) -gt 2){$errors+="Physical scaling at $step : $($m[4])x$($m[5]), expected $expected"}
        }
        [IO.File]::WriteAllText((Join-Path $game 'scale-request.txt'),'-1')
        if(-not $process.WaitForExit(5000)){throw 'Engine did not exit'}
    }catch{$errors+=$_.Exception.Message}finally{if(-not $process.HasExited){Stop-Process -Id $process.Id}}
    $logs=@(Get-ChildItem -LiteralPath $base -Recurse -Filter '*.log')
    $errors+=@(Get-ScalingErrors $logs ($case -eq 'qss-librequake'))
    if(-not($logs | Select-String 'SCALE LIVE 4 active Singleplayer Menu')){$errors+='Scaled mouse target was not activated'}
    $results+=[pscustomobject]@{Case=$case;Passed=($errors.Count -eq 0);Errors=$errors}
    Write-Host "$case : $(if($errors.Count){'FAIL'}else{'PASS'}) ($($errors.Count) errors)"
}
$results | ConvertTo-Json -Depth 5 | Set-Content (Join-Path $output 'results.json')
if(@($results | Where-Object{-not $_.Passed}).Count){throw "Resize regressions found. See $output/results.json"}
Write-Host 'PASS: native window resize, portrait/landscape aspect and production pointer activation in all four combinations.'
