# Changelog

## v0.2.0 - THE HUNT

### Why
The prototype had a strong vampire and nothing to do with it. v0.2.0 builds the smallest version of one real gameplay loop - find a threat,
use Sense, stalk it, choose how to engage, use the vampire's movement, deal with it, feed and recover, carry on - out of the systems that
already existed. See [`docs/PROTOTYPE_NOTES.md`](docs/PROTOTYPE_NOTES.md) (v0.2.0 first) for the full account, numbers and open questions.

### Added
- **An objective that reads the world** (`HuntDirector`, `HuntDefinition`, `HuntClue`): one line under the corner of the screen
  (rumour -> sighted -> engaged -> wary -> down -> done / withdrawn), derived from the hunter's state, with six leads the world already held
  (the wax, the gate lock, the watch log, Elise's lantern, and two new things to read at the hunter's camp).
- **A threat: the Lamplighter, Hollis Crane** (`Hunter`, `HunterProfile`, `HunterPlacement`, `HunterGear`): a camp in the pines and a round of sixteen points
  from dusk to dawn; sees by a cone (further in lamplight, less in the dark), hears by how fast you move, feels you at his back; suspicious -> hunting -> searching ->
  back to his round; a telegraphed blade (0.55 s tell, 26 damage, knock-back, stagger); 120 health; goes down alive; withdraws at dawn; walks over a waypoint graph
  (`HuntNav`) so he uses doorways and cannot use windows or roofs.
- **One attack: Rend** (`PlayerCombat`; R / left mouse / RB-R1): 20 damage, 0.56 s, costs 1 blood and gives 2.5 back; a pounce at a run (25), a plunge when falling (30), an
  ambush on someone who did not know you were there (x3); weaker when hungry, stronger in a Bloodrush; soft aim; remembers one press at the end of a swing; freeze-frame, FOV kick,
  claw marks, blood, floating numbers, vibration. A new `PlayerState.Mode.STAGGERED`, `Player.push()`, `FeedingController.break_off()`.
- **Readouts**: a strike ring on the centre dot, hit marks, red arcs pointing at who hit you, "R  Ambush" when an unaware hunter is in reach, "WOUNDED 74", a persistent red edge below 45%
  health, an over-the-shoulder camera for the length of a fight; over the hunter (constant screen size) a "?" / "!", a health bar, an awareness bar, his few words, and the damage.
