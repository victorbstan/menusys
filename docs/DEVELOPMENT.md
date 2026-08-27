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
