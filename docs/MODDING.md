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

`user://` on Windows is `%APPDATA%\VampireGame\` (the project sets a custom user-data folder name, so it does not depend on the project name or the install folder).

## 2. What is data-driven today

| Content | Resource class (`scripts/data/`) | Folder | What it controls |
|---|---|---|---|
| Forms | `FormData` | `content/forms/` | speed, jump, look, sun vulnerability + heat multiplier, whether humans fear it, which abilities it may use, night vision floor, blood drain / regen, **whether hunger slows it, its resting heartbeat, and which traversal types it may use** |
| Abilities | `AbilityDefinition` | `content/abilities/` | id, input action + default key **and pad button**, toggle, blood cost per second **and up-front activation cost**, **the behavior script**, tunable parameters |
| People | `NpcProfile` | `content/npcs/` | look, personality (notice radius, sleep depth, follow), dialogue by trust/night, blood type + description, **blood memories**, **daily schedule**, **what they can tell you** (`Tiding`s) |
| Things people tell you | `Tiding` (inside an NPC) | - | one useful thing, in order of trust and time of day: the words, the plain takeaway ("Learned: ..."), who it introduces (so Sense names them), what hidden thing it reveals |
| Animals | `AnimalProfile` + `AnimalPlacement` | `content/animals/` | a wild creature that can be fed on: look, how skittish, when it is about, den and roam range, blood type, yield, feed style, and its one memory |
| Hunters (v0.2.0) | `HunterProfile` + `HunterPlacement` | `content/hunters/` | a vampire hunter: look, health, how fast he walks and runs, how well he sees (cone, range, how much the dark costs him), hears (still / walking / running) and feels, how fast he notices, the length of his blade's tell, its damage, knock-back and stagger, his hours (dusk to dawn), his blood (type, yield, feed style, memory) and what he says. A placement gives him a camp and a round (points and how long he lingers) |
| The hunt (v0.2.0) | `HuntDefinition` + `HuntClue` | `content/hunts/` | the objective as a few lines (rumour, sighted, engaged, wary, down, done, withdrawn) and the **clues** that count as leads: a clue read (`INSPECT`, by `InspectPlacement` id) or a thing someone told you (`TIDING`, by `Tiding` id). There is no quest log: which line shows is worked out from the hunter's state |
| Blood memories | `BloodMemory` (inside an NPC or animal) | - | what blood tells you, chosen by the victim's state: `calm`, `asleep`, `afraid`, `trusting`, `any`, or `deep` (opens once every other memory has been heard); may reveal a secret |
| Schedules | `ScheduleEntry` (inside an NPC) | - | hour range, `patrol`/`idle`/`sleep`, route points, bed height, lantern |
| Blood types | `BloodDefinition` | `content/blood/` (people: common, aged, bright, iron; animals: `wild`; hunters: `hunter`) | Sense colour, feed-yield multiplier, **Bloodrush duration / power multipliers** (effects field reserved) |
| Feeding styles | `FeedStyle` | `content/feeding/` | **how a feed plays for one victim state** (`calm`, `asleep`, `afraid`, `trusting`, `wild` for animals, `hunter` for a downed hunter, or a new id): yield, Bloodrush power and length, how far the scream carries, how far sight matters, camera shake, feed volume, vibration, taste note, the Sense hint, and the Blood Memory's tint / fragmentation / sound bed / pace / framing line |
| Sunlight | `SunlightProfile` | `content/sunlight/` | the whole survival curve: stage names, heat thresholds, damage per second, slowdown, cooldown |
| Sky / time | `DayNightProfile` (+ `RestOption`) | `content/time/` | sky, fog, ambient, sun colour, moon and star strength by hour; **the wake-up times the coffin offers** |
| Locations | `LocationData` + `NpcPlacement` + `SecretPlacement` + `TraversalPlacement` + `AnimalPlacement` + `InspectPlacement` + `HunterPlacement` | `content/locations/` | who lives where, hidden secrets and the flags they set, lamp positions, coffin position, **designated routes (windows, walls, roofs) with their prompts and rules** (`reach`, `level_tolerance`, `lateral_tolerance`, `facing_min`, `barrier`, `lip_height`, `show_wall`), **which animals live where and where they den**, **small things to read**, **hunters (camp + round) and the waypoint graph they path by** (`nav_points`: the author places points on the ground, in doorways and inside rooms; links between them are found automatically wherever a body can walk in a straight line, so windows are never doors) |
| Sounds | `SoundDefinition` | `content/sounds/` | replaces a named sound with any `AudioStream`: the originals (`heartbeat`, `bite`, `sense_ping`...) **and the Task 1.75 ones** (`transform_vampire`, `transform_human`, `sense_on`, `feed_rush`, `heartbeat_deep`, `heartbeat_sharp`, `memory_calm`, `memory_asleep`, `memory_afraid`, `traverse_window`, `traverse_climb`, `ui_*`...) |

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
  `player` when the scene starts. (Bloodrush, traversal and the transformation presentation are built this way.)
- **Bloodrush and ability cost** - `BloodSurge.start(power, seconds, name)` gives a timed boost through the same
  hooks anything else can use: `Player.speed_modifiers`, `Player.jump_multiplier`, `Ability.cost_modifiers`
  (multiplies an ability's blood cost; 0 = free), `SunlightExposure.set_heat_modifier`.
- **Reacting to vampiric acts** - `HumanNpc.perceive_vampiric_act(origin, strength, radius, needs_sight)` is the one
  door by which anything supernatural (a feeding, a climb) frightens people; `FeedStyle` supplies the numbers.
- **Traversal** - add a `TraversalPlacement` to a location and list the type in `FormData.traversal`; the
  prompt, both ends, the Sense presence and the movement are generic (`TraversalLink`, `TraversalController`). A route is
  offered only when `TraversalPlacement.entry_problem()` says the player is on the right level, close enough, on the right
  side of the wall (`barrier`), in front of the opening and facing it, and the landing is free (the controller adds that last
  check); give a route sensible `reach` / `barrier` values and it can never be started from the wrong side. An end may be
  on a roof; stepping off a roof always needs the player to face the edge.
- **Things to drink from** - extend `FeedSource` (`can_be_fed`, `begin_feed`, `feed_tick`, `finish_feed`, `interrupt_feed`,
  `feed_style`, `get_feed_result`, optional camera / crouch hints). `FeedingController`, the HUD and the memory view only know that
  interface; people (`HumanNpc`) and animals (`Animal`) are two implementations. An empty `"memory"` in the result means "a
  meal, not a memory". The blood itself is a `BloodDefinition`, how the feed plays a `FeedStyle`.
- **Things people tell you** - add `Tiding`s to an `NpcProfile`; they are told one at a time as trust grows (`min_trust`), by
  time of day (`when`), after another (`after`). A tiding can `introduces` another person (Sense then uses their name) or
  `reveals_secret` (a hidden thing, exactly as a Blood Memory does).
- **Coffin choices** - list `RestOption`s on a `DayNightProfile`; the menu, the wake-up hour and the line shown on waking follow.
- **Input** - gameplay reads named actions only. A new ability's `default_key` / `default_joy_button` are registered
  for you; prompts (`InputGlyph`) show whatever the action is bound to for the device in use.

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
  positions of NPCs, secrets, lamps, the coffin and traversal routes are data. A route can connect any two
  places that already have room to stand (a mod can add a climb onto an existing roof), but a *new window* needs
  a hole in the wall, which is code today.
- **New forms in the player's transform cycle.** Forms load from data, but the cycle (`cycle_ids`)
  and the transformation effects are fixed to Human/Vampire. Wolf/Bat are not implemented.
- **New abilities from a mod, in practice.** An `AbilityDefinition` can point at any script, but a
  mod-shipped script has to be loadable from `user://` and there is no API stability, docs for the
  `Ability` hooks beyond the source, or UI to show extra abilities.
