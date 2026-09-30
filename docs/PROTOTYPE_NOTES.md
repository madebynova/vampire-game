# Vampire prototype - design notes (Task 1 + Task 1.5 + Task 1.75)

North-star question: **"Is being this vampire actually fun - does it feel like you became one?"** Task 1
proved the systems work. Task 1.5 tried to make them create *decisions*. Task 1.75 is about **feel**: the
moments between the systems (changing, feeding, remembering, perceiving, moving) and the screen they happen on.

## Run it / test it
See the README. Quick reference (replace `godot` with the 4.8 binary):

| Command | What |
|---|---|
| `godot --headless --path . res://tests/unit_tests.tscn` | 234 logic checks (clock, blood tuning, input map, content, traversal paths, settings) |
| `godot --headless --path . res://tests/smoke_test.tscn` | 72-check Task 1 playthrough |
| `godot --headless --path . res://tests/scenario_tests.tscn` | 52-check Task 1.5 scenarios |
| `godot --headless --path . res://tests/feel_tests.tscn` | 238-check Task 1.75 feel suite (real key / pad / held-button input) |
| `godot --path . res://tests/playtest_driver.tscn -- <dir>` | scripted walk through the playtest sequence with screenshots |
| `godot --path . res://tests/world_probe.tscn -- <dir> day|night|routes|title` | layout views |
| `godot --headless --path . res://tests/soak_probe.tscn` | fast-forward soak: wanders, transforms, senses, feeds for ~5 minutes at 8x |
| `godot --headless --path . res://tests/sun_map.tscn -- 12` | ASCII shade map at 12:00 (hour arg optional) |
| `godot --path . res://tests/time_probe.tscn -- <dir> 6,12,18,22` | screenshots of the yard by hour, Human vs Vampire |
| `godot --path . res://tests/perf_probe.tscn` | frame time / draw calls in day, dusk, night, Sense on |

## Task 1.75 - vampire feel & immersion

### Baseline (recorded before any change)
Godot 4.8-dev6. `unit_tests` 68/68, `smoke_test` 71/71, `scenario_tests` 52/52, all passing; the only engine
message is the known harmless "ObjectDB instances leaked at exit" warning. The repository had an uncommitted
`project.godot` that showed as modified but whose diff was empty (stat/line-ending only).

### Discrepancies between the docs and the code (found and logged before changing architecture)
1. The README, the in-game help and these notes described **keyboard controls only**; the code already
   bound a pad (LB = Sense, X = interact, Y = transform, A = jump) and **L3 as a held sprint** - awkward to hold
   while steering. Undocumented and never tested.
2. Human blood **did not drain at all** (`blood_drain_per_sec = 0`), and Sense cost **1.4/s** on top of a 0.35/s
   vampire drain (about 31 s of Sense from the starting 55 blood).
3. The memory panel said "[E] dismiss" but it also **auto-dismissed after 24 s**, could be dismissed by the next
   E press one second in, and the E key a player is still holding from the feed is exactly the input that
   would close it. The text reveal (<= 5 s) and the auto-dismiss were unrelated timers.
4. `Esc` freed the mouse (there was no pause); `ui_cancel` was the only menu-ish action.
5. Human and Vampire looked different in the HUD only by the colour of one word.
6. Godot's built-in `ui_accept` had **no gamepad binding in this engine build** - found by a test in this pass,
   it would have made every menu un-confirmable with a pad (fixed in `InputSetup`).

