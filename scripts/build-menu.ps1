[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string] $Compiler,
    [switch] $Csqc
)
$ErrorActionPreference = 'Stop'
$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$build = Join-Path $root 'dist/build'
[void](New-Item -ItemType Directory -Path $build -Force)
$source = if ($Csqc) { 'csprogs.src' } else { 'menu.src' }
$output = if ($Csqc) { 'csprogs.dat' } else { 'menu.dat' }
# The last pragma wins on older FTEQCC builds whose -o flag is ignored for
# new-style sources. Compile a wrapper so the repository source is unchanged.
$wrapper = Join-Path $build $source
$target = (Join-Path $build $output).Replace('\', '/')
[IO.File]::WriteAllText($wrapper, "#include `"../../$source`"`n#pragma progs_dat `"$output`"`n")
Push-Location $build
try {
    if (Test-Path -LiteralPath $target) { Remove-Item -LiteralPath $target }
    & $Compiler -srcfile $wrapper
    if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $target)) {
        throw 'FTEQCC did not produce the requested output.'
    }
    Get-Item -LiteralPath $target | Select-Object FullName, Length
} finally { Pop-Location }
