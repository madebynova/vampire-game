extends "res://tests/test_base.gd"
## v0.2.0 manual-playtest driver: stages each beat of the hunt in the real renderer and photographs it, so the
## look of the hunter, the camp, the telegraph, the HUD marks and the objective can be LOOKED at. It is a
## camera crew, not a player; hunt_playthrough.gd plays the loop through with real input.
##   godot --path . res://tests/hunt_playtest.tscn -- <screenshot_dir> [only=camp,sense,...]

var hunter: Hunter
var _only: PackedStringArray = PackedStringArray()


func _ready() -> void:
	GameSettings.persist = false
	for a in OS.get_cmdline_user_args():
		if a.begins_with("only="):
			_only = a.trim_prefix("only=").split(",")
		else:
			out_dir = a
	HumanNpc.schedules_enabled = false
	Hunter.always_on = true
	main = load("res://scenes/main.tscn").instantiate()
	main.capture_mouse = false
	add_child(main)
	player = main.player
	world = main.world
	hunter = world.hunters[0]
	main.tod.paused = true
	await _wait(3.0)
	await _run()
	get_tree().quit()


func _step(n: String) -> void:
	print("[PLAY] ", n)


func _wants(scene: String) -> bool:
	return _only.is_empty() or _only.has(scene)


func _reset(hour := 23.0) -> void:
	for a in [&"feed", &"interact", &"sprint", &"move_forward", &"move_right", &"jump", &"attack"]:
		Input.action_release(a)
	main.memory_view.force_close()
	PauseControl.clear()
	get_tree().call_group(&"npcs", &"new_day")
	world.corvin.global_position = Vector3(31, 0, 27)
	player.health.revive(1.0)
	player.sunlight.reset()
	player.abilities.deactivate_all()
	player.surge.stop(false)
	player.combat.reset()
	player.state.set_mode(PlayerState.Mode.NORMAL)
	player.visual.visible = true
	player.blood._set_value(70.0)
	main.hud._help.visible = false
	hunter.inert = true
	hunter.hold = false
	hunter.health = hunter.profile.max_health
	hunter._go_away()
	main.tod.sun_override = Vector3.ZERO
	main.tod.set_hour(hour)


## Put the camera `dist` metres from `at`, looking at it from `bearing` degrees (0 = from the south looking
## north), the player standing out of shot (hidden) a camera-arm's length ahead of it.
func _frame(at: Vector3, bearing: float, dist := 5.5, pitch := -0.1) -> void:
	var dir := Vector3(sin(deg_to_rad(bearing)), 0.0, cos(deg_to_rad(bearing)))
	var cam := at + dir * dist
	cam.y = at.y
	var d := at - cam
	d.y = 0.0
	var yaw := atan2(-d.x, -d.z)
	var pos := cam + d.normalized() * 3.9
	player.place_at(Vector3(pos.x, at.y, pos.z), yaw)
	player.camera_rig.yaw = yaw
	player.camera_rig.pitch = pitch
	player.set_facing(yaw)
	player.camera_rig.snap()
	player.visual.visible = false


func _until_swing() -> void:
	var t := 0.0
	while t < 4.0 and hunter.swing != Hunter.Swing.WINDUP:
		await get_tree().physics_frame
		t += get_physics_process_delta_time()


