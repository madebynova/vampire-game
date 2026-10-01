class_name HumanoidModel
extends Node3D
## Procedural primitive humanoid used by the player and NPCs. Faces -Z.
## Prototype art: readable silhouette + a look that can be re-skinned per form.
##
## Rotation convention (Godot, right-handed): a positive rotation.x swings a hanging limb FORWARD (toward
## -Z, the way the model faces); a negative one swings it back. The cape hangs from the shoulders as a
## three-segment chain: each segment follows the one above with a lag, billows back with speed, and a
## cheap clearance pass keeps it behind the legs, so it follows the body without simulating cloth.

const CAPE_LEN := [0.5, 0.45, 0.4]
const CAPE_HALF_WIDTH := [[0.24, 0.34], [0.34, 0.43], [0.43, 0.52]]
const CAPE_BULGE := [0.07, 0.06, 0.1]
const CAPE_PIVOT := Vector2(0.13, 1.5)     ## (z, y) of the shoulders, in body space
const CAPE_CLEARANCE := 0.11               ## how far behind a leg's centre line the cloth stays
const TORSO_BACK := 0.15                   ## cloth stays this far behind the body's centre line
const HIP_HEIGHT := 0.86

var body: Node3D
var _leg_l: Node3D
var _leg_r: Node3D
var _arm_l: Node3D
var _arm_r: Node3D
var _head: Node3D
var _cloak: Node3D
var _cape: Array[Node3D] = []
var _cape_ang := PackedFloat32Array([0.0, 0.0, 0.0])   ## each segment's rotation.x, relative to the one above
var _fangs: Node3D
var _mat_skin := StandardMaterial3D.new()
var _mat_cloth := StandardMaterial3D.new()
var _mat_pants := StandardMaterial3D.new()
var _mat_hair := StandardMaterial3D.new()
var _mat_eye := StandardMaterial3D.new()
var _mat_cloak := StandardMaterial3D.new()
var _phase := 0.0
var _flare := 0.0
## 0..1: a "power pose" used by transformation - arms flung wide, torso arched back.
var pose_amount := 0.0
## 0..1: lying flat on the back (the coffin).
var lying := 0.0


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

	_mat_cloak.cull_mode = BaseMaterial3D.CULL_DISABLED
	_build_cape()


## The cape: three tapered, folded pieces hung one below the next, narrow at the shoulders and
## flaring toward the ground. Segment 0 hangs from the shoulders; `_cloak` is the whole chain's root.
func _build_cape() -> void:
	var parent: Node3D = body
	for i in 3:
		var seg := Node3D.new()
		seg.name = "Cape%d" % i
		if i == 0:
			seg.position = Vector3(0, CAPE_PIVOT.y, CAPE_PIVOT.x)
		else:
			seg.position = Vector3(0, -CAPE_LEN[i - 1], CAPE_BULGE[i - 1] * 1.6)
		parent.add_child(seg)
		var mi := MeshInstance3D.new()
		mi.mesh = _cape_piece(CAPE_HALF_WIDTH[i][0], CAPE_HALF_WIDTH[i][1], CAPE_LEN[i], CAPE_BULGE[i])
		mi.material_override = _mat_cloak
		seg.add_child(mi)
		_cape.append(seg)
		parent = seg
	_cloak = _cape[0]


