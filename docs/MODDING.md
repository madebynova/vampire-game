# Modding Architecture Foundation

> **Honest status:** the game is **not moddable yet**. There is no mod manager, no in-game mod
> menu, no Workshop integration, no stable API promise, and no sandbox. What exists is a
> *foundation*: most game content is authored as plain data resources that a central registry
> loads, so that real modding support can be built on top later without rewriting the game.
> Everything below tells you what works today, what is planned, and what is not supported.

## 1. The idea

Core systems (movement, feeding, sunlight maths, the clock...) are **code**. Anything that
describes *content* - who a person is, what a form can do, what blood remembers, how deadly the
sun is, what the sky looks like at 21:00, who stands where - is a **Resource file** (`.tres`)
under `res://content/`. The `ContentRegistry` autoload finds those files at startup, and the game
asks the registry for content by `(type, id)` instead of hard-coding it.

```
res://content/            core game content  (loaded first)
user://mods/<mod>/content/ mod content        (loaded after; same type + same id = replaces core)
user://mods/<mod>/mod.cfg  optional manifest  (name, version, author, description)
```

`user://` on Windows is `%APPDATA%\Godot\app_userdata\<project name>\`.

## 2. What is data-driven today

| Content | Resource class (`scripts/data/`) | Folder | What it controls |
|---|---|---|---|
| Forms | `FormData` | `content/forms/` | speed, jump, look, sun vulnerability + heat multiplier, whether humans fear it, which abilities it may use, night vision floor, blood drain / regen |
| Abilities | `AbilityDefinition` | `content/abilities/` | id, input action + default key, toggle, blood cost, **the behavior script**, tunable parameters |
| People | `NpcProfile` | `content/npcs/` | look, personality (notice radius, sleep depth, follow), dialogue by trust/night, blood type + description, **blood memories**, **daily schedule** |
| Blood memories | `BloodMemory` (inside an NPC) | - | what blood tells you, chosen by the victim's state: `calm`, `asleep`, `afraid`, `any`; may reveal a secret |
| Schedules | `ScheduleEntry` (inside an NPC) | - | hour range, `patrol`/`idle`/`sleep`, route points, bed height, lantern |
| Blood types | `BloodDefinition` | `content/blood/` | Sense colour, feed-yield multiplier (effects field reserved) |
| Sunlight | `SunlightProfile` | `content/sunlight/` | the whole survival curve: stage names, heat thresholds, damage per second, slowdown, cooldown |
| Sky / time | `DayNightProfile` | `content/time/` | sky, fog, ambient, sun colour, moon and star strength by hour |
| Locations | `LocationData` + `NpcPlacement` + `SecretPlacement` | `content/locations/` | who lives where, hidden secrets and the flags they set, lamp positions, coffin position |
| Sounds | `SoundDefinition` | `content/sounds/` | replaces a named sound (`heartbeat`, `bite`, `sense_on`...) with any `AudioStream` |

All of these extend `ContentDef` (`id`, `display_name`, `description`). The registry keys them
by their class name and `id`.

### Extension points (code that is already generic)

- **Sunlight** - `SunlightExposure.set_heat_modifier(source, multiplier)`. Resistance, protective
  items, blood effects, elder-vampire bonuses, or debuffs only have to call this; they never touch
  the maths. `FormData.sun_heat_multiplier` is the per-form version. Feeding already uses it.
- **Abilities** - add an `AbilityDefinition` whose `behavior` extends `Ability`
  (`_on_activated`, `_on_deactivated`, `_on_tick`). Blood cost, key binding and form gating are
  handled for you. `VampiricSense` is built exactly this way; there is nothing about it in the
  player scene.
- **Sense** - anything can be sensed by adding a `SenseTarget` child. The parent may implement
  `is_sense_visible()` and `get_sense_data(distance)`.
- **Interaction** - anything can be interactable by adding an `Interactable` child; the parent
  may implement `is_interaction_available()` / `get_interaction_prompt()`.
- **Player systems** - extend `PlayerComponent`, put it under `Player/Components`, and it gets
  `player` when the scene starts.

## 3. Making a mod today (manual, developer-level)

1. Create `user://mods/my_mod/content/...` (folders under `content/` are free-form; the registry
   scans recursively).
