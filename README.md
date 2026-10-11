# Classic Menu System

A replacement menu for FTEQW and Quakespasm-Spiked, with classic Quake artwork,
mouse navigation, level and demo browsers, Player Setup, and expanded settings.
The menu scales with the window while preserving the proportions of its artwork.

## Compatibility

Use FTEQW or Quakespasm-Spiked (QSS) with registered Quake or compatible
standalone game data, such as LibreQuake. Game data is not included.

Engines without MenuQC support cannot load this replacement menu. Standard
Ironwail and Mark V are not supported.

## Installation

1. Download the compiled ZIP from
   [GitHub Releases](https://github.com/victorbstan/menusys/releases). Choose the
   attached menu package; GitHub's automatic source archives do not contain
   `menu.pak`.
2. Extract it and copy `menu.pak` into your game's `id1` directory, or the mod
   directory where you want to use the menu.
3. Optionally copy the settings you want from `autoexec.cfg.example` into your
   own `autoexec.cfg`.
4. Restart the engine.

Installing in a mod directory limits the replacement menu to that mod.
To uninstall, remove the installed `menu.pak` and any settings you copied from
the example configuration.

## Using the menu

Press Escape to open the menu. Navigate with the arrow keys and Enter, or
select items with the mouse. Escape returns to the previous screen or game.

- **Single Player:** start a game, load or save, browse levels, and play demos.
  Saving requires a running single-player game.
- **Multiplayer:** join or start a game and open Player Setup to change your
  name, hostname, shirt color, and pants color. Available networking options
  depend on the engine.
- **Options:** adjust controls, video, audio, and effects. Options unsupported
  by the engine may be unavailable.
- **Help / Manual:** view the active game's help pages.

Game artwork takes priority over the included Levels and Demos fallback
headers. The appearance can therefore differ between Quake and LibreQuake.

Under **Options → Controls**, select an action and press Enter to assign a key,
or Backspace to clear its bindings.

## Mouse settings

**Options → Basic Setup** includes **Always Mouselook**, **Invert Mouse**, and
**Sensitivity**. Always Mouselook keeps mouse aiming enabled during gameplay;
the choice made in this menu is remembered across restarts.

In FTE, `cl_cursor ""` selects the system cursor. To use an included custom
cursor, choose one of these commands to enter in the console or add to
`autoexec.cfg`:

```text
cl_cursor "menugfx/cursor_copr.tga"
cl_cursor "menugfx/cursor_tintin.tga"
```

Cursor changes apply while the menu is open. Custom cursor support varies
between engines.

## Text and window size

Under **Options -> Video**, **Menu Zoom** defaults to **Automatic**, which follows
live window size while preserving classic artwork proportions and centering.
Fixed choices are **1x, 2x, 3x and 4x**; they shrink when necessary to fit
small windows. Automatic uses a 640x400 reference, so a 960x600 window uses 1.5x.

In QSS, **Menu Zoom** also controls centered
game messages and the engine's native completion and finale screens. QSS keeps
these native overlays at least 1x. During completion/finale, QSS stops calling
MenuQC, so automatic zoom retains its last value until you reopen a custom menu.
The completion screen remains the engine's original display.

**Console Zoom** and **HUD Zoom** are independent, with **Automatic**, **1x,
2x, 3x, 4x** and **Default** choices. Automatic uses the same 640x400 window
reference as the menus, with a 1x minimum for native UI. Default restores native
engine behavior. Existing native HUD settings and FTE console text settings are
retained until you choose a new setting.

FTE calls the HUD control **HUD/UI Zoom** because it also scales native messages,
scores and other engine overlays. Console Zoom uses a separate physical text size
and stays independent of HUD/UI Zoom for Automatic and fixed choices. Console
Default restores FTE's native text behavior, which follows its UI scale.
Menu Zoom controls the replacement menus.
FTE's old duplicate Video Zoom control has been removed. QSS Menu Zoom
continues to control its native messages and scores separately from HUD Zoom.

**HUD Alpha** in **Options -> Video** controls the status-bar backgrounds:
`0` is transparent and `1` is opaque; numbers and icons remain readable.
Changing it in FTE selects the translucent classic status-bar mode. Use View
Size `100` or `110` for an overlay; smaller views still reserve a border.
In QSS, alpha below `1` also removes the tiled fill beside the status bar.

Selections are saved across restarts. To set menu zoom from the console or
`autoexec.cfg`, use `seta menu_zoom 0` for Automatic or, for example,
`seta menu_zoom 3` for 3x. In QSS the menu applies this choice to `scr_menuscale`.

Classic menu text uses sharp bitmap scaling by default. In FTE, the shared font
filter also makes console text sharp. Explicit menu font overrides retain their
existing rendering.

## Troubleshooting

- **The replacement menu does not appear:** confirm the engine supports MenuQC
  and the package is installed in the active game directory. Another installed
  menu replacement may take priority.
- **Graphics are missing:** confirm the active game's data files are installed.
  The package uses artwork supplied by Quake or the standalone game.
- **Save is unavailable:** start a single-player game before opening Save.
- **A changed installation still shows the old menu:** restart the engine.

## Credits and support

Maintained by vbs; original menu framework and engine support by Spoike.
Includes menu button artwork from Mark V and cursor artwork including TinTin's
cursor. Levels and Demos fallback headers are supplied with the menu.

[Source, license, and bug reports](https://github.com/victorbstan/menusys).
