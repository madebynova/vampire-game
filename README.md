# Vampire Game (prototype)

A third-person single-player vampire action-adventure, built in **Godot 4.8** (developed and tested
on 4.8-dev6, Forward+ renderer, Jolt physics).

This repository is a **prototype**, not the game. Its purpose is to answer one question:
*is being this vampire actually fun?* The systems that exist are small on purpose and are meant to
create decisions where they meet - sunlight vs. feeding vs. time of day vs. what you are (Human or
Vampire) - rather than to pile up features.

## Current status: Task 1.5 (refinement of the first playable)

### Playable today
- **Third-person movement** and camera; run, jump.
- **Human <-> Vampire** transformation. The two forms differ mechanically, not just visually.
- **Day/night cycle** (20 real minutes per day by default): moving sun and moon, dawn/dusk/night,
  stars, lamps that light after dark, ambience that follows the time. Humans are nearly blind at
  night; a vampire sees by a cool floor light.
- **Sunlight** as the central danger: ray-cast shade, strength depends on the sun's height, about
  **three minutes** of continuous noon sun to die, escalating stages with a live time-to-ash readout.
- **Vampiric Sense** (Q): humans glow through walls with their real heartbeat; how much you can
  read depends on distance; sleepers have slow blue hearts; in daylight the ground smoulders where
  the sun would burn you; secrets that blood told you about appear.
- **Feeding** (hold E as a Vampire): a held, interruptible action. Sleeping, unaware, or stunned
  victims are easiest; terrified ones struggle. Feeding heats you up in sunlight.
- **Blood memories**: what blood remembers depends on the victim's state (calm / asleep / afraid),
  so the same person can teach you different things.
- **People with routines**: two NPCs work, watch, and sleep on data-driven schedules. As a Human you
  can talk to them (three friendly chats build trust; a trusting person will follow you). Transform in
  view of someone and they panic - unless they trust you, in which case they freeze for a moment.
- **Coffin**: your home. Sleep until dusk; death returns you here.
- Procedural placeholder audio, placeholder primitive art (intentionally kept for now).

### Not implemented (on purpose)
Wolf/Bat forms, combat, quests, inventory, crafting, skill trees, full blood-type system, turning
people, lineage, a large world, save games, final art/UI, multiplayer. See
[`docs/PROTOTYPE_NOTES.md`](docs/PROTOTYPE_NOTES.md) for known issues and open design questions.

## Open and run
1. Install **Godot 4.8** (the standard, non-.NET build).
2. Godot Project Manager -> **Import** -> select `project.godot` in this folder.
3. Press **F5**. The main scene is `res://scenes/main.tscn`. You start as a Human in your coffin room.

| Key | Action |
|---|---|
| WASD / Shift / Space / mouse | move / run / jump / look |
| F | transform Human <-> Vampire |
| Q | Vampiric Sense (Vampire only) |
| E | Human: talk. Vampire: **hold** to feed. Also: dig, sleep in the coffin |
| H / F3 / Esc | toggle help / debug overlay / free the mouse |

## Tests and tools
All are headless-capable (`godot --headless --path . <scene>`); replace `godot` with your Godot 4.8 binary.

| Scene | What it checks |
|---|---|
| `res://tests/unit_tests.tscn` | clock and sun path, day/night profile, sunlight curve (3 min), content registry, mod override, example mod |
| `res://tests/smoke_test.tscn` | the original Task 1 acceptance playthrough (movement, transform, Sense, feeding, sunlight, coffin, repeatable loop) |
| `res://tests/scenario_tests.tscn` | Task 1.5 scenarios: routines, sleepers, memory variants, trust/follow, witnesses, tiered Sense, embers, night vs day, coffin sleep |

Windowed runs accept a screenshot directory: `godot --path . res://tests/scenario_tests.tscn -- <dir>`.
Dev tools: `sun_map.tscn` (ASCII shade map for an hour), `time_probe.tscn` (sky screenshots by hour),
`visual_probe.tscn`, `audio_probe.tscn`, `perf_probe.tscn`.

## Development philosophy
- Prove the experience before growing the game. If something works but feels bad, fix that first.
- A few systems that interact beat many that don't.
- Keep it modular: a thin player controller, self-contained components, and content as data.
- Never silently make permanent design decisions - uncertain ones are recorded as design questions.

## Modding direction
Modding is a long-term goal. What exists today is a **foundation only** - content lives in data
resources loaded through a registry, and a working example mod is included. There is no mod manager
or stable API yet. Read [`docs/MODDING.md`](docs/MODDING.md) for the honest picture.

## Project layout
```
content/    data: forms, abilities, NPCs, blood, sunlight, day/night, locations, sounds
scripts/    core, data (resource classes), player, abilities, interaction, npc, world, ui, visual
scenes/     main, player, npc, props
shaders/    sky, sense, screen effects
tests/      unit, playthrough, scenario tests and dev tools
docs/       PROTOTYPE_NOTES.md (design notes), MODDING.md
examples/   a working example mod
```

## Limitations
Greybox environment, placeholder audio, no navmesh (NPC pathing is simple), one small location,
two NPCs. Details in the notes.

## License
No license has been chosen yet; until one is added, all rights are reserved by the author.
