class_name WorldLight
extends RefCounted
## How brightly lit a spot is, for the things that look at it (a hunter deciding how far he can see you).
## Lamps, lanterns and room lights register themselves; the answer is 0 in the dark to 1 in full lamplight.
## It is a few distance checks and (given the physics space) a ray per nearby light, so it is cheap enough to
## ask a handful of times a second - never every frame.

static var _lights: Array[OmniLight3D] = []


static func register(light: OmniLight3D) -> void:
	if not _lights.has(light):
		_lights.append(light)


static func unregister(light: OmniLight3D) -> void:
	_lights.erase(light)


static func clear() -> void:
	_lights.clear()


static func count() -> int:
	return _lights.size()


## Light at `pos` (feet position; the body is sampled a metre up). `ambient` is the floor (moonlight, dusk).
## With `space`, a light behind a wall does not count.
static func at(pos: Vector3, ambient := 0.0, space: PhysicsDirectSpaceState3D = null) -> float:
	var lit := ambient
	var spot := pos + Vector3(0, 1.0, 0)
	var stale := false
	for l in _lights:
		if not is_instance_valid(l) or not l.is_inside_tree():
			stale = true
			continue
		if not l.visible or l.light_energy < 0.05:
			continue
		var d := l.global_position.distance_to(spot)
		if d >= l.omni_range:
			continue
		var strength := clampf(l.light_energy / 1.3, 0.0, 1.0) * (1.0 - d / l.omni_range)
		if strength <= 0.02:
			continue
		if space != null:
			var q := PhysicsRayQueryParameters3D.create(l.global_position, spot, Greybox.WORLD)
			if not space.intersect_ray(q).is_empty():
				continue
		lit += strength * 1.35
	if stale:
		_lights.assign(_lights.filter(func(x): return is_instance_valid(x) and x.is_inside_tree()))
	return clampf(lit, 0.0, 1.0)
