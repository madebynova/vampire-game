class_name HunterGear
extends RefCounted
## What makes a hunter read as a hunter at a glance, even as a shape against the dark: a wide-brimmed hat, a long
## coat that flares at the knee, a lantern held out in the left hand (the thing you see first, from far away) and a
## silvered blade at the right. Built from the same primitives as everyone else. `dress()` returns the bits the
## hunter animates: the lantern, its light and flame, the blade.

const IRON := Color(0.08, 0.08, 0.09)
const SILVER := Color(0.82, 0.86, 0.95)


static func _mat(color: Color, emissive := 0.0, metallic := 0.0, roughness := 0.9) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	m.metallic = metallic
	if emissive > 0.0:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = emissive
	return m


static func _mesh(parent: Node3D, mesh: Mesh, mat: Material, pos: Vector3, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	parent.add_child(mi)
	return mi


## Dress `model` for `profile`. Returns {lantern, light, flame, blade, hat, coat}.
static func dress(model: HumanoidModel, profile: HunterProfile) -> Dictionary:
	var out := {}
	# The hat: a wide brim and a tall soft crown, tipped slightly forward.
	var head := model.head_node()
	var hat := Node3D.new()
	hat.name = "Hat"
	hat.position = Vector3(0, 0.1, 0.01)
	hat.rotation.x = deg_to_rad(-6.0)
	head.add_child(hat)
	var hat_mat := _mat(profile.hat_color)
	var brim := CylinderMesh.new()
	brim.top_radius = 0.31
	brim.bottom_radius = 0.31
	brim.height = 0.025
	brim.radial_segments = 14
	_mesh(hat, brim, hat_mat, Vector3.ZERO)
	var crown := CylinderMesh.new()
	crown.top_radius = 0.11
	crown.bottom_radius = 0.145
	crown.height = 0.2
	crown.radial_segments = 12
	_mesh(hat, crown, hat_mat, Vector3(0, 0.1, 0))
	var band := CylinderMesh.new()
	band.top_radius = 0.147
	band.bottom_radius = 0.149
	band.height = 0.035
	band.radial_segments = 12
	_mesh(hat, band, _mat(Color(0.35, 0.05, 0.05)), Vector3(0, 0.035, 0))
	out["hat"] = hat

	# The coat: tapered, to the knee, wider at the hem than the shoulder.
	var coat := CylinderMesh.new()
	coat.top_radius = 0.22
	coat.bottom_radius = 0.37
	coat.height = 0.86
	coat.radial_segments = 8
	var coat_node := _mesh(model.body, coat, _mat(profile.coat_color), Vector3(0, 0.86, 0.0))
	coat_node.scale = Vector3(1.0, 1.0, 0.8)
	out["coat"] = coat_node
	var collar := CylinderMesh.new()
	collar.top_radius = 0.19
	collar.bottom_radius = 0.2
	collar.height = 0.12
	collar.radial_segments = 8
	_mesh(model.body, collar, _mat(profile.coat_color.darkened(0.2)), Vector3(0, 1.5, 0.0))

	# The lantern, held out from the left hand: a cage round a flame, with a ring to carry it by.
	var lantern := Node3D.new()
	lantern.name = "Lantern"
	model.hand_slot(false).add_child(lantern)
	var ring := TorusMesh.new()
	ring.inner_radius = 0.035
	ring.outer_radius = 0.05
	_mesh(lantern, ring, _mat(IRON), Vector3(0, -0.02, 0), Vector3(PI * 0.5, 0, 0))
	var cage := BoxMesh.new()
	cage.size = Vector3(0.13, 0.19, 0.13)
	_mesh(lantern, cage, _mat(IRON), Vector3(0, -0.16, 0))
	var flame_mesh := BoxMesh.new()
	flame_mesh.size = Vector3(0.1, 0.15, 0.1)
	var flame := _mesh(lantern, flame_mesh, _mat(Color(1.0, 0.7, 0.28), 5.0), Vector3(0, -0.16, 0))
	flame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var cap := CylinderMesh.new()
	cap.top_radius = 0.0
	cap.bottom_radius = 0.09
	cap.height = 0.07
	cap.radial_segments = 4
	_mesh(lantern, cap, _mat(IRON), Vector3(0, -0.045, 0))
	var light := OmniLight3D.new()
	light.position = Vector3(0, -0.16, 0)
	light.light_color = Color(1.0, 0.72, 0.4)
	light.light_energy = 1.7
	light.omni_range = 10.0
	light.shadow_enabled = true
	light.shadow_bias = 0.05
	lantern.add_child(light)
	out["lantern"] = lantern
	out["light"] = light
	out["flame"] = flame

	# The blade, down along the right arm: a grip, a guard, a long silvered edge.
	var blade_root := Node3D.new()
	blade_root.name = "Blade"
	model.hand_slot(true).add_child(blade_root)
	var grip := BoxMesh.new()
	grip.size = Vector3(0.04, 0.14, 0.04)
	_mesh(blade_root, grip, _mat(Color(0.22, 0.12, 0.08)), Vector3(0, 0.01, 0))
	var guard := BoxMesh.new()
	guard.size = Vector3(0.24, 0.03, 0.05)
	_mesh(blade_root, guard, _mat(IRON, 0.0, 0.6, 0.4), Vector3(0, -0.07, 0))
	var edge := BoxMesh.new()
	edge.size = Vector3(0.055, 0.7, 0.014)
	var silver := _mat(SILVER, 0.5, 0.9, 0.25)
	_mesh(blade_root, edge, silver, Vector3(0, -0.43, 0))
	out["blade"] = blade_root
	return out
