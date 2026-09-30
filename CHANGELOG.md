# Changelog

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
