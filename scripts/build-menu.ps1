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
    $compile = @(& $Compiler -srcfile $wrapper 2>&1)
    $compile | Set-Content -LiteralPath (Join-Path $build ($output + ".compile.log"))
    $compile | ForEach-Object { Write-Host $_ }
    if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $target) -or
        @($compile | Select-String -Pattern "warning:|warning Q|[1-9][0-9]* warnings").Count) {
        throw 'FTEQCC must produce the requested output with zero warnings. Inspect the compile log.'
    }
    Get-Item -LiteralPath $target | Select-Object FullName, Length
} finally { Pop-Location }
