# Vampire Game (prototype)

A third-person single-player vampire action-adventure, built in **Godot 4.8** (developed and tested
on 4.8-dev6, Forward+ renderer, Jolt physics).

This repository is a **prototype**, not the game. Its purpose is to answer one question:
*is being this vampire actually fun - does it feel like you became one?* The systems that exist are
small on purpose and are meant to create decisions where they meet - sunlight vs. feeding vs. time of
day vs. what you are (Human or Vampire) - rather than to pile up features.

## Current status: Task 1.8 (vampire world & traversal polish)

Task 1 made the loop work, Task 1.5 made it interact (day/night, sun, routines, modding foundation), Task 1.75 made it
*feel* like something. Task 1.8 makes the small world **reliable and purposeful**: traversal you can trust (it only ever
happens on purpose, and only the way you meant), controls that grip, a number on the blood and rewards that explain
themselves, a second thing to drink, people who tell you things, a coffin that asks when you will wake, and more to find.
Nothing big was added; the fox is the largest new system.

### Playable today
- **Human <-> Vampire** with a real transformation: the world tightens into a red-black tunnel, the body
  rises and arches, time stutters, a shockwave and chromatic tear mark the change, the night suddenly
  opens around you. Going back is quieter: a long exhale, warmth, the cloak turning to ash.
- **Blood as something alive**: a vessel that sloshes, pulses with your own heart (slow and heavy as a
  vampire, quick when hungry, feeding or burning), sheds drops while Sense runs, flashes when you drink - with a plain
  **`73 / 100`** under it. A Human spends blood very slowly, a Vampire noticeably faster.
- **Feeding you want to do**: how it plays depends on the victim - a sleeper is fed on quietly and gives
  a long, gentle *Dreamblood*; someone unaware is steady; a terrified victim screams, pays more blood and a
  hot short *Fury* - and anyone who **sees** it runs. A good feed leaves a **Bloodrush**, and the screen now says what it
  does and for how long ("+22% speed, +14% jump, Sense is free, sun burns 20% slower").
- **A second blood: foxes.** Two foxes live under the old wall - curled in their den by day, out among the lamps at
  night, quick to bolt from a vampire. Sense finds them; creep up on a sleeper (or run one down), feed: quiet, safe
  and over in 2.4 s, but less blood and a lighter rush (*Instinct*) than a person. The first drink holds a creature's-eye memory.
- **Blood Memories you experience**: the world freezes, drains into the memory's colour and dims, the room's
  sound recedes and a procedural bed plays; the memory is told a few words at a time. It never times out,
  and only a deliberate press closes it. Fifteen among the people, one more in the fox - including a memory only **trust**
  opens and a **deepest** memory that opens once you have heard the rest.
- **People who tell you things**: talk to someone as a Human and, as they come to trust you, they tell you what they know -
  where the foxes den, who sleeps where and when, who is afraid of what, which of their dreams is worth drinking. A gold
  "Learned:" line says what you got; a stranger they name is called by name when you Sense them.
- **Vampiric Sense**: the nearest thing you face is the one you attend to; scan waves make people flare;
  strangers are pale and flicker, people you know are steady and warm; heartbeats sound different calm,
  asleep or afraid; a heart very close throbs through your hands. It shows people, **animals**, hidden things, and now the
  **walls you can scale** as a pale strip up the stone. It costs a little blood up front and a steady trickle - and is
  free during a Bloodrush.
- **Traversal only a vampire has - and only on purpose**: slip through windows (you dissolve to mist at the sill), scale the manor
  wall, the cottage wall and the watch hut to their roofs, climb onto the ruined wall, climb out of (or drop through) the broken
  roof of the manor. You are only offered a route when you are on the right level, on the right side of the wall, facing it - so
  "in" is never "out", and a roof never offers the room beneath it.
- **Day/night cycle** (20 real minutes per day), **sunlight** (about three minutes of full noon sun to die),
  **NPC routines**, **trust and lures** - as before, unchanged in their numbers.
- **The coffin asks when you will wake**: until dusk (as always), midnight, dawn, or **daylight** (wake as a Human into the day).
- **HUD and menus**: a blood vessel with its number, a serif 12-hour clock with a sun/moon glyph, prompts that show the
  real button for the device you last used (keyboard, Xbox-style, PlayStation), a designed controls screen,
  a pause menu (Resume / Controls / Options / Quit to Title), a small title screen.
- **Movement that grips**: crisp stops and turns (a running vampire stops in about half a metre, not a metre and a half), the
  same on keyboard and pad; a part-tilted stick is a part-speed walk.
- **Three people** with data-driven routines - a groundskeeper, a seamstress, and a night watchman - **two foxes**, and three
  small things to read (a watch log, candle wax under a window, a scratched gate lock) that agree with what people say.

