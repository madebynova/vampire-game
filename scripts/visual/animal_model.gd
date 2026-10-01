class_name AnimalModel
extends Node3D
## Procedural primitive four-legged animal (a fox), in the same blocky style as HumanoidModel. Faces -Z.
## Prototype art: a readable silhouette that walks, bolts, sleeps curled up and goes limp when drunk from.

var body: Node3D
var _legs: Array[Node3D] = []
var _head: Node3D
var _tail: Node3D
var _mats: Dictionary = {}
var _phase := 0.0
## 0..1: curled up asleep. 0..1: limp (being drunk from).
var asleep := 0.0
var limp := 0.0


func _init() -> void:
	body = Node3D.new()
	body.name = "Body"
	add_child(body)


## Build and colour the animal from its profile. `scale` sizes the whole creature.
func setup(fur: Color, belly: Color, tail_tip: Color, dark: Color, body_scale := 1.0) -> void:
	_mats = {"fur": _mat(fur), "belly": _mat(belly), "tip": _mat(tail_tip), "dark": _mat(dark), "eye": _mat(Color(0.95, 0.75, 0.2), 1.5)}
	_box(body, Vector3(0, 0.34, 0), Vector3(0.26, 0.24, 0.62), "fur")
	_box(body, Vector3(0, 0.27, -0.02), Vector3(0.2, 0.14, 0.5), "belly")
	_head = Node3D.new()
	_head.position = Vector3(0, 0.42, -0.34)
	body.add_child(_head)
	_box(_head, Vector3.ZERO, Vector3(0.2, 0.18, 0.2), "fur")
	_box(_head, Vector3(0, -0.03, -0.14), Vector3(0.1, 0.08, 0.14), "fur")
	_box(_head, Vector3(0, -0.01, -0.215), Vector3(0.04, 0.04, 0.03), "dark")
	for side in [-1.0, 1.0]:
		var ear := _box(_head, Vector3(0.07 * side, 0.14, 0.02), Vector3(0.06, 0.12, 0.04), "dark")
		ear.rotation.z = -0.15 * side
		_box(_head, Vector3(0.05 * side, 0.03, -0.1), Vector3(0.03, 0.03, 0.02), "eye")
	_tail = Node3D.new()
	_tail.position = Vector3(0, 0.38, 0.3)
	body.add_child(_tail)
	_box(_tail, Vector3(0, 0.0, 0.2), Vector3(0.13, 0.13, 0.36), "fur")
	_box(_tail, Vector3(0, 0.0, 0.43), Vector3(0.12, 0.12, 0.12), "tip")
	_tail.rotation.x = 0.35
	for lx in [-0.09, 0.09]:
		for lz in [-0.22, 0.22]:
			var leg := Node3D.new()
			leg.position = Vector3(lx, 0.24, lz)
			body.add_child(leg)
			_box(leg, Vector3(0, -0.11, 0), Vector3(0.06, 0.22, 0.06), "dark")
			_legs.append(leg)
	scale = Vector3.ONE * body_scale


func _mat(c: Color, glow := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.9
	if glow > 0.0:
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = glow
	return m


func _box(parent: Node3D, pos: Vector3, size: Vector3, mat_key: String) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = _mats[mat_key]
	mi.position = pos
	parent.add_child(mi)
	return mi


## Walk / run cycle. `speed` in m/s.
func animate(speed: float, delta: float) -> void:
	var moving := clampf(speed / 2.0, 0.0, 1.0)
	_phase += delta * (3.0 + speed * 2.4)
	var s := sin(_phase)
	var amp := 0.55 * moving
	_legs[0].rotation.x = s * amp
	_legs[1].rotation.x = -s * amp
	_legs[2].rotation.x = -s * amp
	_legs[3].rotation.x = s * amp
	body.position.y = absf(cos(_phase)) * 0.03 * moving - 0.1 * asleep
	# The tail streams out when it runs, droops when it sleeps, and flicks when it idles.
	var run := clampf(speed / 6.0, 0.0, 1.0)
	_tail.rotation.x = lerpf(0.35, -0.05, run) + sin(_phase * 0.5) * 0.08 + asleep * 0.4
	_tail.rotation.y = sin(_phase * 0.25) * 0.25 * (1.0 - moving) + asleep * 0.9
	_head.rotation.x = lerpf(0.0, -0.25, run) + asleep * 0.5 + limp * 0.4
	body.scale = Vector3(1.0, 1.0 - 0.3 * asleep, 1.0 + 0.1 * asleep)
	body.rotation.z = limp * 1.3


func head_position() -> Vector3:
	return _head.global_position
