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

Menus follow the current window size and keep their classic proportions,
including when you resize the window during play.

In QSS, **Options → Video** provides separate **Console Zoom** and **Message Zoom**
settings. **Automatic** makes console text and centered gameplay messages grow
with the window, including while the menu is closed. Fixed zoom choices remain
available. These settings control engine text; menu sizing follows the window
automatically.

Use these menu controls to choose a fixed text zoom in QSS. Changing only
`scr_conscale` or `scr_menuscale` in a configuration file can be overridden
while the corresponding zoom is set to Automatic.

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