- **Animal behaviour beyond a den, a wander and a flee.** An `AnimalProfile` tunes how skittish, when it is about and what its
  blood is like; a new *kind* of behaviour (a predator, a flock) is code.
- **Enemies beyond the one archetype, quests, items, dialogue trees, VFX definitions.** A `HunterProfile` tunes the hunter
  (stats, senses, hours, blood, lines) and a location can place more of them, but a new *behaviour* (a ranged hunter, a pack) is code,
  and the objective is one line with clues, not a quest system. There are no items, dialogue trees or VFX definitions. (Sounds and feeding styles are moddable; screen effects, particles and
  the transformation presentation are code.)
- **UI.** The HUD, blood vessel, controls screen, pause menu and Blood Memory view are built in code
  (`scripts/ui/`); only the *content* of a memory (text, facts, style) is data. There is no theming data yet.
- **Rebinding and input glyph sets.** Everything reads actions, so rebinding is possible later, but there is no UI and
  the glyph families (keyboard / Xbox / PlayStation) are built in.
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
| Combat rules (damage, reach, a hunter's senses as arithmetic) | `scripts/combat/` |
| Interaction | `scripts/interaction/` |
| NPCs, animals, the hunter | `scripts/npc/` |
| World (clock, atmosphere, builder, props) | `scripts/world/` |
| UI | `scripts/ui/` |
| Visuals | `scripts/visual/`, `shaders/` |
| Tests | `tests/` |