## One folded strip hanging from y=0: `w0` half-width at the top, `w1` at the bottom, `bulge` how far the
## hem stands off the body (the middle fold stands off further).
func _cape_piece(w0: float, w1: float, length: float, bulge: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var tl := Vector3(-w0, 0.0, 0.0)
	var tm := Vector3(0.0, 0.0, 0.02)
	var tr := Vector3(w0, 0.0, 0.0)
	var bl := Vector3(-w1, -length, bulge)
	var bm := Vector3(0.0, -length, bulge * 1.6)
	var br := Vector3(w1, -length, bulge)
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
	if pose_amount > 0.001:
		_arm_l.rotation.z = lerpf(0.0, -1.25, pose_amount)
		_arm_r.rotation.z = lerpf(0.0, 1.25, pose_amount)
		_arm_l.rotation.x = lerpf(_arm_l.rotation.x, -0.3, pose_amount)
		_arm_r.rotation.x = lerpf(_arm_r.rotation.x, -0.3, pose_amount)
		_head.rotation.x = lerpf(0.0, 0.35, pose_amount)
	else:
		_arm_l.rotation.z = 0.0
		_arm_r.rotation.z = 0.0
		_head.rotation.x = 0.0
	_update_cape(delta, moving, not on_floor)


## Hands and feet finding the stone: arms reach high and alternate, knees drive up the wall, head tipped
## up. `phase` advances as the climb does. Used by the wall climb (TraversalController).
func climb_pose(phase: float, delta: float) -> void:
	var s := sin(phase)
	var c := cos(phase)
	var k := minf(1.0, 16.0 * delta)
	_arm_l.rotation.x = lerpf(_arm_l.rotation.x, 2.6 + 0.45 * s, k)
	_arm_r.rotation.x = lerpf(_arm_r.rotation.x, 2.6 - 0.45 * s, k)
	_arm_l.rotation.z = lerpf(_arm_l.rotation.z, -0.14, k)
	_arm_r.rotation.z = lerpf(_arm_r.rotation.z, 0.14, k)
	_leg_l.rotation.x = lerpf(_leg_l.rotation.x, 0.55 + 0.5 * c, k)
	_leg_r.rotation.x = lerpf(_leg_r.rotation.x, 0.55 - 0.5 * c, k)
	_head.rotation.x = lerpf(_head.rotation.x, 0.3, k)
	body.position.y = lerpf(body.position.y, 0.0, k)
	_flare = lerpf(_flare, 0.4, delta * 6.0)
	_update_cape(delta, 0.0, true)


# ---------------------------------------------------------------- the cape

## Billow with speed, trail behind, lag from the shoulders down - and never pass through a leg.
func _update_cape(delta: float, moving: float, airborne: bool) -> void:
	if not _cloak.visible:
		return
	var air := 1.0 if airborne else 0.0
	var targets := PackedFloat32Array([
		-(0.07 + 0.22 * _flare + 0.10 * air),
		-(0.10 + 0.34 * _flare + 0.10 * air) + sin(_phase * 0.5 + 1.0) * 0.04 * moving,
		-(0.14 + 0.46 * _flare + 0.18 * air) + sin(_phase * 0.5 + 2.0) * 0.07 * moving,
	])
	if pose_amount > 0.001:
		# Arched, arms flung wide: the cape streams out behind.
		for i in 3:
			targets[i] = lerpf(targets[i], -0.42, pose_amount)
	var follow := 1.0 - exp(-delta * 9.0)
	for i in 3:
		_cape_ang[i] = lerpf(_cape_ang[i], targets[i], follow * (1.0 - 0.18 * i))   # the hem lags the shoulders
	_settle_cape()
	for i in 3:
		_cape[i].rotation.x = _cape_ang[i]


## Back-most extent (z) of the legs at height `y`, in body space: a leg swung backward sweeps through
## the space the cloth hangs in. Above the hips it is the torso's back that matters.
func _leg_back(y: float) -> float:
	if y >= HIP_HEIGHT:
		return TORSO_BACK - CAPE_CLEARANCE   # (so `+ CAPE_CLEARANCE` below gives TORSO_BACK)
	var z := 0.0
	for leg in [_leg_l, _leg_r]:
		var th: float = leg.rotation.x
		if th < 0.0:
			z = maxf(z, -(HIP_HEIGHT - y) * tan(th))
	return z


## Forward kinematics of the chain in body space; any segment whose middle or tip would sit inside a leg
## (or the torso) is swung further back until it clears. A handful of multiplications a frame.
func _settle_cape() -> void:
	var cum := 0.0
	var pz := CAPE_PIVOT.x
	var py := CAPE_PIVOT.y
	for i in 3:
		var seg_len: float = CAPE_LEN[i]
		var prior := cum
		for _iter in 8:
			cum = prior + _cape_ang[i]
			var worst := 0.0
			for f: float in [0.25, 0.5, 0.75, 1.0]:
				var z := pz - sin(cum) * seg_len * f
				var y := py - cos(cum) * seg_len * f
				worst = maxf(worst, _leg_back(y) + CAPE_CLEARANCE - z)
			if worst <= 0.001:
				break
			_cape_ang[i] -= worst / seg_len * 1.2
		cum = prior + _cape_ang[i]
		var bulge: float = CAPE_BULGE[i] * 1.6
		pz += -sin(cum) * seg_len + bulge * cos(cum)
		py += -cos(cum) * seg_len - bulge * sin(cum)


## Test hook: the cloth's slack against the body over the whole chain, in metres. >= 0 means every sampled
## point of the cape is behind the legs (by their radius plus a small margin) and the torso; the clearance
## pass in _settle_cape() keeps it there. Strongly negative means the cape is through the body.
func cape_clearance() -> float:
	if not _cloak.visible:
		return 1.0
	var cum := 0.0
	var pz := CAPE_PIVOT.x
	var py := CAPE_PIVOT.y
	var slack := 1.0
	for i in 3:
		var seg_len: float = CAPE_LEN[i]
		cum += _cape_ang[i]
		for f: float in [0.25, 0.5, 0.75, 1.0]:
			var z := pz - sin(cum) * seg_len * f
			var y := py - cos(cum) * seg_len * f
			slack = minf(slack, z - (_leg_back(y) + CAPE_CLEARANCE))
		var bulge: float = CAPE_BULGE[i] * 1.6
		pz += -sin(cum) * seg_len + bulge * cos(cum)
		py += -cos(cum) * seg_len - bulge * sin(cum)
	return slack


## Test hook: where the cape's last segment tip is, in body space (z behind is positive).
func cape_tip() -> Vector2:
	var cum := 0.0
	var pz := CAPE_PIVOT.x
	var py := CAPE_PIVOT.y
	for i in 3:
		var seg_len: float = CAPE_LEN[i]
		cum += _cape_ang[i]
		pz += -sin(cum) * seg_len
		py += -cos(cum) * seg_len
	return Vector2(pz, py)


## Eye glow strength (transformation flares and fades it).
func set_eye_energy(v: float) -> void:
	_mat_eye.emission_energy_multiplier = v


## Arms out in front (feeding grab pose / reaching). A positive rotation.x swings a hanging arm forward.
func set_arms_forward(amount: float) -> void:
	_arm_l.rotation.x = 1.4 * amount
	_arm_r.rotation.x = 1.4 * amount


func head_position() -> Vector3:
	return _head.global_position
