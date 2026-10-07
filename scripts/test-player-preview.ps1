[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string] $Compiler,
    [Parameter(Mandatory = $true)][string] $Engine,
    [Parameter(Mandatory = $true)][string] $GameData,
    [Parameter(Mandatory = $true)][string] $TestName,
    [switch] $Qss
)
$ErrorActionPreference = 'Stop'
if ($TestName -notmatch '^[a-zA-Z0-9_-]+$') { throw 'Invalid test name.' }
$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$build = Join-Path $root 'dist/build'
$testRoot = Join-Path $root "dist/runtime/$TestName"
if (Test-Path -LiteralPath $testRoot) { throw "Test output already exists: $testRoot" }
$id1 = Join-Path $testRoot 'id1'
$game = Join-Path $testRoot 'menusys_test'
[void](New-Item -ItemType Directory -Path $id1)
[void](New-Item -ItemType Directory -Path $game)
foreach ($name in @('pak0.pak', 'pak1.pak')) {
    Copy-Item -LiteralPath (Join-Path $GameData $name) -Destination $id1
}
& (Join-Path $PSScriptRoot 'build-player-preview.ps1') -Pak (Join-Path $id1 'pak0.pak') -OutputDirectory (Join-Path $game 'menugfx/playerpreview')
$wrapper = Join-Path $build 'player-preview.src'
$target = Join-Path $build 'player-preview.dat'
[IO.File]::WriteAllText($wrapper, "#include `"../../tests/player-preview.src`"`n#pragma progs_dat `"player-preview.dat`"`n")
Push-Location $build
try {
    & $Compiler -srcfile $wrapper
    if ($LASTEXITCODE -ne 0) { throw 'Preview test compilation failed.' }
} finally { Pop-Location }
Copy-Item -LiteralPath $target -Destination (Join-Path $game 'menu.dat')
[IO.File]::WriteAllLines((Join-Path $game 'quake.rc'), @('exec default.cfg', 'exec autoexec.cfg', 'stuffcmds'))
$commands = @('developer 1', 'alias startdemos ""', 'cl_cursor ""')
if ($Qss) { $commands += @('host_maxfps 60', 'scr_menuscale 1') }
else { $commands += @('cl_maxfps 60', 'cl_maxidlefps 60', 'forceqmenu 0') }
[IO.File]::WriteAllLines((Join-Path $game 'autoexec.cfg'), $commands)
[IO.File]::WriteAllLines((Join-Path $game 'preview-start.cfg'), $commands)
$engineArgs = @('-basedir', ('"' + $testRoot + '"'), '-game', 'menusys_test', '-window', '-width', '960', '-height', '600', '-condebug')
if (-not $Qss) { $engineArgs = @('-nohome', '+set', 'vid_fullscreen', '0') + $engineArgs + @('+exec', 'preview-start.cfg') }
$process = Start-Process -FilePath $Engine -ArgumentList $engineArgs -WorkingDirectory $testRoot -WindowStyle Hidden -PassThru
if (-not $Qss) {
    # FTE skips SCR_UpdateScreen while minimized. Keep its test window offscreen
    # without activating it so the real renderer still exercises m_draw.
    if (-not ('PreviewTestWindow' -as [type])) {
        Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class PreviewTestWindow {
    [DllImport("user32.dll")] public static extern bool SetWindowPos(IntPtr w, IntPtr after, int x, int y, int cx, int cy, uint flags);
    [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr w, int command);
}
'@
    }
    for ($attempt = 0; $attempt -lt 50 -and -not $process.HasExited; $attempt++) {
        $process.Refresh()
        if ($process.MainWindowHandle -ne [IntPtr]::Zero) {
            [void][PreviewTestWindow]::SetWindowPos($process.MainWindowHandle, [IntPtr]::Zero, -10000, -10000, 0, 0, 0x15)
            [void][PreviewTestWindow]::ShowWindow($process.MainWindowHandle, 4)
            break
        }
        Start-Sleep -Milliseconds 100
    }
}
if (-not $process.WaitForExit(30000)) {
    Stop-Process -Id $process.Id
    throw "Preview test timed out: $testRoot"
}
$logs = @(Get-ChildItem -LiteralPath $testRoot -Recurse -Filter '*.log')
$logText = ($logs | ForEach-Object { [IO.File]::ReadAllText($_.FullName) }) -join "`n"
if ($logText -match 'PREVIEW FAIL|Host_Error|Menu_Abort|unimplemented builtin|Unknown command') { throw "Runtime failure: $testRoot`n$logText" }
if ($logText -notmatch 'PREVIEW COMPLETE') { throw "Test did not finish: $testRoot`n$logText" }
$shots = @(Get-ChildItem -LiteralPath $game -Recurse -Filter '*.png' | Sort-Object Name)
if ($shots.Count -ne 4) { throw "Expected 4 screenshots, got $($shots.Count): $testRoot" }
$names = @('initial', 'shirt-change', 'pants-change', 'external-change')
for ($i = 0; $i -lt $shots.Count; $i++) {
    Move-Item -LiteralPath $shots[$i].FullName -Destination (Join-Path $game ($names[$i] + '.png'))
}
Write-Host ($logText -split "`n" | Where-Object { $_ -match 'PREVIEW' })
& (Join-Path $PSScriptRoot 'verify-player-preview.ps1') -Pak (Join-Path $id1 'pak0.pak') -LayerDirectory (Join-Path $game 'menugfx/playerpreview') -RuntimeDirectory $testRoot
Write-Host "Preview test passed: $testRoot"
