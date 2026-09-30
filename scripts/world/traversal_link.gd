class_name TraversalLink
extends Node3D
## A live route in the world, built from a TraversalPlacement: an interaction prompt at each end and
## a quiet Vampiric Sense presence (faint pale markers) so the routes are discoverable by the ones
## who can use them. All behaviour lives in TraversalController; this only wires data to the world.

var placement: TraversalPlacement
var ends: Array[TraversalInteractable] = []
## One Vampiric Sense presence per end (so each is found where it actually is).
var sense_targets: Array[SenseTarget] = []


## The Sense-visible body of one end of a route: a faint marker the overlay draws on, and the readout.
class RouteEnd extends Node3D:
	var link: TraversalLink

	func is_sense_visible() -> bool:
		return link.is_sense_visible()

	func get_sense_data(dist := 0.0) -> Dictionary:
		return link.get_sense_data(dist)


func setup(p: TraversalPlacement) -> void:
	placement = p
	name = "Traversal_%s" % p.id
	add_to_group(&"traversal_links")
	var window := p.type == TraversalPlacement.Type.WINDOW
	for i in 2:
		var it := TraversalInteractable.new()
		it.link = self
		it.end = i
		it.interact_range = 2.1
		it.position = p.end_position(i) + Vector3(0, 1.1, 0)
		add_child(it)
		ends.append(it)
		var node := RouteEnd.new()
		node.link = self
		node.position = p.end_position(i)
		add_child(node)
		# Invisible to the eye; the Sense overlay draws on it.
		var m := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.24
		sm.height = 0.48
		m.mesh = sm
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0, 0, 0, 0)
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.material_override = mat
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		m.position = Vector3(0, 1.3 if window else 0.9, 0)
		node.add_child(m)
		var st := SenseTarget.new()
		st.kind = &"route"
		st.max_range = 18.0
		st.label_range = 12.0
		st.sense_color = Color(0.72, 0.78, 1.0)
		st.label_offset = Vector3(0, 1.75 if window else 1.4, 0)
		node.add_child(st)
		sense_targets.append(st)


## The other end's feet position.
func destination_of(end: int) -> Vector3:
	return placement.end_position(1 - end)


# ---- Vampiric Sense hooks (the route as a whole)

func is_sense_visible() -> bool:
	var player := get_tree().get_first_node_in_group(&"player") as Player
	return player != null and player.form.current.traversal.has(String(placement.type_name()))


func get_sense_data(_dist := 0.0) -> Dictionary:
	return {"label": placement.sense_label, "title": placement.sense_label, "detail": "", "blood": "", "hint": "",
		"known": true, "state": &"calm", "color": Color(0.72, 0.78, 1.0), "bpm": 0.0}
