[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string] $Version,

    [Parameter(Mandatory = $true)]
    [string] $MenuDat,

    [string] $OutputDirectory = (Join-Path $PSScriptRoot "..\dist"),

    [switch] $Force
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Get-FullPath {
    param([Parameter(Mandatory = $true)][string] $Path)

    return [System.IO.Path]::GetFullPath($Path)
}

function Get-RequiredFile {
    param(
        [Parameter(Mandatory = $true)][string] $Path,
        [Parameter(Mandatory = $true)][string] $Description
    )

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "$Description was not found: $Path"
    }

    return (Get-Item -LiteralPath $Path).FullName
}

function Get-BytesSha256 {
    param([Parameter(Mandatory = $true)][byte[]] $Data)

    $sha = [System.Security.Cryptography.SHA256]::Create()
    try {
        return ([System.BitConverter]::ToString($sha.ComputeHash($Data))).Replace("-", "")
    }
    finally {
        $sha.Dispose()
    }
}

function Normalize-PakPath {
    param([Parameter(Mandatory = $true)][string] $Path)

    $normalized = $Path.Replace([char]92, [char]47)
    $segments = $normalized.Split([char]47)

    if ($normalized.StartsWith("/") -or
        $segments.Count -eq 0 -or
        $segments -contains "" -or
        $segments -contains "." -or
        $segments -contains "..") {
        throw "Unsafe PAK entry path: $Path"
    }

    return $normalized
}

function Read-Pak {
    param([Parameter(Mandatory = $true)][string] $Path)

    $bytes = [System.IO.File]::ReadAllBytes($Path)
    if ($bytes.Length -lt 12 -or
        [System.Text.Encoding]::ASCII.GetString($bytes, 0, 4) -ne "PACK") {
        throw "Not a Quake PAK file: $Path"
    }

    $directoryOffset = [System.BitConverter]::ToInt32($bytes, 4)
    $directoryLength = [System.BitConverter]::ToInt32($bytes, 8)

    if ($directoryOffset -lt 12 -or
        $directoryLength -lt 0 -or
        ($directoryLength % 64) -ne 0 -or
        ($directoryOffset + $directoryLength) -gt $bytes.Length) {
        throw "Invalid PAK directory: $Path"
    }

    $entries = @()
    $entryCount = [int]($directoryLength / 64)

    for ($index = 0; $index -lt $entryCount; $index++) {
        $entryOffset = $directoryOffset + ($index * 64)
        $nameLength = 0
        while ($nameLength -lt 56 -and $bytes[$entryOffset + $nameLength] -ne 0) {
            $nameLength++
        }

        $name = [System.Text.Encoding]::ASCII.GetString($bytes, $entryOffset, $nameLength)
        $dataOffset = [System.BitConverter]::ToInt32($bytes, $entryOffset + 56)
        $dataLength = [System.BitConverter]::ToInt32($bytes, $entryOffset + 60)

        if ($dataOffset -lt 12 -or
            $dataLength -lt 0 -or
            ($dataOffset + $dataLength) -gt $directoryOffset) {
            throw "Invalid data range for PAK entry '$name'"
        }

        $data = New-Object byte[] $dataLength
        [System.Array]::Copy($bytes, $dataOffset, $data, 0, $dataLength)

        $entries += [pscustomobject]@{
            Name = (Normalize-PakPath $name)
            Data = $data
        }
    }

    return $entries
}

