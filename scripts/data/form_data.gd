class_name FormData
extends ContentDef
## Data-driven description of one player form (Human, Vampire, later Wolf/Bat...).
## Everything that differs between forms lives here, not in player code.

@export var tagline := ""

@export_group("Movement")
@export var walk_speed := 3.0
@export var run_speed := 5.5
@export var jump_velocity := 6.0
## How quickly the body reaches the speed you ask for (m/s per second) ...
@export var acceleration := 14.0
## ... how quickly it sheds speed when you let go, slow down or reverse (much higher, so stopping is
## crisp rather than skating) ...
@export var deceleration := 48.0
## ... and how quickly sideways drift is cancelled when you turn (so a turn bites instead of sliding).
@export var turn_grip := 40.0

@export_group("Rules")
@export var sun_vulnerable := false
## Multiplier on incoming sunlight heat for this form (future: elder vampires, hardy forms).
@export var sun_heat_multiplier := 1.0
@export var frightens_humans := false
@export var can_feed := false
## Ability ids (AbilityDefinition.id) this form is allowed to use.
@export var abilities: PackedStringArray = PackedStringArray()
## Background blood use. Humans barely spend any; a vampire burns it noticeably (feeding refills it).
@export var blood_drain_per_sec := 0.0
## Low blood slows this form down (hungry x0.85, empty x0.7). Humans shrug it off.
@export var hunger_slows := false
## Resting heart rate of the player's own body (drives the HUD blood pulse and heartbeat audio).
@export var heartbeat_bpm := 66.0
## Traversal types (TraversalPlacement.type names, lowercase: "window", "climb") this form may use.
@export var traversal: PackedStringArray = PackedStringArray()
@export var regen_per_sec := 0.0
## Blood spent per point of health regenerated.
@export var regen_blood_cost := 0.0
## Damage of this form's basic strike (Rend). 0 = this form cannot fight.
@export var strike_damage := 0.0

@export_group("Look")
@export var skin_color := Color(0.85, 0.66, 0.55)
@export var cloth_color := Color(0.45, 0.35, 0.25)
@export var pants_color := Color(0.25, 0.25, 0.3)
@export var hair_color := Color(0.2, 0.13, 0.08)
@export var eye_color := Color(0.12, 0.08, 0.05)
@export var eye_glow := 0.0
@export var show_cloak := false
@export var show_fangs := false
@export var aura_energy := 0.0
@export var aura_color := Color(0.8, 0.05, 0.1)
@export var hud_color := Color(0.9, 0.85, 0.75)

@export_group("Camera and vision")
@export var fov := 70.0
## Darkest the world ever looks to this form. Humans are nearly blind at night; a vampire
## sees by a cool floor light. (Ambient is max(time-of-day ambient, this floor).)
@export var vision_floor_energy := 0.06
@export var vision_floor_color := Color(0.5, 0.52, 0.62)
@export var saturation := 1.0
@export var brightness := 1.0
@export var contrast := 1.0


func allows_ability(ability_id: StringName) -> bool:
	return abilities.has(String(ability_id))