2. Add `.tres` files. Easiest: open the project in the Godot editor, create a resource of the right
   class (Inspector -> New Resource -> `NpcProfile`, ...), fill it in, save it into your folder.
   Or copy a core file from `res://content/` and edit the text.
3. Use an `id` that is new to **add** content, or a core `id` to **replace** it.
4. Optional `mod.cfg`:
   ```ini
   [mod]
   name="My Mod"
   version="1.0"
   author="you"
   description="what it does"
   ```
5. Run the game; the registry prints `ContentRegistry: <Type> '<id>' replaced by <mod>` for every
   override.

A complete, tested example is in [`examples/example_mod/`](../examples/example_mod/): it replaces the
sunlight curve with one that lasts twice as long and adds a "Sweet" blood type. The unit tests copy
it into `user://mods`, verify the doubled survival time, and remove it again.

### Example: a new blood type
```
[gd_resource type="Resource" script_class="BloodDefinition" load_steps=2 format=3]
[ext_resource type="Script" path="res://scripts/data/blood_definition.gd" id="1_b"]
[resource]
script = ExtResource("1_b")
id = &"sweet"
display_name = "Sweet"
sense_color = Color(1, 0.4, 0.6, 1)
yield_multiplier = 1.3
```
An `NpcProfile` then says `blood_type = &"sweet"`.

### Example: what a person looks like in data
See [`content/npcs/tomas.tres`](../content/npcs/tomas.tres): three blood memories (calm, asleep,
afraid) - one reveals a buried key, one a hidden ledger - and a three-block routine (patrol the yard,
smoke outside at dusk, sleep in the cottage).

## 4. What is currently safe to modify

Safe (values only, no code): every field of every resource in the table above; adding new NPCs,
blood types, sounds, sunlight profiles and day/night profiles; overriding core content by id.
The automated tests cover the registry, mod discovery/override/removal, the sunlight and clock
maths, schedules, memories and ability construction from data.

## 5. What is NOT supported yet

- **Placing new content in the world without replacing a whole location.** A `LocationData` is
  replaced as a unit; there is no "patch" that adds one NPC to the existing location. A mod that
  wants to add a person must currently supply its own copy of the location.
- **New geometry.** Buildings, trees and props are built in code by `WorldBuilder` (greybox). Only
  positions of NPCs, secrets, lamps and the coffin are data.
- **New forms in the player's transform cycle.** Forms load from data, but the cycle (`cycle_ids`)
  and the transformation effects are fixed to Human/Vampire. Wolf/Bat are not implemented.
- **New abilities from a mod, in practice.** An `AbilityDefinition` can point at any script, but a
  mod-shipped script has to be loadable from `user://` and there is no API stability, docs for the
  `Ability` hooks beyond the source, or UI to show extra abilities.
- **Items, enemies, quests, dialogue trees, encounters, VFX definitions** - none of these systems
  exist yet, so there is nothing to mod. (Sounds are moddable; effects are code.)
- **Blood effects.** `BloodDefinition.effects` is reserved and ignored.
- **Save data, mod load order controls, dependency/version checks, conflict UI.** Overrides are
  applied in folder-name order and the last one wins.
- **Sandboxing.** A `.tres` can reference a script, and scripts run with full access. Treat mods
  as code: only install mods you trust.
- **A stable API.** Class names, folders and fields may change between prototype phases.

## 6. Future modding goals (not commitments)

New abilities, forms, blood types (with effects), NPCs, enemies, items, locations (including
geometry), visual effects, sounds, dialogue and encounters added without touching core files;
additive location patches; mod list + load order UI; validation and helpful error messages; a
documented, versioned API; optional Steam Workshop packaging.

## 7. Where things live (architecture map)

| Area | Path |
|---|---|
| Core services (registry, input, audio, fx) | `scripts/core/` |
| Data resource classes | `scripts/data/` |
| Content | `content/` |
| Player (thin controller + components) | `scripts/player/` |
| Abilities | `scripts/abilities/` |
| Interaction | `scripts/interaction/` |
| NPCs | `scripts/npc/` |
| World (clock, atmosphere, builder, props) | `scripts/world/` |
| UI | `scripts/ui/` |
| Visuals | `scripts/visual/`, `shaders/` |
| Tests | `tests/` |