function Write-Pak {
    param(
        [Parameter(Mandatory = $true)][string] $Path,
        [Parameter(Mandatory = $true)][object[]] $Entries
    )

    $stream = [System.IO.File]::Open(
        $Path,
        [System.IO.FileMode]::Create,
        [System.IO.FileAccess]::ReadWrite,
        [System.IO.FileShare]::None
    )

    try {
        $writer = New-Object System.IO.BinaryWriter(
            $stream,
            [System.Text.Encoding]::ASCII,
            $true
        )

        try {
            $writer.Write([System.Text.Encoding]::ASCII.GetBytes("PACK"))
            $writer.Write([int]0)
            $writer.Write([int]0)

            $directoryEntries = @()
            foreach ($entry in $Entries) {
                $name = Normalize-PakPath $entry.Name
                $encodedName = [System.Text.Encoding]::ASCII.GetBytes($name)
                if ($encodedName.Length -gt 55) {
                    throw "PAK entry path exceeds 55 bytes: $name"
                }

                $offset = [int]$stream.Position
                $data = [byte[]]$entry.Data
                $writer.Write($data)

                $directoryEntries += [pscustomobject]@{
                    Name   = $name
                    Offset = $offset
                    Length = [int]$data.Length
                }
            }

            $directoryOffset = [int]$stream.Position
            foreach ($entry in $directoryEntries) {
                $nameBytes = New-Object byte[] 56
                $encodedName = [System.Text.Encoding]::ASCII.GetBytes($entry.Name)
                [System.Array]::Copy($encodedName, $nameBytes, $encodedName.Length)

                $writer.Write($nameBytes)
                $writer.Write([int]$entry.Offset)
                $writer.Write([int]$entry.Length)
            }

            $directoryLength = [int]($stream.Position - $directoryOffset)
            [void]$stream.Seek(4, [System.IO.SeekOrigin]::Begin)
            $writer.Write($directoryOffset)
            $writer.Write($directoryLength)
            $writer.Flush()
        }
        finally {
            $writer.Dispose()
        }
    }
    finally {
        $stream.Dispose()
    }
}