### Feedback -> response
| Playtest feedback | Response |
|---|---|
| "Transforming is boring" | `TransformPresentation`: separate wind-up and release for each direction - FOV tightens, red-black tunnel, body rises and arches, hit-stop at the swap, FOV slam, shockwave ring, chromatic tear, leather wings, the night opens (vampire audio depth); the reverse is warm and quiet. About 1.25 s, control returns on time. |
| "Feeding is a chore" | Feeding is *styled by the victim's state* (`FeedStyle` data) and leaves a **Bloodrush**; memories, blood type and witnesses make each one different; Sense hints that a memory is still unheard. |
| "Blood Memory is a popup that vanishes" | `MemoryView`: the world freezes, drains into the memory's colour, a sound bed plays, the text is told with breaths at punctuation, **no timeout**, deliberate dismissal only, the held feed key cannot close it. |
| "Human blood stops completely" | Human 0.02/s, Vampire 0.16/s (was 0.35/s). |
| "Sense drains too fast" | 0.55/s + 2 up front (was 1.4/s), free during a Bloodrush, cost shown in words on the HUD. |
| "HUD is plain" | `BloodGauge` vessel, serif 12-hour clock with a sun/moon glyph, glyph prompts, contextual hints, designed controls screen. |
| "Needs a pause menu, controller support" | Pause menu + title; InputMap actions for everything; Xbox-first, PlayStation labels; sparing vibration. |
| "Too many trees, bad lamps, pointless objects" | 16 trees -> 9 at the edges, lamps along the road and paths, boulder and garden wall removed, a gate, a hut, paths, a bench, a woodpile. |
| "Want windows, ledges, roofs" | Six data-driven routes: 3 windows (mist), 3 climbs (manor roof, ruined wall, cottage roof). |
| "12-hour clock" | `TimeOfDay.format_12h()`; display only. |

