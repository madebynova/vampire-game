# Vampire prototype - design notes (Task 1 + Task 1.5 + Task 1.75 + Task 1.8 + v0.2.0 The Hunt)

North-star question: **"Is being this vampire actually fun - does it feel like you became one?"** Task 1
proved the systems work. Task 1.5 tried to make them create *decisions*. Task 1.75 is about **feel**: the
moments between the systems (changing, feeding, remembering, perceiving, moving) and the screen they happen on.

## Run it / test it
See the README. Quick reference (replace `godot` with the 4.8 binary):

| Command | What |
|---|---|
| `godot --headless --path . res://tests/unit_tests.tscn` | 288 logic checks (clock, blood tuning, input map, content, traversal paths **and rules**, steering, the cape, new content, settings) |
| `godot --headless --path . res://tests/smoke_test.tscn` | 72-check Task 1 playthrough |
| `godot --headless --path . res://tests/scenario_tests.tscn` | 52-check Task 1.5 scenarios |
| `godot --headless --path . res://tests/feel_tests.tscn` | 242-check Task 1.75 feel suite (real key / pad / held-button input) |
| `godot --headless --path . res://tests/hunt_tests.tscn` | 242-check v0.2.0 suite: the hunter, Rend, escapes, the objective, the HUD readouts, the old systems around them (`-- only=...`) |
| `godot --path . res://tests/hunt_playthrough.tscn -- <dir>` | the whole hunt played with real key events by a script, 33 checks, 17 screenshots |
| `godot --path . res://tests/hunt_playtest.tscn -- <dir>` | scripted windowed photographs of the camp, the hunter, Sense, the ambush, the tell, the roof, the drink, the menus |
| `godot --headless --path . res://tests/hunt_balance.tscn` | three simple 'players' fight the hunter and print how it went |
| `godot --headless --path . res://tests/polish_tests.tscn` | 186-check Task 1.8 suite (traversal rules, blood number and rewards, movement, cape, fox, tidings, coffin, memories and clues; `-- only=...`) |
| `godot --path . res://tests/polish_playtest.tscn -- <dir>` | scripted windowed walk through the Task 1.8 features with ~30 screenshots (`only=fox,...`) |
| `godot --path . res://tests/model_probe.tscn -- <dir>` | the vampire model posed (idle, walk, run, jump, transformation, climb, feed) from the side and behind |
| `godot --path . res://tests/playtest_driver.tscn -- <dir>` | scripted walk through the playtest sequence with screenshots |
| `godot --path . res://tests/world_probe.tscn -- <dir> day|night|routes|title` | layout views |
| `godot --headless --path . res://tests/soak_probe.tscn` | fast-forward soak: wanders, transforms, senses, feeds for ~5 minutes at 8x |
| `godot --headless --path . res://tests/sun_map.tscn -- 12` | ASCII shade map at 12:00 (hour arg optional) |
| `godot --path . res://tests/time_probe.tscn -- <dir> 6,12,18,22` | screenshots of the yard by hour, Human vs Vampire |
| `godot --path . res://tests/perf_probe.tscn` | frame time / draw calls in day, dusk, night, Sense on |

## v0.2.0 - THE HUNT

The Task 1.8 prototype had a strong vampire and nothing to point it at: people, a small world, and no loop that made you think
*"I know what I want to do next"*. v0.2.0 gives the existing systems one thing to push against, and builds the smallest version of
this loop (every arrow is something you do with a system that already existed):

```
find the threat -> Sense -> stalk -> choose how to engage -> use the vampire's moves + traversal -> deal with it -> feed / recover -> carry on
```

Not added, on purpose: an inventory, crafting, skill trees, a quest system, a second enemy type, other forms, a bigger map, saves.

### Baseline (recorded before any change)
Godot 4.8-dev6. `unit_tests` 288/288, `smoke_test` 72/72, `scenario_tests` 52/52, `polish_tests` 186/186, `feel_tests` 242/242 -
**840 checks, 0 failures**. (Run in a *copy* of the repository, so work could go on while they ran; the same trick was used for every later full run.)

### What was built

**1. A reason to hunt - the objective** (`HuntDirector`, `HuntDefinition`, `HuntClue`). There is no quest log and no stored progress.
One quiet line sits under the corner of the screen ("A lantern walks Blackthorn after dark. Find out who carries it.") and changes as the world
changes: rumour -> sighted -> engaged -> wary -> down -> done (or *withdrawn*, if he has gone with the dawn). Which line shows is **worked out
from the hunter's state** each quarter second, so it can never disagree with the world. Six *leads* are things the world already held, and the
hunt just notices them: the three old clues (wax under the north window, the scratched gate lock, the watch log), what Elise says about a lantern
behind the manor, and two new things to read at the hunter's camp. The line shows the latest ("Learned: ...") and "N of 6 leads".
A new HUD toast says where when he comes out for the night ("A lantern kindles in the pines behind the manor").

