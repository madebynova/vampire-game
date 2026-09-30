class_name SecretStash
extends Node3D
## A hidden thing in the world. Invisible to everyone until blood tells the vampire about it
## (SecretStash.reveal). Then Vampiric Sense shows exactly where it is, and it can be dug up.
## This is the prototype's "blood is information -> new way to act on the world" loop.

@export var secret_id: StringName = &"well_key"
@export var label := "Buried: cellar key"
@export var reveal_text := "Blood memory: something is buried beneath the well. Vampiric Sense will show where."
@export var found_text := "You dig up a rusted iron key. It belongs to the cellar hatch inside the house."

## The cellar hatch checks this. Knowledge of the key survives a night's rest.
static var key_held := false

@onready var interactable: Interactable = $Interactable

var discovered := false
var looted := false
var _stone: MeshInstance3D


func _ready() -> void:
	add_to_group(&"secrets")
	interactable.prompt_text = "Dig up the buried key"
	interactable.interacted.connect(_on_dug)
	_stone = Greybox.decal(self, Vector3(0, 0.03, 0), Vector3(0.9, 0.06, 0.9), Color(0.38, 0.37, 0.36))


func reveal(id: StringName) -> void:
	if id != secret_id or discovered:
		return
	discovered = true
	var hud := get_tree().get_first_node_in_group(&"hud") as Hud
	if hud:
		hud.toast(reveal_text, Color(1.0, 0.8, 0.3), 6.5)
	Sfx.play(&"secret", -6.0)


func new_day() -> void:
	looted = false
	key_held = false
	_stone.position.y = 0.03


func _on_dug(_actor: Player) -> void:
	if looted:
		return
	looted = true
	key_held = true
	var tw := create_tween()
	tw.tween_property(_stone, "position:y", 0.35, 0.5)
	Sfx.play(&"secret")
	var hud := get_tree().get_first_node_in_group(&"hud") as Hud
	if hud:
		hud.toast(found_text, Color(1.0, 0.85, 0.4), 6.0)


# Interactable is a child; it asks its parent for availability through this hook.
func is_interaction_available() -> bool:
	return discovered and not looted


func is_sense_visible() -> bool:
	return discovered and not looted


func get_sense_data() -> Dictionary:
	return {"label": label, "color": Color(1.0, 0.72, 0.15), "bpm": 0.0}
