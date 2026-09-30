# Changelog

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
