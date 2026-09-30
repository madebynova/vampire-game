# Vampire prototype - design notes (Task 1 + Task 1.5)

North-star question: **"Is being this vampire actually fun?"** Task 1 proved the systems work.
Task 1.5 tries to make them create *decisions*.

## Run it / test it
See the README. Quick reference (replace `godot` with the 4.8 binary):

| Command | What |
|---|---|
| `godot --headless --path . res://tests/unit_tests.tscn` | 68 logic checks |
| `godot --headless --path . res://tests/smoke_test.tscn` | 71-check Task 1 playthrough |
| `godot --headless --path . res://tests/scenario_tests.tscn` | 52-check Task 1.5 scenarios |
| `godot --headless --path . res://tests/sun_map.tscn -- 12` | ASCII shade map at 12:00 (hour arg optional) |
| `godot --path . res://tests/time_probe.tscn -- <dir> 6,12,18,22` | screenshots of the yard by hour, Human vs Vampire |
| `godot --path . res://tests/perf_probe.tscn` | frame time / draw calls in day, dusk, night, Sense on |

## What changed in Task 1.5, and why

| Feedback | Response |
|---|---|
| "Somewhat boring" | Make systems meet: time of day changes where people are and how dangerous the sun is; who you feed and *how* changes what you learn; Human and Vampire are different tools. |
| "Sun death is too short (~8 s); want ~3 minutes" | New sunlight model tuned to ~180 s of full sun, but strength now follows the sun's height, heat lingers, and feeding heats you. |
| "No meaningful night" | Real day/night cycle, moving sun/moon, lamps, night ambience, night vision that only the vampire has. |
| "Moddable eventually" | Content moved into data resources behind a registry; abilities from data; an example mod; honest docs. |
| "Keep the art" | Untouched. Only lighting/sky/composition changed (a cottage, lamps). |

## Day/night behaviour
- 24 game hours = **20 real minutes** (`TimeOfDay.day_length_seconds`, 50 s per hour). The game starts at **14:00**, so dusk
  arrives about 3.5 minutes in and the night about 5.
- Sun rises east 06:00, crosses the **northern** sky (max 52 degrees at noon), sets west 18:00; the moon is exactly opposite.
- Phases come from the sun's elevation: **Dawn** 05:29-06:51, **Day** 06:51-17:09, **Dusk** 17:09-18:31, **Night** 18:31-05:29.
- Sun *strength* (what sunlight damage scales with) ramps from 0 at 06:00 to full at ~07:53, falls to 0 at 18:00.
- Look (sky, fog, ambient, moon, stars) is keyed by hour in `content/time/default.tres`.
- Vision: ambient is `max(time-of-day ambient, form floor)`. Human floor 0.05 (at midnight the ambient is 0.06); Vampire floor 0.62.
- Lamps/lanterns are `NightLight`s. Ambience: birds by day, crickets at night, a bell at dusk and a warning bell at 05:00.
- Coffin: sleep skips to **19:00**. Sleeping by day = same day's dusk; at night = next day's dusk.
- Anything can react to time via the `time_of_day` group (`hour`, `phase()`, `darkness()`, `sun_strength()`, `phase_changed`,
  `hour_changed`). NPC schedules, night lights, ambience, HUD and the sun already do.

## Sunlight tuning
Heat = exposure-seconds at full strength. `strength = body-in-light x sun intensity x form multiplier x modifiers`.
Default profile (`content/sunlight/default.tres`):

| Stage | Heat from | Damage/s | Speed | Feels like |
|---|---|---|---|---|
| Safe | - | 0 | 100% | shade / night |
| Initial | >0 | 0 | 100% | warning; prickling skin |
| Prolonged | 8 | 0.2 | 97% | discomfort |
| Severe | 80 | 0.55 | 85% | strong feedback, smoke |
| Critical | 140 | 1.3 | 65% | embers, racing heartbeat |
| Death | - | - | - | health 0 -> coffin |

- Full noon sun: **~181 s** to death (tested at 8x in the playthrough, 180 s in the unit model). Half exposure = double time
  (tested). Resistance scales the same way.
- Shade cools heat at 0.5/s: a 60 s exposure needs ~2 minutes in shade to clear.
- Feeding doubles heat while feeding (`FeedingController.sun_heat_multiplier`).
- Low sun is weaker, so dusk/dawn hunting is cheap - but the dawn deadline exists (HUD "Sunrise in m:ss").
- Extension: `SunlightExposure.set_heat_modifier(source, multiplier)`; curve in `SunlightProfile`. Nothing else knows the numbers.

## New systems and how they interact
- **Routines** (`NpcProfile.schedule`): Tomas patrols the yard 05:30-19:30, smokes at his door until 20:30, sleeps in the cottage.
  Elise is in the gatehouse by day, keeps a lantern watch outside 19:00-23:00, sleeps 23:00-05:00.
- **Sleepers**: heavy sleeper Tomas will not wake to a walking vampire; Elise (light sleeper) wakes to a sprint. Woken people are groggy.
- **Blood memories**: `calm` (unaware/lured), `asleep` (dream), `afraid` (grabbed while terrified). Tomas: calm -> *well key*,
  asleep -> *hidden ledger*, afraid -> nine footsteps. Elise: three different fragments about the cellar.
- **Noticing**: only what a person can *see* (front ~100 degrees + line of sight, within ~10 m, a little more for Elise at night) or, slowly,
  someone right behind them. Grabbing at awareness above 0.6 counts as "afraid".