### Controls

| Action | Keyboard / mouse | Xbox-style pad | PlayStation pad |
|---|---|---|---|
| Move / look | WASD / mouse | left stick / right stick | same |
| Run | Shift (hold) | RT (hold), or click **L3** to latch until you stop | R2 / L3 |
| Jump | Space | A | Cross |
| Talk, dig, read, sleep, **slip through windows, climb** | E | X | Square |
| **Feed** (Vampire, hold) | E | X | Square |
| Transform Human <-> Vampire | F | Y | Triangle |
| Vampiric Sense (Vampire, toggle) | Q | LB (R3 also works) | L1 (R3) |
| Continue a Blood Memory | E / Space / Enter / click | A, B or X | Cross / Circle / Square |
| Choose when to wake (at the coffin) | arrows + Enter, Esc to stay awake | D-pad + A, B to stay awake | D-pad + Cross, Circle |
| Pause | Esc | Menu | Options |
| Controls screen | H | View | Create |
| Debug overlay | F3 | - | - |

Menus: arrows / D-pad or left stick to move, Enter / A to accept, Esc / B to go back.

### Controller support
Every gameplay action is a named `InputMap` action; nothing reads keycodes or device names, so rebinding
and more pad layouts need no gameplay changes. The reference layout is Xbox/XInput; a PlayStation pad is
recognised from the driver name and gets Cross/Circle/Square/Triangle glyphs; any other pad is treated as
Xbox-style. Vibration is used sparingly (transformation, your heartbeat while feeding, a close heart, the
Sense pulse, hunger, strong sunlight) and can be switched off in Options.

**Honest status:** automated tests drive the game with injected Xbox-layout pad events (stick, buttons,
trigger, menu navigation). **No physical controller was available** in the development session, so the GameSir
G7 SE and PS5 pads have *not* been tried by hand, and vibration has only been verified as "requested".

### The clock
The HUD shows a normal 12-hour clock: midnight is 12:00 AM, noon is 12:00 PM, 17:43 reads 5:43 PM. This is
display only - the simulation, schedules and tests still run on 24-hour game time.

### Not implemented (on purpose)
Wolf/Bat forms, combat, quests, inventory, crafting, skill trees, full blood-type system, turning people,
lineage, a large world, save games, final art/UI/audio, multiplayer, a mod manager. See
[`docs/PROTOTYPE_NOTES.md`](docs/PROTOTYPE_NOTES.md) for known issues and open design questions.

## Open and run
1. Install **Godot 4.8** (the standard, non-.NET build).
2. Godot Project Manager -> **Import** -> select `project.godot` in this folder.
3. Press **F5**. The game opens on a title screen; **Play** starts in the coffin room as a Human. (**F6**
   on `scenes/main.tscn` skips the title.) Your settings are saved to `user://settings.cfg`.

## Windows build
The project exports to a single `VampireGame.exe` (Windows 10/11, 64-bit; the data is embedded in the exe).
`export_presets.cfg` has two presets: **"Windows Desktop (playtest)"** (the release: no tests, docs, website or launcher) and
**"Windows Desktop (self-test)"** (the same game plus the test scenes, used only by the test script below).

