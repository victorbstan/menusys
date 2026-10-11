[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string] $Compiler,
    [Parameter(Mandatory = $true)][string] $Engine,
    [Parameter(Mandatory = $true)][string] $GameData,
    [Parameter(Mandatory = $true)][string] $MenuPak,
    [string] $TestName = 'navigation',
    [int] $Width = 960,
    [int] $Height = 600,
    [switch] $InGame
)
$ErrorActionPreference = 'Stop'
if ($TestName -notmatch '^[a-zA-Z0-9_-]+$') { throw 'Invalid test name.' }
$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$testRoot = Join-Path $root "dist/runtime/$TestName"
if (Test-Path -LiteralPath $testRoot) { throw "Test output already exists: $testRoot" }
$build = Join-Path $root 'dist/build'
[void](New-Item -ItemType Directory -Path $build -Force)
$target = Join-Path $build 'navigation-menu.dat'
$wrapper = Join-Path $build 'navigation.src'
[IO.File]::WriteAllText($wrapper, "#include `"../../tests/menu-navigation.src`"`n#pragma progs_dat `"navigation-menu.dat`"`n")
Push-Location $build
try {
    if (Test-Path -LiteralPath $target) { Remove-Item -LiteralPath $target }
    & $Compiler -srcfile $wrapper
    if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $target)) { throw 'Navigation fixture compilation failed.' }
} finally { Pop-Location }
$id1 = Join-Path $testRoot 'id1'
$game = Join-Path $testRoot 'menusys_test'
[void](New-Item -ItemType Directory -Path $id1)
[void](New-Item -ItemType Directory -Path $game)
foreach ($name in @('pak0.pak','pak1.pak')) { Copy-Item -LiteralPath (Join-Path $GameData $name) -Destination $id1 }
Copy-Item -LiteralPath $MenuPak -Destination (Join-Path $game 'menu.pak')
Copy-Item -LiteralPath $target -Destination (Join-Path $game 'menu.dat')
[IO.File]::WriteAllLines((Join-Path $game 'quake.rc'), @('exec default.cfg','exec autoexec.cfg','stuffcmds'))
$startup = @('developer 1','cl_maxfps 60','alias startdemos ""','in 1 forceqmenu 0','in 1 menu_restart','in 1.2 vid_conautoscale 4')
if ($InGame) { $startup += @('in 1.3 map start','in 7 exec navigation.cfg') }
else { $startup += 'in 1.5 exec navigation.cfg' }
[IO.File]::WriteAllLines((Join-Path $game 'autoexec.cfg'), $startup)
[IO.File]::WriteAllLines((Join-Path $game 'navigation.cfg'), @(
    'in 0.2 nav_open', 'in 0.5 nav_action join', 'in 2 nav_key DOWNARROW',
    'in 2.3 nav_key END', 'in 2.8 nav_key ESCAPE', 'in 3.2 nav_action setup',
    'in 3.6 nav_key ESCAPE', 'in 4 nav_action join', 'in 4.6 nav_action refresh',
    'in 5 nav_assert refreshed', 'in 5.5 nav_action advanced',
    'in 5.8 nav_assertscale 0', 'in 6 screenshot advanced.png', 'in 6.8 closemenu', 'in 8 nav_open', 'in 8.4 nav_action join',
    'in 9 nav_key END', 'in 9.4 nav_key ESCAPE', 'in 9.8 nav_action join',
    'in 10.4 nav_assert returned', 'in 10.6 nav_assertscale 4', 'in 10.8 screenshot returned.png',
    'in 11 nav_focuslist', 'in 11.2 nav_key F5', 'in 12 nav_assert key-refresh',
    'in 12.2 nav_action favs', 'in 12.8 nav_assert filtered', 'in 13.2 nav_action favs',
    'in 13.8 nav_action empty', 'in 14.4 nav_assert filtered', 'in 15 nav_action empty',
    'in 15.6 nav_action full', 'in 16.2 nav_assert filtered', 'in 16.8 nav_action full',
    'in 17.4 nav_action nq', 'in 18 nav_assert filtered', 'in 18.6 nav_action nq',
    'in 19.2 nav_action qw', 'in 19.8 nav_assert filtered', 'in 20.4 nav_action qw',
    'in 21 nav_action address', 'in 21.2 nav_focuslist', 'in 21.6 nav_key END',
    'in 22 nav_assert returned', 'in 22.4 nav_action advanced', 'in 22.8 nav_assertscale 0', 'in 24.6 closemenu',
    'in 25.4 nav_open', 'in 26 nav_action join', 'in 27 nav_assert final',
    'in 27.5 screenshot final.png', 'in 28 quit'
))
# closemenu runs the native browser's removal callback. MenuQC key hooks only
# exercise our widgets, so they cannot dismiss a native menu.
$engineArgs = @('-nohome','+set','vid_fullscreen','0','-basedir',('"'+$testRoot+'"'),'-game','menusys_test','-window','-width',$Width,'-height',$Height,'-condebug')
$process = Start-Process -FilePath $Engine -ArgumentList $engineArgs -WorkingDirectory $testRoot -WindowStyle Hidden -PassThru
if (-not $process.WaitForExit(55000)) { Stop-Process -Id $process.Id; throw "Navigation timed out: $testRoot" }
# This Windows FTE build returns 1 from Sys_Quit even after a normal shutdown.
if ($process.ExitCode -notin @(0,1)) { throw "Engine exited with $($process.ExitCode): $testRoot" }
$logs = @(Get-ChildItem -LiteralPath $testRoot -Recurse -Filter '*.log')
$errors = @($logs | Select-String -Pattern 'NAV FAIL|Unknown command|unimplemented builtin|Host_Error|Menu_Abort|PF_strunzone:|Bad string|NULL function|runaway loop')
if ($errors.Count) { throw ($errors.Line -join "`n") }
foreach ($checkpoint in @('refreshed','key-refresh','returned','final')) {
    if (-not ($logs | Select-String -Pattern "NAV checkpoint $checkpoint active Servers List")) { throw "Missing Join checkpoint: $checkpoint" }
}

foreach ($name in @('advanced','returned','final')) {
    if (-not (Test-Path -LiteralPath (Join-Path $game "$name.png"))) { throw "Missing navigation screenshot: $name" }
}
Get-ChildItem -LiteralPath $game -Filter '*.png' | Select-Object FullName,Length
