class_name HumanoidModel
extends Node3D
## Procedural primitive humanoid used by the player and NPCs. Faces -Z.
## Prototype art: readable silhouette + a look that can be re-skinned per form.

var body: Node3D
var _leg_l: Node3D
var _leg_r: Node3D
var _arm_l: Node3D
var _arm_r: Node3D
var _head: Node3D
var _cloak: Node3D
var _fangs: Node3D
var _mat_skin := StandardMaterial3D.new()
var _mat_cloth := StandardMaterial3D.new()
var _mat_pants := StandardMaterial3D.new()
var _mat_hair := StandardMaterial3D.new()
var _mat_eye := StandardMaterial3D.new()
var _mat_cloak := StandardMaterial3D.new()
var _phase := 0.0
var _flare := 0.0


func _init() -> void:
	body = Node3D.new()
	body.name = "Body"
	add_child(body)
	for m in [_mat_skin, _mat_cloth, _mat_pants, _mat_hair, _mat_cloak]:
		m.roughness = 0.85
	_mat_eye.emission_enabled = true
	_build()


func _build() -> void:
	_leg_l = _limb(Vector3(-0.11, 0.86, 0.0), 0.09, 0.86, _mat_pants, false)
	_leg_r = _limb(Vector3(0.11, 0.86, 0.0), 0.09, 0.86, _mat_pants, false)
	_arm_l = _limb(Vector3(-0.29, 1.42, 0.0), 0.065, 0.62, _mat_cloth, true)
	_arm_r = _limb(Vector3(0.29, 1.42, 0.0), 0.065, 0.62, _mat_cloth, true)

	var torso := MeshInstance3D.new()
	var tm := CapsuleMesh.new()
	tm.radius = 0.2
	tm.height = 0.68
	torso.mesh = tm
	torso.material_override = _mat_cloth
	torso.position = Vector3(0, 1.15, 0)
	torso.scale = Vector3(1.0, 1.0, 0.65)
	body.add_child(torso)

	_head = Node3D.new()
	_head.position = Vector3(0, 1.64, 0)
	body.add_child(_head)
	var head_mesh := MeshInstance3D.new()
	var hm := SphereMesh.new()
	hm.radius = 0.125
	hm.height = 0.25
	head_mesh.mesh = hm
	head_mesh.material_override = _mat_skin
	_head.add_child(head_mesh)
	var hair := MeshInstance3D.new()
	var hairm := SphereMesh.new()
	hairm.radius = 0.133
	hairm.height = 0.27
	hair.mesh = hairm
	hair.material_override = _mat_hair
	hair.position = Vector3(0, 0.025, 0.045)
	_head.add_child(hair)
	for side in [-1.0, 1.0]:
		var eye := MeshInstance3D.new()
		var em := SphereMesh.new()
		em.radius = 0.03
		em.height = 0.06
		eye.mesh = em
		eye.material_override = _mat_eye
		eye.position = Vector3(0.05 * side, 0.012, -0.106)
		_head.add_child(eye)
	_fangs = Node3D.new()
	_head.add_child(_fangs)
	for side in [-1.0, 1.0]:
		var fang := MeshInstance3D.new()
		var fm := CylinderMesh.new()
		fm.top_radius = 0.012
		fm.bottom_radius = 0.0
		fm.height = 0.05
		fm.radial_segments = 6
		fang.mesh = fm
		var white := StandardMaterial3D.new()
		white.albedo_color = Color(1, 1, 0.95)
		fang.material_override = white
		fang.position = Vector3(0.026 * side, -0.055, -0.108)
		_fangs.add_child(fang)

	_cloak = Node3D.new()
	_cloak.position = Vector3(0, 1.5, 0.13)
	body.add_child(_cloak)
	var cloak_mesh := MeshInstance3D.new()
	cloak_mesh.mesh = _cape_mesh()
	cloak_mesh.material_override = _mat_cloak
	_mat_cloak.cull_mode = BaseMaterial3D.CULL_DISABLED
	_cloak.add_child(cloak_mesh)


