class_name Fx
extends RefCounted
## Tiny helpers for throw-away particle effects (prototype VFX).


static func _make(color: Color, amount: int, lifetime: float, size: float) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = amount
	p.lifetime = lifetime
	var mesh := SphereMesh.new()
	mesh.radius = 0.5
	mesh.height = 1.0
	mesh.radial_segments = 6
	mesh.rings = 3
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.vertex_color_is_srgb = true
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh.material = mat
	p.mesh = mesh
	p.scale_amount_min = size * 0.6
	p.scale_amount_max = size * 1.3
	var ramp := Gradient.new()
	ramp.set_color(0, color)
	ramp.set_color(1, Color(color.r, color.g, color.b, 0.0))
	p.color_ramp = ramp
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return p


## One-shot burst at a world position. Frees itself.
static func burst(parent: Node, pos: Vector3, color: Color, amount := 30, speed := 3.0, size := 0.15, lifetime := 0.9, gravity_y := -1.5) -> CPUParticles3D:
	var p := _make(color, amount, lifetime, size)
	p.one_shot = true
	p.explosiveness = 0.95
	p.direction = Vector3.UP
	p.spread = 180.0
	p.initial_velocity_min = speed * 0.4
	p.initial_velocity_max = speed
	p.gravity = Vector3(0, gravity_y, 0)
	parent.add_child(p)
	p.global_position = pos
	p.emitting = true
	var timer := parent.get_tree().create_timer(lifetime + 0.6)
	timer.timeout.connect(p.queue_free)
	return p


## Persistent emitter; caller toggles `emitting` and keeps the reference.
static func emitter(parent: Node, local_pos: Vector3, color: Color, amount := 20, rate_speed := 1.0, size := 0.2, lifetime := 1.2, gravity_y := 1.2) -> CPUParticles3D:
	var p := _make(color, amount, lifetime, size)
	p.direction = Vector3.UP
	p.spread = 35.0
	p.initial_velocity_min = rate_speed * 0.5
	p.initial_velocity_max = rate_speed
	p.gravity = Vector3(0, gravity_y, 0)
	p.emitting = false
	p.local_coords = false
	parent.add_child(p)
	p.position = local_pos
	return p