- **Witnessing**: a transformation in view = terror. If they trust you they freeze for ~4 s (the lure window). Out of sight is safe.
- **Sense tiers**: far = pulse only; 11-20 m = "a heartbeat, N bpm"; <11 m = who (a stranger until met), mood; <7 m = the blood itself.
- **Embers**: daytime Sense draws smouldering tiles on the ground where the sun would burn you (11x11 grid, 0.6 s refresh).
- **Sun x feeding x time**: feed a sleeper at night for free; feed a worker at noon for heat; lure someone into shade; or wait for dusk.

## Human vs Vampire (what exists)
| | Human | Vampire |
|---|---|---|
| Sun | harmless | dangerous (3 min budget) |
| Night | nearly blind | sees well, free of the sun |
| People | trusted; chats build trust, info, followers | feared on sight; feeds |
| Senses | none | Sense (Q) |
| Speed/jump | 3.0/5.5, 6 | 4.2/9.0, 9 |
| Transforming | witnesses panic | (same) |
Intent: Human = social/day/information, Vampire = night/senses/feeding - two ways to interact, not weak vs strong.

## Tests
- `unit_tests` (68): clock, sun path, phases/transitions, profile sampling, sunlight curve/resistance/cooldown,
  registry, generated mod, example mod override/removal, blood definitions.
- `smoke_test` (71): the Task 1 acceptance loop, with routines frozen and the sun pinned. Changed/obsolete checks are listed in the CHANGELOG.
- `scenario_tests` (52): routines and live transitions, sleeper feed + dream memory + secret + flag, noise wake, trust/follow/stun,
  witnesses, Sense tiers, embers, night safety, HUD countdown, vision, coffin sleep.

## Performance (GTX 1660 SUPER, windowed)
~660 nodes, ~250 draw calls, 4.2 ms/frame (240 fps cap) in day, dusk and night, with Sense + embers on. Physics rays per frame: 3 for
sunlight (skipped at night/when immune) + a few per nearby NPC; embers ~240 rays every 0.6 s while Sense is on by day.

## Known issues
- Greybox: interiors have no true occlusion of ambient light, so "dark" is a global value plus lamps.
- At noon the sun is high (52 degrees), so shadows are short; refuges are mostly buildings. Morning and evening give long shadows.
- NPC movement has no navmesh: routes are straight lines with a "hop if stuck" fallback; fleeing can still corner someone.
- Sleepers/drained NPCs have collision disabled while in bed (you can walk through them).
- Godot prints a harmless "ObjectDB instances leaked at exit" warning after runs.
- Trust resets each night and secrets' "dug up" state resets on sleep (repeatability), while "discovered" persists.
- Sense embers are coarse tiles (2.4 m) and only near the player.
- Only two NPCs and one small area, so routines are easy to see but the world is empty.
- Mods are unsandboxed and there is no API stability (see MODDING.md).

## Design questions (need the designer)
1. **Day length / start**: 20 real minutes, start 14:00 - is dusk soon enough? Should the player pick the time they wake?
2. **Sleeping**: coffin always skips to dusk. Should you be able to sleep until *dawn* or pass time without sleeping?
3. **Noon vs dusk**: sun strength follows elevation, so evenings are cheap. Is that the tension you want, or should dusk still bite?
4. **Human at night**: nearly blind. Too punishing? Should humans carry a light/lantern?
5. **Feeding heat x2** and the 8 s harmless warning: keep, or make feeding in sun a bigger risk?
6. **Trust**: forgetful (resets nightly) or lasting relationships?
7. **Killing**: victims are always left alive. Should draining to death exist (and matter)?
8. **Memory conditions**: is it clear enough to the player that *how* you feed changes what you learn? Should the UI hint it?
9. **Lure**: after the shock, a fed follower is left unconscious; should witnesses remember you?
10. **Persistence**: should discoveries (revealed secrets, flags) survive sleeping? Currently revealed stays, looted resets.
11. **Dawn**: should the game force you toward the coffin at dawn (warnings only right now)?
12. **License** for a public repository intended for modders.

## Future ideas deliberately NOT implemented
Mesmerize/charm; hiding drained bodies; NPC gossip/reactions to a drained neighbour; moon phases (Elise's dream mentions a new moon);
weather/fog banks; animals with distinct heartbeats; vampire hunters at dawn; shade-carrying items or resistance blood; a blood archive;
NPC memories of *you*; doors and locks; footprints/scent trails; additive location patches for mods; an in-game mod list.

## Playtest questions (unchanged - answer before adding more)
1. Do I feel like a vampire? 2. Does becoming one change how I play? 3. Is transforming interesting?
4. Do I *want* to press Q? 5. Does feeding feel like something a vampire does? 6. ...or like refilling a bar?
7. Does sunlight create tension? 8. ...or is it annoying? 9. Do I experiment? 10. Do I think "what happens if I...?"
11. Do I want to explore *with* vampire senses? 12. Does the coffin feel like home?
13. What is boring? 14. What is annoying? 15. What is uniquely vampire?

New things worth trying: feed Tomas asleep, then calm, then terrified; talk three times and lead someone into the house's shade before
transforming; sprint past Elise while she sleeps; walk in the yard at 12:00 with Sense on; wait for dusk and see who is where; sleep and
compare the world; stay out until sunrise.
