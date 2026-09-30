class_name SunlightExposure
extends PlayerComponent
## Detects real sunlight by ray-casting from the body toward the sun (so buildings, walls and
## tree canopies genuinely make shade) and feeds it to a SunlightModel.
##
## Strength of the heat applied per second =
##     (fraction of body in direct light)              -- geometry, this script
##   x (sun intensity from TimeOfDay)                   -- time of day
##   x (form.sun_heat_multiplier)                       -- what you are
##   x (every heat modifier registered by other systems) -- how you are protected/exposed
##
## Other systems (abilities, items, blood effects, being mid-feed...) change the outcome only by
## calling set_heat_modifier(source, multiplier) - they never touch the numbers. The stage table
## (how much heat is how bad) lives in a SunlightProfile resource.

signal stage_changed(new_stage: int, old_stage: int)

const SUN_MASK := 1 | 16   # world + canopies (sun blockers)

@export var profile_id: StringName = &"default"
@export var sample_heights := PackedFloat32Array([0.15, 0.9, 1.7])
@export var ray_length := 80.0

var model: SunlightModel
var exposure := 0.0    ## 0..1 fraction of the body in direct light (geometry only)
var strength := 0.0    ## effective heat/second right now (0 in shade / at night / when immune)
var stage := 0:
	get:
		return model.stage if model else 0
var sun: DirectionalLight3D
var _tod: TimeOfDay
var _mods: Dictionary = {}
var _last_stage := 0
var _smoothed := 0.0


func _on_setup() -> void:
	var profile := ContentRegistry.get_def(&"SunlightProfile", profile_id) as SunlightProfile
	assert(profile != null, "SunlightExposure: unknown profile %s" % profile_id)
	model = SunlightModel.new(profile)
	player.health.died.connect(func(_c): reset())


# ---------------------------------------------------------------- extension API

## Multiply incoming sunlight heat (0.5 = half heat, 2.0 = double, 0 = immune). Replaces any
## earlier multiplier from the same `source`.
func set_heat_modifier(source: StringName, multiplier: float) -> void:
	_mods[source] = multiplier


func clear_heat_modifier(source: StringName) -> void:
	_mods.erase(source)


## Product of the form multiplier and every registered modifier.
func heat_multiplier() -> float:
	var m := player.form.current.sun_heat_multiplier
	for v in _mods.values():
		m *= v
	return m


func stage_count() -> int:
	return model.profile.stage_count()


func stage_name() -> String:
	return model.stage_name()


## Stage as 0..1 (0 = safe, 1 = the last stage), independent of how many stages a profile has.
func stage_fraction() -> float:
	return float(stage) / maxf(stage_count() - 1, 1)


## Heat as 0..1 of the way to the critical stage.
func burn_ratio() -> float:
	return model.ratio()


## Seconds until death if things stay exactly as they are right now (INF if not in light).
func estimated_seconds_to_death() -> float:
	return model.seconds_to_death(player.health.value, strength)


func reset() -> void:
	model.reset()
	_smoothed = 0.0
	exposure = 0.0
	strength = 0.0
	_mods.clear()
	player.speed_modifiers.erase(&"sunlight")
	_emit_if_changed()


# ---------------------------------------------------------------- sun source

## Direction pointing FROM the ground TOWARD the sun.
func to_sun() -> Vector3:
	if _tod == null:
		_tod = get_tree().get_first_node_in_group(&"time_of_day") as TimeOfDay
	if _tod != null:
		return _tod.sun_direction()
	if sun == null:
		sun = get_tree().get_first_node_in_group(&"sun") as DirectionalLight3D
	return sun.global_transform.basis.z.normalized() if sun else Vector3.UP


## 0..1: how hard the sun is shining right now (0 at night, 1 by mid-morning).
func sun_intensity() -> float:
	if _tod == null:
		_tod = get_tree().get_first_node_in_group(&"time_of_day") as TimeOfDay
	return _tod.sun_strength() if _tod != null else 1.0


func is_vulnerable() -> bool:
	return player.form.current.sun_vulnerable and not player.state.is_dead() \
		and player.state.mode != PlayerState.Mode.RESTING


# ---------------------------------------------------------------- simulation

func _physics_process(delta: float) -> void:
	var intensity := sun_intensity()
	# Skip the rays entirely when there is no sun or nothing can be burned.
	if intensity <= 0.001 or not is_vulnerable():
		exposure = 0.0
	else:
		exposure = _sample_exposure()
	_smoothed = move_toward(_smoothed, exposure, delta * 8.0)
	strength = _smoothed * intensity * heat_multiplier() if is_vulnerable() else 0.0

	var damage := model.step(delta, strength)
	if damage > 0.0:
		player.health.damage(damage, &"sunlight")
	player.health.set_regen_blocked(&"sunlight", strength > model.profile.shade_threshold)

	if model.stage > 0:
		player.speed_modifiers[&"sunlight"] = model.speed_multiplier()
	else:
		player.speed_modifiers.erase(&"sunlight")
	_emit_if_changed()


func _emit_if_changed() -> void:
	if model.stage != _last_stage:
		var old := _last_stage
		_last_stage = model.stage
		stage_changed.emit(_last_stage, old)


func _sample_exposure() -> float:
	var dir := to_sun()
	if dir.y < 0.02:
		return 0.0  # sun below the horizon
	var space := player.get_world_3d().direct_space_state
	var lit := 0
	for h in sample_heights:
		var from := player.global_position + Vector3(0, h, 0)
		var query := PhysicsRayQueryParameters3D.create(from, from + dir * ray_length, SUN_MASK, [player.get_rid()])
		if space.intersect_ray(query).is_empty():
			lit += 1
	return float(lit) / sample_heights.size()