**2. One threat - the Lamplighter, Hollis Crane** (`Hunter`, `HunterProfile`, `HunterPlacement`). A wide-brimmed hat, a long coat, a lantern in his
left hand and a silvered blade in the right (primitives, like everyone else; `HunterGear`). Everything numeric is data. He:
- keeps a **camp** in the pines behind the manor (bedroll, crate, stakes, a hung lantern, two things to read; empty by day) and appears there at 7 PM;
- walks a **round** of 16 points, lingering at some (the wax under the north window, the graveyard, the manor door, the well, the cottage), finding his
  own way between them over a waypoint graph (`HuntNav`) that is linked automatically wherever a body can walk in a straight line - so he uses doorways and **cannot use a window or a roof**;
- **perceives** you by a sight cone (58 degrees, 15 m, cut to 55% in the dark and restored by lamplight or his own lantern - `WorldLight`), by hearing (1.5 m if you
  stand still, 4.5 m walking, 9.5 m running) and by feeling someone right behind him; awareness builds (a "?" and an amber bar), a stranger at his back is noticed late
  or never, and a **Human is nothing to him** (only a vampire is hunted);
- **hunts**: suspicious (turns, investigates), hunting (runs you down, 5.4 m/s against your 9), **searches** where he last saw you and goes back to his round, warier for 75 s;
- **swings** a telegraphed blade: the blade goes up and the lantern flares for 0.55 s (tracking you for the first 60%, then committed), the blow lands only if you are still in reach,
  26 damage, throws you back about a metre and staggers you for 0.3 s; you are then safe for 0.7 s; he needs 1.5 s between swings;
- is **hurt**: 120 health; a plain Rend does not break a swing he has started (so trading blows is dangerous), a lunge / plunge / ambush does; 0 health puts him **down**, alive and helpless;
- **withdraws at dawn** (5:00 if idle, 5:45 whatever he is doing), and mends 60% of his wounds when you sleep.

**3. One attack - Rend** (`PlayerCombat`, key **R**, left mouse button, or **RB / R1**; Vampire only). A 0.56 s swing (0.11 s draw, 0.09 s strike, 0.36 s recovery), 20 damage,
costs 1 blood and gives 2.5 back when it lands. Where it lands decides how it lands:

| Strike | When | Damage (of his 120) |
|---|---|---|
| Rend | any | 20 |
| Pounce (lunge) | struck at a run; carries you forward | 25 |
| Plunge | struck while falling (off a roof) | 30 |
| Ambush | he did not know you were there (on any of the above) | x3: 60 / 75 / 90 |

