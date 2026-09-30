class_name SecretStash
extends Node3D
## A hidden thing in the world, configured from a SecretPlacement. Invisible to everyone until
## blood tells the vampire about it (reveal). Then Vampiric Sense shows exactly where it is,
## and it can be searched. Finding it may set a world flag other objects react to.

## World flags set by finding secrets (SecretPlacement.grants_flag). Cleared each night.
static var flags: Dictionary = {}

static func has_flag(flag: StringName) -> bool:
	return flags.has(flag)

@export var placement: SecretPlacement

@onready var interactable: Interactable = $Interactable

var secret_id: StringName = &""
var discovered := false
var looted := false
var _stone: MeshInstance3D


func _ready() -> void:
	add_to_group(&"secrets")
	secret_id = placement.secret_id
	interactable.prompt_text = placement.prompt
	interactable.interacted.connect(_on_dug)
	_stone = Greybox.decal(self, Vector3(0, 0.03, 0), Vector3(0.9, 0.06, 0.9), Color(0.38, 0.37, 0.36))


func reveal(id: StringName) -> void:
	if id != secret_id or discovered:
		return
	discovered = true
	var hud := get_tree().get_first_node_in_group(&"hud") as Hud
	if hud:
		hud.toast(placement.reveal_text, Color(1.0, 0.8, 0.3), 6.5)
	Sfx.play(&"secret", -6.0)


func new_day() -> void:
	looted = false
	if placement.grants_flag != &"":
		flags.erase(placement.grants_flag)
	_stone.position.y = 0.03


func _on_dug(_actor: Player) -> void:
	if looted:
		return
	looted = true
	if placement.grants_flag != &"":
		flags[placement.grants_flag] = true
	create_tween().tween_property(_stone, "position:y", 0.35, 0.5)
	Sfx.play(&"secret")
	var hud := get_tree().get_first_node_in_group(&"hud") as Hud
	if hud:
		hud.toast(placement.found_text, Color(1.0, 0.85, 0.4), 7.0)


# Interactable asks its parent for availability.
func is_interaction_available() -> bool:
	return discovered and not looted


func is_sense_visible() -> bool:
	return discovered and not looted


func get_sense_data(_dist := 0.0) -> Dictionary:
	return {"label": placement.sense_label, "color": Color(1.0, 0.72, 0.15), "bpm": 0.0}
