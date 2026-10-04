[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string] $Compiler,
    [Parameter(Mandatory = $true)][string] $Engine,
    [Parameter(Mandatory = $true)][string] $GameData,
    [Parameter(Mandatory = $true)][string] $MenuPak,
    [string] $TestName = 'layout',
    [int] $Width = 960,
    [int] $Height = 600
)

$ErrorActionPreference = 'Stop'
if ($TestName -notmatch '^[a-zA-Z0-9_-]+$') { throw 'TestName must be a simple directory name.' }
$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$testRoot = Join-Path $root "dist/runtime/$TestName"
if (Test-Path -LiteralPath $testRoot) { throw "Test output already exists: $testRoot" }
$build = Join-Path $root 'dist/build'
[void](New-Item -ItemType Directory -Path $build -Force)
$target = Join-Path $build 'layout-menu.dat'
$wrapper = Join-Path $build 'layout.src'
[IO.File]::WriteAllText($wrapper, "#include `"../../tests/menu-layout.src`"`n#pragma progs_dat `"layout-menu.dat`"`n")
Push-Location $build
try {
    if (Test-Path -LiteralPath $target) { Remove-Item -LiteralPath $target }
    & $Compiler -srcfile $wrapper
    if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $target)) { throw 'Layout fixture compilation failed.' }
} finally { Pop-Location }

$id1 = Join-Path $testRoot 'id1'
$game = Join-Path $testRoot 'menusys_test'
[void](New-Item -ItemType Directory -Path $id1)
[void](New-Item -ItemType Directory -Path $game)
foreach ($name in @('pak0.pak', 'pak1.pak')) {
    Copy-Item -LiteralPath (Join-Path $GameData $name) -Destination $id1
}
Copy-Item -LiteralPath $MenuPak -Destination (Join-Path $game 'menu.pak')
Copy-Item -LiteralPath $target -Destination (Join-Path $game 'menu.dat')
[IO.File]::WriteAllLines((Join-Path $game 'quake.rc'), @('exec default.cfg', 'exec autoexec.cfg', 'stuffcmds'))
[IO.File]::WriteAllLines((Join-Path $game 'autoexec.cfg'), @('developer 1', 'cl_maxfps 60', 'alias startdemos ""', 'in 1 forceqmenu 0', 'in 1 menu_restart', 'in 1.5 exec layout.cfg'))
[IO.File]::WriteAllLines((Join-Path $game 'layout.cfg'), @(
    'in 0.2 layout_video', 'in 0.5 screenshot video-scrolled.png',
    'in 0.6 layout_effects', 'in 0.9 screenshot effects-scrolled.png',
    'in 1.2 layout_updates', 'in 1.5 screenshot updates-prompt.png',
    'in 3 screenshot updates-empty.png', 'in 3.2 layout_metadata',
    'in 3.5 screenshot updates-metadata.png', 'in 3.8 layout_details',
    'in 4.1 screenshot updates-details.png', 'in 4.4 quit'
))

# Dismiss the native update-source consent prompt with Escape in this test
# process only. Do not enable a source or apply any package changes.
if (-not ('MenuLayoutKeys' -as [type])) {
    Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class MenuLayoutKeys {
    public delegate bool EnumProc(IntPtr h, IntPtr l);
    [DllImport("user32.dll")] public static extern bool EnumWindows(EnumProc cb, IntPtr l);
    [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, out uint p);
    [DllImport("user32.dll")] public static extern bool PostMessage(IntPtr h, uint m, IntPtr w, IntPtr l);
    public static void Escape(int pid) {
        EnumWindows((h,l) => {
            uint p; GetWindowThreadProcessId(h,out p);
            if (p == (uint)pid) {
                PostMessage(h,0x100,(IntPtr)27,(IntPtr)0x10001);
                PostMessage(h,0x101,(IntPtr)27,new IntPtr(unchecked((int)0xC0010001)));
            }
            return true;
        }, IntPtr.Zero);
    }
}
'@
}
$engineArgs = @('-nohome', '+set', 'vid_fullscreen', '0', '-basedir', ('"'+$testRoot+'"'), '-game', 'menusys_test', '-window', '-width', $Width, '-height', $Height, '-condebug')
$process = Start-Process -FilePath $Engine -ArgumentList $engineArgs -WorkingDirectory $testRoot -WindowStyle Hidden -PassThru
Start-Sleep -Milliseconds 3800
[MenuLayoutKeys]::Escape($process.Id)
if (-not $process.WaitForExit(15000)) {
    Stop-Process -Id $process.Id
    throw "Layout test timed out. Inspect $testRoot"
}
foreach ($name in @('video-scrolled', 'effects-scrolled', 'updates-prompt', 'updates-empty', 'updates-metadata', 'updates-details')) {
    if (-not (Test-Path -LiteralPath (Join-Path $game "$name.png"))) { throw "Missing layout screenshot: $name" }
}
$logs = @(Get-ChildItem -LiteralPath $testRoot -Recurse -Filter '*.log')
$errors = @($logs | Select-String -Pattern 'Unknown command|unimplemented builtin|Host_Error|Menu_Abort|PF_strunzone:')
if ($errors.Count) { throw ($errors.Line -join "`n") }
if (-not ($logs | Select-String -Pattern 'LAYOUT details height [1-9]')) { throw 'Long metadata did not exercise its scrollbar.' }
Get-ChildItem -LiteralPath $game -Filter '*.png' | Select-Object FullName, Length