Hunger weakens it (hungry x0.8, starving x0.6) and a Bloodrush strengthens it (+25% at full power, now said in the rush's own description). Soft aim turns you toward the nearest
thing in front of the camera. One press in the last 0.2 s of a swing is remembered, so it never feels ignored, but it cannot be spammed. Hits have a freeze-frame, a FOV kick, camera shake,
vibration, claw marks, a spray of blood, a floating number ("-60 AMBUSH") and a hit-marker; being hit has a thump, a red arc at the screen edge **pointing at who hit you**, a shove and a stagger.

**4. The old systems, made to matter**

| System | What it does in the hunt |
|---|---|
| Vampiric Sense | finds him through walls from 22 m (hunters mask their scent with lavender: Sense reaches 28 m for everyone else); says whether he **has noticed you** ("unaware of you" / "suspicious" / "hunting you"), shows his pulse (56 bpm calm, ~95 hunting) and the silhouette going pale gold -> amber -> hot red, and tells you when **his back is to you** |
| Traversal | a **roof** is out of his reach (he stands at the foot of the wall, cannot strike, and gives up after 9 s); a **window** is not a door (he goes round - the test measures 11.5 m for a 2.8 m hop) and the vampire is **mist** while slipping through (nothing can hurt it); falling off a roof onto him is a plunge |
| Darkness | the dark halves his eyes; lamps, the hall and his own lantern give you away; the crickets go quiet when he is near |
| Transformation | turn **Human** in front of him and, after about two seconds, he is not sure what he saw and searches (at the price of the 1.25 s change, and of being nearly blind at night) |
| Feeding | a person is worth 35-52 blood, a fox 26, **a downed hunter 62** with the longest, strongest rush (*Hunter's Rush*, x1.45 for 65 s) and a memory of his own; hunger makes you weaker in a fight, a blow tears you off a victim mid-feed, and a hurt vampire mends at 4 hp/s **for 0.5 blood per hp** (free in a Bloodrush) |
| Blood Memory | the hunter's blood tells why he is here ("The Lamp Is Lit": an order sealed the gate from outside and sent him first; eight more lanterns wait); it agrees with the wax, the lock, the log and the lantern Elise sees |
| Sunlight / day-night | he is about only from dusk to dawn, so the sky still ends every fight; nothing about the sun, the clock or the coffin changed |
| Coffin | rest or death sends you home as before; he mends (60% after a rest, 25% after he killed you) and is wary |

**5. Consequences, lightly.** Getting hurt matters (the vessel's ring, a **WOUNDED 74** line, the edges of the screen stay red below 45% health; mending costs blood). Dying to him
(*THE HUNTER GOT YOU*) sends you to the coffin as the sun does - he keeps his wounds (he mends a quarter), is wary for 110 s and remembers. A fight is loud: awake people within 15 m
grow uneasy, sleepers stir, anyone who can see it runs. **Leaving him alive costs you**: he comes back at the next dusk. Drinking him ends the hunt for good.

**Readouts, in the game's own visual language.** The centre dot gains a thin ring that fills during a swing and flashes when Rend is ready (only when there is something to fight);
four ticks when a blow lands (gold for an ambush / plunge); one word - "R  Ambush" - when an unaware hunter is within reach. Over his head, at a constant size on screen: a "?" or "!", a
health bar (only when he is hurt or hunting), a thin amber awareness bar (only while he suspects you), his few words and the numbers coming off him. The camera slides over your right shoulder
for the length of a fight so he is not hidden behind your own back. No panel, no menu.

### Numbers
| Value | Number | Why |
|---|---|---|
| Hunter health / damage / tell / recovery / gap | 120 / 26 / 0.55 s / 0.5 s / 0.45 s | four blows kill a full vampire, the tell is longer than a human reaction + a sprint out of his 2.45 m reach |
| Rend damage / cost / taste | 20 / 1 / +2.5 | about six clean hits; a swing that lands pays for itself |
| Sight / dark factor / hearing | 15 m / 55% / 1.5, 4.5, 9.5 m | a walker can reach his back; a runner from the dark still can (the pounce); lamplight undoes you |
| Notice rate | 0.35 /s at the edge of sight to 2.2 /s point-blank; 0.9 /s by sound | ~0.5 s point-blank, ~3 s at the edge |
| Knock-back / stagger / grace | 9 m/s (~1 m) / 0.3 s / 0.7 s | a hit is felt, a stunlock is impossible |
| Hours | out 7 PM, retire 5 AM (dawn 5:45) | a night is ~8 real minutes |
| Hunter's blood | 62 blood, rush x1.45 for 65 s | the richest drink in the estate, because you earned it |
| Sunlight, day length, blood drain, Sense cost | unchanged | `unit_tests` still pin them |

**A bot's view of the balance** (`tests/hunt_balance.gd`; the hunter's AI, Rend, damage and knock-back are the real ones, the human is a script): mashing Rend in front of him wins in 4.0 s and
costs ~63 health (three blows taken); hitting, then backing out of reach as the blade rises and coming in on his recovery wins in ~10 s for no damage; an ambush from behind then the same finishes
in 3.7 s for no damage. That is *dangerous if you brawl, easy if you play the game*. It says nothing about reaction times, nerves or a controller.

### Architecture (small and local)
- **Data**: `HunterProfile`, `HunterPlacement` (a camp and a round), `HuntDefinition`, `HuntClue`; `LocationData.hunters` + `LocationData.nav_points`; `FormData.strike_damage`; a `hunter` `FeedStyle` and `BloodDefinition`.
- **Rules as arithmetic**: `CombatRules` (strike damage, reach, hearing, sight, noticing) and `HitInfo` - no nodes, unit-testable.
- **Player**: `PlayerCombat` (a component like the others), a new `PlayerState.Mode.STAGGERED`, `Player.push()` (a shove that does not fight the stick), `FeedingController.break_off()`, `CameraRig.shoulder`, `HumanoidModel` hand slots / `arm_pose` / `strike_pose`.
- **World**: `Hunter` (`extends FeedSource`, so feeding needed no special case), `HunterGear`, `HuntNav`, `WorldLight`, `HuntDirector`; the camp is built by `WorldBuilder`.
- **UI**: `CombatHud` (ring, hit-marks, hurt arcs, the one-word hint), the objective block in `Hud`, a wound vignette in `ScreenFX`.
- **Audio**: eleven procedural sounds in `SfxSynth` (a boot, a lantern, a hum, a stab, a drawn blade, a swing, a grunt, a fall, claws, flesh, a blow taken).
- **Nothing in the old systems was rewritten.** Edits to existing files are additions (a new mode, a new action, a new row in the controls screen, a new hook in the coffin, `perceive_vampiric_act` reused for fight noise).
  Hunters follow `Hunter.enabled` / `HumanNpc.schedules_enabled` (the flag older suites already use to freeze routines), so **no existing check was edited**.

### How to run what is new
| Command | What |
|---|---|
| `godot --headless --path . res://tests/hunt_tests.tscn` | the v0.2.0 suite (242 checks, ~2.5 min); `-- only=rules,data,nav,strike,senses,combat,escape,down,objective,hours,consequence,hud,regress` |
| `godot --path . res://tests/hunt_playthrough.tscn -- <dir>` | **the whole loop played with real key events** by a script (33 checks, ~70 s) with 17 screenshots |
| `godot --path . res://tests/hunt_playtest.tscn -- <dir>` | the camera crew: the camp, the hunter from four sides, Sense, the ambush, the tell, the roof, the drink, the menus (`only=camp,model,...`) |
| `godot --headless --path . res://tests/hunt_balance.tscn` | the three-policy fight above |

### What the new suite checks
**rules** (damage, hunger, reach, senses as pure arithmetic), **data** (everything is content; the new input action on a key, the mouse and a bumper; eleven sounds), **nav** (the graph links, every waypoint is standable,
his whole round is walkable, a window is not a door, a roof is unreachable), **strike** (cost, cooldown, buffer, ambush / lunge / plunge, hunger, Bloodrush, reach, cone, walls, down), **senses** (cone, light, dark, behind,
walking vs running, Human, walls, mist, what Sense says), **combat** (tell before damage, stagger, knock-back, grace, dodge, the opening after a miss, interrupts, swing spacing, mist, torn off a victim, dying to him), **escape**
(roof, window, losing him, turning human), **down** (prompt, worth, early release, drinking, memory, rush, left alive), **objective** (every stage and every lead), **hours**, **consequence**, **hud**, **regress** (Sense, feeding, change, coffin).

### Playtest notes
**What was and was not done.** Besides the suites, I ran the game windowed in the real renderer and photographed it (`hunt_playtest`, 27 shots) and had a script play the loop start to finish with real key events and the real AI
(`hunt_playthrough`: wake, a clue by day, become a vampire, Sense, find him, shadow him, ambush, take a blow, run for the wall and climb, wait on the roof, drop on him, finish him, drink, the hunt is over, talk to Tomas, sleep). I
**did not play by hand**, **did not hold a controller**, and **cannot hear** the procedural audio (I checked only that every new sound exists and has sensible levels). The balance figures come from a bot. Everything here is "reads right in stills and in numbers", not "feels right in the hands".

**Things looking at it changed** (none were caught by the automated checks):
1. In melee the third-person camera put **your own back in front of him**, hiding the very blade you must dodge. The camera now slides over your right shoulder for the length of a fight.
2. The first version of the floating readout was a metre-wide bar: it filled the screen at 2 m and was a speck at 25 m. It is now a constant size on screen, like Sense's labels.
3. A knock-back of 6 m/s moved you 0.47 m, which is a flinch, not a blow: 9 m/s.
4. With the player on a roof edge the hunter walked *into the building* to stand under them; he now goes to the farthest point he can walk to toward you - the foot of the wall.
5. The Bloodrush's description did not say it makes Rend hit harder (and the number it gave was invisible): added to the rush's own text, without touching the existing description that a test pins.
6. Three sounds (the drawn blade, the grunt, the "hm?") were quiet next to the rest; raised. The windup is the thing you listen for.

### Known issues / limits
- Not hand-played, no controller, no ears (above). Balance is from a bot. Tell timing is the number most worth feeling.
- One hunter. His memory promises eight more lanterns; nothing follows them yet. After you drink him the estate is as empty as it was in 1.8.
- Inside rooms he steers in a straight line: furniture can snag him (he hops after about three seconds, as the villagers do).
- When he loses you he searches the last place he saw you and no more (no scent, no tracks).
- A plain Rend does not interrupt a swing he has begun. That is the design (trade blows and he hits you too), but it may feel unresponsive; the cure is the pounce / ambush / plunge.
- The shoulder camera is right-shoulder only and, in the narrow strip behind the manor, the spring arm can still be squeezed by the wall.
- Slipping out of a window buys 2-3 seconds, not a getaway; a roof is the real escape and he gives up there after 9 s.
- Villagers do not react to the hunter, and the hunter ignores villagers.

### Design questions raised by this pass
1. Is 26 damage / 120 health / a 0.55 s tell right? (Mash costs ~63 hp; a hungry brawler dies.)
2. Should a downed hunter be *finished* with Rend as well as drunk? Today the only ways to end him are the drink (he dies) or leaving him (he returns).
3. Should he come back stronger - or should the Order send the next lantern (the memory says eight)?
4. Should turning Human work as a disguise at all, or only before he has seen the change?
5. Should Rend cost blood on a miss only? (Today: 1 per swing, +2.5 when it lands.)
6. Should the villagers fear the lamplighter (and the hunter hunt them)? Should Tomas / Elise / Corvin talk about him once you have met him?
7. Should the objective also live somewhere you can re-read it (the pause menu, a journal)?
8. Is the shoulder camera right for a pad, or should it follow the target?
9. Is "R / left click" the right keyboard binding, given the same click re-captures the mouse after alt-tab?

---

## Task 1.8 - vampire world & traversal polish

The Task 1.75 playtest said: the transformation, Sense, feeding, the camera and the pad buttons are loved; the strongest
vampire moments are slipping through a window "as a bat" and becoming a vampire; the people exist only to be Sensed; the
village looks nice but there is little to *do*; traversal is great **except** that it climbs through floors, sends you
out of a window when you meant in, drops you into rooms from roofs and vaults you through windows from roofs; movement is
like ice; the cape clips; the Bloodrush readout ("Bright Blood +39", "Blood Fury 0:32") means nothing; there should be a
number on the blood; there should be another thing to drink besides people; the coffin only sleeps to dusk. The player
now asks "what can I do as a vampire?" instead of "why is this boring?". This pass makes the existing small world
reliable and purposeful. It adds no system bigger than the foxes.

### Baseline (recorded before any change)
Godot 4.8-dev6. `unit_tests` 234/234, `smoke_test` 72/72, `scenario_tests` 52/52, `feel_tests` 238/238 - 596 checks, all
passing, only the known harmless "ObjectDB instances leaked at exit" message.

### Feedback -> response
| Playtest feedback | Response |
|---|---|
| Traversal climbs through floors, goes OUT when you meant IN, drops from roofs into interiors, vaults through windows from roofs, the hatch does the same | Root cause found in code: `Interactor` measured **ground-plane distance only** (a roof was "within reach" of the room under it, and the reverse), picked the end by *camera-forward score* so standing between the two ends of a window could choose the far one, and `TraversalController.start()` then **teleported the player to the chosen end**. Fixed at the root: see *Traversal rules* below. |
| Movement is like ice | Separate acceleration / **braking** / **turn grip** (`Player.steer`). A running vampire stopped in ~1.5 m; now ~0.55 m in 0.13 s. |
| Cape clips through the player while running | Found in code: positive `rotation.x` swings a hanging cape **forward**, so `_cloak.rotation.x = +flare` drove the hem through the legs. Rebuilt as a 3-segment chain with lag and a leg-clearance pass; no cloth simulation. |
| "Bright Blood +39 / Blood Fury 0:32" is unreadable | The memory screen now says what the blood **is** ("Bright blood. Young, quick and heady."), how much it gave ("+39 blood restored") and, in gold, what the rush **does** and for how long ("Fury 0:32: +22% speed, +14% jump, Sense is free, sun burns 20% slower"). The HUD shows the same under the timer. Generated from the real tuning numbers. |
| Wants a number in the blood HUD | `73 / 100` under the vessel (smoothed with the liquid, so it counts up as you drink). The vessel is untouched. |
| Wants more ways to get blood | A **fox** (`Animal`, data: `AnimalProfile`, blood `wild`, feed style `wild`). Two foxes live under the old wall: asleep in the den by day, out at night, skittish, bolting from a vampire (much more than a human), going to ground for a while after a feed. Sense finds them. |
| NPCs "kinda just there so you can sense them" | Each person has **tidings** (`Tiding` data): the next thing they will tell you as you earn trust, gated by time of day. They can name a stranger (Sense then calls them by name), point at a hidden thing, or hint at which feeding state holds a memory. No quest log. |
| Wants more Blood Memories | +7: a **trusting** memory for each person, a **deepest** memory for each (opens once the other four are heard, whatever state they are in), and the fox's. Fifteen among the people (was nine). |
| Wants to climb a wall to a roof | The climb routes existed but did not read as supernatural. They now have a hands-and-feet climb pose, stone dust, a mist trail off the cloak, a light camera shudder, and **Sense draws the wall** as a pale strip with a label ("Climb: manor wall"). Prompts name the building. A fourth (`hut_roof`) and a deliberate **broken-roof** route (`manor_hatch`) were added. |
| Coffin only sleeps to dusk | The coffin now asks **when you will wake** (data: `RestOption`): until dusk (first, selected - the old behaviour), midnight, dawn, **daylight** (8 AM: wake as a Human into the day, to talk to people). |
| World needs more immersion | Not a bigger map: foxes at night, tidings that connect people and places, three small readable clues (a log, wax under a window, a scratched gate lock) that agree with what people say, more routes, more memories. |

### Traversal rules (the main fix)
Nothing is ever started by proximity. `TraversalController.problem(link, end)` is the single decision; it returns a reason
code and the route is **not offered** (no prompt) and `start()` **refuses** unless it is `""`:
1. the form may use that kind of route (Human: none);
2. the player is `can_act` and not already traversing (and 0.45 s after the last one);
3. **level** - the player's feet are within 1.1 m of the *start end's* height (`level`);
4. **reach** - within 2.0 m on the ground plane of the start end (`far`);
5. **side** - not already past the wall: the player's position along the route is before the wall (`barrier`, a fraction of the
   run; 0.5 for a window). Standing inside by the sill you can *never* start from the outside end, and vice versa (`side`);
6. **lateral** - roughly in front of the opening, not 1.5 m along the wall (`lateral`);
7. **facing** - body *or* camera within ~75 degrees of the way the route goes (`facing`). You arrive facing *into* the room, so a
   second press cannot send you back out; to leave you must turn to the window. **Stepping off a roof** always needs you
   to face the edge, whatever the route says;
8. **landing** - the exit spot (or the first nearby spot that fits) is free *and has floor* (`blocked`).
The first six live on `TraversalPlacement.entry_problem()` (pure geometry, data per route: `reach`, `level_tolerance`,
`lateral_tolerance`, `facing_min`, `barrier`), so tests and mods can use it without a player. `Interactable` gained
`reach_up` / `reach_down` and the `Interactor` skips anything on another level (this alone also stops the cellar hatch being
used from the roof and every NPC/secret/coffin prompt leaking through floors). The path eases from where the player
stood onto the route's line instead of snapping. The collapsed section of the manor roof has a low stone rim (blocks the
body only; sunlight is untouched), so nobody falls into the hall by accident; the `manor_hatch` route is the intentional way.
`Player.place_at` clears the interaction focus (a stale prompt used to survive a teleport).

