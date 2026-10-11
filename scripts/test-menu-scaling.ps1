[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string] $Compiler,
    [Parameter(Mandatory=$true)][string] $Fte,
    [Parameter(Mandatory=$true)][string] $Qss,
    [Parameter(Mandatory=$true)][string] $QuakeData,
    [Parameter(Mandatory=$true)][string] $LibreQuakeData,
    [Parameter(Mandatory=$true)][string] $SupportDirectory,
    [string[]] $Cases = @('fte-id1','fte-librequake','qss-id1','qss-librequake'),
    [string[]] $Sizes = @('400x300','960x600','1920x1080','3840x2070'),
    [ValidateRange(0,4)][double] $MenuZoom = 0,
    [switch] $CheckNativeZooms,
    [switch] $ImageAudit,
    [string] $TestName = 'issue6-scaling'
)
$ErrorActionPreference='Stop'
if($TestName -notmatch '^[a-zA-Z0-9_-]+$'){throw 'Invalid test name'}
$root=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$output=Join-Path $root "dist/runtime/$TestName"
if(Test-Path -LiteralPath $output){throw "Output already exists: $output"}
[void](New-Item -ItemType Directory -Path $output)
$build=Join-Path $root 'dist/build'
[void](New-Item -ItemType Directory -Force -Path $build)
[IO.File]::WriteAllText((Join-Path $build 'scaling.src'),"#include `"../../tests/menu-scaling.src`"`n#pragma progs_dat `"scaling-menu.dat`"`n")
Push-Location $build
try{
    $compile=@(& $Compiler -srcfile scaling.src)
    $compile | Set-Content (Join-Path $output 'compiler.log')
    if($LASTEXITCODE -ne 0 -or ($compile -match 'warning:|warning Q|[1-9][0-9]* warnings').Count){throw 'Fixture must compile with zero warnings'}
}finally{Pop-Location}
. (Join-Path $PSScriptRoot 'scaling-test-tools.ps1')
$screens=@('main','single','multi','options','basic','video','keys','audio','effects','newgame','setup','help','levels','demos','load','video-scrolled')
if($ImageAudit){$screens+=@('save','particles','hud','configs','presets','cvars','mods','help1','help2','help3','help4','help5')}
$results=@()
foreach($case in $Cases){
    if($case -notin @('fte-id1','fte-librequake','qss-id1','qss-librequake')){throw 'Invalid case'}
    $isQss=$case.StartsWith('qss');$engine=if($isQss){$Qss}else{$Fte}
    $data=if($case.EndsWith('librequake')){$LibreQuakeData}else{$QuakeData}
    foreach($size in $Sizes){
        if($size -notmatch '^(\d+)x(\d+)$'){throw 'Invalid size'}
        $width=[int]$Matches[1];$height=[int]$Matches[2]
        $base=Join-Path $output "$case-$size";$game=Join-Path $base 'menusys_test';$id1=Join-Path $base 'id1'
        [void](New-Item -ItemType Directory -Force -Path $game,$id1)
        foreach($name in @('pak0.pak','pak1.pak')){Copy-Item -LiteralPath (Join-Path $data $name) -Destination $id1}
        Copy-Item -LiteralPath (Join-Path $SupportDirectory 'menugfx') -Destination $game -Recurse
        & (Join-Path $PSScriptRoot 'build-player-preview.ps1') -Pak (Join-Path $id1 'pak0.pak') -OutputDirectory (Join-Path $game 'menugfx/playerpreview') | Out-Null
        Copy-Item -LiteralPath (Join-Path $build 'scaling-menu.dat') -Destination (Join-Path $game 'menu.dat')
        [IO.File]::WriteAllLines((Join-Path $game 'quake.rc'),@('exec default.cfg','exec autoexec.cfg'))
        $commands=@('developer 1','alias startdemos ""','cl_cursor ""',"seta menu_zoom $MenuZoom")
    if($CheckNativeZooms){$commands+=@('seta scaling_test_nativezoom 1','seta menu_consoleauto 1','seta menu_fteconsolezoom 0','seta menu_hudauto 1')}
        if($isQss){$commands+=@('host_maxfps 60')}
        else{$commands+=@('cl_maxfps 60','cl_maxidlefps 60',(('wait;'*60)+'forceqmenu 0;menu_restart'))}
        $pause='wait;'*20
        foreach($screen in $screens){
            $open=if($screen -eq 'video-scrolled'){'scale_open video;scale_scroll'}else{"scale_open $screen"}
            $shot=if($isQss){'screenshot png'}else{"screenshot $screen.png"}
            $commands+="$pause $open; $pause scale_check; $shot"
        }
        $commands+='quit'
        [IO.File]::WriteAllLines((Join-Path $game 'autoexec.cfg'),$commands)
        $arguments=@('-basedir',('"'+$base+'"'),'-game','menusys_test','-window','-width',$width,'-height',$height,'-condebug')
        if(-not $isQss){$arguments=@('-nohome','+set','vid_fullscreen','0')+$arguments}
        $process=Start-Process -FilePath $engine -ArgumentList $arguments -WorkingDirectory $base -WindowStyle Hidden -PassThru
        $errors=@()
        if(-not $process.WaitForExit([Math]::Max(55000, $screens.Count*2500))){Stop-Process -Id $process.Id;$errors+='Engine timed out'}
        if($isQss){
            $shots=@(Get-ChildItem -LiteralPath $game -Filter 'spasm*.png' | Sort-Object Name)
            if($shots.Count -eq $screens.Count){for($i=0;$i -lt $shots.Count;$i++){Move-Item -LiteralPath $shots[$i].FullName -Destination (Join-Path $game ($screens[$i]+'.png'))}}
        }
        $logs=@(Get-ChildItem -LiteralPath $base -Recurse -Filter '*.log')
        $errors+=@(Get-ScalingErrors $logs ($case -eq 'qss-librequake'))
        if(@($logs | Select-String 'SCALE checked').Count -ne $screens.Count){$errors+='Missing geometry checkpoints'}
        foreach($screen in $screens){
            $path=Join-Path $game "$screen.png"
            if(-not(Test-Path -LiteralPath $path)){$errors+="Missing $screen screenshot";continue}
            $m=Measure-Marker $path $MenuZoom;$expected=32*(Get-TestZoom $m[0] $m[1] $MenuZoom)
            if(-not(Test-PixelFont $path)){$errors+="Font interpolation/resampling $screen"}
            if($m[0] -ne $width -or $m[1] -ne $height){$errors+="Wrong drawable dimensions $screen : $($m[0])x$($m[1])"}
            if([Math]::Abs($m[4]-$m[5]) -gt 1 -or [Math]::Abs($m[4]-$expected) -gt 2){$errors+="Physical aspect/scale $screen : $($m[4])x$($m[5]), expected $expected"}
        }
        # Contact sheets are for human review; keep original engine captures.
        $sheet=[Drawing.Bitmap]::new(1280,[int](240*[Math]::Ceiling($screens.Count/4.0)));$g=[Drawing.Graphics]::FromImage($sheet);$g.Clear([Drawing.Color]::Black)
        $font=[Drawing.Font]::new('Arial',11)
        try{
            for($i=0;$i -lt $screens.Count;$i++){
                $x=($i%4)*320;$y=[Math]::Floor($i/4)*240
                $g.DrawString($screens[$i],$font,[Drawing.Brushes]::White,$x+6,$y+3)
                $path=Join-Path $game ($screens[$i]+'.png')
                if(Test-Path -LiteralPath $path){
                    $img=[Drawing.Image]::FromFile($path)
                    try{$s=[Math]::Min(320.0/$img.Width,216.0/$img.Height);$g.DrawImage($img,[single]($x+(320-$img.Width*$s)/2),[single]($y+24),[single]($img.Width*$s),[single]($img.Height*$s))}finally{$img.Dispose()}
                }
            }
            $sheet.Save((Join-Path $output "$case-$size.png"),[Drawing.Imaging.ImageFormat]::Png)
        }finally{$font.Dispose();$g.Dispose();$sheet.Dispose()}
        $results += [pscustomobject]@{Case=$case;Size=$size;Screens=$screens.Count;Passed=($errors.Count -eq 0);Errors=$errors}
        Write-Host "$case $size : $(if($errors.Count){'FAIL'}else{'PASS'}) ($($errors.Count) errors)"
    }
}
$results | ConvertTo-Json -Depth 5 | Set-Content (Join-Path $output 'results.json')
if(@($results | Where-Object{-not $_.Passed}).Count){throw "Scaling regressions found. See $output/results.json"}
Write-Host "PASS: all scaling cases. Review contact sheets and originals in $output"
