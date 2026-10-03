# Classic Menu System

Classic Menu System is a MenuQC replacement for Quake engines that support
external `menu.dat` modules. It keeps the original image-based Quake menus while
adding mouse navigation, level and demo browsers, Player Setup, and expanded
engine options. A separate mod browser is available with `m_mods`.

The project also serves as a base for building custom MenuQC menus or menus
inside CSQC. The active release branch is `simple-menus`. The `menusys/`
directory contains the reusable widget library, while `menu/` contains this
project's menu screens.

## Contents

- [Compatibility](#compatibility)
- [Installation](#installation)
- [Build and test](#build-and-test)
- [Architecture](#architecture)
- [Customize the menus](#customize-the-menus)
- [Create a mod options menu](#create-a-mod-options-menu)
- [Server browser](#server-browser)
- [Create a release](#create-a-release)
- [Repository layout](#repository-layout)
- [Licensing](#licensing)

## Compatibility

The packaged menu is intended for:

- FTEQW
- Quakespasm-Spiked (QSS)

Standard Ironwail, Mark V, and engines without MenuQC support cannot load this
`menu.dat`. The menu also expects the normal registered Quake data files. In
particular, the animated selection marker uses `gfx/menudot1.lmp` through
`gfx/menudot6.lmp` from Quake's original `pak0.pak`.

### DarkPlaces

The underlying menusys library has partial DarkPlaces compatibility, but some
features are unavailable or behave differently. Known limitations include 3D
models in MenuQC and server browsers in CSQC. FTE is the primary development
target.

The `dp_workarounds` variable is used throughout the library for known engine
differences. Check DarkPlaces cvar names and behavior when adding engine-specific
options, and verify that compatibility changes still work in FTE.

## Installation

1. Download the compiled ZIP from the project's
   [GitHub Releases](https://github.com/victorbstan/menusys/releases) page.
2. Extract the archive.
3. Copy `menu.pak` into `id1` or into the game directory of the mod that should
   use the menu.
4. Optionally copy the settings from `autoexec.cfg.example` into the applicable
   `autoexec.cfg`.

Putting `menu.pak` in a mod directory limits the replacement menu to that mod.

## Build and test

Build with FTEQCC using the helper, which writes to `dist/build` without
overwriting an installed menu:

```powershell
.\scripts\build-menu.ps1 -Compiler C:\path\to\fteqcc.exe
.\scripts\build-menu.ps1 -Compiler C:\path\to\fteqcc.exe -Csqc
```

Compiling `menu.src` directly in the GUI retains its historical output path,
`../menu.dat`.

For a clean runtime test, copy the result into a dedicated game directory and
launch FTEQW from the Quake basedir:

```powershell
$quakeBasedir = "C:\path\to\quake"

New-Item -ItemType Directory -Force "$quakeBasedir\menusys_test"
Copy-Item ".\dist\build\menu.dat" "$quakeBasedir\menusys_test\menu.dat" -Force

Set-Location $quakeBasedir
.\fteqw64.exe -nohome -game menusys_test
```

See [Development](docs/DEVELOPMENT.md) for the complete build, test, branch, and
troubleshooting workflow.

## Architecture

### Menu hierarchy

Menusys is hierarchical. A `mitem_desktop` object is the root node. Top-level
windows and menus are children of that desktop; controls such as sliders,
buttons, and pictures are children of those containers.

Items can technically be placed directly on the desktop, but using a top-level
menu or frame makes mouse capture and release easier to manage. Containers also
handle child positioning, clipping, focus, and cleanup.

Menusys uses inheritance. For example, a custom frame can inherit from
`mitem_frame` and act as a container while overriding only the behavior it
needs. See [menusys/readme.txt](menusys/readme.txt) for the widget fields,
events, factory functions, and resize flags.

### MenuQC

When an engine loads `menu.dat`, its built-in menu becomes inaccessible. A mod
that wants to add even one custom built-in-style option must therefore provide
the complete menu experience. This project supplies that base implementation so
mods do not need to begin from an empty MenuQC module.

### CSQC

The CSQC build can provide menus equivalent to the MenuQC build, which often
makes enabling both complete sets redundant. CSQC is useful for in-game menus
that communicate with the server, such as class customization, while MenuQC can
continue to provide the remaining front-end menus.

In FTE, setting the following in `default.cfg` makes the engine use
`csprogs.dat` instead of `menu.dat` for menus:

```text
pr_csqcformenus 1
```

This can place all menus in one module for a standalone game. It is FTE-specific
and does not bypass CSQC cheat protections on public servers. When MenuQC and
CSQC are both active, CSQC receives Escape events and can invoke its own menu;
console commands can link the two menu sets.

For a strictly single-player project, a PureCSQC-style architecture is another
option, but its entry points must be merged with this menu framework manually.

## Customize the menus

### Artwork and cursor

The Levels and Demos buttons prefer `gfx/levels.lmp` and `gfx/demos.lmp` from
the active game. Their headers prefer `gfx/p_levels.lmp` and `gfx/p_demos.lmp`.
Loose files and PAK entries both work. Packaged fallbacks live under `menugfx/`
and retain their native proportions.

In FTE, `cl_cursor ""` selects the system cursor. Set a packaged image such as
`cl_cursor "menugfx/cursor_copr.tga"` for a custom cursor. Changes apply while
the menu is open. Menu layout scales uniformly to fit smaller windows without
changing the user's scale settings.

The engine shortcuts `menu_load`, `menu_save`, `menu_setup`, and `menu_demo`
open the corresponding screens, as do `m_load`, `m_save`, `m_setup`, and
`m_demos`. Save stays visible before a game starts and explains why its slots
are disabled.

### Add or change a menu item

Open the relevant `menu/*.qc` file, find an existing control of the same type,
and duplicate and edit it. Some screens calculate their vertical positioning,
so adding a control may also require adjusting sizes or offsets.

Most customizations should remain under `menu/`. Beginners should avoid
changing `menusys/*.qc` unless the change belongs in the reusable widget
framework.

### Add a new menu screen

In `menu.src`, add an entry to the `concommandslist` macro. For example:

```c
cmd("m_mod", M_Options_Mod, menu/options_mod.qc) \
```

This maps a console command to a function and includes the corresponding source
file. Copy a similar existing screen, rename it, and then adjust its controls
and return command.

### Mod defaults

A mod with custom defaults should provide its own `default.cfg`. It can define:

- default key bindings;
- engine cvar defaults; and
- mod-specific cvars using `set` or persistent `seta` commands.

Running FTEQCC with `-v -v` can generate a list of autocvars, including default
values and some descriptions. Change entries that should persist from `set` to
`seta` when preparing the mod configuration.

### Key bindings

Key bindings can be changed directly in `menu/options_keys.qc`. Alternatively,
provide a `bindlist.lst` containing quoted command and description pairs:

```text
"+attack" "Attack"
"impulse 10" "Next Weapon"
```

Use `-` as the command for a caption row. If the list exceeds the available
height, the containing frame adds a scrollbar.

## Create a mod options menu

The easiest starting point is a copy of `menu/options_video.qc`. Register the
new screen in `menu.src`:

```c
cmd("m_mod", M_Options_Mod, menu/options_mod.qc) \
```

Then create `menu/options_mod.qc` and adjust the copied implementation.

### Create the full-screen menu

```c
mitem_exmenu m;
m = spawn(
    mitem_exmenu,
    item_text: _("Mod Options"),
    item_flags: IF_SELECTABLE,
    item_command: "m_options"
);
desktop.add(
    m,
    RS_X_MIN_PARENT_MIN | RS_Y_MIN_PARENT_MIN |
        RS_X_MAX_PARENT_MAX | RS_Y_MAX_PARENT_MAX,
    '0 0',
    '0 0'
);
desktop.item_focuschange(m, IF_KFOCUSED);
m.totop();
```

`item_command` is run when the menu closes by Escape or right-click, so it
normally names the command for the parent screen. `totop()` places the new menu
above existing desktop children.

### Add a banner

```c
float h = 200 * 0.5;
mitem_pic banner = spawn(
    mitem_pic,
    item_text: "gfx/p_option.lmp",
    item_size_y: 24,
    item_flags: IF_CENTERALIGN
);
m.add(
    banner,
    RS_X_MIN_PARENT_MID | RS_Y_MIN_PARENT_MID |
        RS_X_MAX_OWN_MIN | RS_Y_MAX_PARENT_MID,
    [(160 - 160 - banner.item_size_x) * 0.5, -h - 32],
    [banner.item_size_x, -h - 8]
);
```

The `RS_` resize flags define which parent or item reference points are used to
calculate the child's corners. The two vectors provide offsets from those
points. This example centers the image above a 200-virtual-pixel-high content
area.

### Add a scrolling content frame

```c
mitem_frame fr = spawn(
    mitem_frame,
    item_flags: IF_SELECTABLE,
    frame_hasscroll: TRUE
);
m.add(
    fr,
    RS_X_MIN_PARENT_MID | RS_Y_MIN_PARENT_MID |
        RS_X_MAX_PARENT_MID | RS_Y_MAX_OWN_MIN,
    [-160, -h],
    [160, h * 2]
);
```

The frame clips its children and adds a scrollbar when they no longer fit.
Artwork attached to the outer menu remains stationary while the controls
scroll.

### Add the background

```c
addmenuback(m);
```

This adds an item that darkens the game view behind the menu. Insertion order
affects draw order, so preserve the ordering used by existing option screens:
the background must render before the interactive controls.

### Add a combo box

```c
fr.add(
    spawn_combo(
        _("Video Width"),
        "vid_width",
        '280 8',
        _(
            "0    \"Default\" "
            "640  \"640\" "
            "800  \"800\" "
            "1024 \"1024\" "
            "1280 \"1280\" "
            "1920 \"1920\" "
        )
    ),
    fl,
    [0, pos],
    [0, 8]
);
pos += 8;
```

The arguments are the label, attached cvar, widget size, and value/description
pairs. The `_()` wrapper marks text for localization.

### Add a slider

```c
fr.add(
    spawn_hslider(
        _("View Size"),
        "viewsize",
        '50 120 10',
        '280 8'
    ),
    fl,
    [0, pos],
    [0, 8]
);
pos += 8;
```

The third argument contains minimum, maximum, and step values. Minimum and
maximum may be reversed when the step is also adjusted appropriately.

### Add a checkbox

```c
fr.add(
    spawn_check(
        _("Show Framerate"),
        dp("showfps", "show_fps"),
        '280 8'
    ),
    fl,
    [0, pos],
    [0, 8]
);
pos += 8;
```

The `dp(primary, fallback)` helper uses the first cvar when the engine reports
that it exists and otherwise uses the fallback. It cannot reconcile options
whose values have different meanings between engines; `vid_fullscreen` is one
example that requires additional engine-specific logic.

Finally, add a selectable item on the parent menu that runs `m_mod` so users can
open the new screen.

## Server browser

QC-based server browsers cannot access the system clipboard, which makes
copying and pasting addresses unavailable. This project therefore delegates to
FTE's normal server browser when possible.

To limit results to a game directory, configure `MOD_GAMEDIR` in
`menu/servers.qc`. The file includes an example definition:

```c
//#define MOD_GAMEDIR cvar_string("game")
```

DarkPlaces does not provide the same delegation path, and a heavily customized
mod may require its own browser behavior.

## Create a release

Release packages are built from a compiled `menu.dat` and the non-code support
assets in the previous release package:

```powershell
.\scripts\build-release.ps1 `
    -Version v1.0-beta.7 `
    -MenuDat .\dist\build\menu.dat `
    -BasePackageDirectory C:\path\to\classic-menusys-vbs-v1.0-beta.6
```

The script creates a validated package and ZIP under `dist/`. It refuses to
publish a PAK containing duplicate `menu.dat` entries or Windows-style internal
paths.

See [Releasing](docs/RELEASING.md) before tagging or uploading an artifact.

## Repository layout

| Path | Purpose |
| --- | --- |
| `menu.src` | MenuQC compiler entry point |
| `menu/` | Project-specific menu screens and controls |
| `menusys/` | Reusable menu widget framework |
| `csprogs.src` and `cs/` | Optional CSQC build |
| `docs/DEVELOPMENT.md` | Contributor build and test workflow |
| `docs/RELEASING.md` | Packaging and GitHub release workflow |
| `scripts/build-release.ps1` | Reproducible release packager and validator |
| `scripts/build-menu.ps1` | MenuQC and CSQC builds under `dist/build` |
| `scripts/build-menu-assets.ps1` | Generates native Levels and Demos headers |
| `scripts/test-menu-runtime.ps1` | Isolated engine screenshots and save regression |
| `assets/release/` | End-user README and example configuration templates |
| `LICENSE` | Original project licensing notice |
| `README.TXT` | Original unformatted project notes, retained for history |
| `menusys/readme.txt` | Detailed widget-library reference |

Generated files such as `menu.dat`, `menu.pak`, and release ZIPs should not be
committed.

## Licensing

The root [LICENSE](LICENSE) preserves the licensing paragraph from the original
project notes verbatim. It states that the software has no warranty,
acknowledges that small portions could have been influenced by GPL-licensed
sources, and encourages users to share their changes.