### The fox, and what makes it a different kind of blood
`FeedSource` is a small interface (`can_be_fed`, `begin_feed`, `feed_tick`, `finish_feed`, `interrupt_feed`, `feed_style`,
`get_feed_result`, plus camera / crouch hints). `HumanNpc` and `Animal` both implement it; `FeedingController`, the HUD and the
memory view needed no special case. What differs is data:
| | Person | Fox |
|---|---|---|
| Blood (calm) | 35-52 (by blood type) | 26 |
| Bloodrush | Clear Blood 1.0 x 50 s (Fury 1.35 x 32 s afraid, Dreamblood 0.8 x 75 s asleep) | Instinct 0.7 x 40 s |
| Feed | 3.6 s | 2.4 s |
| Noise / who minds | afraid victims scream (17 m); witnesses within 12-16 m run | silent; only someone within **7 m** who sees it runs |
| Memory | every state has one; trust and "all heard" open more | one, **first time only** - after that a fox is a meal (no frozen world, control returns at once) |
| Effort | they walk their routine; you can talk, lure, wait for sleep | skittish: notices a sprinting vampire from ~13 m, a walking one from ~8.5 m, a human from ~4 m; asleep by day (creep up), goes to ground for ~100 s after a feed |
Humans stay worth more (information, bigger rush, deeper memories); the fox is the quick, safe, small drink.

