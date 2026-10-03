[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string] $Engine,
    [Parameter(Mandatory = $true)][string] $GameData,
    [Parameter(Mandatory = $true)][string] $MenuPak,
    [string] $TestName = 'quake',
    [switch] $Qss,
    [int] $Width = 960,
    [int] $Height = 600
)

$ErrorActionPreference = 'Stop'
if ($TestName -notmatch '^[a-zA-Z0-9_-]+$') { throw 'TestName must be a simple directory name.' }
$rconPassword = [Guid]::NewGuid().ToString('N')
$portProbe = [Net.Sockets.UdpClient]::new([Net.IPEndPoint]::new([Net.IPAddress]::Loopback, 0))
$testPort = $portProbe.Client.LocalEndPoint.Port
$portProbe.Dispose()
$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$testRoot = Join-Path $root "dist/runtime/$TestName"
if (Test-Path -LiteralPath $testRoot) { throw "Test output already exists: $testRoot" }
$id1 = Join-Path $testRoot 'id1'
[void](New-Item -ItemType Directory -Path $id1)
$game = Join-Path $testRoot 'menusys_test'
[void](New-Item -ItemType Directory -Path $game)
foreach ($name in @('pak0.pak', 'pak1.pak')) {
    Copy-Item -LiteralPath (Join-Path $GameData $name) -Destination $id1
}
Copy-Item -LiteralPath $MenuPak -Destination (Join-Path $game 'menu.pak')
# Each screenshot comes from the engine, so hidden windows can still be tested.
$pause = ('wait;' * $(if ($Qss) { 10 } else { 120 }))
$commands = @(
    'developer 1',
    $(if ($Qss) { 'host_maxfps 60' } else { 'cl_maxfps 60' }),
    $(if ($Qss) { "$pause togglemenu" } else { "$pause forceqmenu 0; menu_restart; togglemenu" }),
    'cl_cursor ""',
    "$pause m_pop; m_single; $pause screenshot single.png",
    "m_pop; menu_load; $pause screenshot load-empty.png",
    "m_pop; menu_save; $pause screenshot save-disabled.png",
    $(if ($Qss) { "m_pop; rcon_password $rconPassword; sv_public 0; listen 1; map start" } else { 'm_pop; map start; in 6 exec regression-ingame.cfg' })
)
$ingame = @(
    'save s0',
    "$pause menu_save; $pause screenshot save.png",
    "m_pop; menu_load; $pause screenshot load.png",
    "m_pop; m_levels; $pause screenshot levels.png",
    "m_pop; m_demos; $pause screenshot demos.png",
    "m_pop; m_setup; $pause screenshot setup.png",
    'quit'
)
if ($Qss) {
    $commands = @($commands | ForEach-Object { $_ -replace 'screenshot [a-z-]+\.png', 'screenshot png' })
    $ingame = @($ingame | ForEach-Object { $_ -replace 'screenshot [a-z-]+\.png', 'screenshot png' })
}
[IO.File]::WriteAllLines((Join-Path $game 'regression.cfg'), $commands)
[IO.File]::WriteAllLines((Join-Path $game 'regression-ingame.cfg'), $ingame)
# Disable Quake's startup demo loop before it can interrupt queued commands.
[IO.File]::WriteAllText((Join-Path $game 'autoexec.cfg'), $(if ($Qss) { 'exec regression.cfg' } else { 'alias startdemos ""' }))
$args = @('-basedir', ('"' + $testRoot + '"'), '-game', 'menusys_test', '-window', '-width', $Width, '-height', $Height, '-condebug', '+exec', 'regression.cfg')
if ($Qss) { $args = @('-basedir', ('"' + $testRoot + '"'), '-game', 'menusys_test', '-window', '-width', $Width, '-height', $Height, '-condebug') }
if ($Qss) {
    $args += @('-ip', '127.0.0.1', '-port', $testPort)
    [IO.File]::WriteAllLines((Join-Path $game 'quake.rc'), @('exec default.cfg', 'exec autoexec.cfg', 'stuffcmds'))
}
if (-not $Qss) { $args = @('-nohome', '+set', 'vid_fullscreen', '0') + $args }
$process = Start-Process -FilePath $Engine -ArgumentList $args -WorkingDirectory $testRoot -WindowStyle Hidden -PassThru
if ($Qss) {
    # Signon commands are appended to the engine buffer. An entire queued
    # regression script would prevent them from running until after Save.
    # Allow signon to finish, then enqueue the next phase through localhost.
    Start-Sleep -Seconds 6
    $body = [Text.Encoding]::ASCII.GetBytes(([char]5) + $rconPassword + [char]0 + 'exec regression-ingame.cfg' + [char]0)
    $length = $body.Length + 4
    [byte[]]$packet = @(128, 0, ($length -shr 8), ($length -band 255)) + $body
    $client = [Net.Sockets.UdpClient]::new()
    try { [void]$client.Send($packet, $packet.Length, '127.0.0.1', $testPort) }
    finally { $client.Dispose() }
}
if (-not $process.WaitForExit(55000)) {
    Stop-Process -Id $process.Id
    throw "Engine timed out. Inspect $testRoot"
}
$expected = @('single', 'load-empty', 'save-disabled', 'save', 'load', 'levels', 'demos', 'setup')
if ($Qss) {
    $shots = @(Get-ChildItem -LiteralPath $game -Filter 'spasm*.png' | Sort-Object Name)
    if ($shots.Count -ne $expected.Count) { throw "Expected eight screenshots, found $($shots.Count). Inspect $testRoot" }
    for ($i = 0; $i -lt $shots.Count; $i++) {
        Move-Item -LiteralPath $shots[$i].FullName -Destination (Join-Path $game ($expected[$i] + '.png'))
    }
}
foreach ($name in $expected) {
    if (-not (Test-Path -LiteralPath (Join-Path $game "$name.png"))) { throw "Missing screenshot: $name" }
}
if (-not (Get-ChildItem -LiteralPath $game -Recurse -Filter 's0.sav')) { throw 'Engine did not save s0.' }
$logs = @(Get-ChildItem -LiteralPath $testRoot -Recurse -Filter '*.log')
$failures = @($logs | Select-String -Pattern 'Unknown command|unimplemented builtin|Host_Error|Menu_Abort|PF_strunzone:|Can.t savegame')
if ($failures.Count) { throw ($failures.Line -join "`n") }
Get-ChildItem -LiteralPath $testRoot -Recurse -File |
    Where-Object { $_.Extension -in @('.png', '.log') } | Select-Object FullName, Length
