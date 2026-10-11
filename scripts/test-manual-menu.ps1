[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string] $Compiler,
    [Parameter(Mandatory = $true)][string] $Fte,
    [Parameter(Mandatory = $true)][string] $Qss,
    [Parameter(Mandatory = $true)][string] $QuakeData,
    [Parameter(Mandatory = $true)][string] $LibreQuakeData,
    [string] $TestName = 'manual-starters'
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
if ($TestName -notmatch '^[a-zA-Z0-9_-]+$') { throw 'Invalid test name.' }
$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$output = Join-Path $root "dist/runtime/$TestName"
if (Test-Path -LiteralPath $output) { throw "Evidence already exists: $output" }
$manual = Join-Path $output 'manual'
[void][IO.Directory]::CreateDirectory($manual)
function Assert([bool] $Condition, [string] $Message) { if (-not $Condition) { throw $Message } }
function Hash([string] $Path) { (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash }
# Seed an old launcher, with settings/saves and overrides that must leave the search path.
$legacy = Join-Path $manual 'fte-quake'
[void][IO.Directory]::CreateDirectory((Join-Path $legacy 'id1'))
$legacyGame = Join-Path $legacy 'menusys_test'
[void][IO.Directory]::CreateDirectory((Join-Path $legacyGame 'menugfx'))
foreach ($pak in @('pak0.pak', 'pak1.pak')) { Copy-Item -LiteralPath (Join-Path $QuakeData $pak) -Destination (Join-Path $legacy 'id1') }
[IO.File]::WriteAllText((Join-Path $legacyGame 'menu.pak'), 'obsolete fixture')
[IO.File]::WriteAllText((Join-Path $legacyGame 'menugfx/obsolete.lmp'), 'obsolete artwork')
[IO.File]::WriteAllLines((Join-Path $legacyGame 'autoexec.cfg'), @('name "personal name"', 'in 1 forceqmenu 0', 'in 1 menu_restart', 'in 1 togglemenu'))
[IO.File]::WriteAllText((Join-Path $legacyGame 'config.cfg'), 'sensitivity "4.25"')
[IO.File]::WriteAllText((Join-Path $legacyGame 'fte.cfg'), 'name "saved FTE name"')
[IO.File]::WriteAllText((Join-Path $legacyGame 'preserved.sav'), 'save preservation sentinel')
$saved = @{}
foreach ($file in @('config.cfg', 'fte.cfg', 'preserved.sav')) { $saved[$file] = Hash (Join-Path $legacyGame $file) }
& (Join-Path $PSScriptRoot 'prepare-manual-menu.ps1') -Compiler $Compiler -ManualDirectory $manual -QuakeData $QuakeData -LibreQuakeData $LibreQuakeData *> (Join-Path $output 'first-prepare.log')
Assert (-not (Test-Path -LiteralPath (Join-Path $legacyGame 'menu.pak'))) 'Old fixture remains active.'
Assert (-not (Test-Path -LiteralPath (Join-Path $legacyGame 'menugfx/obsolete.lmp'))) 'Obsolete artwork remains active.'
Assert (@(Get-ChildItem -LiteralPath (Join-Path $manual 'archive') -Recurse -Filter 'obsolete.lmp').Count -eq 1) 'Old artwork evidence was lost.'
Assert ((Get-Content -LiteralPath (Join-Path $legacyGame 'autoexec.cfg') -Raw).Trim() -eq 'name "personal name"') 'Personal autoexec was not preserved.'
$firstMenuHash = Hash (Join-Path $legacyGame 'menu.dat')
$firstCsqcHash = Hash (Join-Path $root 'dist/build/csprogs.dat')
# Change one installed module and shared artwork, then prepare through the actual new starter.
[IO.File]::WriteAllText((Join-Path $manual 'qss-librequake/menusys_test/menu.dat'), 'stale module')
[IO.File]::WriteAllText((Join-Path $manual 'shared/quake/menugfx/cursor_copr.tga'), 'stale artwork')
$escapedSettings = @{
    Compiler = $Compiler.Replace("'", "''")
    Fte = $Fte.Replace("'", "''")
    Qss = $Qss.Replace("'", "''")
}
[IO.File]::WriteAllLines((Join-Path $manual 'settings.psd1'), @('@{', "Compiler = '$($escapedSettings.Compiler)'", "Fte = '$($escapedSettings.Fte)'", "Qss = '$($escapedSettings.Qss)'", '}'))
& (Join-Path $manual 'qss-librequake.cmd') -PrepareOnly > (Join-Path $output 'second-prepare.log')
Assert ($LASTEXITCODE -eq 0) 'The generated QSS/LibreQuake starter failed.'
$manifest = Get-Content -LiteralPath (Join-Path $manual 'manifest.json') -Raw | ConvertFrom-Json
Assert ($manifest.MenuSha256 -eq $firstMenuHash) 'Repeated MenuQC builds differ.'
Assert ((Hash (Join-Path $root 'dist/build/csprogs.dat')) -eq $firstCsqcHash) 'Repeated CSQC builds differ.'
Assert (@($manifest.Targets.PSObject.Properties).Count -eq 4) 'The launcher matrix is incomplete.'
foreach ($property in $manifest.Targets.PSObject.Properties) {
    $name = $property.Name
    $entry = $property.Value
    $game = Join-Path $manual "$name/menusys_test"
    foreach ($file in $entry.Files.PSObject.Properties) { Assert ((Hash (Join-Path $game $file.Name)) -eq $file.Value) "Drift in $name/$($file.Name)" }
    foreach ($pak in $entry.GameData.PSObject.Properties) { Assert ((Hash (Join-Path $manual "$name/id1/$($pak.Name)")) -eq $pak.Value) "Game data drift in $name" }
    foreach ($pair in @(@('id1', "shared/$($entry.Dataset)/id1"), @('menusys_test/menugfx', "shared/$($entry.Dataset)/menugfx"))) {
        $item = Get-Item -LiteralPath (Join-Path $manual "$name/$($pair[0])")
        Assert (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) "$name has a duplicate data directory."
        Assert ([IO.Path]::GetFullPath([string]@($item.Target)[0]) -eq [IO.Path]::GetFullPath((Join-Path $manual $pair[1]))) "$name links to the wrong dataset."
    }
    $startup = Get-Content -LiteralPath (Join-Path $game 'quake.rc') -Raw
    Assert ($startup.Contains('exec config.cfg')) "$name skips saved settings."
    if ($name.StartsWith('fte-')) { Assert ($startup.Contains('exec fte.cfg')) "$name skips FTE settings." }
    else { Assert ($startup -notmatch 'forceqmenu|menu_restart|exec fte.cfg|in 1') "$name contains FTE startup commands." }
}
foreach ($file in $saved.Keys) { Assert ((Hash (Join-Path $legacyGame $file)) -eq $saved[$file]) "Preparation changed $file" }
Assert ((Hash (Join-Path $manual 'shared/quake/menugfx/cursor_copr.tga')) -eq (Hash (Join-Path $root 'assets/menu/cursor_copr.tga'))) 'Source artwork was not restored.'
. (Join-Path $PSScriptRoot 'scaling-test-tools.ps1')
$results = @()
foreach ($name in @('fte-quake', 'fte-librequake', 'quakespasm-spiked', 'qss-librequake')) {
    $isFte = $name.StartsWith('fte-')
    $engine = if ($isFte) { $Fte } else { $Qss }
    $basedir = Join-Path $manual $name
    $game = Join-Path $basedir 'menusys_test'
    foreach ($phase in @('menu', 'map')) {
        $pause = 'wait;' * 120
        $commands = @(($pause + 'echo SCALE checked manual-startup'))
        if ($name -eq 'fte-librequake' -and $phase -eq 'menu') {
            $commands += @('joy_enable 0', 'joystick', 'joy_enable 1', 'joystick')
        }
        if ($phase -eq 'menu') {
            foreach ($screen in @('main', 'single', 'options', 'setup')) {
                $open = if ($screen -eq 'setup') { 'm_setup' } else { "m_$screen" }
                $shot = if ($isFte) { "screenshot $screen.png" } else { 'screenshot png' }
                $commands += "m_pop; $open; $pause $shot"
            }
        } else {
            $shot = if ($isFte) { 'screenshot map.png' } else { 'screenshot png' }
            $commands += "$pause $shot"
        }
        $commands += 'quit'
        [IO.File]::WriteAllLines((Join-Path $game 'manual-smoke.cfg'), $commands)
        $engineArgs = @('-basedir', ('"' + $basedir + '"'), '-game', 'menusys_test', '-window', '-width', 960, '-height', 600, '-condebug')
        if ($isFte) { $engineArgs = @('-nohome', '+set', 'vid_fullscreen', '0') + $engineArgs }
        if ($phase -eq 'menu') {
            $boot = if ($isFte) { @('+in', '1', 'exec', 'quake.rc', '+in', '1', 'togglemenu', '+in', '2', 'exec', 'manual-smoke.cfg') } else { @('+m_main', '+exec', 'manual-smoke.cfg') }
        } elseif ($isFte) {
            # Schedule after the generated startup has restored saved settings.
            # FTE's single-player server does not open a UDP listener.
            [IO.File]::WriteAllLines((Join-Path $game 'manual-map-queue.cfg'), @('exec quake.rc', 'in 6 exec manual-smoke.cfg'))
            $boot = @('+map', 'start', '+in', '1', 'exec', 'manual-map-queue.cfg')
        } else {
            # Waits in the startup buffer can prevent client signon from completing.
            # Run screenshot commands afterwards through a temporary loopback listener.
            $password = [Guid]::NewGuid().ToString('N')
            $probe = [Net.Sockets.UdpClient]::new([Net.IPEndPoint]::new([Net.IPAddress]::Loopback, 0))
            $port = $probe.Client.LocalEndPoint.Port
            $probe.Dispose()
            $boot = @('+sv_public', '0', '+rcon_password', $password, '+listen', '1', '+map', 'start')
            $engineArgs += @('-ip', '127.0.0.1', '-port', $port)
        }
        # Keep +commands ahead of long paths; QSS 2021 truncates its cmdline cvar.
        $engineArgs = $boot + $engineArgs
        $process = Start-Process -FilePath $engine -ArgumentList $engineArgs -WorkingDirectory $basedir -WindowStyle Hidden -PassThru
        if ($phase -eq 'map' -and -not $isFte) {
            Start-Sleep -Seconds 6
            $body = [Text.Encoding]::ASCII.GetBytes(([char]5) + $password + [char]0 + 'exec manual-smoke.cfg' + [char]0)
            $length = $body.Length + 4
            [byte[]]$packet = @(128, 0, ($length -shr 8), ($length -band 255)) + $body
            $client = [Net.Sockets.UdpClient]::new()
            try { [void]$client.Send($packet, $packet.Length, '127.0.0.1', $port) } finally { $client.Dispose() }
        }
        if (-not $process.WaitForExit(55000)) { Stop-Process -Id $process.Id; throw "$name timed out in $phase phase." }
        # FTE SVN 6202 returns 1 for an explicit quit; captures and logs must still pass.
        Assert ($process.ExitCode -eq 0 -or ($isFte -and $process.ExitCode -eq 1)) "$name exited with $($process.ExitCode)."
        $expected = @(if ($phase -eq 'menu') { 'main', 'single', 'options', 'setup' } else { 'map' })
        if (-not $isFte) {
            $shots = @(Get-ChildItem -LiteralPath $game -Filter 'spasm*.png' | Sort-Object Name)
            Assert ($shots.Count -eq $expected.Count) "Wrong capture count in $name/$phase"
            for ($i = 0; $i -lt $shots.Count; $i++) { Move-Item -LiteralPath $shots[$i].FullName -Destination (Join-Path $game ($expected[$i] + '.png')) }
        }
        foreach ($screen in $expected) { Assert (Test-Path -LiteralPath (Join-Path $game "$screen.png")) "Missing $name/$screen capture." }
        if ($phase -eq 'map') {
            # The opaque center of the native title is identical when Main covers
            # the map. Compare actual rendered pixels, independently of VM logs.
            $mainImage = [Drawing.Bitmap]::new((Join-Path $game 'main.png'))
            $mapImage = [Drawing.Bitmap]::new((Join-Path $game 'map.png'))
            try {
                $scale = [Math]::Min($mainImage.Width / 640.0, $mainImage.Height / 400.0)
                $left = [int]($mainImage.Width / 2) - 4
                $top = [int]($mainImage.Height / 2 - 84 * $scale) - 4
                $matching = 0
                for ($y = $top; $y -lt $top + 8; $y++) {
                    for ($x = $left; $x -lt $left + 8; $x++) {
                        if ($mainImage.GetPixel($x, $y).ToArgb() -eq $mapImage.GetPixel($x, $y).ToArgb()) { $matching++ }
                    }
                }
                Assert ($matching -lt 60) "$name opened Main over a command-line map."
            } finally { $mainImage.Dispose(); $mapImage.Dispose() }
        }
        $logs = @(Get-ChildItem -LiteralPath $basedir -Recurse -Filter '*.log')
        if ($name -eq 'fte-librequake' -and $phase -eq 'menu') {
            foreach ($value in @('0', '1')) {
                Assert (@($logs | Select-String -SimpleMatch ('"joystick" is "' + $value + '"')).Count -gt 0) "Joystick alias did not forward $value."
            }
        }
        $errors = @(Get-ScalingErrors $logs ($name -eq 'qss-librequake'))
        Assert ($errors.Count -eq 0) ($errors -join "`n")
        foreach ($log in $logs) { Copy-Item -LiteralPath $log.FullName -Destination (Join-Path $output "$name-$phase-$($log.Name)") -Force }
        $results += [pscustomobject]@{ Target = $name; Phase = $phase; Captures = $expected.Count; Passed = $true }
    }
}

# Exercise the real starter without any command that opens a menu.
# Hide only its process launch; keep its preparation, arguments and startup intact.
if (-not ('ManualStarterWindow' -as [type])) {
Add-Type -TypeDefinition @'
using System;
using System.Text;
using System.Runtime.InteropServices;
public static class ManualStarterWindow {
    public delegate bool EnumProc(IntPtr h, IntPtr l);
    [DllImport("user32.dll")] static extern bool EnumWindows(EnumProc cb, IntPtr l);
    [DllImport("user32.dll")] static extern uint GetWindowThreadProcessId(IntPtr h, out uint p);
    [DllImport("user32.dll")] static extern int GetClassName(IntPtr h, StringBuilder s, int n);
    [DllImport("user32.dll")] static extern bool PostMessage(IntPtr h, uint m, IntPtr w, IntPtr l);
    public static IntPtr Find(int pid) {
        IntPtr found = IntPtr.Zero;
        EnumWindows((h,l) => {
            uint p; GetWindowThreadProcessId(h,out p);
            var name = new StringBuilder(100); GetClassName(h,name,100);
            if (p == pid && name.ToString() == "SDL_app") found = h;
            return true;
        },IntPtr.Zero);
        return found;
    }
    public static void Capture(IntPtr h) {
        PostMessage(h,0x100,(IntPtr)123,(IntPtr)0x580001);
        PostMessage(h,0x101,(IntPtr)123,new IntPtr(unchecked((int)0xC0580001)));
    }
    public static void Close(IntPtr h) { PostMessage(h,0x10,IntPtr.Zero,IntPtr.Zero); }
}
'@
}
foreach ($name in @('quakespasm-spiked', 'qss-librequake')) {
    $basedir = Join-Path $manual $name
    $game = Join-Path $basedir 'menusys_test'
    Add-Content -LiteralPath (Join-Path $game 'autoexec.cfg') -Value 'bind F12 "echo SCALE checked actual-starter; screenshot png"'
    $launchOutput = & {
        function Start-Process([string] $FilePath, [string[]] $ArgumentList, [string] $WorkingDirectory) {
            Microsoft.PowerShell.Management\Start-Process @PSBoundParameters -WindowStyle Hidden -PassThru
        }
        & (Join-Path $PSScriptRoot 'start-manual-menu.ps1') -Target $name -SettingsFile (Join-Path $manual 'settings.psd1')
    } 2>&1 3>&1 4>&1 5>&1 6>&1
    $launchOutput | Out-File -LiteralPath (Join-Path $output "$name-actual-starter-prepare.log")
    $processes = @($launchOutput | Where-Object { $_ -is [Diagnostics.Process] })
    Assert ($processes.Count -eq 1) 'The real starter did not launch an engine.'
    $process = $processes[0]
    try {
        Start-Sleep -Seconds 6
        $handle = [ManualStarterWindow]::Find($process.Id)
        Assert ($handle -ne [IntPtr]::Zero) 'Missing starter window.'
        [ManualStarterWindow]::Capture($handle)
        $deadline = [DateTime]::UtcNow.AddSeconds(10)
        $capture = Join-Path $game 'spasm0000.png'
        while (-not (Test-Path -LiteralPath $capture) -and [DateTime]::UtcNow -lt $deadline) { Start-Sleep -Milliseconds 100 }
        Assert (Test-Path -LiteralPath $capture) 'The real starter did not produce its initial capture.'
        [ManualStarterWindow]::Close($handle)
        Assert ($process.WaitForExit(5000)) 'The starter engine did not close.'
        Move-Item -LiteralPath $capture -Destination (Join-Path $game 'starter.png')
        $mainImage = [Drawing.Bitmap]::new((Join-Path $game 'main.png'))
        $startupImage = [Drawing.Bitmap]::new((Join-Path $game 'starter.png'))
        try {
            Assert ($startupImage.Width -eq 960 -and $startupImage.Height -eq 600) 'Wrong starter window dimensions.'
            $left = [int]($mainImage.Width / 2) - 4
            $top = [int]($mainImage.Height / 2 - 84 * [Math]::Min($mainImage.Width / 640.0, $mainImage.Height / 400.0)) - 4
            $matching = 0
            for ($y = $top; $y -lt $top + 8; $y++) {
                for ($x = $left; $x -lt $left + 8; $x++) {
                    if ($mainImage.GetPixel($x, $y).ToArgb() -eq $startupImage.GetPixel($x, $y).ToArgb()) { $matching++ }
                }
            }
            Assert ($matching -ge 60) "$name stopped at the console instead of opening Main."
        } finally { $mainImage.Dispose(); $startupImage.Dispose() }
        $logs = @(Get-ChildItem -LiteralPath $basedir -Recurse -Filter '*.log')
        $errors = @(Get-ScalingErrors $logs ($name -eq 'qss-librequake'))
        Assert ($errors.Count -eq 0) ($errors -join "`n")
        foreach ($log in $logs) { Copy-Item -LiteralPath $log.FullName -Destination (Join-Path $output "$name-starter-$($log.Name)") }
        $results += [pscustomobject]@{ Target = $name; Phase = 'actual-starter'; Captures = 1; Passed = $true }
    } finally { if (-not $process.HasExited) { Stop-Process -Id $process.Id } }
}

$results | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $output 'results.json')
Write-Host "Manual migration, drift repair, settings preservation and all ten engine sessions passed: $output"
