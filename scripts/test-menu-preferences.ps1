[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string] $Compiler,
    [Parameter(Mandatory = $true)][string] $Engine,
    [Parameter(Mandatory = $true)][string] $GameData,
    [Parameter(Mandatory = $true)][string] $SupportDirectory,
    [string] $TestName = 'preferences'
)
$ErrorActionPreference = 'Stop'
if ($TestName -notmatch '^[a-zA-Z0-9_-]+$') { throw 'Invalid test name' }
$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$base = Join-Path $root "dist/runtime/$TestName"
if (Test-Path -LiteralPath $base) { throw "Test output already exists: $base" }
$build = Join-Path $root 'dist/build'
[void](New-Item -ItemType Directory -Force -Path $build)
[IO.File]::WriteAllText((Join-Path $build 'preferences.src'), "#include `"../../tests/menu-preferences.src`"`n#pragma progs_dat `"preferences-menu.dat`"`n")
Push-Location $build
try {
    & $Compiler -srcfile preferences.src
    if ($LASTEXITCODE -ne 0) { throw 'Fixture compilation failed' }
} finally { Pop-Location }
$game = Join-Path $base 'menusys_test'
$id1 = Join-Path $base 'id1'
[void](New-Item -ItemType Directory -Force -Path $game, $id1)
foreach ($name in @('pak0.pak','pak1.pak')) {
    Copy-Item -LiteralPath (Join-Path $GameData $name) -Destination $id1
}
Copy-Item -LiteralPath (Join-Path $SupportDirectory 'menugfx') -Destination $game -Recurse
Copy-Item -LiteralPath (Join-Path $build 'preferences-menu.dat') -Destination (Join-Path $game 'menu.dat')
[IO.File]::WriteAllLines((Join-Path $game 'quake.rc'), @('exec default.cfg','exec config.cfg','exec autoexec.cfg','m_textscale','stuffcmds'))
[IO.File]::WriteAllText((Join-Path $game 'autoexec.cfg'), 'exec preferences.cfg')
$pause = 'wait;' * 30
foreach ($phase in 1..3) {
    $expectedInitial = if ($phase -eq 2) { '1' } else { '0' }
    $zoom = if ($phase -eq 2) { '4' } else { '0' }
    $commands = @(
        'host_maxfps 60',
        "$pause m_pop; m_basicopts; $pause pref_assert $expectedInitial",
        "pref_toggle; $pause screenshot png",
        "m_pop; m_video; $pause pref_zoom $zoom",
        "m_pop; toggleconsole; $pause screenshot png", 'pref_exit'
    )
    [IO.File]::WriteAllLines((Join-Path $game 'preferences.cfg'), $commands)
    $width = if ($phase -eq 2) { 1920 } else { 960 }
    $height = if ($phase -eq 2) { 1080 } else { 600 }
    $process = Start-Process -FilePath $Engine -WorkingDirectory $base -WindowStyle Hidden -PassThru -ArgumentList @(
        '-basedir', ('"'+$base+'"'), '-game', 'menusys_test', '-window',
        '-width', $width, '-height', $height, '-condebug'
    )
    if (-not $process.WaitForExit(25000)) { Stop-Process -Id $process.Id; throw 'QSS timed out' }
    $log = [IO.File]::ReadAllText((Join-Path $base 'qconsole.log'))
    if ($log -match 'PREF FAIL|Unknown command') { throw "Phase $phase failed: $log" }
    $config = [IO.File]::ReadAllText((Join-Path $game 'config.cfg'))
    if ($config -notmatch 'scr_menuscale "100"') { throw 'Gameplay message scale was not saved' }
    $enabled = $phase -ne 2
    $expected = if ($enabled) { '1' } else { '0' }
    if ($config -notmatch ('seta menu_alwaysmlook "'+$expected+'"')) { throw 'Mouselook preference was not saved' }
    if (($config -match '(?m)^\+mlook\s*$') -ne $enabled) { throw 'Native mouselook state was not saved' }
    $expectedWidth = if ($enabled) { '640' } else { '0' }
    if ($config -notmatch ('scr_conwidth "'+$expectedWidth+'"')) { throw 'Console width was not saved' }
    Copy-Item -LiteralPath (Join-Path $base 'qconsole.log') -Destination (Join-Path $base "phase-$phase.log")
    Copy-Item -LiteralPath (Join-Path $game 'config.cfg') -Destination (Join-Path $base "phase-$phase.cfg")
}
Write-Host "PASS: checkbox toggles, native mouselook persistence, restart state, fixed/automatic console scale. Screenshots: $game"