### Controller tuning
`FormData.deceleration` and `turn_grip` are new data; values (acceleration / deceleration / grip): Vampire 42 / 70 / 55 (was 26
for everything), Human 30 / 48 / 42 (was 16). `Player.steer` raises the speed *along* the wanted direction at the acceleration rate,
sheds speed (letting go, easing the stick, reversing) at the braking rate, and cancels sideways drift at the grip rate; in
the air the rates are scaled down. Stopping from a full run: Vampire 0.55 m in 0.13 s, Human 0.29 m in 0.12 s. Reaching 90% of run
speed takes ~0.2 s, so it is not instant. The analog stick is unchanged (deadzone 0.25, magnitude -> speed). A part-tilted
stick is a part-speed walk. Nothing about the InputMap, vibration or bindings changed.

### Wall-to-roof climbing (prototype)
Four climbs (manor wall -> roof, ruined wall top, cottage wall -> roof, **watch hut -> roof**) and the **broken roof** route.
All are `TraversalPlacement` data. A climb is not physics and not free climbing: you approach the foot of a marked wall facing it,
Sense shows the wall strip, the prompt appears (`Scale the manor wall to the roof`), and the body climbs hand over hand
(`HumanoidModel.climb_pose`), dust falling, mist trailing off the cloak, then flows over the lip. Dropping needs you to face the
edge. The start points were moved to hug the wall (they floated ~1 m out).

