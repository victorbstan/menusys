# Releasing

Releases consist of a Git tag plus a downloadable ZIP containing a compiled
`menu.pak`, an end-user README, and the example configuration.

## Before packaging

1. Merge the completed pull request into `simple-menus`.
2. Switch to and update the release branch.
3. Compile `menu.src` from that merged commit.
4. Complete the regression checklist in
   [DEVELOPMENT.md](DEVELOPMENT.md#manual-regression-checklist).
5. Extract the previous release ZIP. Its directory supplies the cursor and
   menu-button assets. Headers are generated from source; README and example
   configuration come from `assets/release/`.

Example branch update:

```powershell
git switch simple-menus
git pull --ff-only origin simple-menus
```

## Build the package

Run the release builder from the repository root:

```powershell
.\scripts\build-release.ps1 `
    -Version v1.0-beta.7 `
    -MenuDat .\dist\build\menu.dat `
    -BasePackageDirectory C:\path\to\classic-menusys-vbs-v1.0-beta.6
```

By default this creates:

```text
dist/classic-menusys-vbs-v1.0-beta.7/
dist/classic-menusys-vbs-v1.0-beta.7.zip
```

Use `-OutputDirectory` to put artifacts elsewhere. Use `-Force` only when you
intend to replace an artifact for the same version.

The script reads the previous `menu.pak`, preserves its support assets, adds or
replaces the two generated `menugfx/p_*.lmp` headers, inserts the newly compiled
`menu.dat`, and writes a fresh PAK. A beta.6 base produces 22 entries. It does
not modify the previous package or override the game's `gfx/` artwork.

## Automatic validation

The builder fails unless all of the following are true:

- the base package has the required Levels, Demos, and default custom cursor;
- the new PAK entry count matches the assembled inputs;
- there is exactly one root-level `menu.dat`;
- the packaged `menu.dat` hash matches the compiled input;
- all support assets match their source bytes, including generated headers;
- every internal PAK path uses `/`, not `\`; and
- the ZIP contains the expected top-level package directory and three files.

Do not update an old PAK in place with the bundled Windows `pak.exe`. During the
beta-4 release it appended a duplicate `menu.dat`; rebuilding with that tool
also converted internal paths to Windows backslashes. The project release
script writes and validates the PAK directly to prevent both failures.

## Test the packaged artifact

Extract the newly generated ZIP, copy its `menu.pak` into a clean test game
directory, and repeat the runtime regression checklist. This final test catches
search-path and packaging failures that testing the loose `menu.dat` cannot.

Record the downloadable file's SHA-256 checksum:

```powershell
Get-FileHash -Algorithm SHA256 `
    .\dist\classic-menusys-vbs-v1.0-beta.7.zip
```

## Publish on GitHub

1. Open <https://github.com/victorbstan/menusys/releases/new>.
2. Create a new tag such as `v1.0-beta.7`.
3. Target the merged `simple-menus` commit.
4. Use a title such as `Classic Menu System v1.0-beta.7`.
5. Mark beta versions as pre-releases.
6. Attach `classic-menusys-vbs-v1.0-beta.7.zip`.
7. Publish the release.

GitHub's automatic source ZIP does not contain the compiled `menu.pak`; users
need the attached release asset.

Suggested release notes:

```markdown
## Changes

- Describe user-visible changes.

## Installation

Extract the archive and copy `menu.pak` into your Quake `id1` directory or the
directory of the mod that should use the menu.

Requires a MenuQC-capable engine such as FTEQW or Quakespasm-Spiked.
```
