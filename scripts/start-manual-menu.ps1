[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('quakespasm-spiked', 'qss-librequake', 'fte-quake', 'fte-librequake')][string] $Target,
    [string] $SettingsFile = (Join-Path $PSScriptRoot '../dist/manual/settings.psd1'),
    [ValidateRange(240, 16384)][int] $Width = 960,
    [ValidateRange(200, 16384)][int] $Height = 600,
    [switch] $PrepareOnly
)
$ErrorActionPreference = 'Stop'
# A .cmd launched from PowerShell 7 can inherit its module search path.
# Load the modules belonging to this host rather than a different PS version.
Import-Module (Join-Path $PSHOME 'Modules/Microsoft.PowerShell.Utility')
Import-Module (Join-Path $PSHOME 'Modules/Microsoft.PowerShell.Management')
$settings = Import-PowerShellDataFile -LiteralPath $SettingsFile
$isFte = $Target.StartsWith('fte-')
$engine = if ($isFte) { $settings.Fte } else { $settings.Qss }
if (-not (Test-Path -LiteralPath $engine -PathType Leaf)) { throw "Engine not found: $engine" }
$manual = Split-Path ([IO.Path]::GetFullPath($SettingsFile))
& (Join-Path $PSScriptRoot 'prepare-manual-menu.ps1') -Compiler $settings.Compiler -Target $Target -ManualDirectory $manual
if ($PrepareOnly) { return }
$basedir = Join-Path $manual $Target
$engineArgs = @('-basedir', ('"' + $basedir + '"'), '-game', 'menusys_test', '-window', '-width', $Width, '-height', $Height, '-condebug')
if ($isFte) {
    $engineArgs = @('-nohome', '+set', 'vid_fullscreen', '0') + $engineArgs + @('+in', '1', 'exec', 'quake.rc', '+in', '1', 'togglemenu')
} else {
    # QSS 2021 stores only 256 command-line characters for stuffcmds.
    # Open explicitly: togglemenu can close Main after LibreQuake startup draws.
    $engineArgs = @('+m_main') + $engineArgs
}
Start-Process -FilePath $engine -ArgumentList $engineArgs -WorkingDirectory $basedir