### Coffin
Interacting opens `RestMenu` (world frozen, `PauseControl` reason `rest`): the options come from `DayNightProfile.rest_options`
(`RestOption`: label, hour, wake text; the four above are in `content/time/default.tres`). Options less than an hour ahead are not
offered. Enter / A chooses, Esc / B stays awake (and the same key press can no longer also open the pause menu). Everything the
coffin always reset still resets, and **the animals** are reset too.

### Values tuned
| Value | Before | After | Reasoning |
|---|---|---|---|
| Vampire / Human acceleration | 26 / 16 | 42 / 30 | reaches speed in ~0.2 s |
| Braking / turn grip | (= acceleration) | 70 / 55 and 48 / 42 | crisp stops and turns |
| Blood HUD | no number | `N / 100` under the vessel | the player asked; vessel kept |
| Cape rest angle | hem 0.43 m behind, flare *forward* | 3 segments, trailing back with speed | no clipping |
| Route reach | 2.1 m (end spheres), no level / side / facing | 2.0 m + level 1.1 + side + lateral 1.2 + facing + landing | the traversal fix |
| Human blood drain / Vampire drain / Sense cost | 0.02 / 0.16 / 0.55 + 2 | **unchanged** | not retuned; tests confirm 0.02/s and 0.16/s in real time |
| Sunlight, day length, night | - | **untouched** | three minutes at noon, 20-minute day |