### Values tuned
| Value | Before | After | Reasoning |
|---|---|---|---|
| Human blood drain | 0 | **0.02/s** | 100 s costs 2 blood: a background fact, not a chore. |
| Vampire blood drain | 0.35/s | **0.16/s** | A full vessel lasts ~10 minutes at rest - about one night. With Sense in use, feeding about twice a night. |
| Sense cost | 1.4/s | **0.55/s + 2.0 on activation** | ~77 s of Sense from the starting 55 (was ~31 s); toggling is not free; free for ~50 s after a feed. |
| Hunger slowdown | any drain | only `FormData.hunger_slows` (Vampire) | A Human at low blood is not slowed. |
| Transformation | 1.1 s, swap at 50% | **1.25 s, swap at 45%** | Room for a wind-up before, a release after. |
| Feeding yield | 1.0 / x1.25 afraid | 1.0 calm & asleep, **1.25 afraid, 1.1 trusting** | Unchanged numbers; trusting is new. |
| Bloodrush | - | calm 1.0 x 50 s; asleep 0.8 x 75 s; afraid 1.35 x 32 s; trusting 1.0 x 60 s; +16% speed, +10% jump, -15% sun heat, free Sense, 2x free healing per 1.0 power; iron blood x1.2 duration | "Power, information, risk, satisfaction". |
| Scream / witnesses | - | afraid: heard within 17 m, seen within 16 m; calm 12 m; trusting 10 m; asleep 6 m | Only the terrified are loud. |
| Blood Memory | auto-dismiss at 24 s, dismiss after 1 s | intro 2.4 s, 34 chars/s with breaths, 1.2 s hold, **no timeout** | Tested with real held keys. |
| Sunlight, day/night, noon | - | **untouched** | About three minutes of full noon sun, 20-minute day, the night as it was. (The Bloodrush's 15% heat relief uses the existing `set_heat_modifier` hook.) |
| Map | 16 trees, 7 lamps, south wall z=34 | **9 trees, 8 lamps, south wall z=30** | Smaller and more purposeful. |

### How it works now
**Transformation** (`TransformPresentation`, a player component). Presentation only; `FormController` still owns
the sequence. Stage 1 (`transform_started`): camera FOV / distance tween, body pose, eye flicker (human) or
rising tunnel and chromatic aberration (vampire), ambience low-pass, NPCs within 10 m feel it (`feel_transformation`:
they stop, glance over and show "?"). Stage 2 (`form_changed`): the swap effects - kick, shockwave (a shader quad),
light flash, particles, hit-stop (`Engine.time_scale` dip with a guaranteed restore), vision change. The Vampire also
gets an ambience reverb ("heightened hearing") and a persistent cold rim on the screen edge.

**Blood and Bloodrush.** `BloodPool` computes `pulse_rate()` (used by the gauge, the screen-edge pulse, feeding
heartbeat and audio). `BloodSurge` (a component) applies a Bloodrush only through existing hooks
(`speed_modifiers`, `Ability.cost_modifiers`, `SunlightExposure.set_heat_modifier`, `Health` regen).

**Feeding.** `FeedStyle` resources (`content/feeding/`) for `calm`, `asleep`, `afraid`, `trusting` hold everything
that differs: yield, Bloodrush, noise, witnesses, camera shake, feed volume/pitch, vibration, taste, the Sense
hint and the memory's look. `HumanNpc.feed_style_id()` chooses; `perceive_vampiric_act()` is how others react.
`HumanNpc.tasted` remembers which memories you have heard (persists across nights) so Sense can say "a dream
waits" only for what is still unheard.

**Blood Memory** (`MemoryView`, a canvas layer that keeps running while the tree is paused via `PauseControl`).
Dismissal is polled: the dismiss actions must be seen *released* after it opens before any press counts; a press
during the telling completes the text, a further press (after a short lock and a 1.2 s hold) closes it. `HUD`
steps aside, sound is muffled, the memory's bed plays on the Music bus.

**Vampiric Sense.** `SenseTarget` splits its readout (name, pulse and mood, blood, gold hint) and scales it by
attention; the overlay shader knows strangers (flicker) from acquaintances (steady); the scan wave flares targets it
passes; nearby hearts beat through `Haptics`. `VampiricSense` picks the focus (nearest, most in front).

**Traversal.** `TraversalPlacement` (data in `LocationData.traversals`) -> `TraversalLink` (prompts at both ends,
Sense presence) -> `TraversalController` (authored path, mist for windows, scramble for climbs, exit clearance check
with nudges and a return-to-start fallback). `FormData.traversal` decides who may use what. Nothing in `Player.gd`.

**Input.** `InputSetup` registers every action with keyboard, pad and `device = -1` (any pad); tracks the
last-used device; maps pad names to a label family; guarantees pad bindings on the `ui_*` actions. `InputGlyph`
draws keycaps / coloured buttons / PlayStation symbols. `Interactable.get_action()` lets feeding use `feed` while
talking uses `interact`.

**Pause.** `PauseControl` (autoload) holds freeze *reasons* (menu, memory), so one closing never unpauses the
other. While frozen NPCs, the clock, sunlight, blood and abilities do not advance and no gameplay input reaches the
game (tested). `Main` also opens the menu when the window loses focus.

**World.** `WorldBuilder` now records `walkways` and `tree_positions` so layout rules are testable: no tree on or
beside a path or against a building, every lamp beside a path, road lamps 8-9 m apart.

### Test changes (and why)
| Test | Change | Why |
|---|---|---|
| smoke / scenario: feeding | hold `feed` instead of `interact` | Feeding is its own action now (rebindable). |
| smoke / scenario: memory | wait for `MemoryView`, dismiss it with a real press, then continue; `hud._memory_*` -> `memory_view` | The memory is a full-screen, dismiss-on-purpose experience that freezes the world. "Control returns after feeding" became "...after the memory is dismissed". |
| smoke: "Tomas fled" step | reset Tomas at his post and start the run at x=3 | The longer transform and the frozen world changed where Tomas stood after the earlier scare, and the straight line from x=4.5 met the new lamp post. Both are test-geometry, not behaviour. |
| smoke: sun death step | end any Bloodrush first (`player.surge.stop`) | The feeds before it leave a Bloodrush (sun heat x0.85); the step measures the unmodified three-minute baseline (it took 202 s with the Bloodrush still active - a deliberate, small advantage, recorded as a design question). The smoke suite also gained one check, "control is held while the memory plays" (72, was 71). |
| scenario: HUD clock | read `clock_summary()` | The clock is a designed widget; the test still checks "Sunrise in" and "Night". |
| smoke / scenario: coffin | wait 6 s / 6.5 s (was 4.5 / 5) | The coffin now plays a lid animation before the fade. |
| unit | 68 -> 234 checks | Pure logic for this task (clock, blood tuning, input map, content, traversal paths, settings, blood-vessel polygons). Nothing removed. |

### What remains intentionally unfinished
No music, no voiced or visual memories (text over a tinted frozen world), no free climbing or parkour, no rebinding
UI, no resolution / quality options, no save games, NPC pathing still straight lines, no consequences for being
witnessed beyond people running, Wolf/Bat/combat/quests untouched.

### Known issues
- Controllers and vibration are untested on hardware (see README). PS5 labels are unverified beyond the name match.
- The transformation hit-stop changes `Engine.time_scale` for ~0.13 s; it is restored even if a menu opens, but
  anything else that sets `time_scale` at that moment would be overwritten.
- Headless runs cannot compile shaders or draw, so shader typos only show in windowed runs (the windowed
  `playtest_driver` exercises every shader).
- `SystemFont` picks Georgia / Palatino / Cambria where installed; on other systems the serif falls back to the default UI font.
- A sprinting vampire that hits a lamp post head-on stops dead rather than sliding (physics; thin posts).
- Tomas's patrol passes near the well; if a lamp sits on his line he hops (`_unstick`). The well lamp was moved off it.
- Godot still prints the harmless "ObjectDB instances leaked at exit" warning after runs.

### Manual playtest observations
**What was and was not done.** I ran the game windowed, with the real renderer and real (injected) key and pad
events, through the brief's 20-step sequence using `tests/playtest_driver.gd`, looked at about 40 screenshots of
it, walked the map with `world_probe` (day / night / routes / title), fast-forwarded two in-game days with
`soak_probe`, and ran `perf_probe`. I did **not** play for 20 minutes by hand, did **not** hold a controller (the
GameSir G7 SE and a PS5 pad were not available), and **cannot hear** the procedural audio or feel the vibration
- those are checked only as "the code asks for them" (tests count `Haptics` pulses and `Sfx` loops). Treat
everything below as "reads right in stills and numbers", not "feels right in the hands".

**Things looking at it changed** (none of these were caught by the automated checks):
1. The controls screen was huge and ran off the screen edges and over the clock. It is now compact on the HUD (only the
   column for the device you are using) and two-column in the menus; both fit.
2. The pause menu ghosted the HUD's own controls behind its own. The HUD is now hidden while paused.
3. The Options panel was clipped at the right edge (slider widths); fixed.
4. Vampiric Sense labels stacked upside-down (mood above the name) - fixed. Route markers were all sitting at the world
   origin (so only visible when near it) - there is now one Sense presence per route end.
5. A Blood Memory in a dark night scene was nearly black. The shader now lifts shadows before tinting, so the room and the
   victim stay readable in calm (sepia), asleep (blue) and afraid (torn red).
6. The blood vessel's liquid polygon failed to triangulate at some levels (near empty / full) - found by the two-day soak, not
   the suites. Fixed and covered by a level sweep in `unit_tests`.
7. The clock read "Day - Day 1"; it now reads "Daylight - Day 1".

**Against the brief's questions** (stills and numbers only):
- *Transformation - does it feel like becoming a vampire?* The frames read as a sequence: arms flung wide and dark mist, a
  chromatic tear at the edges, nearby people reacting ("!", "Something's wrong with you!"), a red flash, then a bigger
  crimson vessel with fangs and the cold rim. The hit-stop, the FOV slam and the audio low-pass cannot be judged from stills.
- *Sense - supernatural?* Strangers are pale, hollow and flicker; people you know are steady in their blood's colour; scan
  waves make them flare; the readout is name, pulse and mood, then blood, then a gold hint. Legible at the distances tested.
- *Feeding - do I want to?* The pieces are there (red tunnel, "+N" rising from the vessel, a rush, free Sense for about a
  minute, a memory, a risk of being seen). Whether that adds up to *wanting* it is the question for the next playtest.
- *Blood Memory - someone else's memory?* The world freezes, drains into the memory's colour and is readable; the telling,
  the bed and the heartbeat are on; audio unverified by ear.
- *Traversal - more open?* The roof view from the manor with "Drop down to the yard" on screen, Sense markers labelled
  Window / Ledge / Roof. The mist slip itself is a moving body that is hidden mid-way, so stills show it poorly.
- *Night intact?* Same sky, stars, moon and lamp look as before (screenshots at 23:00); the south road has more lamps now.
- *A place rather than a test map?* From the gate the road, the alternating lamps, the paths and the buildings read as a
  place. The estate is still small and its middle is open.
- *UI part of the game?* Serif type, a blood vessel and keycap / button glyphs read as one visual language.

**Performance:** `perf_probe`, GTX 1660 SUPER, windowed: about 4.2 ms per frame (the 240 fps cap) in the yard by day, with
~1100 nodes and ~400 draw calls (was ~660 / ~250): the extra nodes are UI, the Sense labels and the new buildings.
**Soak** (`soak_probe`, 8x time): two full in-game days of wandering, transformations, Sense and interacting found the blood-vessel bug above; a 300-second run with feeding (about 1.3 days, one feed and one memory, no deaths) and the fixed build logged no errors. It is a smoke screen for runtime errors, not a balance test.

### Design questions raised by this pass
1. How much blood should a Vampire use in a night? (0.16/s rest = ~10 minutes per vessel; Sense on top.)
2. Should feeding restore immediately, or over the whole feed as now (~3.6 s)?
3. How long should Bloodrush last (32-75 s today) and should it stack?
4. Should some blood give different senses (iron = vigilance, etc.)? The hook is `BloodDefinition` + `FeedStyle`.
5. How dangerous should being *witnessed* be? Today witnesses run; there is no reputation or pursuit.
6. Should transformation need a blood threshold?
7. How much traversal should a vampire have, and should roofs become a whole layer? (A wall-top to cottage-roof jump already works by plain physics.)
8. How should NPCs react to *seeing* traversal? Today anyone who sees a window slip or a climb is frightened, like a transformation.
9. Should Blood Memories eventually be fully visual? What would a mod author provide?
10. Should blood information (what you learned, names) persist beyond Sense? (Names and "memory heard" already do.)
11. How much UI should stay visible during exploration? Is the vessel alone enough?
12. Is "Sense is free after a feed" too generous - does it make a feed-then-sense loop the only way to play?
13. Should the world keep moving during a Blood Memory (tension) rather than freezing (fairness)?
14. Does the 15% sun relief from a Bloodrush blur the "three minutes" promise, or is it the reason to feed before dawn?
15. Should a Human at very low blood suffer something, or is hunger a vampire-only problem?
16. Should the title screen be the default launch for development, or should F5 go straight to the game?
17. Is latching run with a stick click (and releasing on stop) the right pad default, or should run be a pure hold?

---

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
- **Sense tiers** (1.75 adds a gold hint when a memory is unheard; the tiers are unchanged): far = pulse only; 11-20 m = "a heartbeat, N bpm"; <11 m = who (a stranger until met), mood; <7 m = the blood itself.
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
| Transforming | witnesses panic | (same; 1.75: each direction has its own presentation) |
Intent: Human = social/day/information, Vampire = night/senses/feeding - two ways to interact, not weak vs strong.
(Task 1.75: a Human now spends blood very slowly (0.02/s) instead of none, and only the Vampire has traversal, hunger slowdown, Bloodrush and the vampire audio/screen presence.)

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
- Only three NPCs and one small area, so routines are easy to see but the world is small (Task 1.75 added the night watchman).
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
