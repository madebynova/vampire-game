extends "res://tests/test_base.gd"
## A scripted walk through the playtest sequence from the Task 1.75 brief, in real time, with real
## rendering and real input, capturing a screenshot at each step so the feel can be *looked at*.
## It is not a replacement for playing the game by hand with a controller.
##   godot --path . res://tests/playtest_driver.tscn -- <screenshot_dir>

func _ready() -> void:
	GameSettings.persist = false
	out_dir = OS.get_cmdline_user_args()[0]
	HumanNpc.schedules_enabled = true
	main = load("res://scenes/main.tscn").instantiate()
	main.capture_mouse = false
	add_child(main)
	player = main.player
	world = main.world
	main.tod.paused = false
	await _wait(3.2)
	await _run()
	get_tree().quit()


func _step(n: String) -> void:
	print("[PLAY] ", n)


func _key(code: Key, pressed: bool) -> void:
	var ev := InputEventKey.new()
	ev.physical_keycode = code
	ev.keycode = code
	ev.pressed = pressed
	Input.parse_input_event(ev)


func _pad(button: JoyButton, pressed: bool) -> void:
	var ev := InputEventJoypadButton.new()
	ev.button_index = button
	ev.pressed = pressed
	Input.parse_input_event(ev)


func _walk_to(target: Vector3, stop_dist := 1.5, timeout := 12.0, run := false) -> void:
	var t := 0.0
	if run:
		Input.action_press(&"sprint")
	Input.action_press(&"move_forward")
	while t < timeout:
		_face(target)
		var flat := Vector2(target.x - player.global_position.x, target.z - player.global_position.z)
		if flat.length() < stop_dist:
			break
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
	Input.action_release(&"move_forward")
	Input.action_release(&"sprint")


