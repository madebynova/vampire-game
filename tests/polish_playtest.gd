extends "res://tests/test_base.gd"
## Task 1.8 manual-playtest driver: plays the new things in real time, windowed, with real input and real
## rendering, and photographs each step so the feel can be LOOKED at (it is not a substitute for playing
## with a controller in your hands).
##   godot --path . res://tests/polish_playtest.tscn -- <screenshot_dir>

var _only: PackedStringArray = PackedStringArray()


func _ready() -> void:
	GameSettings.persist = false
	for a in OS.get_cmdline_user_args():
		if a.begins_with("only="):
			_only = a.trim_prefix("only=").split(",")
		else:
			out_dir = a
	HumanNpc.schedules_enabled = false
	main = load("res://scenes/main.tscn").instantiate()
	main.capture_mouse = false
	add_child(main)
	player = main.player
	world = main.world
	main.tod.paused = true
	await _wait(3.0)
	await _run()
	get_tree().quit()


func _step(n: String) -> void:
	print("[PLAY] ", n)


## `-- <dir> only=fox,coffin` plays just those scenes: talk, hud, window, wall, fox, run, coffin, memory.
func _wants(scene: String) -> bool:
	return _only.is_empty() or _only.has(scene)


func _key(code: Key, pressed: bool) -> void:
	var ev := InputEventKey.new()
	ev.physical_keycode = code
	ev.keycode = code
	ev.pressed = pressed
	Input.parse_input_event(ev)


func _reset() -> void:
	for a in [&"feed", &"interact", &"sprint", &"move_forward", &"move_right", &"jump"]:
		Input.action_release(a)
	main.memory_view.force_close()
	PauseControl.clear()
	get_tree().call_group(&"npcs", &"new_day")
	get_tree().call_group(&"animals", &"new_day")
	world.corvin.global_position = Vector3(31, 0, 27)
	player.health.revive(1.0)
	player.sunlight.reset()
	player.abilities.deactivate_all()
	player.surge.stop(false)
	player.state.set_mode(PlayerState.Mode.NORMAL)
	player.visual.visible = true
	player.blood._set_value(60.0)
	main.hud._help.visible = false


func _stand_for(id: StringName, end: int, back := 0.6, facing_route := true) -> void:
	var p: TraversalPlacement
	for l in world.traversal_links:
		if l.placement.id == id:
			p = l.placement
	var start := p.end_position(end)
	var d := p.end_position(1 - end) - start
	d.y = 0.0
	d = d.normalized() if d.length() > 0.01 else Vector3.FORWARD
	var pos := start - d * back
	pos.y = start.y + 0.05
	var yaw := rad_to_deg(atan2(-d.x, -d.z))
	_place(pos, yaw if facing_route else yaw + 180.0)
	await _wait(0.5)


