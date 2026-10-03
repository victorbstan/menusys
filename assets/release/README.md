# Classic Menu System

A replacement menu for FTEQW and Quakespasm-Spiked, with classic Quake artwork,
mouse navigation, level and demo browsers, Player Setup, and expanded options.

Copy `menu.pak` into your `id1` or mod directory. Settings in
`autoexec.cfg.example` are optional; copy the ones you want into your own
`autoexec.cfg`. Restart the engine after installing.

Single Player includes Load, Save, Levels, and Demos. Save requires a running
single-player game. Multiplayer > Setup includes hostname, player name, shirt
and pants colors, and the active game's `gfx/menuplyr.lmp` artwork.

FTE uses the system mouse cursor when `cl_cursor ""` is set. To select one of the
packaged cursors, set `cl_cursor "menugfx/cursor_copr.tga"`. Cursor changes take
effect while the menu is open. Engine support for custom cursors varies.

Game artwork takes priority over the packaged fallbacks at `gfx/levels.lmp`,
`gfx/demos.lmp`, `gfx/p_levels.lmp`, and `gfx/p_demos.lmp`. These may be loose
files or PAK entries. The replacement menu does not include Quake's base-game
artwork; install Quake or a compatible standalone game's data alongside it.

Source and bug reports: <https://github.com/victorbstan/menusys>.

Maintained by vbs; original menu framework and engine support by Spoike.
Includes menu button artwork from Mark V and cursor artwork including TinTin's
cursor. Levels and Demos fallback headers are generated from this repository.