function Assert-ChildPath {
    param(
        [Parameter(Mandatory = $true)][string] $Parent,
        [Parameter(Mandatory = $true)][string] $Child
    )

    $parentPath = (Get-FullPath $Parent).TrimEnd(
        [System.IO.Path]::DirectorySeparatorChar,
        [System.IO.Path]::AltDirectorySeparatorChar
    ) + [System.IO.Path]::DirectorySeparatorChar
    $childPath = Get-FullPath $Child

    if (-not $childPath.StartsWith($parentPath, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Path is outside the output directory: $childPath"
    }
}

if ($Version -notmatch '^v[0-9]+\.[0-9]+(?:\.[0-9]+)?(?:-[0-9A-Za-z.-]+)?$') {
    throw "Version must look like v1.0-beta.5 or v1.0.0: $Version"
}

$menuDatPath = Get-RequiredFile (Get-FullPath $MenuDat) "Compiled menu.dat"
$releaseTemplates = Join-Path $PSScriptRoot '../assets/release'
$baseReadmePath = Get-RequiredFile (Join-Path $releaseTemplates "README.md") "Package README template"
$baseConfigPath = Get-RequiredFile (
    (Join-Path $releaseTemplates "autoexec.cfg.example")
) "Example configuration template"

$outputPath = Get-FullPath $OutputDirectory
[void](New-Item -ItemType Directory -Path $outputPath -Force)

$artifactName = "classic-menusys-vbs-$Version"
$finalPackageDirectory = Join-Path $outputPath $artifactName
$finalZipPath = Join-Path $outputPath "$artifactName.zip"
Assert-ChildPath $outputPath $finalPackageDirectory
Assert-ChildPath $outputPath $finalZipPath

if (-not $Force -and
    ((Test-Path -LiteralPath $finalPackageDirectory) -or
     (Test-Path -LiteralPath $finalZipPath))) {
    throw "Release output already exists. Choose another version or pass -Force."
}

$stagingRoot = Join-Path $outputPath (".build-" + [System.Guid]::NewGuid().ToString("N"))
$stagingPackageDirectory = Join-Path $stagingRoot $artifactName
$stagingZipPath = Join-Path $stagingRoot "$artifactName.zip"
Assert-ChildPath $outputPath $stagingRoot

try {
    [void](New-Item -ItemType Directory -Path $stagingPackageDirectory -Force)

    $assetDirectory = Join-Path $stagingRoot 'assets'
    & (Join-Path $PSScriptRoot 'build-menu-assets.ps1') -OutputDirectory $assetDirectory
    $supportEntries = @(Get-ChildItem -LiteralPath $assetDirectory -File | ForEach-Object {
        [pscustomobject]@{ Name = 'menugfx/' + $_.Name; Data = [IO.File]::ReadAllBytes($_.FullName) }
    })
    foreach ($required in @('menugfx/levels.lmp', 'menugfx/demos.lmp', 'menugfx/cursor_copr.tga')) {
        if ($supportEntries.Name -notcontains $required) { throw "Missing support asset: $required" }
    }

    $duplicateSupportPaths = @($supportEntries |
        Group-Object { (Normalize-PakPath $_.Name).ToLowerInvariant() } |
        Where-Object Count -gt 1)
    if ($duplicateSupportPaths.Count -ne 0) {
        throw "Support artwork contains duplicate asset paths."
    }

    $compiledMenuBytes = [System.IO.File]::ReadAllBytes($menuDatPath)
    $newEntries = @(
        [pscustomobject]@{
            Name = "menu.dat"
            Data = $compiledMenuBytes
        }
    ) + $supportEntries

    $stagingPakPath = Join-Path $stagingPackageDirectory "menu.pak"
    Write-Pak $stagingPakPath $newEntries
    Copy-Item -LiteralPath $baseReadmePath -Destination $stagingPackageDirectory
    Copy-Item -LiteralPath $baseConfigPath -Destination $stagingPackageDirectory

    $verifiedEntries = @(Read-Pak $stagingPakPath)
    if ($verifiedEntries.Count -ne $newEntries.Count) {
        throw "Release PAK entry count does not match the build inputs."
    }

    $menuEntries = @($verifiedEntries | Where-Object { $_.Name -ieq "menu.dat" })
    if ($menuEntries.Count -ne 1) {
        throw "Expected exactly one menu.dat; found $($menuEntries.Count)."
    }

    $invalidPaths = @($verifiedEntries | Where-Object { $_.Name.Contains([char]92) })
    if ($invalidPaths.Count -ne 0) {
        throw "The release PAK contains Windows-style internal paths."
    }

    $compiledHash = Get-BytesSha256 $compiledMenuBytes
    $packagedHash = Get-BytesSha256 ([byte[]]$menuEntries[0].Data)
    if ($compiledHash -ne $packagedHash) {
        throw "The packaged menu.dat does not match the compiled input."
    }

    foreach ($supportEntry in $supportEntries) {
        $name = Normalize-PakPath $supportEntry.Name
        $verified = @($verifiedEntries | Where-Object { $_.Name -ieq $name })
        if ($verified.Count -ne 1 -or
            (Get-BytesSha256 ([byte[]]$verified[0].Data)) -ne
            (Get-BytesSha256 ([byte[]]$supportEntry.Data))) {
            throw "Support asset changed while packaging: $name"
        }
    }

    Compress-Archive -LiteralPath $stagingPackageDirectory -DestinationPath $stagingZipPath

    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $archive = [System.IO.Compression.ZipFile]::OpenRead($stagingZipPath)
    try {
        $zipEntries = @($archive.Entries | Where-Object { -not [string]::IsNullOrEmpty($_.Name) })
        $expectedZipEntries = @(
            "$artifactName/README.md",
            "$artifactName/autoexec.cfg.example",
            "$artifactName/menu.pak"
        )

        if ($zipEntries.Count -ne 3) {
            throw "Expected three files in the release ZIP; found $($zipEntries.Count)."
        }

        foreach ($expectedEntry in $expectedZipEntries) {
            if (-not ($zipEntries.FullName -contains $expectedEntry)) {
                throw "Release ZIP is missing: $expectedEntry"
            }
        }
    }
    finally {
        $archive.Dispose()
    }

    if ($Force) {
        if (Test-Path -LiteralPath $finalPackageDirectory) {
            Remove-Item -LiteralPath $finalPackageDirectory -Recurse -Force
        }
        if (Test-Path -LiteralPath $finalZipPath) {
            Remove-Item -LiteralPath $finalZipPath -Force
        }
    }

    Move-Item -LiteralPath $stagingPackageDirectory -Destination $finalPackageDirectory
    Move-Item -LiteralPath $stagingZipPath -Destination $finalZipPath

    [pscustomobject]@{
        Version       = $Version
        Package       = $finalPackageDirectory
        Zip           = $finalZipPath
        ZipSHA256     = (Get-FileHash -Algorithm SHA256 -LiteralPath $finalZipPath).Hash
        MenuDatSHA256 = $compiledHash
        PakEntries    = $verifiedEntries.Count
    }
}
finally {
    if (Test-Path -LiteralPath $stagingRoot) {
        Assert-ChildPath $outputPath $stagingRoot
        Remove-Item -LiteralPath $stagingRoot -Recurse -Force
    }
}
