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

## Manual-test follow-up — 2026-10-04

- Combo fields and dropdown lists intersect their private clips with the
  containing frame. Scrolled values cannot paint above the header. Mouse focus
  also respects the frame viewport.
- Updates uses one centered 320×200 panel with a native-sized banner and an
  Apply button anchored inside it. Empty lists show useful guidance rather than
  metadata for a nonexistent selection; reopening the screen avoids duplicates.
- Metadata wraps using the shared UI text path, respecting font size and canvas
  projection. Description scroll offsets no longer enlarge the visible area.
  Offscreen labels retain scroll state, and dragging uses the scrollbar bounds.
- Package grids release owned sliders, bound scroll offsets after resizing,
  place scrollbar input correctly, and reveal keyboard-selected rows.
- Both production variants and the dedicated layout fixture compile without
  warnings. Packaged runtime checks pass for Quake in FTE/QSS and LibreQuake in
  FTE. FTE layout fixtures cover scrolled Video/Effects, the native source prompt,
  an empty list, 60 synthetic rows, and long metadata at 960×600 and 400×300.
  Screenshot review confirms clipping and the panel layout; log and scrollbar
  assertions pass. The layout fixture does not validate remote package services.

Updated artifact: `dist/classic-menusys-vbs-v1.0-beta.8.zip`.

SHA-256: `021912D14A03D719898756F92F329A147BBD77BE1B0689762E80938AD749E306`


## Alignment follow-up — 2026-10-04

- LibreQuake 0.09 Solo aligns the visible Levels/Demos lettering with the
  original rows. Its native LMP canvases have different transparent margins;
  the measured 172×63/116×20 artwork profile gets separate row origins.
  Quake/Mark V and differently sized replacements retain their existing origin.
- Options shares Main's 16-pixel plaque margin and 72-pixel content origin.
  Its title is centered with its original proportions; the previous -12 offset
  also stretched the title by 12 pixels.
- Join prefers a centered MenuQC browser when the host-cache API is supported,
  instead of handing ordinary navigation to FTE's top-left engine browser.
  The panel fits smaller windows and is capped at 480×280 logical pixels.
  Replies refresh the sorted view, column/row clips stay inside the list,
  scrollbar bounds are nonnegative, and selection survives periodic sorting.
  Compact switches preserve display, protocol, proxy, empty/full, and favorite
  filters. Refresh, sorting, arrows, paging, End, Enter, and double-click joining
  remain available. Advanced browser (or `m_servers native`) retains access to
  the engine browser and its additional features; that screen owns its layout.
- MenuQC, optional CSQC, and the layout fixture compile with zero warnings.
  Final fixture checks pass for Quake at 1920×1080 and LibreQuake at 400×300,
  including plaque/label/panel geometry, Updates/Video/Effects regression
  coverage, and real server lists before/after End scrolling (169/28 replies
  respectively in those runs). Production-package Main/Solo/Options/Join checks
  pass for QSS (June 25, 2021) with Quake and FTE SVN 6202 with LibreQuake at
  1920×1080. Screenshots were reviewed. These runs query lists without joining
  public servers. CSQC coverage remains compilation only.

Updated local artifact: `dist/classic-menusys-vbs-v1.0-beta.9.zip`.

SHA-256: `666C8B28C0B49E9A2F22FB952F2879E8D43350C10197FF412DBA25876390A31B`

All three existing manual-test launchers install beta.9 before starting the
engine. The currently running LibreQuake process locks its old PAK, so its
replacement is deferred until close/relaunch. Config and save files persist.

## Join crash follow-up — 2026-10-04

- Reproduced a native access violation in FTE SVN 6202 while reopening Join
  after navigating through Setup. Crash capture and disassembly confirmed the
  installed engine's `Master_HideServer` shifts its sorted-array pointer instead
  of decrementing the visible count. A later hostname read dereferences garbage.
- Poll server replies with masks clear, then rebuild the filtered view without
  another polling call. Derive the filtered count through address reads, cache
  it for row/key handling, and clear masks before handing control elsewhere.
  Poll each frame to preserve FTE's query pacing; refilter on new rows and
  periodic metadata updates. Capture selection before polling can reorder it.
- Reopening Join keeps its current query/cache. The Refresh button updates the
  existing widgets, matching R/F5, rather than removing and recreating the menu.
  Native advanced-browser handoff clears old displayed flags before querying.
- Added an isolated navigation fixture covering Join/Setup/reopening, widget
  identity across Refresh, F5, favorite/protocol/population/display switches,
  End scrolling, and two advanced-browser returns. Native removal is exercised
  with `closemenu`; public servers are queried without joining them. The Full
  switch is tested through its navigation cycle because FTE's numeric getter
  can differ from the stored value its mask uses.
- Final navigation checks pass with LibreQuake in-game and disconnected and
  Quake in-game. The LibreQuake run exercises hundreds of replies (523 visible
  rows at its second return checkpoint), along with empty filtered views.
  MenuQC, optional CSQC, and test fixtures compile with zero warnings.
  Production-package checks pass in FTE/LibreQuake and QSS/Quake at 1920×1080;
  the eleven-screen LibreQuake layout fixture passes at 400×300. Screenshots,
  PowerShell syntax, whitespace, VM logs, and return checkpoints were checked.
  CSQC coverage remains compilation only; the engine executable is unchanged.

Updated local artifact: `dist/classic-menusys-vbs-v1.0-beta.10.zip`.

SHA-256: `0CE404A219F61E869F723B938138DDF5B5277D919E1959F3852E3667959168DA`

All three manual launchers install beta.10, and their test folders contain the
matching PAK. Close/relaunch to replace an already-loaded module. Beta.9 is
preserved, and the new artifact has not been published.
