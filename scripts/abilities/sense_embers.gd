class_name SenseEmbers
extends Node3D
## Part of Vampiric Sense in daylight: the ground *near you* smoulders wherever the sun would burn
## you. Not an objective marker - it is the vampire reading light the way others read shade.
## A small camera-centred grid of soft tiles, re-sampled a couple of times a second.

const GRID := 11
const SPACING := 2.4
const RADIUS := GRID * SPACING * 0.5
const SUN_MASK := 1 | 16

## Brightness (alpha) of each tile from the last refresh; readable without a renderer (tests/tools).
var tile_alpha := PackedFloat32Array()
var _mm: MultiMesh
var _timer := 0.0
var _origin_snap := Vector2(1e9, 1e9)


func _ready() -> void:
	top_level = true
	var mesh := QuadMesh.new()
	mesh.size = Vector2(SPACING * 1.05, SPACING * 1.05)
	mesh.orientation = PlaneMesh.FACE_Y
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.vertex_color_use_as_albedo = true
	mat.vertex_color_is_srgb = true
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var grad := Gradient.new()
	grad.set_color(0, Color(1, 1, 1, 1))
	grad.set_color(1, Color(1, 1, 1, 0))
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 64
	tex.height = 64
	mat.albedo_texture = tex
	mesh.material = mat
	_mm = MultiMesh.new()
	_mm.transform_format = MultiMesh.TRANSFORM_3D
	_mm.use_colors = true
	_mm.mesh = mesh
	_mm.instance_count = GRID * GRID
	tile_alpha.resize(GRID * GRID)
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = _mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mmi.extra_cull_margin = 60.0
	add_child(mmi)
	hide_all()


func hide_all() -> void:
	for i in _mm.instance_count:
		_mm.set_instance_color(i, Color(0, 0, 0, 0))
		_mm.set_instance_transform(i, Transform3D(Basis().scaled(Vector3.ZERO), Vector3.ZERO))
		tile_alpha[i] = 0.0
	_origin_snap = Vector2(1e9, 1e9)


## Re-sample around `center`. `to_sun` = direction toward the sun, `intensity` 0..1.
func refresh(center: Vector3, to_sun: Vector3, intensity: float) -> void:
	if intensity <= 0.02 or to_sun.y < 0.02:
		hide_all()
		return
	var space := get_world_3d().direct_space_state
	var snapped_x := roundf(center.x / SPACING) * SPACING
	var snapped_z := roundf(center.z / SPACING) * SPACING
	_origin_snap = Vector2(snapped_x, snapped_z)
	var half := GRID / 2
	for ix in GRID:
		for iz in GRID:
			var i := ix * GRID + iz
			var x := snapped_x + (ix - half) * SPACING
			var z := snapped_z + (iz - half) * SPACING
			var dist := Vector2(x - center.x, z - center.z).length()
			var color := Color(0, 0, 0, 0)
			var xf := Transform3D(Basis().scaled(Vector3.ZERO), Vector3.ZERO)
			if dist < RADIUS:
				var down := PhysicsRayQueryParameters3D.create(Vector3(x, center.y + 1.5, z), Vector3(x, center.y - 4.0, z), 1)
				var hit := space.intersect_ray(down)
				if not hit.is_empty():
					var p: Vector3 = hit["position"]
					var up := PhysicsRayQueryParameters3D.create(p + Vector3(0, 0.4, 0), p + Vector3(0, 0.4, 0) + to_sun * 60.0, SUN_MASK)
					if space.intersect_ray(up).is_empty():
						var fade := 1.0 - smoothstep(RADIUS * 0.45, RADIUS, dist)
						color = Color(1.0, 0.5, 0.14, (0.16 + 0.34 * intensity) * fade)
						xf = Transform3D(Basis(), p + Vector3(0, 0.07, 0))
			_mm.set_instance_color(i, color)
			_mm.set_instance_transform(i, xf)
			tile_alpha[i] = color.a
