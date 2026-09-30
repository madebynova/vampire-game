class_name PlayerComponent
extends Node
## Base for every self-contained player system. Player calls setup() once all
## components exist, so components may safely reach each other via `player`.

var player: Player


func setup(p: Player) -> void:
	player = p
	_on_setup()


func _on_setup() -> void:
	pass
