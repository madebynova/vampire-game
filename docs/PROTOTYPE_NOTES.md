# Vampire prototype (Task 1) - designer notes

Question this prototype exists to answer: **"Is being this vampire actually fun?"**

## Run it
- Open the project in Godot 4.8 and press F5 (main scene: `res://scenes/main.tscn`).
- Controls: WASD move, Shift run, Space jump, mouse look, **F** transform, **Q** Vampiric Sense (vampire only),
  **E** interact (as a vampire, *hold* E on a human to feed), H toggles help, F3 debug, Esc frees the mouse.

## Dev tools (all headless-capable)
| Command | What it does |
|---|---|
| `godot --path . res://tests/smoke_test.tscn -- <dir>` | Full scripted playthrough through real input actions (67 checks) + screenshots into `<dir>`. Add `--headless` to skip screenshots. |
| `godot --headless --path . res://tests/sun_map.tscn` | ASCII map of sun/shade using the exact rays the game uses. Use it when moving props. |
| `godot --path . res://tests/visual_probe.tscn -- <dir>` | Overview + model + sense screenshots. |
| `godot --headless --path . res://tests/audio_probe.tscn` | Build time / peak level of the procedural sounds. |

## What each system is (and where)
| System | Files | Notes |
|---|---|---|
| Locomotion, camera | `player/player.gd`, `player/camera_rig.gd` | Player only moves/faces; everything else is a component under `Player/Components`. |
| Forms | `player/form_controller.gd`, `data/forms/*.tres`, `data/form_data.gd` | Human/Vampire are data. A new form = a new `FormData` + id in `cycle_ids`. |
| Vampiric Sense | `abilities/vampiric_sense.gd`, `sense_target.gd`, `shaders/sense_*.gdshader` | See below. Anything gains a sense outline by having a `SenseTarget` child. |
| Feeding | `player/feeding_controller.gd`, `npc/human_npc.gd`, `npc/npc_interactable.gd` | Hold-to-feed, interruptible. |
| Blood as information | `data/npc_profile.gd`, `data/npcs/*.tres`, `world/secret_stash.gd`, HUD memory panel | Placeholder architecture: profile -> memory text + facts + optional `reveals_secret`. |
| Sunlight | `player/sunlight_exposure.gd` | Real ray-casts toward the sun; buildings/walls/canopies make shade. |
| Coffin | `world/coffin.gd` | Spawn, rest (end the night), death respawn. Seed of the home system. |
| World | `world/world_builder.gd`, `greybox.gd`, `world_atmosphere.gd` | All layout numbers in one file. |
| Presentation | `main.gd`, `ui/hud.gd`, `ui/screen_fx.gd`, `player/player_feedback.gd`, `core/sfx.gd` | Gameplay code never reads these. |

## Current design (tuning values live in `@export`s and `.tres` files)
- **Human**: walk 3.0 / run 5.5, jump 6, no ability, immune to sun, NPCs treat you as normal (you can talk).
- **Vampire**: walk 4.2 / run 9.0, jump 9, sun-vulnerable, drains 0.35 blood/s, regenerates health by spending blood,
  night vision (brighter cool ambient + desaturation), NPCs that see you within 10 m panic.
- **Vampiric Sense** (Q toggle, 1.4 blood/s): red scan ring sweeps out from you; humans glow *through walls* pulsing at
  their real heart rate (which rises with fear) and you hear the heartbeats; floating text gives heart rate, mood and what
  their blood smells like; your coffin calls from anywhere; secrets that blood memories told you about become visible.
  Humans get an explicit "You can't do that as a human" denial.
- **Feeding**: hold E (0.45 s; 0.25 s to tackle a runner). Camera closes in, red tunnel + heartbeat, 3.6 s drink.
  Release early = they tear free terrified, no memory. Finish = they are left unconscious, you get blood + a **Blood Memory**
  (title, scene, facts). Terrified victims give +25% blood ("fear has a flavour").
- **Sunlight**: a burn meter fills with time in direct light (partial exposure fills it proportionally) and drains at 0.7/s in shade.
  `>0` WARNING (1.5 s, no damage) -> BURNING (6 dps, 15% slower) -> SEARING (from 4.5 s, 22 dps, 45% slower) -> death.
  Continuous exposure kills in ~8 s. A full feed in open sun costs ~26 hp.
- **Coffin**: you start there as Human. E = end the night (fade, heal, NPCs reset, blood floor 40, back to Human).
  Sun death = same but wake at 55% health.
- **Secret loop**: Tomas' blood -> "buried key under the well" -> Sense shows it -> dig -> unlocks the cellar hatch (placeholder toast).
  Elise's blood only adds story (cellar, robed figures, a child).

## Known limitations / hooks for later
- Interior brightness is one global ambient value (no GI/occlusion), so "human vs vampire vision" is a colour/brightness shift, not true darkness.
- NPC flee = "run directly away" with wall sliding; they can pin themselves in corners. No navmesh.
- NPCs do not move otherwise; one line cycle each; no schedules.
- No crouch/stealth. NPC notice rules: within 10 m, in view (or <2.2 m), line of sight clear.
- Blood is a single float. Blood *types*, archive, turning, lineage: deliberately absent.
- Audio is synthesized placeholder; no footsteps/ambience beyond wind.
- Art is primitive shapes.
- Coffin `wake()` is the future hub for "home" features; `SecretStash.key_held` is a static flag, not a save system.

## Playtest questions (answer these before building more)
1. Do I feel like a vampire? 2. Does becoming one change how I play? 3. Is transforming interesting?
4. Do I *want* to press Q? 5. Does feeding feel like something a vampire does? 6. ...or like refilling a bar?
7. Does sunlight create tension? 8. ...or is it annoying? 9. Do I experiment? 10. Do I think "what happens if I...?"
11. Do I want to explore *with* vampire senses? 12. Does the coffin feel like home?
13. What is boring? 14. What is annoying? 15. What is uniquely vampire?

Things worth *deliberately* trying: feed Tomas in the open sun; feed Elise from behind vs. from the door; let go mid-feed;
transform next to someone; sense while hungry; stand in the doorway sun-shaft; rest and repeat; dig up the key, unlock the hatch.
