[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string] $Compiler,
    [Parameter(Mandatory=$true)][string] $Fte,
    [Parameter(Mandatory=$true)][string] $Qss,
    [Parameter(Mandatory=$true)][string] $QuakeData,
    [Parameter(Mandatory=$true)][string] $LibreQuakeData,
    [Parameter(Mandatory=$true)][string] $SupportDirectory,
    [string] $TestName = 'zoom-preferences'
)
$ErrorActionPreference = 'Stop'
if ($TestName -notmatch '^[a-zA-Z0-9_-]+$') { throw 'Invalid test name' }
$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$output = Join-Path $root "dist/runtime/$TestName"
if (Test-Path -LiteralPath $output) { throw 'Output already exists' }
[void](New-Item -ItemType Directory -Path $output)
$build = Join-Path $root 'dist/build'
[IO.File]::WriteAllText((Join-Path $build 'zoom-preferences.src'), "#include `"../../tests/menu-preferences.src`"`n#pragma progs_dat `"zoom-preferences-menu.dat`"`n")
Push-Location $build
try {
    $compile = @(& $Compiler -srcfile zoom-preferences.src 2>&1)
    $compile | Set-Content (Join-Path $output 'compiler.log')
    if ($LASTEXITCODE -ne 0 -or @($compile | Select-String 'warning:|warning Q|[1-9][0-9]* warnings').Count) { throw 'Compilation failed' }
} finally { Pop-Location }
. (Join-Path $PSScriptRoot 'scaling-test-tools.ps1')
$results = @()
foreach ($case in @('fte-id1','fte-librequake','qss-id1','qss-librequake')) {
    $qssCase = $case.StartsWith('qss')
    $engine = if ($qssCase) { $Qss } else { $Fte }
    $data = if ($case.EndsWith('librequake')) { $LibreQuakeData } else { $QuakeData }
    $base = Join-Path $output $case
    $game = Join-Path $base 'menusys_test'
    $id1 = Join-Path $base 'id1'
    [void](New-Item -ItemType Directory -Path $game,$id1 -Force)
    foreach ($name in @('pak0.pak','pak1.pak')) { Copy-Item -LiteralPath (Join-Path $data $name) -Destination $id1 }
    Copy-Item -LiteralPath (Join-Path $SupportDirectory 'menugfx') -Destination $game -Recurse
    Copy-Item -LiteralPath (Join-Path $build 'zoom-preferences-menu.dat') -Destination (Join-Path $game 'menu.dat')
    [IO.File]::WriteAllLines((Join-Path $game 'quake.rc'), (@('exec default.cfg','exec fte.cfg','exec config.cfg','exec autoexec.cfg','m_textscale') + $(if ($qssCase) { @('stuffcmds') } else { @() })))
    # Seed legacy settings once. Subsequent sessions must load saved choices.
    $seed = if ($qssCase) { @('seta menu_consoleauto 0','scr_conwidth 0','scr_conscale 2','scr_sbarscale 3') } else { @('vid_conautoscale 3','seta con_textsize 10') }
    [IO.File]::WriteAllLines((Join-Path $game 'config.cfg'), $seed)
    foreach ($phase in 1..4) {
        $pause = 'wait;' * 35
        $commands = @('developer 1','alias startdemos ""')
        if ($qssCase) { $commands += 'host_maxfps 60' } else { $commands += @('cl_maxfps 60','cl_maxidlefps 60',"$pause forceqmenu 0;menu_restart") }
        $commands += "$pause m_pop; m_video; $pause"
        $initial = if ($phase -eq 1) { if ($qssCase) { '2 0 3 2 3' } else { '-1 0 3 10 3' } } elseif ($phase -eq 2) { if ($qssCase) { '2 3 4 2 4' } else { '2 3 4 -16 4' } } elseif ($phase -eq 3) { if ($qssCase) { '0 0 0 1.5 1.5' } else { '0 0 0 -12 1.5' } } else { if ($qssCase) { '-1 0 -1 1 1' } else { '-1 0 -1 8 0' } }
        $commands += "pref_native $initial"
        if ($phase -eq 1) {
            $commands += @('pref_independent menu_consolezoom 2','pref_independent menu_hudzoom 4','pref_independent menu_zoom 3')
        } elseif ($phase -eq 2) {
            $commands += @('pref_independent menu_consolezoom 0','pref_independent menu_hudzoom 0','pref_independent menu_zoom 0')
        } elseif ($phase -eq 3) {
            # Exercise every preset through the menu backend and verify the
            # untouched native controls after each change.
            foreach ($choice in 1..4) {
                foreach ($key in @('menu_consolezoom','menu_hudzoom','menu_zoom')) { $commands += "pref_independent $key $choice" }
            }
            $commands += @('pref_independent menu_consolezoom -1','pref_independent menu_hudzoom -1','pref_independent menu_zoom 0')
        }
        $shot = if ($qssCase) { 'screenshot png' } else { "screenshot phase-$phase-menu.png" }
        $consoleShot = if ($qssCase) { 'screenshot png' } else { "screenshot phase-$phase-console.png" }
        $commands += @("$pause $shot", "m_pop; toggleconsole; $pause echo ZOOMCHECK ZOOMCHECK; $pause $consoleShot")
        if ($phase -eq 1) {
            # Repeat the same native console line while the HUD scale changes.
            # The resulting captures must keep the same physical glyph size.
            $commands += @("toggleconsole; m_video; $pause pref_independent menu_hudzoom 1; m_pop; toggleconsole; $pause echo ZOOMCHECK ZOOMCHECK; $pause " + $(if ($qssCase) { 'screenshot png' } else { 'screenshot console-hud1.png' }))
            $commands += @("toggleconsole; m_video; $pause pref_independent menu_hudzoom 4; m_pop; toggleconsole; $pause echo ZOOMCHECK ZOOMCHECK; $pause " + $(if ($qssCase) { 'screenshot png' } else { 'screenshot console-hud4.png' }))
        }
        if (-not $qssCase) { $commands += 'cfg_save' }
        $commands += 'pref_exit'
        [IO.File]::WriteAllLines((Join-Path $game 'autoexec.cfg'), $commands)
        $arguments = @('-basedir',('"'+$base+'"'),'-game','menusys_test','-window','-width',960,'-height',600,'-condebug')
        if (-not $qssCase) { $arguments = @('-nohome','+set','vid_fullscreen','0') + $arguments }
        $process = Start-Process -FilePath $engine -WorkingDirectory $base -WindowStyle Hidden -PassThru -ArgumentList $arguments
        if (-not $process.WaitForExit(35000)) { Stop-Process -Id $process.Id; throw "$case phase $phase timed out" }
        $logs = @(Get-ChildItem -LiteralPath $base -Recurse -Filter '*.log' | Where-Object { $_.Name -notmatch '^phase-' })
        $errors = @(Get-ScalingErrors $logs ($case -eq 'qss-librequake'))
        $errors += @($logs | Select-String 'PREF FAIL' | ForEach-Object { $_.Line })
        if (@($logs | Select-String 'PREF native').Count -ne $(if ($qssCase) { 1 } else { $phase })) { $errors += 'Missing native checkpoint' }
        $log = $logs | Where-Object { $_.Name -match 'qconsole|console' } | Select-Object -First 1
        if ($log) { Copy-Item -LiteralPath $log.FullName -Destination (Join-Path $base "phase-$phase.log") }
        if (-not $qssCase -and $phase -eq 1) { Remove-Item -LiteralPath (Join-Path $game 'config.cfg') }
        $saved = Join-Path $game $(if ($qssCase) { 'config.cfg' } else { 'fte.cfg' })
        if (-not (Test-Path -LiteralPath $saved)) { throw 'Engine did not write settings' }
        Copy-Item -LiteralPath $saved -Destination (Join-Path $base "phase-$phase.cfg")
        # FTE writes fte.cfg under the current game directory; preserve the
        # actual generated file so each restart exercises engine persistence.
        $results += [pscustomobject]@{Case=$case;Phase=$phase;Passed=($errors.Count -eq 0);Errors=$errors}
        if ($errors.Count) { $results | ConvertTo-Json -Depth 6 | Set-Content (Join-Path $output 'results.json'); throw ($errors -join "`n") }
    }
    $fontShots = if ($qssCase) { @('spasm0002.png','spasm0003.png') } else { @('console-hud1.png','console-hud4.png') }
    $fontPaths = @($fontShots | ForEach-Object { Join-Path $game $_ })
    & python (Join-Path $PSScriptRoot 'test-console-zoom.py') --data $id1 --scale 2 --captures $fontPaths --output (Join-Path $base 'console-pixels.json')
    if ($LASTEXITCODE -ne 0) { throw 'Native console pixel regression' }
    $automaticShot = Join-Path $game $(if ($qssCase) { 'spasm0005.png' } else { 'phase-2-console.png' })
    & python (Join-Path $PSScriptRoot 'test-console-zoom.py') --data $id1 --scale 1.5 --captures $automaticShot --output (Join-Path $base 'console-auto-pixels.json')
    if ($LASTEXITCODE -ne 0) { throw 'Automatic console pixel regression' }
}
$results | ConvertTo-Json -Depth 6 | Set-Content (Join-Path $output 'results.json')
Write-Host 'PASS: legacy settings, independent zoom choices, all presets, Automatic, Default and four engine restarts for both engines and datasets.'
