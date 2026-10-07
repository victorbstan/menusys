[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string] $Pak,
    [Parameter(Mandatory = $true)][string] $LayerDirectory,
    [string] $RuntimeDirectory
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Read-PakEntry([string] $Path, [string] $Entry) {
    $stream = [IO.File]::OpenRead([IO.Path]::GetFullPath($Path))
    $reader = [IO.BinaryReader]::new($stream)
    try {
        if ([Text.Encoding]::ASCII.GetString($reader.ReadBytes(4)) -ne 'PACK') { throw 'Not a PAK.' }
        $offset = $reader.ReadInt32()
        $count = $reader.ReadInt32() / 64
        $stream.Position = $offset
        for ($i = 0; $i -lt $count; $i++) {
            $name = [Text.Encoding]::ASCII.GetString($reader.ReadBytes(56)).TrimEnd([char]0)
            $start = $reader.ReadInt32()
            $length = $reader.ReadInt32()
            if ($name -ieq $Entry) {
                $stream.Position = $start
                return ,$reader.ReadBytes($length)
            }
        }
        throw "Missing PAK entry $Entry"
    } finally { $reader.Dispose(); $stream.Dispose() }
}

$source = Read-PakEntry $Pak 'gfx/menuplyr.lmp'
$width = [BitConverter]::ToInt32($source, 0)
$height = [BitConverter]::ToInt32($source, 4)
$base = [IO.File]::ReadAllBytes((Join-Path $LayerDirectory 'base.lmp'))
$tops = @(); $bottoms = @()
foreach ($color in 0..13) {
    $tops += ,([IO.File]::ReadAllBytes((Join-Path $LayerDirectory "top$color.lmp")))
    $bottoms += ,([IO.File]::ReadAllBytes((Join-Path $LayerDirectory "bottom$color.lmp")))
}
foreach ($layer in (,$base) + $tops + $bottoms) {
    # Validate authored dimensions as well as pixel data; 48x56 is not 64x64.
    if ($layer.Length -ne $source.Length) { throw 'Layer length differs from source.' }
    for ($i = 0; $i -lt 8; $i++) {
        if ($layer[$i] -ne $source[$i]) { throw 'Layer dimensions differ from source.' }
    }
}

# Independent oracle copied from the native game's translation-table algorithm:
# id-Software/Quake WinQuake/menu.c M_BuildTranslationTable and render.h.
# Test every shirt/pants combination, including all reversed destination ramps,
# and every unchanged pixel (skin, face, gun, boots, transparent background).
$checks = 0
foreach ($shirt in 0..13) {
    foreach ($pants in 0..13) {
        $translation = [int[]](0..255)
        for ($shade = 0; $shade -lt 16; $shade++) {
            $translation[16 + $shade] = if ($shirt -lt 8) { 16 * $shirt + $shade } else { 16 * $shirt + 15 - $shade }
            $translation[96 + $shade] = if ($pants -lt 8) { 16 * $pants + $shade } else { 16 * $pants + 15 - $shade }
        }
        for ($p = 8; $p -lt $source.Length; $p++) {
            $composite = $base[$p]
            if ($tops[$shirt][$p] -ne 255) { $composite = $tops[$shirt][$p] }
            if ($bottoms[$pants][$p] -ne 255) { $composite = $bottoms[$pants][$p] }
            if ($composite -ne $translation[$source[$p]]) {
                throw "Palette mismatch at pixel $($p - 8), shirt $shirt, pants $pants"
            }
            $checks++
        }
    }
}
Write-Host "Native Quake palette oracle: PASS ($checks pixels across 196 combinations; ${width}x${height})."

if ($RuntimeDirectory) {
    Add-Type -AssemblyName System.Drawing
    $logs = Get-ChildItem -LiteralPath $RuntimeDirectory -Recurse -Filter '*.log'
    $logText = ($logs | ForEach-Object { [IO.File]::ReadAllText($_.FullName) }) -join "`n"
    $number = '(-?\d+(?:\.\d+)?)'
    $pattern = "PREVIEW RECT $number $number $number SIZE $number $number $number VIEW $number $number $number SCALE $number $number $number"
    $match = [regex]::Match($logText, $pattern)
    if (-not $match.Success) { throw 'Missing preview rectangle in runtime log.' }
    $game = Join-Path $RuntimeDirectory 'menusys_test'
    $images = @()
    try {
        foreach ($name in @('initial', 'shirt-change', 'pants-change')) {
            $images += [Drawing.Bitmap]::new((Join-Path $game "$name.png"))
        }
        $xScale = $images[0].Width / [double]$match.Groups[7].Value * [double]$match.Groups[10].Value
        $yScale = $images[0].Height / [double]$match.Groups[8].Value * [double]$match.Groups[11].Value
        $xOrigin = [double]$match.Groups[1].Value * $xScale
        $yOrigin = [double]$match.Groups[2].Value * $yScale
        $upperChanged = 0; $lowerChanged = 0; $upperCount = 0; $lowerCount = 0
        for ($y = 0; $y -lt $height; $y++) {
            for ($x = 0; $x -lt $width; $x++) {
                $index = $source[8 + $y * $width + $x]
                if ($index -eq 255) { continue }
                $px = [int][Math]::Floor($xOrigin + ($x + 0.5) * $xScale)
                $py = [int][Math]::Floor($yOrigin + ($y + 0.5) * $yScale)
                $a = $images[0].GetPixel($px, $py).ToArgb()
                $b = $images[1].GetPixel($px, $py).ToArgb()
                $c = $images[2].GetPixel($px, $py).ToArgb()
                # Avoid interpolation at boundaries: only compare pixels whose
                # 3x3 neighborhood belongs to the same region.
                $region = if ($index -ge 16 -and $index -lt 32) { 1 } elseif ($index -ge 96 -and $index -lt 112) { 2 } else { 0 }
                $interior = $true
                foreach ($dy in -1..1) {
                    foreach ($dx in -1..1) {
                        if ($x + $dx -lt 0 -or $x + $dx -ge $width -or $y + $dy -lt 0 -or $y + $dy -ge $height) { $interior = $false; continue }
                        $neighbor = $source[8 + ($y + $dy) * $width + $x + $dx]
                        $neighborRegion = if ($neighbor -ge 16 -and $neighbor -lt 32) { 1 } elseif ($neighbor -ge 96 -and $neighbor -lt 112) { 2 } else { 0 }
                        if ($neighborRegion -ne $region -or $neighbor -eq 255) { $interior = $false }
                    }
                }
                if (-not $interior) { continue }
                if ($region -eq 1) {
                    $upperCount++
                    if ($a -ne $b) { $upperChanged++ }
                    if ($b -ne $c) { throw "Pants control changed a shirt pixel at $x,$y." }
                } elseif ($region -eq 2) {
                    $lowerCount++
                    if ($b -ne $c) { $lowerChanged++ }
                    if ($a -ne $b) { throw "Shirt control changed a pants pixel at $x,$y." }
                } elseif ($a -ne $b -or $b -ne $c) {
                    throw "Color control changed an untranslatable pixel at $x,$y."
                }
            }
        }
        if ($upperCount -eq 0 -or $lowerCount -eq 0 -or $upperChanged -eq 0 -or $lowerChanged -eq 0) {
            throw "Missing visible update: shirt $upperChanged/$upperCount, pants $lowerChanged/$lowerCount."
        }
        Write-Host "Rendered body regions: PASS (shirt $upperChanged/$upperCount changed; pants $lowerChanged/$lowerCount changed; opposite regions and other pixels unchanged)."
    } finally { foreach ($bitmap in $images) { $bitmap.Dispose() } }
}
