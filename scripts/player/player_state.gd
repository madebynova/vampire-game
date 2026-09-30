class_name PlayerState
extends PlayerComponent
## High-level "what is the player doing" mode. Gates movement, interaction and abilities.

## TRAVERSING: sliding through a window / up a ledge. MEMORY: lost in a Blood Memory (world frozen).
enum Mode { NORMAL, TRANSFORMING, FEEDING, RESTING, DEAD, TRAVERSING, MEMORY }

signal mode_changed(old_mode: Mode, new_mode: Mode)

var mode: Mode = Mode.NORMAL


func _on_setup() -> void:
	player.health.died.connect(func(_cause): set_mode(Mode.DEAD))


func set_mode(new_mode: Mode) -> void:
	if new_mode == mode:
		return
	var old := mode
	mode = new_mode
	mode_changed.emit(old, new_mode)


func can_control_movement() -> bool:
	return mode == Mode.NORMAL


func can_act() -> bool:
	return mode == Mode.NORMAL


func is_dead() -> bool:
	return mode == Mode.DEAD
