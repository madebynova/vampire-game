class_name Interactor
extends PlayerComponent
## Finds the best Interactable in front of the player and runs press / hold interaction.

signal focus_changed(interactable: Interactable)

@export var scan_interval := 0.08

var focused: Interactable
var hold_progress := 0.0
var _scan_timer := 0.0
var _wait_release := false


func _process(delta: float) -> void:
	if not player.state.can_act():
		_clear()
		return
	_scan_timer -= delta
	if _scan_timer <= 0.0:
		_scan_timer = scan_interval
		_rescan()
	if focused == null:
		hold_progress = 0.0
		return

	var action := focused.get_action(player)
	var pressed := Input.is_action_pressed(action)
	if not pressed:
		_wait_release = false
	var hold_time := focused.get_hold_time(player)
	if hold_time <= 0.0:
		if Input.is_action_just_pressed(action):
			focused.interact(player)
		return
	if pressed and not _wait_release:
		hold_progress += delta / hold_time
		if hold_progress >= 1.0:
			hold_progress = 0.0
			_wait_release = true
			focused.interact(player)
	else:
		hold_progress = maxf(hold_progress - delta * 4.0 / hold_time, 0.0)


## Forget what was in focus and look again at once (after the player is moved somewhere else).
func reset_focus() -> void:
	_clear()
	_scan_timer = 0.0
	_wait_release = false


func _clear() -> void:
	hold_progress = 0.0
	if focused != null:
		focused = null
		focus_changed.emit(null)


func _rescan() -> void:
	var cam_forward := -Basis(Vector3.UP, player.camera_rig.yaw).z
	var best: Interactable = null
	var best_score := INF
	for node in get_tree().get_nodes_in_group(&"interactables"):
		var it := node as Interactable
		if it == null or not it.is_on_level_with(player):
			continue
		var to := it.global_position - player.global_position
		to.y = 0.0
		var dist := to.length()
		if dist > it.interact_range:
			continue
		var facing := cam_forward.dot(to.normalized()) if dist > 0.05 else 1.0
		if dist > 1.0 and facing < 0.15:
			continue
		# Availability last: some checks (a traversal's landing spot) cost a physics query.
		if not it.is_available(player):
			continue
		var score := dist - facing
		if score < best_score:
			best_score = score
			best = it
	if best != focused:
		hold_progress = 0.0
		focused = best
		focus_changed.emit(best)
