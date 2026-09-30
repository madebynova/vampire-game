# Vampire Game (prototype)

A third-person single-player vampire action-adventure, built in **Godot 4.8** (developed and tested
on 4.8-dev6, Forward+ renderer, Jolt physics).

This repository is a **prototype**, not the game. Its purpose is to answer one question:
*is being this vampire actually fun - does it feel like you became one?* The systems that exist are
small on purpose and are meant to create decisions where they meet - sunlight vs. feeding vs. time of
day vs. what you are (Human or Vampire) - rather than to pile up features.

## Current status: Task 1.75 (vampire feel & immersion pass)

Task 1 made the loop work, Task 1.5 made it interact (day/night, sun, routines, modding foundation).
Task 1.75 is about **feel**: what it is like to *become* a vampire, feed, perceive and move. Nothing big
was added; what exists was made to read, sound and feel like something.

### Playable today
- **Human <-> Vampire** with a real transformation: the world tightens into a red-black tunnel, the body
  rises and arches, time stutters, a shockwave and chromatic tear mark the change, the night suddenly
  opens around you. Going back is quieter: a long exhale, warmth, the cloak turning to ash.
- **Blood as something alive**: a vessel that sloshes, pulses with your own heart (slow and heavy as a
  vampire, quick when hungry, feeding or burning), sheds drops while Sense runs, flashes when you drink.
  No numbers. A Human spends blood very slowly, a Vampire noticeably faster.
- **Feeding you want to do**: how it plays depends on the victim - a sleeper is fed on quietly and gives
  a long, gentle *Dreamblood*; someone unaware is steady; a terrified victim screams, pays more blood and a
  hot short *Fury* - and anyone who **sees** it runs. A good feed leaves a **Bloodrush** (quicker, higher,
  Sense free, wounds close faster, a little more patience with the sun).
- **Blood Memories you experience**: the world freezes, drains into the memory's colour and dims, the room's
  sound recedes and a procedural bed plays; the memory is told a few words at a time. It never times out,
  and only a deliberate press closes it (the key still held from the feed cannot).
- **Vampiric Sense**: the nearest thing you face is the one you attend to; scan waves make people flare;
  strangers are pale and flicker, people you know are steady and warm; heartbeats sound different calm,
  asleep or afraid; a heart very close throbs through your hands. Sense tells you when a memory is still
  unheard ("a dream waits"). It costs a little blood up front and a steady trickle - and is free during a Bloodrush.
- **Traversal only a vampire has**: slip through windows (you dissolve to mist at the sill), climb to the
  manor roof, the ruined wall and the cottage roof. Humans see none of it.
- **Day/night cycle** (20 real minutes per day), **sunlight** (about three minutes of full noon sun to die),
  **NPC routines**, **trust and lures**, **coffin** - as in Task 1.5, unchanged in their numbers.
- **HUD and menus**: a blood vessel, a serif 12-hour clock with a sun/moon glyph, prompts that show the
  real button for the device you last used (keyboard, Xbox-style, PlayStation), a designed controls screen,
  a pause menu (Resume / Controls / Options / Quit to Title), a small title screen.
- **Three people** with data-driven routines - a groundskeeper, a seamstress, and a night watchman who
  patrols the road all night and sleeps by day - so there is someone to find at almost every hour.

### Controls

| Action | Keyboard / mouse | Xbox-style pad | PlayStation pad |
|---|---|---|---|
| Move / look | WASD / mouse | left stick / right stick | same |
| Run | Shift (hold) | RT (hold), or click **L3** to latch until you stop | R2 / L3 |
| Jump | Space | A | Cross |
| Talk, dig, sleep, **slip through windows, climb** | E | X | Square |
| **Feed** (Vampire, hold) | E | X | Square |
| Transform Human <-> Vampire | F | Y | Triangle |
| Vampiric Sense (Vampire, toggle) | Q | LB (R3 also works) | L1 (R3) |
| Continue a Blood Memory | E / Space / Enter / click | A, B or X | Cross / Circle / Square |
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

## Windows playtest build
Exporting needs the Godot editor plus the matching **export templates**. The project is export-ready
(`export_presets.cfg` has a "Windows Desktop (playtest)" preset that excludes tests, docs and examples).

1. In the Godot editor: *Editor -> Manage Export Templates -> Download and Install* (the templates folder
   for 4.8-dev6 is `%APPDATA%\Godot\export_templates\4.8.dev6\`).
2. Run `./tools/build_windows.ps1 -Godot "<path to your Godot 4.8 console exe>"`. It checks for the templates
   first and tells you exactly what is missing; on success it writes `build/windows/Vampire.exe`
   (git-ignored - publish binaries as GitHub Releases, not in the repository).

**Status:** the development machine has **no export templates installed**, so no build was produced in this
pass (the script reports the missing `windows_release_x86_64.exe` / `windows_debug_x86_64.exe`). Nothing was
faked; see the notes for the state of the preset.

## Tests and tools
All are headless-capable (`godot --headless --path . <scene>`); replace `godot` with your Godot 4.8 binary.

| Scene | What it checks |
|---|---|
| `res://tests/unit_tests.tscn` | clock (24 h and the 12-hour display), sun path, sunlight curve, content registry, mods, blood tuning, the input map (every action has keyboard and pad bindings, nothing hard-codes devices), feed styles, traversal paths, settings and audio buses |
| `res://tests/smoke_test.tscn` | the original acceptance playthrough (movement, transform, Sense, feeding, sunlight, coffin, repeatable loop) |
| `res://tests/scenario_tests.tscn` | Task 1.5 scenarios: routines, sleepers, memory variants, trust, witnesses, tiered Sense, embers, night vs day |
| `res://tests/feel_tests.tscn` | Task 1.75: transformation presentation, blood and Bloodrush, feeding per victim state, witnesses, the Blood Memory view and its input rules (held keys, pad, mouse), Sense, every traversal route both ways (and blocked exits), pause and menus, controller-only play, HUD and controls screen, coffin, the cleaned-up world |

Windowed runs accept a screenshot directory: `godot --path . res://tests/feel_tests.tscn -- <dir>`.
Dev tools: `playtest_driver.tscn` (a scripted walk through the playtest sequence with screenshots),
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
content/    data: forms, abilities, NPCs, blood, feeding styles, sunlight, day/night, locations (incl. routes), sounds
scripts/    core (registry, input, settings, audio, haptics, pause), data, player, abilities, interaction, npc, world, ui, visual
scenes/     title, main, player, npc, props
shaders/    sky, sense, screen effects
tests/      unit, playthrough, scenario, feel tests and dev tools
tools/      build_windows.ps1
docs/       PROTOTYPE_NOTES.md (design notes), MODDING.md
examples/   a working example mod
```

## Limitations
Greybox environment, placeholder procedural audio (no music), no navmesh (NPC pathing is simple), one small
location, three people, no save games, traversal is authored routes (not free climbing), the controllers are
untested on hardware, and there is no built executable yet. Details in the notes.

## License
No license has been chosen yet; until one is added, all rights are reserved by the author.
