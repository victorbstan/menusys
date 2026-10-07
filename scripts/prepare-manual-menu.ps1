[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string] $Compiler,
    [Parameter(Mandatory = $true)]
    [ValidateSet('quakespasm-spiked', 'fte-quake', 'fte-librequake')][string] $Target
)
$ErrorActionPreference = 'Stop'
$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$testBase = Join-Path $root "dist/manual/$Target"
$game = Join-Path $testBase 'menusys_test'
$pak = Join-Path $testBase 'id1/pak0.pak'
if (-not (Test-Path -LiteralPath $pak -PathType Leaf)) { throw "Missing game artwork: $pak" }
# Deploy support images independently of menu.dat so the package cannot mask
# the freshly compiled module. Only private, non-game artwork is extracted.
$supportPak = Join-Path $root 'dist/classic-menusys-vbs-v1.0-beta.10/menu.pak'
if (-not (Test-Path -LiteralPath $supportPak)) { throw "Missing menu support package: $supportPak" }
$reader = [IO.BinaryReader]::new([IO.File]::OpenRead($supportPak))
try {
    if ([Text.Encoding]::ASCII.GetString($reader.ReadBytes(4)) -ne 'PACK') { throw 'Invalid support PAK' }
    $directoryOffset = $reader.ReadInt32()
    $directoryLength = $reader.ReadInt32()
    for ($entry = 0; $entry -lt $directoryLength / 64; $entry++) {
        $reader.BaseStream.Position = $directoryOffset + $entry * 64
        $name = [Text.Encoding]::ASCII.GetString($reader.ReadBytes(56)).TrimEnd([char]0)
        $offset = $reader.ReadInt32()
        $length = $reader.ReadInt32()
        if ($name -notmatch '^(menugfx|scrollbars)/' -or $name -match '(^|/)\.\.(/|$)' -or $name.Contains('\')) { continue }
        if ($name.StartsWith('menugfx/playerpreview/')) { continue }
        $destination = Join-Path $game $name
        [void](New-Item -ItemType Directory -Force -Path (Split-Path $destination))
        $reader.BaseStream.Position = $offset
        [IO.File]::WriteAllBytes($destination, $reader.ReadBytes($length))
    }
} finally { $reader.Dispose() }
& (Join-Path $PSScriptRoot 'build-menu.ps1') -Compiler $Compiler
& (Join-Path $PSScriptRoot 'build-player-preview.ps1') -Pak $pak -OutputDirectory (Join-Path $game 'menugfx/playerpreview')
Copy-Item -LiteralPath (Join-Path $root 'dist/build/menu.dat') -Destination (Join-Path $game 'menu.dat') -Force
# Preserve old packages outside the engine's *.pak search when deploying loose
# output, so an older build cannot mask the latest module or preview layers.
$stalePak = Join-Path $game 'menu.pak'
if (Test-Path -LiteralPath $stalePak) {
    $backup = Join-Path $game ('menu.pak.stale-' + [Guid]::NewGuid().ToString('N'))
    Move-Item -LiteralPath $stalePak -Destination $backup
    Write-Host "Preserved stale menu.pak as $backup"
}
Write-Host "Latest menu and game-specific live preview deployed for $Target."

# Load saved settings as well as defaults in the isolated QSS launcher.
if ($Target -eq 'quakespasm-spiked') {
    [IO.File]::WriteAllLines((Join-Path $game 'quake.rc'), @('exec default.cfg', 'exec config.cfg', 'exec autoexec.cfg', 'm_textscale', 'stuffcmds'))
}