func _run() -> void:
	_reset(14.0)
	if _wants("rumor"):
		_step("a. by day, a Human, the hunt as a quiet line")
		player.form.set_form_immediate(&"human")
		player.place_at(Vector3(3, 0, 3), 0.0)
		await _wait(1.5)
		await _shot("a01_rumor_line")
	if _wants("camp"):
		_step("b. the hunter's camp by day")
		_reset(14.0)
		player.form.set_form_immediate(&"human")
		_frame(world.location.hunters[0].camp + Vector3(0.5, 0, 0), 25.0, 6.0, -0.2)
		player.visual.visible = true
		await _wait(1.2)
		await _shot("b01_camp_day")
		_place(Vector3(-12.2, 0, -19.3), 0.0)
		player.camera_rig.pitch = -0.25
		player.camera_rig.yaw = 0.35
		await _wait(0.8)
		await _shot("b02_camp_journal_prompt")
		await _tap(&"interact")
		await _wait(0.8)
		await _shot("b03_journal_read")
	if _wants("night"):
		_step("c. dusk: a lantern kindles in the pines")
		_reset(19.1)
		player.form.set_form_immediate(&"vampire")
		hunter.inert = false
		hunter.hold = true
		_frame(Vector3(-13.5, 0, -19.0), 80.0, 8.0, -0.06)
		await _wait(1.6)
		await _shot("c01_lantern_kindles")
		await _wait(0.8)
		_frame(Vector3(-13.5, 0, -19.0), 80.0, 14.0, -0.04)
		await _wait(0.6)
		await _shot("c02_hunter_far")
	if _wants("model"):
		_step("d. the hunter, close: front, back, side, and the blade raised")
		_reset(23.0)
		player.form.set_form_immediate(&"vampire")
		hunter.deploy(Vector3(3, 0, 1.0), 180.0)
		hunter.inert = true
		_frame(hunter.global_position + Vector3(0, 1.0, 0), 0.0, 4.4, -0.03)
		await _wait(0.9)
		await _shot("d01_hunter_front")
		_frame(hunter.global_position + Vector3(0, 1.0, 0), 180.0, 4.4, -0.03)
		await _wait(0.5)
		await _shot("d02_hunter_back")
		_frame(hunter.global_position + Vector3(0, 1.0, 0), 90.0, 4.0, -0.02)
		await _wait(0.5)
		await _shot("d03_hunter_side")
		hunter.swing = Hunter.Swing.WINDUP
		hunter._swing_t = hunter.profile.attack_windup * 0.95
		hunter._flare = 1.0
		_frame(hunter.global_position + Vector3(0, 1.0, 0), 20.0, 4.6, -0.03)
		await _wait(0.4)
		await _shot("d04_blade_raised")
		hunter.swing = Hunter.Swing.NONE
	if _wants("sense"):
		_step("e. Sense: his heart, his mood, his back is to you")
		_reset(23.0)
		player.form.set_form_immediate(&"vampire")
		hunter.deploy(Vector3(3, 0, -2.5), -90.0)
		hunter.hold = true
		hunter.inert = false
		_place(Vector3(-3.0, 0, -2.5), -90.0)
		player.camera_rig.yaw = -PI * 0.5
		player.camera_rig.pitch = -0.1
		await _tap(&"vampiric_sense")
		await _wait(2.6)
		await _shot("e01_sense_unaware")
		await _tap(&"vampiric_sense")
	if _wants("ambush"):
		_step("f. the ambush")
		_reset(23.0)
		player.form.set_form_immediate(&"vampire")
		hunter.deploy(Vector3(5, 0, 1.0), -90.0)
		hunter.inert = true
		_place(Vector3(2.9, 0, 1.0), -90.0)
		player.camera_rig.yaw = -PI * 0.5
		player.camera_rig.pitch = -0.12
		await _wait(0.7)
		await _shot("f01_behind_him")
		await _tap(&"attack")
		await _wait(0.12)
		await _shot("f02_strike")
		await _wait(0.25)
		await _shot("f03_hit")
		await _wait(0.7)
		await _shot("f04_aftermath")
	if _wants("tell"):
		_step("g. his blade: the tell, the blow, the arc")
		_reset(23.0)
		player.form.set_form_immediate(&"vampire")
		hunter.deploy(Vector3(3, 0, 0.0), 180.0, Hunter.State.HUNTING)
		hunter.hold = false
		hunter.inert = false
		_place(Vector3(3, 0, 2.1), 0.0)
		player.camera_rig.yaw = 0.0
		player.camera_rig.pitch = -0.14
		await _until_swing()
		await _wait(0.3)
		await _shot("g01_windup")
		await _wait(0.3)
		await _shot("g02_blow_lands")
		await _wait(0.5)
		await _shot("g03_after_blow")
		player.health.value = 28.0
		await _wait(1.8)
		await _shot("g04_badly_wounded")
	if _wants("roof"):
		_step("h. the roof")
		_reset(23.0)
		player.form.set_form_immediate(&"vampire")
		player.place_at(Vector3(-5.0, 3.95, -6.4), PI)
		hunter.deploy(Vector3(-5.0, 0, -3.0), 0.0, Hunter.State.HUNTING)
		hunter.inert = false
		hunter.hold = false
		player.camera_rig.yaw = PI
		player.camera_rig.pitch = -0.5
		await _wait(2.5)
		await _shot("h01_hunter_below")
	if _wants("down"):
		_step("i. down: drink or leave")
		_reset(23.0)
		player.form.set_form_immediate(&"vampire")
		hunter.deploy(Vector3(3, 0, 0.0), 180.0, Hunter.State.DOWNED)
		hunter.health = 0.0
		hunter.inert = true
		_place(Vector3(4.4, 0, -0.4), 90.0)
		player.camera_rig.yaw = deg_to_rad(90.0)
		player.camera_rig.pitch = -0.3
		await _wait(1.2)
		await _shot("i01_down_prompt")
		Input.action_press(&"feed")
		await _wait(2.4)
		await _shot("i02_drinking")
		await _wait(2.4)
		Input.action_release(&"feed")
		await _wait(1.6)
		await _shot("i03_memory")
		main.memory_view.force_close()
		await _wait(0.8)
		await _shot("i04_after_rush")
	if _wants("menus"):
		_step("k. the pause menu and its controls screen, with Rend on it")
		_reset(23.0)
		player.form.set_form_immediate(&"vampire")
		main.pause_menu.open()
		await _wait(0.6)
		await _shot("k01_pause")
		var down := InputEventKey.new()
		down.physical_keycode = KEY_DOWN
		down.keycode = KEY_DOWN
		down.pressed = true
		Input.parse_input_event(down)
		await _wait(0.1)
		down.pressed = false
		Input.parse_input_event(down)
		await _wait(0.2)
		await _press_enter()
		await _wait(0.8)
		await _shot("k02_pause_controls")
		main.pause_menu.close()
		await _wait(0.4)
	if _wants("done"):
		_step("j. the line, when it is over")
		await _wait(1.0)
		await _shot("j01_done_line")
