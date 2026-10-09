[CmdletBinding()]
param([Parameter(Mandatory = $true)][string] $OutputDirectory)
$ErrorActionPreference = 'Stop'
[void](New-Item -ItemType Directory -Path $OutputDirectory -Force)
# Static artwork is versioned alongside the menu; no previous release is needed.
Get-ChildItem -LiteralPath (Join-Path $PSScriptRoot '../assets/menu') -File |
    Copy-Item -Destination $OutputDirectory -Force
# Original 5x7 letterforms, expanded to three-pixel strokes with a shadow.
# Native dimensions are retained at runtime; games can override these headers
# with gfx/p_levels.lmp and gfx/p_demos.lmp in their own visual style.
$glyphs = @{
    L = @('10000','10000','10000','10000','10000','10000','11111')
    E = @('11111','10000','10000','11110','10000','10000','11111')
    V = @('10001','10001','10001','10001','10001','01010','00100')
    S = @('01111','10000','10000','01110','00001','00001','11110')
    D = @('11110','10001','10001','10001','10001','10001','11110')
    M = @('10001','11011','10101','10101','10001','10001','10001')
    O = @('01110','10001','10001','10001','10001','10001','01110')
}
foreach ($label in @('LEVELS', 'DEMOS')) {
    $width = $label.Length * 18 - 3 + 4
    $height = 24
    $pixels = New-Object byte[] ($width * $height)
    for ($i = 0; $i -lt $pixels.Length; $i++) { $pixels[$i] = 255 }
    for ($letter = 0; $letter -lt $label.Length; $letter++) {
        $glyph = $glyphs[[string]$label[$letter]]
        for ($y = 0; $y -lt 7; $y++) {
            for ($x = 0; $x -lt 5; $x++) {
                if ($glyph[$y][$x] -ne '1') { continue }
                for ($dy = 0; $dy -lt 3; $dy++) {
                    for ($dx = 0; $dx -lt 3; $dx++) {
                        $px = 1 + $letter * 18 + $x * 3 + $dx
                        $py = 1 + $y * 3 + $dy
                        $pixels[($py+1)*$width+$px+1] = 0
                        $pixels[$py*$width+$px] = [byte](160 + [Math]::Min(10, $y))
                    }
                }
            }
        }
    }
    $path = Join-Path $OutputDirectory ('p_' + $label.ToLowerInvariant() + '.lmp')
    $stream = [IO.File]::Create($path)
    $writer = [IO.BinaryWriter]::new($stream)
    try { $writer.Write([int]$width); $writer.Write([int]$height); $writer.Write($pixels) }
    finally { $writer.Dispose() }
}
