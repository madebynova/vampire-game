extends Node
## Autoload: one place that decides whether the world is frozen. Several things want to stop the
## simulation (the pause menu, a Blood Memory); each asks with its own reason and releases it when
## done, so one closing never unpauses the other. Nodes that must keep running while frozen
## (menus, the memory view, screen effects) use Node.PROCESS_MODE_ALWAYS.
## While frozen nothing advances: NPCs, the clock, sunlight, blood drain, abilities.

signal changed(is_paused: bool)

var _reasons: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func request(reason: StringName) -> void:
	var was := is_paused()
	_reasons[reason] = true
	_apply(was)


func release(reason: StringName) -> void:
	var was := is_paused()
	_reasons.erase(reason)
	_apply(was)


func has_reason(reason: StringName) -> bool:
	return _reasons.has(reason)


func is_paused() -> bool:
	return not _reasons.is_empty()


## Drop every reason (scene changes, tests).
func clear() -> void:
	var was := is_paused()
	_reasons.clear()
	_apply(was)


func _apply(was: bool) -> void:
	var now := is_paused()
	if get_tree():
		get_tree().paused = now
	if now:
		Engine.time_scale = 1.0   # a hit-stop must never survive into a menu
	if now != was:
		changed.emit(now)
