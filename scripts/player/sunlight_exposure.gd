class_name SunlightExposure
extends PlayerComponent
## Detects real sunlight by ray-casting from the body toward the sun (so buildings, walls
## and tree canopies genuinely make shade) and turns exposure into escalating danger.
##
##   Stage 1 WARNING  - you feel it. No damage yet.
##   Stage 2 BURNING  - damage + slowed.
##   Stage 3 SEARING  - heavy damage + heavily slowed.
##   Stage 4 DEATH    - health hits zero -> Health.died -> coffin.
##
## A "burn meter" fills while exposed and drains slowly in shade, so dodging in and out of
## light is not free.

enum Stage { SAFE, WARNING, BURNING, SEARING }

signal stage_changed(new_stage: Stage, old_stage: Stage)

const SUN_MASK := 1 | 16

@export var sample_heights := PackedFloat32Array([0.15, 0.9, 1.7])
@export var ray_length := 80.0
@export var burning_at := 1.5
@export var searing_at := 4.5
@export var meter_max := 6.0
@export var meter_decay := 0.7
@export var burning_dps := 6.0
@export var searing_dps := 22.0
@export var burning_speed_mult := 0.85
@export var searing_speed_mult := 0.55

var exposure := 0.0      ## 0..1, fraction of body currently in direct sun
var meter := 0.0         ## accumulated burn, seconds-equivalent
var stage: Stage = Stage.SAFE
var sun: DirectionalLight3D
var _smoothed := 0.0


func _on_setup() -> void:
	player.health.died.connect(func(_c): reset())


## Direction pointing FROM the ground TOWARD the sun.
func to_sun() -> Vector3:
	if sun == null:
		sun = get_tree().get_first_node_in_group(&"sun") as DirectionalLight3D
	if sun == null:
		return Vector3.UP
	return sun.global_transform.basis.z.normalized()


func is_vulnerable() -> bool:
	return player.form.current.sun_vulnerable and not player.state.is_dead() \
		and player.state.mode != PlayerState.Mode.RESTING


func _physics_process(delta: float) -> void:
	exposure = _sample_exposure()
	_smoothed = move_toward(_smoothed, exposure, delta * 8.0)
	var in_sun := _smoothed > 0.05

	if is_vulnerable() and in_sun:
		meter = minf(meter + _smoothed * delta, meter_max)
	else:
		meter = maxf(meter - meter_decay * delta, 0.0)

	var new_stage := Stage.SAFE
	if is_vulnerable() and (in_sun or meter > 0.0):
		if meter >= searing_at:
			new_stage = Stage.SEARING
		elif meter >= burning_at:
			new_stage = Stage.BURNING
		elif in_sun:
			new_stage = Stage.WARNING
	_set_stage(new_stage)

	# Damage only while actually standing in light; smouldering after leaving just slows you.
	if in_sun and is_vulnerable():
		var dps := 0.0
		if stage == Stage.BURNING:
			dps = burning_dps
		elif stage == Stage.SEARING:
			dps = searing_dps
		if dps > 0.0:
			player.health.damage(dps * _smoothed * delta, &"sunlight")
	player.health.set_regen_blocked(&"sunlight", in_sun and is_vulnerable())

	match stage:
		Stage.BURNING:
			player.speed_modifiers[&"sunlight"] = burning_speed_mult
		Stage.SEARING:
			player.speed_modifiers[&"sunlight"] = searing_speed_mult
		_:
			player.speed_modifiers.erase(&"sunlight")


## 0..1 progress from safe to searing, for UI/VFX.
func burn_ratio() -> float:
	return clampf(meter / searing_at, 0.0, 1.0)


func reset() -> void:
	meter = 0.0
	_smoothed = 0.0
	exposure = 0.0
	player.speed_modifiers.erase(&"sunlight")
	_set_stage(Stage.SAFE)


func _set_stage(s: Stage) -> void:
	if s == stage:
		return
	var old := stage
	stage = s
	stage_changed.emit(s, old)


func _sample_exposure() -> float:
	var dir := to_sun()
	if dir.y < 0.02:
		return 0.0  # sun below horizon
	var space := player.get_world_3d().direct_space_state
	var lit := 0
	for h in sample_heights:
		var from := player.global_position + Vector3(0, h, 0)
		var query := PhysicsRayQueryParameters3D.create(from, from + dir * ray_length, SUN_MASK, [player.get_rid()])
		if space.intersect_ray(query).is_empty():
			lit += 1
	return float(lit) / sample_heights.size()
