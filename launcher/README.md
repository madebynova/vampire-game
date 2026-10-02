# Vampire Game Launcher

A small Windows program that installs the full Vampire Game and keeps it up to date from this repository's
**GitHub Releases**. It is a separate project from the Godot game: nothing here is loaded by, or loads, the game.

> **Status: foundation.** The logic is finished and tested (26 tests, including a fake GitHub release server running a
> real install → update 0.1.0 → 0.2.0). The window runs and was checked by eye. **Not done yet:** a built `.exe`
> (needs PyInstaller, see below), a first game release to install, code signing, self-updating.

## What the player sees

```
VAMPIRE GAME                 INSTALLED VERSION   0.1.0        CHANGELOG · Vampire Game 0.2.0
LAUNCHER · v0.1.0            LATEST VERSION      0.2.0        (the GitHub release notes)
                             New update available
                             INSTALL LOCATION  C:\Users\…\AppData\Local\VampireGame
[ UPDATE ]  [ PLAY ]                                              [ CHECK FOR UPDATES ]
```

| State | Status line | Main button |
|---|---|---|
| nothing installed | Game not installed | **INSTALL GAME** |
| installed, latest | Up to date | **PLAY** |
| newer release exists | New update available | **UPDATE** (PLAY still offered for the old version) |
| installed, can't reach GitHub | Couldn't check for updates | **PLAY** |

If GitHub is unreachable, the last known release (and its changelog) is shown from a small local cache.

## Why Python?

The launcher uses only Python's standard library (`tkinter` for the window, `urllib`, `zipfile`, `hashlib`): no packages to
install and no Godot needed, which also means its logic could be tested properly on the development machine. Python 3.12+
is required to *run from source*; players get a single `.exe` (built with PyInstaller) and need no Python.
If you later prefer a different technology, the contract the game releases follow (see `docs/RELEASING.md`) does not change.

## Layout

```
launcher/
  VERSION                     the launcher's version (single source of truth)
  run_launcher.py             entry point (PyInstaller uses this)
  build_launcher.ps1          tests → PyInstaller → VampireGameLauncher-v<version>.exe (+ .sha256)
  vampire_launcher/
    config.py                 repo name, release naming contract, default folders
    versions.py               MAJOR.MINOR.PATCH parse/compare
    releases.py               ask GitHub for releases; keep only installable ones; cache
    install.py                download, verify, unpack, swap, roll back, recover   ← the safety-critical part
    state.py                  "installed vs latest → what can the player do?" + settings
    core.py                   Launcher class used by the window and the command line
    app.py                    the window
    cli.py / __main__.py      command-line front-end
  tests/                      unit + integration tests (fake GitHub on localhost)
```

## Run it from source

```powershell
cd launcher
python -m vampire_launcher                 # the window
python -m vampire_launcher status          # command line: status | check | install | play
python -m vampire_launcher --smoke         # builds the window once and exits (does it start?)
python -m unittest discover -s tests -t .  # the tests
```

Set `VAMPIRE_LAUNCHER_HOME` to use a scratch folder instead of `%LOCALAPPDATA%\VampireGame` while experimenting.

## Build the .exe

```powershell
python -m pip install pyinstaller          # once
./launcher/build_launcher.ps1              # runs the tests, then builds launcher/dist/VampireGameLauncher-v0.1.0.exe
```

This script has **not been run yet** (PyInstaller isn't installed on the development machine); run the resulting exe once
before publishing it. Publishing steps: [`docs/RELEASING.md`](../docs/RELEASING.md).

## Where things live

| Path | What | Replaced by updates? |
|---|---|---|
| `%LOCALAPPDATA%\VampireGame\game\` | the installed game | **yes**, whole folder |
| `%LOCALAPPDATA%\VampireGame\launcher.json` | launcher settings (install folder, allow pre-releases) | no |
| `%LOCALAPPDATA%\VampireGame\release_cache.json` | last seen release (for offline) | refreshed |
| `%APPDATA%\VampireGame\` | **the game's settings and saves** | **never touched** |

The installed version is read from `game\VERSION`, so the game folder is its own record and can't disagree with a
separate database. The install folder can be changed (CHANGE… button) only before the first install.

## How an update works

1. **Check:** `GET api.github.com/repos/madebynova/vampire-game/releases`. Keep releases that are published, not
   pre-releases, tagged `vX.Y.Z`, with both `VampireGame-Windows-vX.Y.Z.zip` and `….zip.sha256` attached, and whose
   download URLs are this repo's release assets. Newest version wins (numeric compare).
2. **Compare** with `game\VERSION` → one of the four states above.
3. **Download** the checksum, then the zip to `downloads\*.part`; renamed only if the size matches.
4. **Verify** SHA-256. Mismatch → the file is deleted and nothing changes.
5. **Unpack** into `staging\` (rejecting path escapes, links, absurd sizes); verify `VampireGame.exe` exists and `VERSION`
   equals the release.
6. **Refuse** if `VampireGame.exe` is running.
7. **Swap:** `game\` → `backup\`, `staging` → `game\`; if the second move fails the first is undone. Then `backup\` is removed.
8. **Recover:** at start-up, leftovers from a crash are removed and a missing `game\` is restored from `backup\`.

## Known limitations

- Unsigned exe → Windows SmartScreen warning on first run.
- Doesn't update itself; the checksum guards against corruption, not a compromised release (signatures are a future step).
- Windows-only for *playing*; the window and tests also run elsewhere.
- Can't move an existing install; no pause/resume of downloads; no delta updates (every update is a full zip).
- GitHub's unauthenticated API limit is 60 requests/hour per IP.
