# Development

## Requirements

- A local Quake installation with registered `id1/pak0.pak` data
- FTEQCC with MenuQC support
- FTEQW or Quakespasm-Spiked for runtime testing
- PowerShell 5.1 or newer for the release script

The compiler and Quake game data are external dependencies and are not included
in this repository.

## Branch workflow

`simple-menus` is the release branch. Make changes on a short-lived branch,
compile and test there, then merge a pull request into `simple-menus`. Build and
tag releases from the merged commit rather than from the feature branch.

Use closing keywords in the pull request description when applicable:

```text
Fixes #5
Fixes #6
```

## Source layout

- `menu.src` declares the MenuQC build and console-command mappings.
- `menu/*.qc` implements the actual menus.
- `menusys/*.qc` is the lower-level widget framework. Prefer changing files in
  `menu/` unless a feature belongs in the reusable framework.
- `csprogs.src` and `cs/entrypoints.qc` provide the optional CSQC variant.

The classic main, single-player, and multiplayer screens use static Quake
artwork plus invisible selectable hotspots. `menu/classic_widgets.qc` adds the
animated menudot to those hotspots. Keep keyboard focus, mouse-follow focus,
and draw ordering in mind when changing these screens.

## Compile MenuQC

The command-line build helper writes under `dist/build` and keeps compiler
logs there. It avoids overwriting an installed module even with older FTEQCC
versions that ignore `-o`:

```powershell
.\scripts\build-menu.ps1 -Compiler C:\path\to\fteqcc.exe
.\scripts\build-menu.ps1 -Compiler C:\path\to\fteqcc.exe -Csqc
```

Both variants should report zero warnings. The following GUI workflow retains
the original output path.

From the repository root, open `menu.src` in FTEQCC and choose **Compile**. A
command-line invocation also works with compiler builds that support it:

```powershell
fteqccgui64.exe menu.src -stdout
```

A successful build reports zero compiler errors and writes:

```text
../menu.dat
```

This location comes from the first line of `menu.src`:

```text
#pragma progs_dat "../menu.dat"
```

Some FTEQCC GUI builds remain open after compiling. Close the compiler after
confirming the successful result; do not treat the persistent GUI process as a
failed build.

## Test in an isolated game directory

Do not copy a development build over an existing release until it has passed an
isolated test. From the Quake basedir:

```powershell
$quakeBasedir = "C:\path\to\quake"
$menuDat = "C:\path\to\id1\menu.dat"

New-Item -ItemType Directory -Force "$quakeBasedir\menusys_test"
Copy-Item $menuDat "$quakeBasedir\menusys_test\menu.dat" -Force

Set-Location $quakeBasedir
.\fteqw64.exe -nohome -game menusys_test
```

Use `-nohome` so per-user files do not silently override the test data. The
explicit `-game menusys_test` directory also gives the development `menu.dat`
clearer priority than copies under `id1` or `fte`.

For Quakespasm-Spiked:

```powershell
.\quakespasm-spiked-win64.exe -basedir $quakeBasedir -game menusys_test
```

Exact executable names vary by engine build.

### Startup regression test

Verify that a command-line map starts without the menu covering it:

```powershell
.\fteqw64.exe -nohome -game menusys_test +map start
```

### Manual regression checklist

- The main menu uses the classic large-letter artwork.
- The animated menudot appears to the left of the selected main-menu option.
- Arrow keys move the selector and Enter activates the selected option.
- Mouse movement changes the selected classic-menu option.
- The Single Player and Multiplayer menus display the same selector behavior.
- Escape opens and closes the menu normally.
- `+map start` loads the map without leaving the main menu open.
- The Levels, Mods, Options, Load, and Save screens still open.
- Levels and Demos align with the original Single Player rows.
- Game `gfx/levels.lmp`, `gfx/demos.lmp`, and their `p_` headers override the
  packaged fallbacks, whether loose or inside a PAK.
- `menu_load` and `menu_save` open Load and Save. Empty slots and section
  headings cannot be loaded; Save before a game starts explains its disabled
  slots. Save a running game, reopen Load, and load that slot.
- Multiplayer > Setup displays `gfx/menuplyr.lmp`; name, hostname, and both
  color controls work.
- `cl_cursor ""` uses FTE's system cursor. Switching to a packaged cursor and
  back works while a menu is open.
- A small window retains artwork proportions and matching mouse hitboxes.
- Repeatedly opening and closing scrolling screens releases their widgets.

### Automated packaged runtime check

```powershell
.\scripts\test-menu-runtime.ps1 `
    -Engine C:\path\to\fteqw64.exe `
    -GameData C:\path\to\quake\id1 `
    -MenuPak .\dist\classic-menusys-vbs-v1.0-beta.9\menu.pak `
    -TestName quake
```

