extends Node
## Shared helpers for the scripted playthrough tests (smoke_test.gd, scenario_tests.gd).

var main: Main
var player: Player
var world: WorldBuilder
var out_dir := ""
var checks := 0
var failures := 0


func _check(cond: bool, msg: String) -> void:
	checks += 1
	if cond:
		print("[TEST] PASS  ", msg)
	else:
		failures += 1
		print("[TEST] FAIL  ", msg)


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _tap(action: StringName) -> void:
	# Press at the START of a frame (before nodes' _process) so is_action_just_pressed sees it,
	# exactly like a real key event.
	await get_tree().process_frame
	Input.action_press(action)
	await get_tree().process_frame
	await get_tree().process_frame
	Input.action_release(action)
	await get_tree().process_frame


func _shot(shot_name: String) -> void:
	if out_dir == "" or DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png("%s/%s.png" % [out_dir, shot_name])


func _place(pos: Vector3, yaw_deg: float) -> void:
	player.place_at(pos, deg_to_rad(yaw_deg))


func _face(target: Vector3) -> void:
	var d := target - player.global_position
	player.camera_rig.yaw = atan2(-d.x, -d.z)


func _prompt() -> String:
	var it := player.interactor.focused
	return it.get_prompt(player) if it != null else "none"


## Sprint toward `target` until something is interactable (or timeout). Returns elapsed time.
func _run_until_focus(target: Vector3, timeout: float, sprint := true) -> float:
	var t := 0.0
	if sprint:
		Input.action_press(&"sprint")
	Input.action_press(&"move_forward")
	while t < timeout:
		_face(target)
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
		if player.interactor.focused != null:
			break
	Input.action_release(&"move_forward")
	Input.action_release(&"sprint")
	return t


func _run_to(target: Vector3, dist: float, timeout: float) -> void:
	var t := 0.0
	Input.action_press(&"sprint")
	Input.action_press(&"move_forward")
	while t < timeout:
		_face(target)
		var flat := Vector2(target.x - player.global_position.x, target.z - player.global_position.z)
		if flat.length() < dist:
			break
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
	Input.action_release(&"move_forward")
	Input.action_release(&"sprint")


func _become_vampire() -> void:
	player.form.request_form(&"vampire")
	await _wait(player.form.transform_time + 0.3)


