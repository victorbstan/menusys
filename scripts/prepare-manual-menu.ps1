[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string] $Compiler,
    [ValidateSet('quakespasm-spiked', 'qss-librequake', 'fte-quake', 'fte-librequake')]
    [string] $Target = 'quakespasm-spiked',
    [string] $ManualDirectory = (Join-Path $PSScriptRoot '../dist/manual'),
    [string] $QuakeData,
    [string] $LibreQuakeData
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$manual = [IO.Path]::GetFullPath($ManualDirectory).TrimEnd('\', '/')
$dist = [IO.Path]::GetFullPath((Join-Path $root 'dist')).TrimEnd('\', '/') + '\'
if (-not $manual.StartsWith($dist, [StringComparison]::OrdinalIgnoreCase)) {
    throw 'ManualDirectory must be an isolated directory under dist.'
}
[void][IO.Directory]::CreateDirectory($manual)
$lock = [IO.File]::Open((Join-Path $manual 'prepare.lock'), 'OpenOrCreate', 'ReadWrite', 'None')
$targets = [ordered]@{
    'fte-quake' = 'quake'
    'fte-librequake' = 'librequake'
    'quakespasm-spiked' = 'quake'
    'qss-librequake' = 'librequake'
}
function Assert-ManualPath([string] $Path) {
    $full = [IO.Path]::GetFullPath($Path)
    if (-not $full.StartsWith($manual + '\', [StringComparison]::OrdinalIgnoreCase)) {
        throw "Path outside the manual directory: $full"
    }
    # Never traverse an unexpected directory link when cleaning managed files.
    $parent = $full
    while ($parent -ne $manual) {
        if (Test-Path -LiteralPath $parent) {
            if ((Get-Item -LiteralPath $parent -Force).Attributes -band [IO.FileAttributes]::ReparsePoint) {
                throw "Unexpected linked path: $parent"
            }
        }
        $parent = Split-Path $parent
    }
}
$archive = Join-Path $manual ('archive/' + [DateTime]::Now.ToString('yyyyMMdd-HHmmss') + '-' + [Guid]::NewGuid().ToString('N'))
function Archive-ManualPath([string] $Path, [string] $Name) {
    Assert-ManualPath $Path
    $destination = Join-Path $archive $Name
    Assert-ManualPath $destination
    [void][IO.Directory]::CreateDirectory((Split-Path $destination))
    Move-Item -LiteralPath $Path -Destination $destination
    return $destination
}
function Get-Hash([string] $Path) { return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash }
function Set-SharedDirectoryLink([string] $Path, [string] $Source, [string] $Name) {
    $Source = [IO.Path]::GetFullPath($Source)
    $item = Get-Item -LiteralPath $Path -Force -ErrorAction SilentlyContinue
    if ($item -and ($item.Attributes -band [IO.FileAttributes]::ReparsePoint)) {
        if ([IO.Path]::GetFullPath([string]@($item.Target)[0]).TrimEnd('\') -ne $Source.TrimEnd('\')) {
            throw "Unexpected game-data link: $Path"
        }
        return
    }
    if ($item) {
        $old = Archive-ManualPath $Path $Name
        # Delete only verified duplicates; preserve differing overrides and evidence.
        foreach ($file in Get-ChildItem -LiteralPath $old -Recurse -File) {
            Assert-ManualPath $file.FullName
            $equivalent = Join-Path $Source $file.FullName.Substring($old.Length + 1)
            if ((Test-Path -LiteralPath $equivalent -PathType Leaf) -and (Get-Hash $file.FullName) -eq (Get-Hash $equivalent)) {
                Remove-Item -LiteralPath $file.FullName
            }
        }
        foreach ($directory in @(Get-ChildItem -LiteralPath $old -Recurse -Directory | Sort-Object { $_.FullName.Length } -Descending) + @(Get-Item -LiteralPath $old)) {
            Assert-ManualPath $directory.FullName
            if (@(Get-ChildItem -LiteralPath $directory.FullName -Force).Count -eq 0) { Remove-Item -LiteralPath $directory.FullName }
        }
    }
    [void](New-Item -ItemType Junction -Path $Path -Target $Source)
}
$staging = $null
try {
    # Seed one authoritative data directory per game from the existing installations.
    $sources = @{ quake = $QuakeData; librequake = $LibreQuakeData }
    $legacy = @{ quake = 'quakespasm-spiked'; librequake = 'fte-librequake' }
    foreach ($dataset in @('quake', 'librequake')) {
        $canonical = Join-Path $manual "shared/$dataset/id1"
        Assert-ManualPath $canonical
        $source = $sources[$dataset]
        if (-not $source) {
            $source = if (Test-Path -LiteralPath (Join-Path $canonical 'pak0.pak')) { $canonical } else { Join-Path $manual ($legacy[$dataset] + '/id1') }
        }
        $source = [IO.Path]::GetFullPath($source).TrimEnd('\', '/')
        foreach ($pak in @('pak0.pak', 'pak1.pak')) {
            if (-not (Test-Path -LiteralPath (Join-Path $source $pak) -PathType Leaf)) {
                throw "Missing $dataset data: $source/$pak. Supply -QuakeData and -LibreQuakeData on first preparation."
            }
        }
        [void][IO.Directory]::CreateDirectory($canonical)
        foreach ($pak in @('pak0.pak', 'pak1.pak')) {
            $inputPak = Join-Path $source $pak
            $outputPak = Join-Path $canonical $pak
            if ($source -ne $canonical -and (-not (Test-Path -LiteralPath $outputPak) -or (Get-Hash $inputPak) -ne (Get-Hash $outputPak))) {
                Copy-Item -LiteralPath $inputPak -Destination $outputPak -Force
            }
        }
    }
    # Compile once, then install those exact bytes in every launcher. CSQC is compile-only.
    & (Join-Path $PSScriptRoot 'build-menu.ps1') -Compiler $Compiler
    & (Join-Path $PSScriptRoot 'build-menu.ps1') -Compiler $Compiler -Csqc
    $staging = Join-Path $manual ('.prepare-' + [Guid]::NewGuid().ToString('N'))
    Assert-ManualPath $staging
    foreach ($dataset in @('quake', 'librequake')) {
        $art = Join-Path $staging "$dataset/menugfx"
        & (Join-Path $PSScriptRoot 'build-menu-assets.ps1') -OutputDirectory $art
        & (Join-Path $PSScriptRoot 'build-player-preview.ps1') -Pak (Join-Path $manual "shared/$dataset/id1/pak0.pak") -OutputDirectory (Join-Path $art 'playerpreview')
    }
    foreach ($dataset in @('quake', 'librequake')) {
        $sourceArt = Join-Path $staging "$dataset/menugfx"
        $sharedArt = Join-Path $manual "shared/$dataset/menugfx"
        Assert-ManualPath $sharedArt
        [void][IO.Directory]::CreateDirectory($sharedArt)
        foreach ($file in Get-ChildItem -LiteralPath $sharedArt -Recurse -File) {
            Assert-ManualPath $file.FullName
            $relative = $file.FullName.Substring($sharedArt.Length + 1)
            if (-not (Test-Path -LiteralPath (Join-Path $sourceArt $relative))) {
                [void](Archive-ManualPath $file.FullName "shared/$dataset/menugfx/$relative")
            }
        }
        foreach ($file in Get-ChildItem -LiteralPath $sourceArt -Recurse -File) {
            $destination = Join-Path $sharedArt $file.FullName.Substring($sourceArt.Length + 1)
            Assert-ManualPath $destination
            [void][IO.Directory]::CreateDirectory((Split-Path $destination))
            Copy-Item -LiteralPath $file.FullName -Destination $destination -Force
        }
    }
    $manifest = [ordered]@{ MenuSha256 = Get-Hash (Join-Path $root 'dist/build/menu.dat'); Targets = [ordered]@{} }
    foreach ($name in $targets.Keys) {
        $dataset = $targets[$name]
        $isFte = $name.StartsWith('fte-')
        $basedir = Join-Path $manual $name
        $game = Join-Path $basedir 'menusys_test'
        Assert-ManualPath $game
        [void][IO.Directory]::CreateDirectory($game)
        Set-SharedDirectoryLink (Join-Path $basedir 'id1') (Join-Path $manual "shared/$dataset/id1") "$name/id1"
        Set-SharedDirectoryLink (Join-Path $game 'menugfx') (Join-Path $manual "shared/$dataset/menugfx") "$name/menusys_test/menugfx"
        # Remove old overrides from the engine search path while retaining evidence.
        foreach ($relative in @('scrollbars', 'gfx', 'maps', 'menu.pak', 'graphics-check.cfg')) {
            $obsolete = Join-Path $game $relative
            if (Test-Path -LiteralPath $obsolete) { [void](Archive-ManualPath $obsolete "$name/menusys_test/$relative") }
        }
        foreach ($package in @(Get-ChildItem -LiteralPath $game -File | Where-Object { $_.Extension -in @('.pak', '.pk3') })) {
            [void](Archive-ManualPath $package.FullName "$name/menusys_test/$($package.Name)")
        }
        $qw = Join-Path $basedir 'qw'
        if (Test-Path -LiteralPath $qw) { [void](Archive-ManualPath $qw "$name/qw") }
        Copy-Item -LiteralPath (Join-Path $root 'dist/build/menu.dat') -Destination (Join-Path $game 'menu.dat') -Force
        # Leave personal settings intact, removing only the old launcher's delayed commands.
        $autoexec = Join-Path $game 'autoexec.cfg'
        if (Test-Path -LiteralPath $autoexec) {
            $lines = @(Get-Content -LiteralPath $autoexec)
            $bootstrap = @('developer 1', 'cl_cursor ""', 'alias startdemos ""', 'cl_maxfps 60', 'host_maxfps 60', 'in 1 forceqmenu 0', 'in 1 menu_restart', 'in 1 togglemenu')
            $kept = @($lines | Where-Object { $_ -notmatch '^in 1 (forceqmenu 0|menu_restart|togglemenu)\s*$' })
            if (@($lines | Where-Object { $_.Trim() -and $_.Trim() -notin $bootstrap }).Count -eq 0) { $kept = @('// Personal settings for this engine and game.') }
            if (($kept -join "`n") -ne ($lines -join "`n")) {
                [void](Archive-ManualPath $autoexec "$name/menusys_test/autoexec.cfg")
                [IO.File]::WriteAllLines($autoexec, [string[]]$kept)
            }
        } else { [IO.File]::WriteAllText($autoexec, "// Personal settings for this engine and game.`r`n") }
        # Engine defaults precede saved/personal settings; startup commands are managed separately.
        $defaults = @('developer 1') + $(if ($isFte) { @('cl_maxfps 60') } else { @('alias startdemos ""', 'host_maxfps 60') })
        [IO.File]::WriteAllLines((Join-Path $game 'manual-defaults.cfg'), $defaults)
        $startup = @()
        if ($isFte -and $dataset -eq 'librequake') {
            # LibreQuake's joy_enable is named joystick in FTE SVN 6202.
            $startup += 'alias joy_enable "joystick $*"'
        }
        $startup += @('exec default.cfg', 'exec manual-defaults.cfg')
        if ($isFte) { $startup += 'exec fte.cfg' }
        $startup += @('exec config.cfg', 'exec autoexec.cfg')
        $startup += $(if ($isFte) { @('forceqmenu 0', 'menu_restart') } else { @('m_textscale') })
        if (-not $isFte) { $startup += 'stuffcmds' }
        [IO.File]::WriteAllLines((Join-Path $game 'quake.rc'), $startup)
        $launcherScript = [Uri]::UnescapeDataString(([Uri]($manual + '\')).MakeRelativeUri([Uri](Join-Path $PSScriptRoot 'start-manual-menu.ps1')).ToString()).Replace('/', '\')
        $launcher = @('@echo off', ('powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0' + $launcherScript + '" -SettingsFile "%~dp0settings.psd1" -Target ' + $name + ' %*'), 'if errorlevel 1 (', '  pause', '  exit /b 1', ')')
        [IO.File]::WriteAllLines((Join-Path $manual "$name.cmd"), $launcher)
        $expected = [ordered]@{ 'menu.dat' = $manifest.MenuSha256 }
        $artRoot = Join-Path $staging $dataset
        foreach ($file in Get-ChildItem -LiteralPath $artRoot -Recurse -File) {
            $relative = $file.FullName.Substring($artRoot.Length + 1).Replace('\', '/')
            $expected[$relative] = Get-Hash $file.FullName
        }
        foreach ($relative in $expected.Keys) {
            if ((Get-Hash (Join-Path $game $relative)) -ne $expected[$relative]) { throw "Deployment mismatch: $name/$relative" }
        }
        $dataHashes = [ordered]@{}
        foreach ($pak in @('pak0.pak', 'pak1.pak')) { $dataHashes[$pak] = Get-Hash (Join-Path $basedir "id1/$pak") }
        $manifest.Targets[$name] = [ordered]@{ Dataset = $dataset; Files = $expected; GameData = $dataHashes }
    }
    $manifest | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $manual 'manifest.json')
    Write-Host "All four manual installations synchronized; $Target is ready."
} finally {
    if ($staging -and (Test-Path -LiteralPath $staging)) {
        Assert-ManualPath $staging
        Remove-Item -LiteralPath $staging -Recurse -Force
    }
    $lock.Dispose()
}
