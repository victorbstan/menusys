[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string] $Pak,
    [Parameter(Mandatory = $true)][string] $OutputDirectory
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$pakPath = [IO.Path]::GetFullPath($Pak)
$outputPath = [IO.Path]::GetFullPath($OutputDirectory)
$stream = [IO.File]::OpenRead($pakPath)
$reader = [IO.BinaryReader]::new($stream)
try {
    if ([Text.Encoding]::ASCII.GetString($reader.ReadBytes(4)) -ne 'PACK') {
        throw "Not a Quake PAK: $pakPath"
    }
    $directoryOffset = $reader.ReadInt32()
    $directoryLength = $reader.ReadInt32()
    if ($directoryOffset -lt 12 -or $directoryLength -lt 64 -or ($directoryLength % 64) -or
        [long]$directoryOffset + $directoryLength -gt $stream.Length) {
        throw "Invalid Quake PAK directory: $pakPath"
    }
    $stream.Position = $directoryOffset
    $entryOffset = -1
    $entryLength = -1
    for ($i = 0; $i -lt ($directoryLength / 64); $i++) {
        $name = [Text.Encoding]::ASCII.GetString($reader.ReadBytes(56)).TrimEnd([char]0).Replace('\', '/')
        $offset = $reader.ReadInt32()
        $length = $reader.ReadInt32()
        if ($name -ieq 'gfx/menuplyr.lmp') {
            $entryOffset = $offset
            $entryLength = $length
        }
    }
    if ($entryOffset -lt 0) { throw "gfx/menuplyr.lmp was not found in $pakPath" }
    if ($entryOffset -lt 12 -or $entryLength -lt 8 -or [long]$entryOffset + $entryLength -gt $stream.Length) {
        throw 'Invalid menuplyr.lmp data range.'
    }
    $stream.Position = $entryOffset
    $source = $reader.ReadBytes($entryLength)
} finally {
    $reader.Dispose()
    $stream.Dispose()
}

if ($source.Length -lt 8) { throw 'menuplyr.lmp is truncated.' }
$width = [BitConverter]::ToInt32($source, 0)
$height = [BitConverter]::ToInt32($source, 4)
$pixelCount = [long]$width * $height
if ($width -le 0 -or $height -le 0 -or $pixelCount -gt 1048576 -or $source.Length -ne 8 + $pixelCount) {
    throw "Invalid menuplyr.lmp dimensions: ${width}x${height}"
}

[void][IO.Directory]::CreateDirectory($outputPath)
$header = [byte[]]::new(8)
[Array]::Copy($source, 0, $header, 0, 8)

function Write-Layer([string] $Name, [scriptblock] $MapPixel) {
    $result = [byte[]]::new(8 + $pixelCount)
    [Array]::Copy($header, 0, $result, 0, 8)
    for ($p = 0; $p -lt $pixelCount; $p++) {
        $result[8 + $p] = & $MapPixel ([int]$source[8 + $p])
    }
    [IO.File]::WriteAllBytes((Join-Path $outputPath $Name), $result)
}

# These are Quake's TOP_RANGE=16 and BOTTOM_RANGE=96 (render.h),
# NOT consecutive bands. Match M_BuildTranslationTable in WinQuake/menu.c:
# destination bands 8..13 reverse shade order; all other pixels are unchanged.
# Body regions are defined by the artwork's palette indices, not screen Y.
Write-Layer 'base.lmp' { param($pixel) if (($pixel -ge 16 -and $pixel -lt 32) -or ($pixel -ge 96 -and $pixel -lt 112)) { 255 } else { $pixel } }
foreach ($color in 0..13) {
    $band = $color * 16
    Write-Layer "top$color.lmp" { param($pixel) if ($pixel -ge 16 -and $pixel -lt 32) { if ($band -lt 128) { $band + $pixel - 16 } else { $band + 15 - ($pixel - 16) } } else { 255 } }
    Write-Layer "bottom$color.lmp" { param($pixel) if ($pixel -ge 96 -and $pixel -lt 112) { if ($band -lt 128) { $band + $pixel - 96 } else { $band + 15 - ($pixel - 96) } } else { 255 } }
}

Write-Host "Generated 29 live player-preview layers from $pakPath in $outputPath"
