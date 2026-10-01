class_name Interactable
extends Node3D
## Anything the Interactor can focus. Subclasses override the hooks; the Interactor only
## ever talks to this interface. Place the node where the prompt should anchor (e.g. chest height).

signal interacted(actor: Player)

@export var interact_range := 2.3
@export var prompt_text := "Interact"
## How far above / below the actor's feet this may sit (metres) and still be reachable. Range is measured
## on the ground plane, so without this a roof could "reach" the room beneath it (and a room, the roof).
@export var reach_up := 2.4
@export var reach_down := 1.6


func _ready() -> void:
	add_to_group(&"interactables")


## On the same level as the actor (not a floor above or below)?
func is_on_level_with(actor: Node3D) -> bool:
	var dy := global_position.y - actor.global_position.y
	return dy <= reach_up and dy >= -reach_down


## By default asks the parent (if it implements is_interaction_available()) so simple props
## don't need an Interactable subclass.
func is_available(_actor: Player) -> bool:
	var p := get_parent()
	if p and p.has_method(&"is_interaction_available"):
		return p.is_interaction_available()
	return true


func get_prompt(_actor: Player) -> String:
	var p := get_parent()
	if p and p.has_method(&"get_interaction_prompt"):
		return p.get_interaction_prompt()
	return prompt_text


## Which input action triggers this (and which glyph the prompt shows). Feeding uses &"feed".
func get_action(_actor: Player) -> StringName:
	return &"interact"


## Seconds the key must be held. 0 = instant on press.
func get_hold_time(_actor: Player) -> float:
	return 0.0


func interact(actor: Player) -> void:
	interacted.emit(actor)