### Test changes (and why)
| Test | Change | Why |
|---|---|---|
| unit: memory counts | Tomas / Corvin 3 -> 5 | trusting + deepest memories |
| smoke / feel: coffin | press Enter after interact | the coffin now asks when you wake (first answer = old behaviour) |
| scenario / feel: trust feed | expects "Flour on Her Hands" (and the well key, which that memory also reveals) | Tomas now has a memory of his own for trust; it opens the key too, so trust is still a way to the key |
| feel: routes | new prompt strings; "at the window it begins" now faces the window; the thin ruined-wall top is stood on 0.2 m behind the end (0.6 m put the test player in the air); the blocked-landing check now expects the route *not to be offered* (the mid-route fallback moved to polish_tests) | the traversal rules |
| feel: "blood is a living vessel, not a number" | allows the drawn number and the reward line | the number was requested; the check now looks for stray numeric labels |
| test_base `_run_until_focus` | keeps going 0.12 s after the prompt appears | the body now stops almost at once, so it halted right at the edge of range where the prompt flickers |
| `Player.place_at` | clears the interaction focus | a teleported player kept the old prompt for 0.08 s (found by a new test) |

### How to run what is new
| Command | What |
|---|---|
| `godot --headless --path . res://tests/polish_tests.tscn` | the Task 1.8 suite (186 checks); `-- only=traversal,blood,reward,movement,cape,fox,people,coffin,memories` runs sections |
| `godot --path . res://tests/polish_playtest.tscn -- <dir>` | scripted windowed walk through the new features with ~30 screenshots |
| `godot --path . res://tests/model_probe.tscn -- <dir>` | the vampire model posed (idle, walk, run, jump, transformation, climb, feed) from the side and behind |

### Manual playtest observations
**What was and was not done.** As in Task 1.75: I ran the game windowed, with the real renderer and real (injected) key events,
through `tests/polish_playtest.gd` (30 screenshots), posed the model with `tests/model_probe.gd` (14 shots), re-ran the Task 1.75
`playtest_driver` (41 screenshots) as a regression look, ran `perf_probe` and a 300-second `soak_probe`, and looked at the pictures. I did
**not** play by hand, did **not** hold a controller (the GameSir G7 SE and a PS5 pad were not available), and **cannot hear** the procedural
audio or feel the vibration. Everything below is "reads right in stills and numbers", not "feels right in the hands".