func _run() -> void:
	# 1-4. Start as a Human, walk the village, talk, look around (14:00, daylight).
	_step("1. start as a Human in the coffin room")
	main.tod.set_hour(14.0)
	await _wait(0.5)
	await _shot("p01_start_human")
	_step("2. walk out the front door and down the road")
	await _walk_to(Vector3(3.0, 0, -3.0), 1.2, 8.0)
	await _walk_to(Vector3(3.0, 0, 8.0), 1.5, 10.0)
	await _shot("p02_walking_the_road")
	_step("3. talk to Tomas")
	await _walk_to(Vector3(6.2, 0, 9.6), 1.5, 8.0)
	_face(world.tomas.global_position)
	await _wait(0.6)
	await _shot("p03_talk_prompt")
	await _tap(&"interact")
	await _wait(0.4)
	await _shot("p04_talking")
	_step("4. observe the world")
	player.camera_rig.yaw = PI * 0.75
	await _wait(0.6)
	await _shot("p05_village_day")

	# 5-6. Transform.
	_step("5. transform (Human -> Vampire) and watch the presentation")
	main.tod.paused = true
	_place(Vector3(3.0, 0, 2.0), 180.0)
	player.camera_rig.yaw = PI
	await _wait(0.5)
	await _tap(&"transform")
	for i in 5:
		await _wait(0.15)
		await _shot("p06_transform_%d" % i)
	await _wait(1.0)
	await _shot("p07_vampire_hud")

	# 7-11. Sense, a target, feed, memory. Move to dusk/night first so the vampire can walk freely.
	_step("12. it is night: explore as a vampire")
	main.tod.set_hour(23.0)
	main.tod.paused = true
	get_tree().call_group(&"npcs", &"new_day")
	_place(Vector3(3.0, 0, 6.0), 180.0)
	await _wait(1.5)
	await _shot("p08_night_road_vampire")
	_step("7. use Sense")
	await _tap(&"vampiric_sense")
	await _wait(0.45)
	await _shot("p09_sense_wave")
	await _wait(1.6)
	await _shot("p10_sense_settled")
	_step("8-9. find a target and read the blood")
	HumanNpc.schedules_enabled = false   # from here the people stand at their posts so the feed is repeatable
	get_tree().call_group(&"npcs", &"new_day")
	world.corvin.global_position = Vector3(31, 0, 27)
	_place(Vector3(-13.5, 0, 5.5), 90.0)
	player.camera_rig.yaw = PI * 0.5
	player.camera_rig.pitch = -0.05
	await _wait(2.2)
	await _shot("p11_sense_elise")
	_place(Vector3(-19.6, 0, 5.5), 90.0)
	player.camera_rig.yaw = PI * 0.5
	await _wait(1.6)
	await _shot("p11b_sense_close")
	await _tap(&"vampiric_sense")
	_step("10. feed")
	_place(Vector3(-20.4, 0, 5.5), 90.0)
	await _run_until_focus(world.elise.global_position, 3.0)
	await _wait(0.3)
	await _shot("p12_feed_prompt")
	Input.action_press(&"feed")
	await _wait(1.8)
	await _shot("p13_feeding")
	await _wait(3.4)
	Input.action_release(&"feed")
	await _wait(0.45)
	await _shot("p14_the_rush")
	_step("11. the Blood Memory (calm)")
	await _wait_memory(3.0)
	await _wait(1.6)
	await _shot("p15_memory_intro")
	await _wait(3.5)
	await _shot("p16_memory_telling")
	await _wait(8.0)
	await _shot("p17_memory_done")
	await _dismiss_memory()
	await _wait(0.8)
	await _shot("p18_after_memory_bloodrush")
	_step("11b. a terrified victim: a different memory")
	world.tomas.awareness = 0.9
	_place(Vector3(10.5, 0, 11.0), 90.0)
	await get_tree().physics_frame
	Input.action_press(&"feed")
	player.feeding.start(world.tomas)
	await _wait(1.6)
	await _shot("p18b_afraid_feeding")
	await _wait(2.4)
	Input.action_release(&"feed")
	await _wait_memory(3.0)
	await _wait(4.2)
	await _shot("p18c_afraid_memory")
	await _dismiss_memory()

	# 13-14. Daylight and shade.
	_step("13. exploring in daylight")
	main.tod.set_hour(12.0)
	player.health.revive(1.0)
	player.sunlight.reset()
	_place(Vector3(14.0, 0, 5.0), 0.0)
	await _wait(6.0)
	await _shot("p19_daylight_sun_warning")
	_step("14. step into shade")
	_place(Vector3(3.0, 0, -4.0), 0.0)
	await _wait(3.0)
	await _shot("p20_shade")

	# 15-16. Window, roof.
	_step("15. window traversal")
	main.tod.set_hour(23.0)
	player.sunlight.reset()
	_place(Vector3(6.2, 0, -4.0), 180.0)
	await _wait(0.6)
	await _shot("p21_window_prompt")
	await _tap(&"interact")
	await _wait(0.35)
	await _shot("p22_window_mist")
	await _wait(1.2)
	await _shot("p23_inside_house")
	_step("16. climb to the roof")
	_place(Vector3(-5.0, 0, -4.3), 180.0)
	await _wait(0.6)
	await _shot("p24_roof_prompt")
	await _tap(&"interact")
	await _wait(0.7)
	await _shot("p25_climbing")
	await _wait(1.6)
	await _shot("p26_on_the_roof")

	# 17. Coffin.
	_step("17. return to the coffin")
	_place(Vector3(-4.0, 0, -11.0), -60.0)
	_face(world.coffin.global_position)
	await _wait(0.6)
	await _shot("p27_coffin_prompt")
	await _tap(&"interact")
	await _wait(0.8)
	await _shot("p28_lid_open")
	await _wait(0.9)
	await _shot("p29_lying_down")
	await _wait(5.5)

	# 18-20. Pause, controls, controller.
	_step("18. pause menu")
	await _press(KEY_ESCAPE)
	await _wait(0.4)
	await _shot("p30_pause")
	_step("19. controls with keyboard and mouse")
	await _press(KEY_DOWN)
	await _wait(0.3)
	await _shot("p31_controls_keyboard")
	await _press(KEY_DOWN)
	await _wait(0.3)
	await _press(KEY_ENTER)
	await _wait(0.4)
	await _shot("p32_options")
	_step("20. controller glyphs")
	await _press(KEY_ESCAPE)
	await _press(KEY_ESCAPE)
	InputSetup.set_device_kind(InputSetup.XBOX)
	main.hud._help.visible = true
	await _wait(0.5)
	await _shot("p33_controller_hud")
	InputSetup.set_device_kind(InputSetup.PLAYSTATION)
	await _wait(0.5)
	await _shot("p34_playstation_hud")
	InputSetup.set_device_kind(InputSetup.KEYBOARD)


func _press(code: Key) -> void:
	await get_tree().process_frame
	_key(code, true)
	await get_tree().process_frame
	await get_tree().process_frame
	_key(code, false)
	await get_tree().process_frame