Use `-Qss` for Quakespasm-Spiked and `-Width 400 -Height 300` for a smaller
window. Each run creates a new isolated basedir under `dist/runtime`, copies
both game PAKs, captures eight screenshots, verifies a save was written, and
checks logs for command and VM failures. Inspect the screenshots as well.
QSS test commands use a temporary localhost-only listener after signon; the
test shuts down that engine at completion. The original game data is untouched.

Use `-LayoutOnly -Width 1920 -Height 1080` to capture Main, Solo, Options, and
Join directly from the production module. This mode skips gameplay and save
checks, and sets QSS menu scale to 3 in its isolated config for readable images.

### Scrolling and Updates layout regression

Use the FTE-only layout fixture to reproduce scrolled dropdown fields and
update details that require wrapping and scrolling:

```powershell
.\scripts\test-menu-layout.ps1 `
    -Compiler C:\path\to\fteqcc.exe `
    -Engine C:\path\to\fteqw64.exe `
    -GameData C:\path\to\quake\id1 `
    -MenuPak .\dist\classic-menusys-vbs-v1.0-beta.9\menu.pak `
    -TestName layout
```

Repeat with LibreQuake data and `-Width 400 -Height 300`. Inspect the eleven
screenshots: Video/Effects text stays below the banner; Updates keeps its list,
details, and Apply button within the same panel; scrolling long details never
expands the viewport. The fixture supplies 60 synthetic package rows and a long
description without enabling update sources or applying packages. It dismisses
the native source prompt with Escape in its isolated process.

It also checks that Main/Options plaques share their origin, LibreQuake 0.09
Solo's extra rows align by visible lettering, and Join's panel remains centered.
The Join screenshots include the real host cache before/after End scrolling;
server counts depend on available network replies. Join uses MenuQC when the
engine exposes its host-cache API. `m_servers native` or Advanced browser opens
the engine browser for additional features; that browser owns its own layout.

The test compiles a separate wrapper from `tests/menu-layout.src` and checks
logs and scrollbar creation. Never distribute its `layout-menu.dat`; packaged
runtime checks use the production `menu.dat` instead.

### Join browser navigation regression

Run the FTE-only navigation fixture with LibreQuake or Quake data:

```powershell
.\scripts\test-menu-navigation.ps1 `
    -Compiler C:\path\to\fteqcc.exe `
    -Engine C:\path\to\fteqw64.exe `
    -GameData C:\path\to\librequake\id1 `
    -MenuPak .\dist\classic-menusys-vbs-v1.0-beta.10\menu.pak `
    -TestName navigation -InGame
```

Omit `-InGame` for the disconnected case. Each run uses a new isolated folder.
The fixture activates actual controls through their keyboard handlers: Join,
Setup, repeated reopening, in-place Refresh, F5, display/population/protocol/
favorite switches, and two advanced-browser round trips. It closes the native
browser through FTE's `closemenu` command, which runs its removal callback.
Assertions check widget identity, fresh filtered rows, and return checkpoints;
three engine screenshots and clean VM/command logs are required. It queries
public servers without joining them. Never package `navigation-menu.dat`.
The Full switch is exercised through navigation rather than a numeric-row
assertion: FTE's mask uses cached `freeslots`, while its getter recomputes
`maxplayers - players` after QuakeWorld player parsing changes those fields.

The polling order matters on FTE SVN 6202. Its `Master_HideServer` decrements
the sorted-array pointer instead of the visible count. Polling while a mask
excludes a formerly visible server can therefore crash the engine. The MenuQC
browser clears masks and rebuilds the view before polling, then sorts/filters
without another polling call. It counts the filtered prefix through address
reads, clears masks, and caches the count for drawing and navigation. Keep
polling `gethostcachevalue` calls out of filtered-row loops and key handlers.
Each draw polls with masks already clear so FTE can pace its queries normally.
New rows trigger filtering immediately; metadata changes are refiltered at
least every half second. Selection is captured before polling can reorder rows.
Native handoff starts a fresh query with the old displayed flags cleared.
This is a MenuQC workaround; the engine executable remains unmodified.

## Troubleshooting

### FTE shows its text menu

Another `menu.dat` has higher search-path priority. Common competing files are:

```text
fte/menu.dat
fte/menu.pak
id1/menu.dat
```

Launch with both `-nohome` and `-game menusys_test`, and confirm the test
directory contains the newly compiled file.

### Classic artwork appears but the menudot does not

Confirm that:

- the engine can read the registered Quake `pak0.pak`;
- `gfx/menudot1.lmp` through `gfx/menudot6.lmp` exist in the base game data;
- the loaded `menu.dat` contains the new build rather than an older copy; and
- keyboard or mouse focus is on one of the classic-menu hotspots.

The menudot is a 16-by-24-pixel animated selection marker, not punctuation and
not the mouse cursor.

### Generated files

Do not commit compiler or release output. The repository ignores `dist/`, while
the default `menu.dat` output is already outside the repository root.