**Things looking at it changed** (the automated checks did not catch these):
1. The roof-hole route drew a pale "wall" strip through the manor window area under Sense; routes that are not walls now opt out (`show_wall`).
2. The feeding camera hid the fox behind the vampire's own back (a person is fed over, a fox is under the torso). The vampire now kneels *beside*
   it and the camera swings round to the side with a steeper look-down (`FeedSource.feed_stand_side / feed_camera_yaw / feed_camera_pitch`); the
   fox is plainly visible, limp, with the cape draped over the vampire's back. (Two earlier settings were tried and rejected by looking.)
3. The HUD's left column grew by a line (the reward's effect under the timer): its box was enlarged so nothing hangs below the screen. The memory
   screen's new reward block fits at 1280x720 with the facts and the prompt (checked at full reveal).
4. The cape bug was found by reading the code (a positive `rotation.x` swings a hanging limb forward); the model probe confirmed the fix - the hem
   trails behind in walk, run, jump and transformation - and showed the same sign error had been throwing the feeding pose's arms *backward*.
5. A test found a stale prompt surviving a teleport; `Player.place_at` now clears it. Another found that Esc closed the coffin menu and opened the
   pause menu in the same frame.

**Against the brief's questions** (stills and numbers only):
- *Is traversal intentional?* In the frames the prompt names the building and the direction, and a Sense strip marks the wall. In tests the case the
  playtest described (press E again right after going in) now does nothing, and every wrong-side, wrong-level and wrong-facing case offers nothing.
- *A supernatural wall climb?* The frames show the hands-over-hand pose, dust, a mist trail and the body flowing over the lip. It is still a short,
  fixed, authored path - not the feeling of free climbing, which was out of scope.
- *Controller:* a running stop measures 0.13 s / 0.55 m with the same numbers on keyboard and pad. I cannot say how it *feels* in the hands.
- *If I spawned as a vampire with no marker, would I want to explore?* Closer than before, for a few minutes: with Sense on at night there are foxes to
  hunt, windows, climb strips and a hole in the roof drawing the eye, people whose prompt says "something to tell", and three things to read. It is still
  one very small estate; I can say it creates curiosity in screenshots, not that it holds it for an hour.

**Performance:** `perf_probe` (GTX 1660 SUPER, windowed): about 4.2 ms per frame (the 240 fps cap) in the yard by day, ~1250 nodes and ~410-430 draw
calls (was ~1100 / ~400): the extra nodes are the foxes, the cape segments, the rest menu and the route markers. **Soak** (`soak_probe`, 8x, 300 s,
foxes included): no script errors, no deaths, one feed and one memory.

### What remains intentionally unfinished
No Wolf / Bat, no combat, no quest log (tidings are lines, not objectives), the fox has no pack or ecology (two foxes, one den),
no animals other than foxes, climbing is authored routes (not free), the roof-hole rim blocks bodies but a vampire can still *jump*
over it on purpose, clues are single lines, memories are still text over a frozen world, NPC pathing is still straight lines.

### Known issues
- Controllers and vibration are still untested on hardware.
- Sense route markers for the broken roof sit near the manor window's markers when you are close to both; their labels can overlap.
- A fox that has just bolted is only cornered by running it down; there is no scent trail.
- The feed camera is a fixed orbit, so a feed on the ground leans on the vampire's lowered back for framing (steeper pitch helps).
- `tests/out/` is where windowed tests write screenshots (git-ignored).
- Headless runs now also print "RID allocations ... leaked at exit" lines (cached UI fonts used by the blood number); like the ObjectDB message they are harmless.

### Design questions raised by this pass
1. Is "sleep until daylight" what the player meant by "sleep to sunlight"? (An alternative reading: sleep *through* the day until the next dusk without waking as a Human - which is "until dusk" as before.)
2. Should foxes (and other creatures) be able to *see* a vampire's transformation and bolt? Today a transformation only unsettles humans.
3. Should the fox's memory repeat per individual fox instead of once per species?
4. Should an animal's Bloodrush differ in *kind* (not only strength): e.g. keener Sense, quieter steps? `BloodSurge` has a fixed bundle today.
5. Should tidings eventually show in a quiet journal? (Out of scope now: the HUD "Learned:" line is the only record.)
6. How much should hearing a story change what Sense shows (names today; locations / schedules next)?
7. Should a roof rim be a visible gate (jump to enter) or should entering the manor by the roof always be via the route?
8. Should witnesses of a fox feed react at all? (Today: yes within 7 m. A hunter's view of "the vampire eats foxes" may be less alarming than "the vampire eats a person".)

---

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