func _run() -> void:
	_reset()
	if _wants("talk"):
		# 1. Human by day: talk and learn something.
		_step("1. a Human talks to Tomas and learns something")
		main.tod.set_hour(13.0)
		player.form.set_form_immediate(&"human")
		_place(world.tomas.global_position + Vector3(-1.5, 0, 0), -90.0)
		player.camera_rig.pitch = -0.05
		await _wait(0.7)
		await _shot("a01_talk_prompt")
		await _tap(&"interact")
		await _wait(0.9)
		await _shot("a02_talk_learned")

	if _wants("hud"):
		# 2. Become a vampire at night: the HUD with the blood number.
		_step("2. the vampire's HUD: a number under the vessel")
		_reset()
		main.tod.set_hour(23.0)
		player.form.set_form_immediate(&"vampire")
		player.blood._set_value(73.0)
		_place(Vector3(3.0, 0, 2.0), 180.0)
		await _wait(2.2)
		await _shot("b01_hud_73")
		player.blood._set_value(18.0)
		await _wait(2.0)
		await _shot("b02_hud_hungry")
		player.blood._set_value(80.0)

	if _wants("window"):
		# 3. A window, both ways.
		_step("3. the manor window")
		_reset()
		player.form.set_form_immediate(&"vampire")
		player.blood._set_value(90.0)
		await _stand_for(&"manor_window", 0)
		await _tap(&"vampiric_sense")
		await _wait(2.4)
		await _shot("c01_window_outside_sense")
		await _tap(&"vampiric_sense")
		await _tap(&"interact")
		await _wait(0.45)
		await _shot("c02_window_mid")
		await _wait(1.0)
		await _shot("c03_window_inside")
		await _tap(&"interact")
		await _wait(1.3)
		await _shot("c04_inside_mash_stays_in")
		await _stand_for(&"manor_window", 1)
		await _shot("c05_inside_facing_window")
		await _tap(&"interact")
		await _wait(1.4)
		await _shot("c06_back_outside")

	if _wants("wall"):
		# 4. The wall climb.
		_step("4. scale the manor wall")
		_reset()
		player.form.set_form_immediate(&"vampire")
		player.blood._set_value(90.0)
		await _stand_for(&"manor_roof", 0, 1.4)
		player.camera_rig.pitch = -0.02
		player.camera_rig.yaw += 0.5
		await _tap(&"vampiric_sense")
		await _wait(2.4)
		await _shot("d01_wall_sense")
		await _tap(&"vampiric_sense")
		await _wait(0.2)
		await _shot("d02_wall_prompt")
		await _tap(&"interact")
		for i in 4:
			await _wait(0.33)
			await _shot("d03_climb_%d" % i)
		await _wait(0.8)
		await _shot("d04_on_the_roof")
		# The broken roof: face the hole, offered the drop; walk at the rim, held back.
		_place(Vector3(6.55, 3.9, -10.6), 0.0)
		player.camera_rig.pitch = -0.4
		await _wait(0.8)
		await _shot("d05_roof_hole_prompt")
		Input.action_press(&"move_forward")
		await _wait(1.0)
		Input.action_release(&"move_forward")
		await _shot("d06_rim_holds")

	if _wants("fox"):
		# 5. The fox.
		_step("5. the fox")
		_reset()
		main.tod.set_hour(23.0)
		player.form.set_form_immediate(&"vampire")
		player.blood._set_value(40.0)
		_place(Vector3(19.0, 0, 2.0), 180.0)
		player.camera_rig.pitch = -0.1
		await _tap(&"vampiric_sense")
		await _wait(2.6)
		await _shot("e01_fox_sense")
		await _tap(&"vampiric_sense")
		main.tod.set_hour(13.0)
		get_tree().call_group(&"animals", &"new_day")
		_place(Vector3(19.0, 0, 7.3), 180.0)
		await _wait(0.8)
		await _shot("e02_fox_asleep_prompt")
		Input.action_press(&"feed")
		await _wait(1.6)
		await _shot("e03_fox_feeding")
		await _wait(1.6)
		Input.action_release(&"feed")
		await _wait_memory(3.0)
		await _wait(19.0)
		await _shot("e04_fox_memory_reward")
		await _dismiss_memory()
		await _wait(0.8)
		await _shot("e05_after_fox_rush_hud")

	if _wants("run"):
		# 6. Running with the cape, seen from the side.
		_step("6. running with the cape")
		_reset()
		main.tod.set_hour(23.0)
		player.form.set_form_immediate(&"vampire")
		_place(Vector3(-2.0, 0, 8.0), 180.0)
		player.camera_rig.default_distance = 3.2
		player.camera_rig.pitch = -0.08
		Input.action_press(&"move_right")
		Input.action_press(&"sprint")
		await _wait(0.9)
		await _shot("f01_run_side")
		await _wait(0.12)
		await _shot("f02_run_side")
		Input.action_release(&"move_right")
		Input.action_release(&"sprint")
		player.camera_rig.default_distance = 3.9
		await _tap(&"jump")
		await _wait(0.25)
		await _shot("f03_jump")

	if _wants("coffin"):
		# 7. The coffin asks when.
		_step("7. the coffin asks when you will wake")
		_reset()
		main.tod.set_hour(14.0)
		_place(Vector3(-4.0, 0, -11.0), -60.0)
		_face(world.coffin.global_position)
		await _wait(0.6)
		await _tap(&"interact")
		await _wait(0.8)
		await _shot("g01_rest_menu")
		await _press_key_local(KEY_ESCAPE)
		await _wait(0.5)

	if _wants("memory"):
		# 8. A Blood Memory with its reward spelled out (a person this time).
		_step("8. a person's memory with the reward spelled out")
		_reset()
		HumanNpc.reset_tasted()
		main.tod.set_hour(23.0)
		player.form.set_form_immediate(&"vampire")
		player.blood._set_value(40.0)
		_place(Vector3(-20.4, 0, 5.5), 90.0)
		await _run_until_focus(world.elise.global_position, 3.0)
		Input.action_press(&"feed")
		await _wait(5.2)
		Input.action_release(&"feed")
		await _wait_memory(3.0)
		await _wait(20.0)
		await _shot("h01_memory_elise")
		await _dismiss_memory()
		await _wait(0.8)
		await _shot("h02_after_memory_hud")
		_reset()


func _press_key_local(code: Key) -> void:
	await get_tree().process_frame
	_key(code, true)
	await get_tree().process_frame
	await get_tree().process_frame
	_key(code, false)
	await get_tree().process_frame
