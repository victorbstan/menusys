# Issue #6 and PR #8 fixes

Implemented on `simple-menus`, based on `e553f89`.

## Changes

- Levels and Demos use the original Single Player row origin. Their buttons
  retain native image dimensions rather than centering inside `sp_menu.lmp`.
- Active-game `gfx/levels.lmp`, `gfx/demos.lmp`, `gfx/p_levels.lmp`, and
  `gfx/p_demos.lmp` take priority over private `menugfx/` fallbacks. Dedicated
  Levels and Demos headers are generated during packaging.
- Demos now opens a scrolling recording browser and plays the selected file.
- Multiplayer > Setup opens Player Setup, including the game's `menuplyr.lmp`,
  hostname, name, and shirt/pants color controls.
- Load, Save, Setup, and Demos also accept the engine's `menu_*` shortcuts.
  Save explains its disabled slots before a single-player game starts. Save
  section headings are separate from selectable slots; legacy description
  padding is removed before centering the text.
- Empty `cl_cursor` is preserved for FTE's system cursor. Cursor selection,
  size, and hotspot changes apply while menus are open.
- Menu drawing, clipping, and mouse coordinates use a uniform physical scale
  when the engine independently clamps its virtual dimensions.
- Interactive widgets own one command-string allocation. Hover text owns its
  allocation, map-list temporary strings are freed per iteration, and frames
  release their separately owned scrollbars. Empty commands are normalized to
  null to avoid QSS string-cleanup warnings. Unused legacy Levels code is gone.
- Keyboard navigation handles screens with no selectable items. The optional
  CSQC entry point now includes the classic widget implementation.
- Build helpers keep output in `dist/`; release documentation and configuration
  templates describe the current behavior. Reviewed trailing whitespace is
  removed.

## Validation — 2026-10-03

- MenuQC and CSQC compile with FTEQCC, with zero warnings.
- Final packaged runtime checks pass in FTE SVN 6202 with registered Quake at
  960×600, FTE with LibreQuake 0.09-beta at 400×300, and QSS (June 25, 2021 build)
  with registered Quake at 960×600. Each run verifies eight screenshots, a real
  `s0.sav`, and the absence of command/VM/ownership errors.
- Targeted Windows key events to an isolated FTE process activate Save, write
  `quick.sav`, load that file, change a player color, and play `demo1.dem`.
- Live cursor changes switch between a packaged image and an empty selection.
- Repeated Levels open/close cycles include intervening draws, exercising
  scrollbar creation and cleanup without runtime errors.
- A 320×240 fixture uses a loose `gfx/levels.lmp` and a PAK-contained
  `gfx/demos.lmp`; its screenshot shows both replacing the packaged buttons.
- PowerShell syntax and Git whitespace checks pass.
- The release builder verifies all 22 PAK entries, compiled-menu and support
  hashes, path normalization, and the ZIP's three-file layout.

Runtime checks cover MenuQC; the optional CSQC variant was compile-checked.
The LibreQuake runtime data is 0.09-beta, with separate replacement-art fixtures.

## Local artifact

`dist/classic-menusys-vbs-v1.0-beta.7.zip`

SHA-256: `0B0DA5E4C228C200D5D4386D08A2740007C8FEF3190BFFE0689040A139C1930E`

The ZIP is a locally built prerelease artifact. GitHub release publication is
separate from the fixes submitted through PR #8.
