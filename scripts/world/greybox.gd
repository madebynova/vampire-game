class_name Greybox
extends RefCounted
## Prototype level-geometry helpers: coloured boxes, walls with openings, cones.
## Collision layers: WORLD blocks everything (and sun); SUN_ONLY blocks sunlight rays only (canopies).

const WORLD := 1
const SUN_ONLY := 16

static var _mats: Dictionary = {}
static var _noise_tex: NoiseTexture2D


static func material(color: Color, emissive := 0.0) -> StandardMaterial3D:
	var key := "%s_%s" % [color.to_html(), emissive]
	if _mats.has(key):
		return _mats[key]
	if _noise_tex == null:
		var noise := FastNoiseLite.new()
		noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		noise.frequency = 0.04
		noise.fractal_octaves = 3
		_noise_tex = NoiseTexture2D.new()
		_noise_tex.noise = noise
		_noise_tex.seamless = true
		_noise_tex.width = 256
		_noise_tex.height = 256
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.albedo_texture = _noise_tex
	m.uv1_triplanar = true
	m.uv1_scale = Vector3(0.45, 0.45, 0.45)
	m.roughness = 0.95
	if emissive > 0.0:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = emissive
	_mats[key] = m
	return m


## Solid box centred at `center`. Visible unless `visible_mesh` is false.
static func box(parent: Node, center: Vector3, size: Vector3, color: Color, layer := WORLD, node_name := "Box") -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = node_name
	body.collision_layer = layer
	body.collision_mask = 0
	body.position = center
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = material(color)
	body.add_child(mi)
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	cs.shape = shape
	body.add_child(cs)
	parent.add_child(body, true)   # readable, unique names: Bench, Bench2, ...
	return body


## Visual-only flat slab (roads, rugs): no collision.
static func decal(parent: Node, center: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = material(color)
	mi.position = center
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


static func cylinder(parent: Node, center: Vector3, radius: float, height: float, color: Color, layer := WORLD) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = layer
	body.collision_mask = 0
	body.position = center
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = radius
	cm.bottom_radius = radius
	cm.height = height
	cm.radial_segments = 12
	mi.mesh = cm
	mi.material_override = material(color)
	body.add_child(mi)
	var cs := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = radius
	shape.height = height
	cs.shape = shape
	body.add_child(cs)
	parent.add_child(body)
	return body


## Cone (tree canopy). Collides only as a sun blocker, so the player walks under it.
static func cone(parent: Node, base_center: Vector3, radius: float, height: float, color: Color, layer := SUN_ONLY) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = layer
	body.collision_mask = 0
	body.position = base_center + Vector3(0, height * 0.5, 0)
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.0
	cm.bottom_radius = radius
	cm.height = height
	cm.radial_segments = 10
	mi.mesh = cm
	mi.material_override = material(color)
	body.add_child(mi)
	var cs := CollisionShape3D.new()
	cs.shape = cm.create_convex_shape(true, false)
	body.add_child(cs)
	parent.add_child(body)
	return body


## Axis-aligned wall from `a` to `b` (XZ plane). `openings` = [{at, w, y0, y1}, ...] measured
## along the wall from `a`. Builds solid pieces around each opening.
static func wall(parent: Node, a: Vector2, b: Vector2, height: float, thickness: float, color: Color, openings: Array = []) -> void:
	var dir := (b - a)
	var length := dir.length()
	dir = dir.normalized()
	var sorted := openings.duplicate()
	sorted.sort_custom(func(x, y): return x["at"] < y["at"])
	var cursor := 0.0
	for o in sorted:
		var at: float = o["at"]
		var w: float = o["w"]
		var y0: float = o.get("y0", 0.0)
		var y1: float = o.get("y1", height)
		if at > cursor:
			_wall_piece(parent, a, dir, cursor, at, 0.0, height, thickness, color)
		if y0 > 0.0:
			_wall_piece(parent, a, dir, at, at + w, 0.0, y0, thickness, color)
		if y1 < height:
			_wall_piece(parent, a, dir, at, at + w, y1, height, thickness, color)
		cursor = at + w
	if cursor < length:
		_wall_piece(parent, a, dir, cursor, length, 0.0, height, thickness, color)


static func _wall_piece(parent: Node, a: Vector2, dir: Vector2, s0: float, s1: float, v0: float, v1: float, thickness: float, color: Color) -> void:
	var mid := a + dir * ((s0 + s1) * 0.5)
	var seg := s1 - s0
	var size := Vector3(seg, v1 - v0, thickness) if absf(dir.x) > 0.5 else Vector3(thickness, v1 - v0, seg)
	box(parent, Vector3(mid.x, (v0 + v1) * 0.5, mid.y), size, color, WORLD, "Wall")


## Horizontal slab covering `rect` (XZ) at height `y`, with an optional hole (also XZ).
static func slab_with_hole(parent: Node, rect: Rect2, y: float, thickness: float, hole: Rect2, color: Color) -> void:
	var x0 := rect.position.x
	var x1 := rect.end.x
	var z0 := rect.position.y
	var z1 := rect.end.y
	var hx0 := hole.position.x
	var hx1 := hole.end.x
	var hz0 := hole.position.y
	var hz1 := hole.end.y
	_slab(parent, x0, x1, z0, hz0, y, thickness, color)
	_slab(parent, x0, x1, hz1, z1, y, thickness, color)
	_slab(parent, x0, hx0, hz0, hz1, y, thickness, color)
	_slab(parent, hx1, x1, hz0, hz1, y, thickness, color)


static func _slab(parent: Node, x0: float, x1: float, z0: float, z1: float, y: float, thickness: float, color: Color) -> void:
	if x1 - x0 < 0.01 or z1 - z0 < 0.01:
		return
	box(parent, Vector3((x0 + x1) * 0.5, y, (z0 + z1) * 0.5), Vector3(x1 - x0, thickness, z1 - z0), color, WORLD, "Roof")