- **Sense reads the hunter** (22 m): whether he has noticed you, his pulse, a silhouette that goes gold -> amber -> red, and "his back is to you".
- **A downed hunter can be drunk**: the richest blood in the estate (62, *Hunter's Rush* x1.45 for 65 s) and his own memory, "The Lamp Is Lit". Leave him alive and he is back at dusk.
- **Content**: `content/hunters/lamplighter.tres`, `content/hunts/lantern_in_the_manor.tres`, a `hunter` feed style and blood type, a hunter placement and 31 waypoints in `blackthorn.tres`, a camp.
- **Eleven procedural sounds**: boots, a lantern, a "hm?", a stab when he sees you, a blade drawn, a swing, a grunt, a fall, claws, flesh, a blow taken.
- **The night holds its breath**: the crickets go quiet when the hunter is near.
- Tests: `hunt_tests` (245 checks), `hunt_playthrough` (33 checks, real key events), `hunt_playtest` (27 photographs), `hunt_balance`; all five older suites unchanged.

### Fixed
- **Long Blood Memories pushed the reward line and "Continue" off the bottom of a 720 px screen** (the hunter's, and Tomas's *trusting* memory, which has shipped since 0.1.0).
  `MemoryView.fit_to_screen()` measures the full text and, only when needed, scales the column to fit. Short memories are untouched.

### Changed
- The Bloodrush's own description now says it makes Rend hit harder (the pinned wording of the existing description is untouched).
- The controls screen lists Rend; the HUD has a Rend chip; the death banner says who killed you (*THE HUNTER GOT YOU* / *THE SUN TOOK YOU*).
- `NightLight` and the interior lights register with `WorldLight` so something can ask how brightly lit a spot is.
- The coffin tells hunters that you rested or died (`player_rested`).
- Version 0.2.0 (`VERSION`, `export_presets.cfg`, `project.godot`). `tools/test_exported_build.ps1` also runs `hunt_tests`.
- The Godot editor re-saved `scenes/main.tscn` with scene and script UIDs (committed separately; no behaviour change).

### Not changed
Sunlight, day length, blood drain, Sense cost, the transformation, the people, the foxes, traversal rules and every existing check.

## Task 1.8 - Vampire world & traversal polish

### Why
Playtest feedback after Task 1.75: the transformation, Sense, feeding, camera and pad buttons are loved; slipping through a
window is the best vampire moment; but traversal climbed through floors, went out when you meant in, dropped you from roofs
into rooms and vaulted you through windows from roofs; movement felt like ice; the cape clipped; "Bright Blood +39 / Blood Fury
0:32" meant nothing; there was no blood number, no second blood, nothing for people to say and the coffin only slept to dusk.
This pass fixes the traversal at the root and makes the small world more purposeful. No new category of game was started.

### Fixed
- **Traversal could fire from the wrong place.** The interactor measured ground distance only, so a roof was "within reach" of the
  room under it (and the cellar hatch of the roof above it), picked the route end by camera score, and then teleported the player to
  that end. A route is now offered and started only when the form may use it, the player is on its level, near its start end, on
  that end's side of the wall, in front of the opening, facing the way it goes, and the landing is free and has floor
  (`TraversalController.problem`, `TraversalPlacement.entry_problem`). `Interactable.reach_up / reach_down` stop every other prompt
  leaking through floors too.
- **The vampire's cape went through its legs when running.** A positive `rotation.x` swings a hanging cape forward; the flare used a
  positive angle. The cape is now a three-segment chain with lag and a clearance pass (`HumanoidModel`). The feeding "arms forward" pose had
  the same sign error and threw the arms backward.
- **Esc closed a menu and opened another in the same frame** (found while building the coffin menu).
- A teleported player kept the previous prompt for a moment (`Player.place_at` clears the interaction focus).

### Added
- **Blood number** under the vessel (`N / 100`), smoothed with the liquid.
- **Readable rewards**: the memory screen names the blood and what it is like, says how much blood you got and, in gold, what the rush does and for how long;
  the HUD shows the effect under the timer ("Faster, higher jumps, Sense is free, the sun burns slower"). Text is generated from the surge's own numbers.
- **A second blood: the fox** (`Animal`, `AnimalProfile`, `AnimalPlacement`, `FeedSource`, blood `wild`, feed style `wild`, rush *Instinct*): den, nocturnal
  routine, skittish, goes to ground after a feed, found by Sense, one creature's-eye memory (first time only), safe but small.
- **What people tell you** (`Tiding`): twelve tidings across the three people, told in order as trust grows, by time of day, naming strangers to Sense,
  pointing at secrets and at which feeding state holds a dream. "Talk to X (something to tell)".
- **Seven more Blood Memories**: a trusting memory for each person, a deepest memory for each (opens once the rest are heard), and the fox's.
- **Wall climbing, prototype**: hands-and-feet climb pose, dust, mist trail, camera shudder; Sense draws the wall as a pale strip; prompts name the
  building; a fourth climb (`hut_roof`) and the intentional **broken roof** route (`manor_hatch`); a low rim stops bodies falling into the manor by accident.
- **Coffin choices** (`RestMenu`, `RestOption`): dusk (default, focused), midnight, dawn, daylight; options too close to now are hidden.
- **Three small clues** (`InspectPlacement`, `Inspectable`): a watch log, candle wax under a window, a scratched gate lock.
- Tests: `polish_tests` (Task 1.8, 186 checks, with `-- only=` sections), 54 new unit checks (288 total), `polish_playtest` and `model_probe` dev tools; 840 checks across the five suites.

### Changed
- **Movement**: separate acceleration / braking / turn grip (`FormData.deceleration`, `turn_grip`, `Player.steer`); Vampire 42 / 70 / 55 (was 26 for
  everything), Human 30 / 48 / 42 (was 16).
- Route prompts name the building and the direction ("Slip into the manor through the window"); the climb starts hug the wall.
- Tomas's trusting memory also reveals the buried key (trust has always been a way to the key).
- The coffin asks when you wake; every existing reset still happens, and animals are reset too.
- `Player` collides with a new "player only" layer (the roof rim); sun rays, NPCs and the camera are unaffected.

### Unchanged on purpose
Sunlight (about three minutes at noon), the 20-minute day and the night, blood drain (Human 0.02/s, Vampire 0.16/s) and Sense cost,
transformation, feeding feel and camera shake, the pad bindings and vibration.

## Task 1.75 - Vampire feel & immersion pass

### Why
Playtest feedback: night, Sense and sunlight are excellent; transforming and feeding are boring; Blood
Memory is a popup that disappears; human blood stops completely; the HUD is plain; there is no pause menu, the
controls are a debug list, the world has pointless props, and the player wants a controller, windows and roofs.
This pass is about *feel*, not features; nothing from the "not yet" list (combat, Wolf/Bat, quests...) was started.

### Added
- **Transformation presentation** (`TransformPresentation`): wind-up and release per direction - FOV and camera
  dolly, a red-black tunnel with chromatic tear, the body rising and arching, hit-stop at the swap, a shockwave
  ring, flash, particles, muffled-then-open sound, NPCs within 10 m feel it; Human <-> Vampire are different beats.
  The Vampire also hears the night with more depth and has a cold rim on the screen.
- **Living blood**: `BloodGauge` vessel (liquid surface, your heart's pulse, droplets while Sense spends, a flash
  when you drink, a dashed ring when hungry, fangs on the rim), `BloodPool.pulse_rate()`, screen-edge heartbeat and
  hunger desaturation, hunger pangs, a quiet heartbeat when hungry.
- **Bloodrush** (`BloodSurge`): after a feed - quicker, higher, Sense free, wounds close faster, a little more sun
  patience; strength and length from the victim's state and blood type.
- **Feeding by victim state** (`FeedStyle` data: calm / asleep / afraid / trusting): quiet over a sleeper, loud and
  richer with a terrified victim (heard within 17 m), witnesses who SEE it run, a `feed` action of its own, a
  heartbeat you feel in the pad, a rush at the end. Sense hints at memories not yet heard ("a dream waits").
- **Blood Memory view** (`MemoryView`): the world freezes, drains into the memory's colour, per-state sound bed and
  heartbeat, the text told with breaths, facts surfacing, **no timeout**, deliberate dismissal only (E / Space /
  Enter / click / pad A, B, X), held-key release gate, a press during the telling completes it.
- **Vampiric Sense**: attention (nearest, most in front), scan-wave flares, strangers flicker vs acquaintances steady,
  split readout (name, mood, blood, gold hint), calm / asleep / afraid heartbeat sounds, throbbing through the pad
  when very close, camera breath and rumble on activation.
- **Traversal**: data-driven routes (`TraversalPlacement` -> `TraversalLink` -> `TraversalController`): three windows
  (mist), three climbs (manor roof, ruined wall, cottage roof), both directions, Sense shows them, clear-exit guard.
- **Controller-first input**: every action with keyboard + pad (any device), run trigger + stick-click latch, R3/LB
  Sense, `sprint_toggle`, `feed`, `pause`, `memory_dismiss`; last-device tracking, Xbox / PlayStation glyphs
  (`InputGlyph`); UI navigation actions guaranteed to have pad bindings; `Haptics` with an Options toggle.
- **HUD**: 12-hour serif clock with a sun / half-sun / moon glyph, glyph prompts (feed shows the feed button),
  contextual hints, a designed **controls screen** on the right (grouped, keyboard column + pad column, dims
  vampire-only rows), sun danger with an icon, toasts.
- **Pause menu** (Resume / Controls / Options / Quit to Title), **Options** (master / effects / ambience / music
  volume, mouse and stick sensitivity, vibration, fullscreen; saved), a **title screen**, `PauseControl` reasons.
- **World**: 16 trees -> 9 at the edges, lamps along the road and paths, boulder and low wall removed, an iron gate
  with a sign, a watch hut, footpaths to every destination, a bench, a woodpile, the cart moved off the road.
- **A third person**: Corvin Hale, a night watchman who patrols all night and sleeps by day, with iron blood and
  three memories; someone is awake at every hour and a sleeper can be found for most of the day.
- **Coffin**: the lid slides open, you lie down, it closes; you wake as it opens.
- **12-hour clock** for the player (display only).
- **Audio**: buses (Effects, Ambience, Music) with muffle and vampire-hearing reverb; new procedural sounds
  (transformations, Sense on, feed rush, deep and sharp heartbeats, hunger, memory beds, windows, climbs, UI), built lazily.
- `export_presets.cfg` (Windows playtest preset) and `tools/build_windows.ps1`.
- Tests: `feel_tests` (238 checks), 166 new unit checks (234 total), plus `playtest_driver`, `world_probe`, `soak_probe`, `boot_probe`.

### Changed
- Human blood drains at 0.02/s (was 0), Vampire 0.16/s (was 0.35). Sense 0.55/s + 2 (was 1.4/s).
- Transformation 1.25 s (swap at 45%). Hunger slows Vampires only.
- Esc pauses (it used to free the mouse). The window losing focus pauses.
- Feeding is held with `feed` (same keys as `interact`). The HUD is rebuilt.
- South boundary wall moved to z=30 (was 34); trees, lamps and props as above.
- The controls are documented for keyboard, Xbox-style and PlayStation pads.

### Fixed
- Godot 4.8-dev6's built-in `ui_accept` had no gamepad binding: menus could not be confirmed with a pad.
- The old memory panel could close on the very E press a player was still holding from the feed.

### Test changes (documented, not deleted)
See `docs/PROTOTYPE_NOTES.md`: feed held on `feed`; memory checks go through `MemoryView` with a real dismissal;
"control returns after feeding" now means after the memory is dismissed; the coffin wait is longer; one smoke step
resets Tomas and starts at x=3.

## Task 1.5 - Core loop refinement, day/night, sunlight and modding foundation

### Why
Playtesting Task 1 said the prototype worked but felt a little boring, that the sun killed far too
fast (~8 seconds), that there was no real night, and that the game should become moddable. This phase
makes the *existing* systems interact instead of adding big new ones.

### Added
- **Day/night cycle.** `TimeOfDay` clock (20 real minutes/day), sun and moon on a real orbit, dawn / day /
  dusk / night phases, a custom sky with stars, sun and moon discs, time-keyed sky/fog/ambient from a data
  profile, lamps and lanterns that light after dark, day/night ambience (birds, crickets, a bell at dusk),
  HUD clock with a sunrise countdown, dawn warning.
- **Form-dependent vision.** Humans are nearly blind at night; the vampire sees by a cool floor light.
- **Sunlight rework.** About three minutes of continuous full sun to die (was ~8 s). Stages: Safe,
  Initial (warning, no damage), Prolonged, Severe, Critical, death. Heat model with cooldown in shade;
  strength scales with the sun's height (dawn/dusk are gentle, noon is not); HUD shows the stage and a live
  "ash in m:ss" estimate; critical exposure adds a racing heartbeat.
- **Sunlight extension API**: `SunlightExposure.set_heat_modifier()` and `FormData.sun_heat_multiplier`
  (resistances, items, blood effects, debuffs can plug in later). Feeding doubles heat while you kneel.
- **NPC routines.** Data-driven schedules (patrol / idle / sleep, lanterns). Tomas has a cottage and bed.
  Elise keeps a lantern watch at night and sleeps on the gatehouse bench.
- **Sleeping victims**: woken by noise (sprinting), not by sight; feed them quietly and their blood is different.
- **Blood-memory variants** by victim state (calm / asleep / afraid) - same person, different secrets.
  A second hidden thing (Tomas's ledger) is revealed only by his dream.
- **Human vs Vampire**: as a Human, friendly chats build trust, people share more, and a trusting person will
  follow you (lure them into shade, transform, feed within their moment of shock). Transforming in someone's
  view terrifies them.
- **Facing-based noticing**: approach from behind. Better fleeing (slides along walls).
- **Vampiric Sense upgrades**: information depends on distance; unknown people are "a stranger" until met;
  blue sleeping hearts; sun **embers** on the ground by day.
- **Blood-memory presentation**: sepia flashback tint, fade-in, letter-by-letter recollection.
- **Modding foundation**: `ContentRegistry` (res://content + user://mods), resource classes for forms,
  abilities (behavior script + tunables), NPCs, memories, schedules, blood, sunlight, day/night, locations,
  sounds; example mod; `docs/MODDING.md`.
- Tests: unit suite (68), scenario suite (52), shared test base, tools (time/perf probes).
- Repository hygiene: git, Godot `.gitignore`, README, this changelog.

### Changed
- Abilities are instantiated from `AbilityDefinition` data rather than wired into the player scene.
- Forms/NPCs/secrets/locations come from `content/` (the old `data/` folder moved).
- Coffin: "sleep until dusk" (was "end the night").
- Human/Vampire: the vampire's vision floor replaces the old fixed ambient values in `FormData`.

### Test changes (documented, not deleted)
- The Task 1 acceptance suite (71 checks now) still runs; it freezes NPC routines and pins the sun direction
  (`TimeOfDay.sun_override`) so the original layout assumptions hold.
- Obsolete by design: "sun kills in 5-12 s" -> "kills in ~3 min (run at 8x)"; "a full feed in sun costs 8-60 hp"
  -> "costs heat, not health"; "a terrified Tomas reveals the well key" -> terror gives a different memory and
  the key needs a calm feed.

## Task 1 - First playable vampire prototype
Third-person controller; Human/Vampire forms; Vampiric Sense; feeding and blood memory; sunlight;
coffin; two NPCs; a small test arena; procedural audio; basic HUD; 67-check automated acceptance suite.
