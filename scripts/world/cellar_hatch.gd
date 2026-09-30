class_name CellarHatch
extends Node3D
## Placeholder payoff for the buried key: proves "blood -> knowledge -> action" closes a loop.
## What lies below is deliberately out of scope for the prototype.

@onready var interactable: Interactable = $Interactable


func _ready() -> void:
	interactable.interacted.connect(_on_used)
	Greybox.box(self, Vector3(0, 0.05, 0), Vector3(1.5, 0.1, 1.5), Color(0.22, 0.15, 0.1), Greybox.WORLD, "Hatch")
	Greybox.decal(self, Vector3(0, 0.11, 0), Vector3(1.55, 0.02, 0.14), Color(0.12, 0.12, 0.13))
	Greybox.decal(self, Vector3(0, 0.11, 0), Vector3(0.14, 0.02, 1.55), Color(0.12, 0.12, 0.13))


func get_interaction_prompt() -> String:
	return "Unlock the cellar hatch" if SecretStash.key_held else "Iron hatch (locked)"


func _on_used(_actor: Player) -> void:
	var hud := get_tree().get_first_node_in_group(&"hud") as Hud
	if hud == null:
		return
	if SecretStash.key_held:
		Sfx.play(&"secret")
		hud.toast("The key turns. Cold air breathes up from below. (The cellar is beyond this prototype.)", Color(1.0, 0.85, 0.4), 6.0)
	else:
		Sfx.play(&"deny", -6.0)
		hud.toast("The hatch is locked. Someone hid the key.", Color(0.85, 0.8, 0.8), 3.5)
