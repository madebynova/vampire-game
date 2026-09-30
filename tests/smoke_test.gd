extends Node
## Automated playthrough of the whole prototype loop. Drives the real game through real
## input actions. Run windowed to also capture screenshots:
##   godot --path . res://tests/smoke_test.tscn -- <screenshot_dir>
## or headless (no screenshots):
##   godot --headless --path . res://tests/smoke_test.tscn

var main: Main
var player: Player
var world: WorldBuilder
var out_dir := ""
var checks := 0
var failures := 0
var _denied_reasons: Array[String] = []
var _stages_seen: Array[int] = []


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	out_dir = args[0] if args.size() > 0 else ""
	main = load("res://scenes/main.tscn").instantiate()
	main.capture_mouse = false
	add_child(main)
	player = main.player
	world = main.world
	player.abilities.ability_denied.connect(func(_a, reason): _denied_reasons.append(reason))
	player.sunlight.stage_changed.connect(func(s, _o): _stages_seen.append(int(s)))
	await _run()
	print("[TEST] ===== %d checks, %d failures =====" % [checks, failures])
	get_tree().quit(1 if failures > 0 else 0)


# ------------------------------------------------------------------ helpers

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
func _run_until_focus(target: Vector3, timeout: float) -> float:
	var t := 0.0
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


# ------------------------------------------------------------------ scenario