1. Install the matching **export templates** once: Godot editor -> *Editor -> Manage Export Templates -> Download and Install*
   (for 4.8-dev6 they go to `%APPDATA%\Godot\export_templates\4.8.dev6\`).
2. `./tools/build_windows.ps1 -Godot "<path to your Godot 4.8 console exe>"` writes `build/windows/VampireGame.exe`
   (git-ignored; binaries are published as GitHub Releases, never committed). It checks the templates first and says what is missing.
3. `./tools/test_exported_build.ps1 -Godot "<same exe>"` runs all five test suites (about 840 checks) **inside an exported
   build** instead of the editor (about 15 minutes). It works on a temporary copy of the project and an isolated `%APPDATA%`.
   One known limitation: 4 example-mod checks cannot run in an export (the test copies `res://` files) and are skipped explicitly.
4. `./tools/package_release.ps1` makes `dist/VampireGame-Windows-v<VERSION>.zip` + `.sha256`; see [`docs/RELEASING.md`](docs/RELEASING.md).

**Where the game stores things:** settings (and, later, saves) go to `%APPDATA%\VampireGame\` (the project sets
`config/use_custom_user_dir`), never next to the exe, so the game folder can be replaced or updated without touching them.
**Version:** the `VERSION` file is the single source; `./tools/sync_version.ps1` copies it into `export_presets.cfg` (the exe's file
version) and `project.godot` (`config/version`), and `python tools/check_repo.py` fails if they disagree.

**Status:** build, self-test and a hands-on run of the real exe (title, play, move, transform, Sense, pause, options, fullscreen,
clean exit; D3D12 on an NVIDIA GTX 1660 SUPER, ~220 FPS) were done on one machine. Controllers have not been tried on hardware.

## Playtest ecosystem (website -> play -> feedback -> launcher -> updates)
Beyond the game itself, this repository holds the pieces that turn it into something people can try:

```
website/   public home page + Player Feedback + Community Reports    (GitHub Pages)   docs/FEEDBACK_BACKEND.md
   |
   +-- PLAY NOW .......... browser build in website/play/            (planned, not built)
   +-- DOWNLOAD LAUNCHER . launcher/ -> Windows .exe                  (foundation done, not published)
                              |
                              +-- reads GitHub Releases  ->  downloads VampireGame-Windows-vX.Y.Z.zip  ->  verifies  ->  installs
VERSION    the one game version number; tools/package_release.ps1 turns an export into a release     docs/RELEASING.md
supabase/  the feedback database schema (Row Level Security)
```

| Piece | State today |
|---|---|
| Website, feedback forms, community list | built and tested (against a stand-in server); **not deployed** |
| Feedback database | schema written; **no Supabase project exists yet**, so the site shows "feedback temporarily unavailable" |
| Launcher (`launcher/`) | logic + window built, 26 tests pass; **no `.exe` built, no game release to install yet** |
| Release tooling (`tools/package_release.ps1`) | tested with a stand-in build; **no real Windows export has been made** |
| Browser build | **not started** |

Guides: [`docs/FEEDBACK_BACKEND.md`](docs/FEEDBACK_BACKEND.md) (set up the database), [`docs/RELEASING.md`](docs/RELEASING.md)
(versions, publishing the game / launcher / browser build, how updates reach players, where saves live),
[`launcher/README.md`](launcher/README.md). Checks that need no Godot: `python tools/check_repo.py`,
`node tools/check_site.js website`, and the launcher tests (also run by `.github/workflows/ci.yml`).

## Website (GitHub Pages)
The game's public home page lives in [`website/`](website/): plain static HTML, CSS and a little JavaScript. There is no
build step and no dependencies, and it is separate from the Godot project (`website/.gdignore` keeps the Godot editor and
exports from scanning it; nothing in the game reads it). It only describes things that exist in the prototype today and uses
no screenshots or art that don't exist. Besides the game description it has a **Play** section (browser build + launcher), a
**Player Feedback** hub (report a bug / submit an idea, anonymous allowed) and **Community Reports** (public list with
statuses). Feedback is stored in Supabase; see [`docs/FEEDBACK_BACKEND.md`](docs/FEEDBACK_BACKEND.md). Its public settings are in
`website/assets/js/config.js` and must never contain a secret key.

**Status:** the page is written and tested locally, but **it has not been deployed yet** (GitHub Pages is not
enabled on this repository). The **PLAY NOW** and **DOWNLOAD LAUNCHER** buttons are deliberate placeholders: there is no Web
export and no launcher release yet. Each is switched on by one attribute on `<html>` in `website/index.html`
(`data-play-url`, `data-launcher-url`).

### View it locally
```
cd website
python -m http.server 8000
```
Then open <http://localhost:8000>. (Opening `website/index.html` straight from disk also works.)

### Deploying with GitHub Pages (intended, not set up yet)
GitHub Pages can only publish a repository's root or its `docs/` folder from a branch, and `docs/` here holds the design
notes, so the site is published from `website/` by the included workflow,
[`.github/workflows/pages.yml`](.github/workflows/pages.yml):

1. Repository **Settings -> Pages -> Build and deployment -> Source: GitHub Actions**.
2. **Actions** tab -> *Deploy website to GitHub Pages* -> **Run workflow**.
3. The site should then be served at `https://madebynova.github.io/vampire-game/` (the usual project-page address).

The workflow is manual (`workflow_dispatch`) for now so it cannot fail before Pages is enabled; to redeploy automatically on
every push that touches `website/`, uncomment the `push:` trigger in the file. It has **not been run yet**, so treat the first
run as its test. Every link and asset path on the site is relative, so it works under a project URL (`/vampire-game/`) as
well as at a domain root.

### Phase 2: connecting PLAY NOW (planned, not started)
Godot project -> Web export -> browser testing -> host the Web build -> connect PLAY NOW. When there is a build to connect:

- Put the Web export in `website/play/` (it needs an `index.html`).
- In `website/index.html` set `data-play-url="play/"` on the `<html>` tag. Every PLAY NOW button becomes a real link and the
  "not connected yet" note hides itself.
- Update the remaining "coming soon" wording by hand: the browser card and footnote in the Play section, the Play card under
  Links, the *Browser build* step and the "no built executable or web build" line under Development Status.

Things to check when that work starts (none of this has been tried):
- `.gitignore` ignores `*.pck`, so a Web export's data file would need an exception (or to be built in CI) to live under `website/play/`.
- Godot's Web export has so far supported only the Compatibility renderer, while this project uses Forward+ and several custom
  shaders (sky, Sense, screen effects); expect testing and adjustment. Confirm against the Godot 4.8 documentation.
- GitHub Pages cannot set the cross-origin-isolation headers that threaded Web exports need, so use a single-threaded export.

## Tests and tools
All are headless-capable (`godot --headless --path . <scene>`); replace `godot` with your Godot 4.8 binary.

| Scene | What it checks |
|---|---|
| `res://tests/unit_tests.tscn` | clock (24 h and the 12-hour display), sun path, sunlight curve, content registry, mods, blood tuning, the input map (every action has keyboard and pad bindings, nothing hard-codes devices), feed styles, traversal paths, settings and audio buses |
| `res://tests/smoke_test.tscn` | the original acceptance playthrough (movement, transform, Sense, feeding, sunlight, coffin, repeatable loop) |
| `res://tests/scenario_tests.tscn` | Task 1.5 scenarios: routines, sleepers, memory variants, trust, witnesses, tiered Sense, embers, night vs day |
| `res://tests/feel_tests.tscn` | Task 1.75: transformation presentation, blood and Bloodrush, feeding per victim state, witnesses, the Blood Memory view and its input rules (held keys, pad, mouse), Sense, every traversal route both ways (and blocked exits), pause and menus, controller-only play, HUD and controls screen, coffin, the cleaned-up world |
| `res://tests/polish_tests.tscn` | Task 1.8: traversal that only happens on purpose (direction, level, side, facing, blocked landings, the broken roof), the blood number and what a Bloodrush says, controller movement and bindings, the cape through running / jumping / transforming, the fox (data, behaviour, Sense, feeding, witnesses), what people tell you, the coffin's choices, the extra memories and clues (`-- only=traversal,fox,...` runs sections) |

Windowed runs accept a screenshot directory: `godot --path . res://tests/feel_tests.tscn -- <dir>`.
Dev tools: `playtest_driver.tscn` (a scripted walk through the playtest sequence with screenshots), `polish_playtest.tscn` (the same for
the Task 1.8 features), `model_probe.tscn` (the vampire model posed and photographed from the side and behind),
`world_probe.tscn` (layout views by day / night / routes / title), `soak_probe.tscn` (8x fast-forward with wandering, feeding and memories), `boot_probe.tscn` (does it start),
`sun_map.tscn`, `time_probe.tscn`, `visual_probe.tscn`, `audio_probe.tscn`, `perf_probe.tscn`.

## Development philosophy
- Prove the experience before growing the game. If something works but feels bad, fix that first.
- A few systems that interact beat many that don't.
- Keep it modular: a thin player controller, self-contained components, and content as data.
- Never silently make permanent design decisions - uncertain ones are recorded as design questions.

## Modding direction
Modding is a long-term goal. What exists today is a **foundation only** - content lives in data
resources loaded through a registry (now including feeding styles and traversal routes), and a working
example mod is included. There is no mod manager or stable API yet. Read
[`docs/MODDING.md`](docs/MODDING.md) for the honest picture.

## Project layout
```
content/    data: forms, abilities, NPCs (incl. what they tell you), animals, blood, feeding styles, sunlight, day/night (incl. coffin wake times), locations (routes, clues), sounds
scripts/    core (registry, input, settings, audio, haptics, pause), data, player, abilities, interaction, npc, world, ui, visual
scenes/     title, main, player, npc, props
shaders/    sky, sense, screen effects
tests/      unit, playthrough, scenario, feel tests and dev tools
tools/      build_windows.ps1, sync_version.ps1, package_release.ps1 (release zip), check_repo.py, check_site.js
docs/       PROTOTYPE_NOTES.md (design notes), MODDING.md
examples/   a working example mod
website/    the public home page, feedback hub and community reports (static HTML/CSS/JS for GitHub Pages; not part of the game)
launcher/   the Windows launcher: installs the game and updates it from GitHub Releases (Python, separate from the game)
supabase/   feedback_schema.sql: the feedback database and its security rules
VERSION     the game's version (single source of truth for releases)
.github/    workflows/pages.yml (manual deploy of website/), ci.yml (checks that need no Godot)
```

## Limitations
Greybox environment, placeholder procedural audio (no music), no navmesh (NPC pathing is simple), one small
location, three people and two foxes, no save games, traversal is authored routes (not free climbing), the controllers are
untested on hardware, no code signing (Windows SmartScreen will warn), and no browser build yet. Details in the notes.

## License
No license has been chosen yet; until one is added, all rights are reserved by the author.