## Tapered, folded cape: narrow at the shoulders, flaring toward the ground, hanging from y=0.
func _cape_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var tl := Vector3(-0.24, 0.0, 0.0)
	var tm := Vector3(0.0, 0.02, 0.03)
	var tr := Vector3(0.24, 0.0, 0.0)
	var bl := Vector3(-0.52, -1.25, 0.16)
	var bm := Vector3(0.0, -1.3, 0.3)
	var br := Vector3(0.52, -1.25, 0.16)
	for tri in [[tl, bl, bm], [tl, bm, tm], [tm, bm, br], [tm, br, tr]]:
		for v in tri:
			st.add_vertex(v)
	st.generate_normals()
	return st.commit()


func _limb(pivot_pos: Vector3, radius: float, length: float, mat: StandardMaterial3D, with_hand: bool) -> Node3D:
	var pivot := Node3D.new()
	pivot.position = pivot_pos
	body.add_child(pivot)
	var mi := MeshInstance3D.new()
	var cap := CapsuleMesh.new()
	cap.radius = radius
	cap.height = length
	mi.mesh = cap
	mi.material_override = mat
	mi.position = Vector3(0, -length * 0.5, 0)
	pivot.add_child(mi)
	if with_hand:
		var hand := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.06
		sm.height = 0.12
		hand.mesh = sm
		hand.material_override = _mat_skin
		hand.position = Vector3(0, -length - 0.02, 0)
		pivot.add_child(hand)
	return pivot


## Re-skin. `show_cloak`/`show_fangs`/`eye_glow` make the vampire form read at a glance.
func apply_look(skin: Color, cloth: Color, pants: Color, hair: Color, eye: Color, eye_glow: float, show_cloak: bool, show_fangs: bool) -> void:
	_mat_skin.albedo_color = skin
	_mat_cloth.albedo_color = cloth
	_mat_pants.albedo_color = pants
	_mat_hair.albedo_color = hair
	_mat_cloak.albedo_color = cloth.darkened(0.3)
	_mat_eye.albedo_color = eye
	_mat_eye.emission = eye
	_mat_eye.emission_energy_multiplier = eye_glow
	_cloak.visible = show_cloak
	_fangs.visible = show_fangs


## Procedural walk cycle. `speed` in m/s.
func animate(speed: float, on_floor: bool, delta: float) -> void:
	var moving := clampf(speed / 3.5, 0.0, 1.0)
	_phase += delta * (4.0 + speed * 1.15)
	var amp := 0.9 * moving
	if on_floor:
		var s := sin(_phase)
		_leg_l.rotation.x = s * amp
		_leg_r.rotation.x = -s * amp
		_arm_l.rotation.x = -s * amp * 0.8
		_arm_r.rotation.x = s * amp * 0.8
		body.position.y = absf(cos(_phase)) * 0.045 * moving
	else:
		_leg_l.rotation.x = lerpf(_leg_l.rotation.x, 0.5, delta * 10.0)
		_leg_r.rotation.x = lerpf(_leg_r.rotation.x, -0.3, delta * 10.0)
		_arm_l.rotation.x = lerpf(_arm_l.rotation.x, -1.0, delta * 10.0)
		_arm_r.rotation.x = lerpf(_arm_r.rotation.x, -1.0, delta * 10.0)
	_flare = lerpf(_flare, clampf(speed * 0.085, 0.0, 0.85), delta * 6.0)
	_cloak.rotation.x = _flare + (0.5 if not on_floor else 0.0) + sin(_phase * 0.5) * 0.04 * moving


## Arms out in front (feeding grab pose / reaching).
func set_arms_forward(amount: float) -> void:
	_arm_l.rotation.x = -1.4 * amount
	_arm_r.rotation.x = -1.4 * amount


func head_position() -> Vector3:
	return _head.global_position