func _run() -> void:
	print("[TEST] --- WAKE / SPAWN ---")
	await _wait(2.6)
	_check(player.state.mode == PlayerState.Mode.NORMAL, "player controllable after waking")
	_check(player.form.is_form(&"human"), "starts as Human")
	_check(player.global_position.x < -2.0 and player.global_position.z < -6.0, "spawns inside the crypt room by the coffin")
	await _shot("01_wake")

	print("[TEST] --- MOVEMENT ---")
	var start_x := player.global_position.x
	Input.action_press(&"move_forward")
	await _wait(0.8)
	Input.action_release(&"move_forward")
	_check(player.global_position.x > start_x + 1.0, "walk forward moves the player (dx=%.2f)" % (player.global_position.x - start_x))
	await _tap(&"jump")
	await _wait(0.12)
	_check(player.velocity.y > 0.5 or not player.is_on_floor(), "jump leaves the ground")
	await _wait(0.8)

	print("[TEST] --- HUMAN CANNOT SENSE ---")
	await _tap(&"vampiric_sense")
	await _wait(0.2)
	var sense: VampiricSense = player.abilities.get_ability(&"vampiric_sense")
	_check(not sense.active, "Vampiric Sense does not activate as Human")
	_check(_denied_reasons.size() > 0, "player gets explicit feedback when denied: '%s'" % (_denied_reasons[0] if _denied_reasons.size() > 0 else ""))

	print("[TEST] --- HUMAN TALKS ---")
	_place(Vector3(6.2, 0, 9.4), 180.0)
	await _wait(0.4)
	_check(_prompt().begins_with("Talk"), "Human sees 'Talk' prompt near Tomas: %s" % _prompt())
	await _tap(&"interact")
	await _wait(0.2)
	_check(world.tomas.speech_label.visible and world.tomas.speech_label.text != "", "Tomas speaks: %s" % world.tomas.speech_label.text)
	_check(world.tomas.mode == HumanNpc.Mode.CALM, "Tomas stays calm around a Human player")
	await _shot("02_talk")

	print("[TEST] --- TRANSFORM ---")
	var human_run := player.form.current.run_speed
	player.form.request_toggle()
	await _wait(0.4)
	_check(player.state.mode == PlayerState.Mode.TRANSFORMING, "state is TRANSFORMING mid-sequence")
	await _shot("03_transforming")
	await _wait(1.2)
	_check(player.form.is_form(&"vampire"), "Human -> Vampire")
	_check(player.state.mode == PlayerState.Mode.NORMAL, "control returns after transformation")
	_check(player.form.current.run_speed > human_run * 1.4, "Vampire is mechanically faster (%.1f vs %.1f)" % [player.form.current.run_speed, human_run])
	_check(player.form.current.jump_velocity > 7.0, "Vampire jumps higher")
	_place(Vector3(0.0, 0, -3.0), 180.0)
	await _wait(0.5)
	await _shot("04_vampire_shade")

	print("[TEST] --- VAMPIRIC SENSE ---")
	# Stand in the gatehouse's shade, outside its walls, 6 m from Elise who is inside.
	_place(Vector3(-24.0, 0, 11.5), 0.0)
	await _wait(0.6)
	var elise_target: SenseTarget = world.elise.get_node("SenseTarget")
	_check(not elise_target.revealed, "before sensing, Elise is not revealed")
	var blood_before := player.blood.value
	await _tap(&"vampiric_sense")
	await _wait(0.5)
	_check(sense.active, "Vampiric Sense activates as Vampire")
	await _wait(1.8)
	_check(elise_target.revealed, "Elise is revealed THROUGH the gatehouse walls")
	_check(not world.tomas.get_node("SenseTarget").revealed, "Tomas is beyond sense range from here (range is limited)")
	_check(player.blood.value < blood_before, "Sense costs blood (%.1f -> %.1f)" % [blood_before, player.blood.value])
	var info: String = world.elise.get_sense_data()["label"]
	_check(info.contains("bpm"), "sense reads heart rate + blood: %s" % info.replace("\n", " | "))
	await _shot("05_sense_elise")
	await _tap(&"vampiric_sense")
	await _wait(0.3)
	_check(not sense.active, "Sense toggles off")
	_check(not elise_target.revealed, "Elise hidden again after sense ends")
	_place(Vector3(3.0, 0, -3.0), 0.0)
	await _tap(&"vampiric_sense")
	await _wait(1.6)
	var home: SenseTarget = world.coffin.get_node("SenseTarget")
	_check(home.revealed, "Sense reveals your coffin (home) from afar")
	await _tap(&"vampiric_sense")
	await _wait(0.3)

	print("[TEST] --- FEEDING (stealth approach: Elise, facing away, in gatehouse) ---")
	_place(Vector3(-20.4, 0, 5.5), 90.0)
	var t := await _run_until_focus(world.elise.global_position, 3.0)
	_check(player.interactor.focused != null, "Elise becomes interactable as the vampire closes in (t=%.2fs, awareness %.2f)" % [t, world.elise.awareness])
	_check(_prompt().begins_with("Feed"), "Vampire sees 'Feed' prompt: %s" % _prompt())
	var blood_b4 := player.blood.value
	Input.action_press(&"interact")
	await _wait(1.6)
	_check(player.state.mode == PlayerState.Mode.FEEDING, "state is FEEDING while holding")
	_check(player.blood.value > blood_b4, "blood rises while feeding")
	await _shot("06_feeding")
	await _wait(3.4)
	Input.action_release(&"interact")
	await _wait(0.5)
	_check(world.elise.mode == HumanNpc.Mode.DRAINED, "Elise is drained (alive, unconscious)")
	_check(player.blood.value > blood_b4 + 20.0, "Blood restored by feeding (%.0f -> %.0f)" % [blood_b4, player.blood.value])
	_check(main.hud._memory_panel.visible, "Blood memory shown: %s" % main.hud._memory_title.text)
	await _shot("07_memory")
	_check(player.state.mode == PlayerState.Mode.NORMAL, "control returns after feeding")
	_check(player.interactor.focused == null, "a drained victim is no longer interactable (not a pickup)")
	main.hud._memory_panel.visible = false

	print("[TEST] --- NPC NOTICES A VAMPIRE, FLEES; VAMPIRE OUTRUNS ---")
	_place(Vector3(4.5, 0, 1.0), 180.0)
	_stages_seen.clear()
	t = 0.0
	var caught := false
	var saw_flee := false
	Input.action_press(&"sprint")
	Input.action_press(&"move_forward")
	while t < 7.0 and not caught:
		_face(world.tomas.global_position)
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
		if world.tomas.mode == HumanNpc.Mode.FLEEING:
			saw_flee = true
		if _prompt().begins_with("Seize"):
			caught = true
	Input.action_release(&"move_forward")
	Input.action_release(&"sprint")
	_check(saw_flee, "Tomas noticed the vampire and fled")
	_check(caught, "Vampire outruns fleeing Tomas and can 'Seize' him (t=%.1fs)" % t)
	_check(_stages_seen.has(1), "Sunlight WARNING stage reached in the open yard: %s" % str(_stages_seen))
	await _shot("08_chase_sun")
	if caught:
		var hp0 := player.health.value
		Input.action_press(&"interact")
		Input.action_press(&"sprint")
		Input.action_press(&"move_forward")
		var lunge := 0.0
		while lunge < 2.5 and player.state.mode != PlayerState.Mode.FEEDING:
			_face(world.tomas.global_position)
			await get_tree().physics_frame
			lunge += get_physics_process_delta_time()
		Input.action_release(&"move_forward")
		Input.action_release(&"sprint")
		await _wait(0.6)
		_check(player.state.mode == PlayerState.Mode.FEEDING, "seized a fleeing human while sprinting -> FEEDING (lunge %.2fs)" % lunge)
		await _shot("09_feed_in_sun")
		await _wait(3.4)
		Input.action_release(&"interact")
		await _wait(0.4)
		_check(not player.state.is_dead(), "survived feeding in open sun (hp %.0f)" % player.health.value)
		_check(world.tomas.mode == HumanNpc.Mode.DRAINED, "Tomas drained after feed")
		_check(player.health.value < hp0 - 1.0, "chase + feed under sunlight costs health (%.0f -> %.0f hp)" % [hp0, player.health.value])
		_check(main.hud._memory_title.text.begins_with("The Well"), "Tomas' memory shown: %s" % main.hud._memory_title.text)
		_check(world.stash.discovered, "Tomas' blood revealed the buried key (blood -> information)")
		main.hud._memory_panel.visible = false

	print("[TEST] --- SECRET REVEALED BY SENSE, THEN DUG ---")
	await _run_to(Vector3(3.0, 0, -3.0), 2.0, 6.0)
	await _wait(2.5)
	_check(player.sunlight.exposure < 0.1, "back in shade (exposure %.2f, meter %.2f)" % [player.sunlight.exposure, player.sunlight.meter])
	player.health.revive(1.0)
	player.sunlight.reset()
	_place(Vector3(11.0, 0, 4.0), 0.0)
	await _tap(&"vampiric_sense")
	await _wait(1.8)
	_check(world.stash.get_node("SenseTarget").revealed, "Sense now shows the buried key")
	await _shot("10_sense_stash")
	await _tap(&"vampiric_sense")
	_place(Vector3(11.0, 0, 15.6), 0.0)
	await _wait(0.4)
	_check(_prompt().begins_with("Dig"), "'Dig up the buried key' prompt appears: %s" % _prompt())
	await _tap(&"interact")
	await _wait(0.3)
	_check(SecretStash.key_held, "Key dug up")
	_place(Vector3(5.2, 0, -9.5), 0.0)
	await _wait(0.4)
	_check(_prompt().begins_with("Unlock"), "Hatch now says: %s" % _prompt())

	print("[TEST] --- SUN DEATH -> COFFIN ---")
	player.health.revive(1.0)
	player.sunlight.reset()
	_place(Vector3(14.0, 0, 5.0), 0.0)
	_stages_seen.clear()
	var died_at := -1.0
	var shot_burning := false
	t = 0.0
	while t < 14.0:
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
		if not shot_burning and player.sunlight.stage == SunlightExposure.Stage.BURNING and player.sunlight.meter > 2.5:
			shot_burning = true
			await _shot("11_burning")
		if player.state.is_dead():
			died_at = t
			break
	_check(_stages_seen.has(1) and _stages_seen.has(2) and _stages_seen.has(3), "sun escalates through stages 1,2,3 (%s)" % str(_stages_seen))
	_check(died_at > 5.0 and died_at < 12.0, "continued exposure kills the vampire in a fair time (t=%.1fs)" % died_at)
	await _shot("12_death")
	await _wait(7.5)
	_check(not player.state.is_dead() and player.state.mode == PlayerState.Mode.NORMAL, "player is alive and controllable after death/respawn")
	_check(player.global_position.distance_to(world.coffin.global_position) < 4.5, "respawned at the coffin (dist %.1f)" % player.global_position.distance_to(world.coffin.global_position))
	_check(player.form.is_form(&"human"), "wakes as Human")
	_check(player.health.value > 40.0 and player.health.value < 100.0, "wakes weakened (%.0f hp)" % player.health.value)
	_check(world.tomas.mode == HumanNpc.Mode.CALM and world.elise.mode == HumanNpc.Mode.CALM, "NPCs reset for the new night")
	_check(player.visual.visible, "player model visible again")

	print("[TEST] --- NIGHT 2: INTERRUPTED FEED ---")
	await _become_vampire()
	_check(player.form.is_form(&"vampire"), "transform works again")
	_place(Vector3(-20.4, 0, 5.5), 90.0)
	await _run_until_focus(world.elise.global_position, 3.0)
	Input.action_press(&"interact")
	await _wait(1.3)
	_check(player.state.mode == PlayerState.Mode.FEEDING, "feeding started on night 2")
	Input.action_release(&"interact")
	await _wait(0.4)
	_check(world.elise.mode == HumanNpc.Mode.FLEEING, "letting go early: victim tears free, terrified")
	_check(not main.hud._memory_panel.visible, "no memory from an interrupted feed")
	_check(player.state.mode == PlayerState.Mode.NORMAL, "control returns after interrupt")

	print("[TEST] --- REST IN COFFIN (end the night) ---")
	player.form.set_form_immediate(&"vampire")
	_place(Vector3(-4.0, 0, -11.0), -60.0)
	_face(world.coffin.global_position)
	await _wait(0.4)
	_check(_prompt().begins_with("Rest"), "Coffin prompt: %s" % _prompt())
	await _tap(&"interact")
	await _wait(4.5)
	_check(player.state.mode == PlayerState.Mode.NORMAL, "control returns after resting")
	_check(world.elise.mode == HumanNpc.Mode.CALM, "resting resets the world (Elise calm again)")
	_check(player.form.is_form(&"human"), "rest returns you to Human form")

	print("[TEST] --- NIGHT 3: FULL LOOP AGAIN, NO MANUAL FIXING ---")
	await _become_vampire()
	_place(Vector3(-20.4, 0, 5.5), 90.0)
	await _run_until_focus(world.elise.global_position, 3.0)
	Input.action_press(&"interact")
	await _wait(4.6)
	Input.action_release(&"interact")
	await _wait(0.4)
	_check(world.elise.mode == HumanNpc.Mode.DRAINED and main.hud._memory_panel.visible, "night 3: Elise fed on again, memory shown")
	main.hud._memory_panel.visible = false

	print("[TEST] --- COST OF FEEDING IN OPEN SUN ---")
	# Deterministic: calm Tomas, vampire adjacent in the open. (No approach time counted.)
	player.health.revive(1.0)
	player.sunlight.reset()
	_place(Vector3(8.0, 0, 11.0), 90.0)
	world.tomas.awareness = 0.0
	await get_tree().physics_frame
	_face(world.tomas.global_position)
	await _wait(0.2)
	var hp_sun0 := player.health.value
	Input.action_press(&"interact")
	await _wait(4.4)
	Input.action_release(&"interact")
	await _wait(0.3)
	var lost := hp_sun0 - player.health.value
	_check(not player.state.is_dead() and lost > 8.0 and lost < 60.0, "a full feed in open sun is survivable but costly (-%.0f hp, meter %.1f)" % [lost, player.sunlight.meter])
	main.hud._memory_panel.visible = false

	print("[TEST] --- HUMAN FORM IS SAFE IN SUN ---")
	player.form.set_form_immediate(&"human")
	_place(Vector3(14.0, 0, 5.0), 0.0)
	player.health.revive(1.0)
	await _wait(3.5)
	_check(player.sunlight.stage == SunlightExposure.Stage.SAFE and player.health.value >= 99.0, "Human takes no sun damage (hp %.0f)" % player.health.value)
