class_name Inspectable
extends Node3D
## A small thing to read in the world (InspectPlacement): offered to anyone, Human or Vampire, and it only
## ever gives a line of text. Reading it again repeats the line; what you have read is remembered so the
## prompt can say so. It is the lightest possible kind of environmental storytelling - a clue that
## agrees (or disagrees) with what someone told you.

## Which clues have been read this game: id -> true. Cleared when a game starts (Main).
static var read_ids: Dictionary = {}

signal inspected(placement: InspectPlacement)

@export var placement: InspectPlacement

var interactable: Interactable


static func reset() -> void:
	read_ids.clear()


func _ready() -> void:
	add_to_group(&"inspectables")
	name = "Inspect_%s" % placement.id
	interactable = Interactable.new()
	interactable.interact_range = 2.0
	interactable.reach_up = 1.8
	interactable.position = Vector3.ZERO
	add_child(interactable)
	interactable.interacted.connect(_on_read)
	if placement.mark_size != Vector2.ZERO:
		var mark := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(placement.mark_size.x, 0.012, placement.mark_size.y)
		mark.mesh = bm
		mark.material_override = Greybox.material(placement.mark_color)
		mark.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mark.position = Vector3(0, -0.12, 0)
		add_child(mark)


## The Interactable asks its parent for the prompt text.
func get_interaction_prompt() -> String:
	return "%s%s" % [placement.prompt, "  (read)" if read_ids.has(placement.id) else ""]


func has_been_read() -> bool:
	return read_ids.has(placement.id)


func _on_read(_actor: Player) -> void:
	read_ids[placement.id] = true
	var hud := get_tree().get_first_node_in_group(&"hud") as Hud
	if hud != null:
		hud.toast(placement.text, Color(0.95, 0.9, 0.78), clampf(3.0 + placement.text.length() * 0.045, 5.0, 11.0))
	Sfx.play(&"blip", -8.0, 0.8)
	inspected.emit(placement)
