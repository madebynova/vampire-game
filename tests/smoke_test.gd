extends "res://tests/test_base.gd"
## Automated playthrough of the whole prototype loop. Drives the real game through real
## input actions. Run windowed to also capture screenshots:
##   godot --path . res://tests/smoke_test.tscn -- <screenshot_dir>
## or headless (no screenshots):
##   godot --headless --path . res://tests/smoke_test.tscn

var _denied_reasons: Array[String] = []
var _stages_seen: Array[int] = []


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	out_dir = args[0] if args.size() > 0 else ""
	# The legacy acceptance run needs NPCs standing at fixed spots; routines get their own scenarios below.
	HumanNpc.schedules_enabled = false
	main = load("res://scenes/main.tscn").instantiate()
	main.capture_mouse = false
	add_child(main)
	player = main.player
	world = main.world
	_fast_memory()
	# Deterministic clock: paused at 16:00 unless a test moves it.
	main.tod.paused = true
	main.tod.set_hour(16.0)
	# Pin the sun to the direction the Task 1 layout/tests were tuned for (north-north-east, 24 deg).
	main.tod.sun_override = Vector3(0.312, 0.407, -0.858)
	player.abilities.ability_denied.connect(func(_a, reason): _denied_reasons.append(reason))
	player.sunlight.stage_changed.connect(func(s, _o): _stages_seen.append(int(s)))
	await _run()
	print("[TEST] ===== %d checks, %d failures =====" % [checks, failures])
	get_tree().quit(1 if failures > 0 else 0)


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
	Input.action_press(&"feed")
	await _wait(1.6)
	_check(player.state.mode == PlayerState.Mode.FEEDING, "state is FEEDING while holding")
	_check(player.blood.value > blood_b4, "blood rises while feeding")
	await _shot("06_feeding")
	await _wait(3.4)
	Input.action_release(&"feed")
	await _wait(0.5)
	_check(world.elise.mode == HumanNpc.Mode.DRAINED, "Elise is drained (alive, unconscious)")
	_check(player.blood.value > blood_b4 + 20.0, "Blood restored by feeding (%.0f -> %.0f)" % [blood_b4, player.blood.value])
	# Task 1.75: the memory is a full-screen experience that holds control until dismissed.
	_check(await _wait_memory(), "Blood memory takes over the screen: %s" % main.memory_view.title_text())
	await _wait(0.5)
	await _shot("07_memory")
	_check(player.state.mode == PlayerState.Mode.MEMORY, "control is held while the memory plays")
	await _dismiss_memory()
	_check(player.state.mode == PlayerState.Mode.NORMAL, "control returns once the memory is dismissed")
	_check(player.interactor.focused == null, "a drained victim is no longer interactable (not a pickup)")

	print("[TEST] --- NPC NOTICES A VAMPIRE, FLEES; VAMPIRE OUTRUNS ---")
	# Tomas fled earlier (the witnessed transformation) and, with routines frozen, stopped wherever his
	# run ended. Put him back at his post so this step does not depend on where that happened to be.
	world.tomas.new_day()
	# (Start at x=3: the straight line from x=4.5 now runs into the new lamp post beside the plaza.)
	_place(Vector3(3.0, 0, 1.0), 180.0)
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
		Input.action_press(&"feed")
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
		Input.action_release(&"feed")
		await _wait(0.4)
		_check(not player.state.is_dead(), "survived feeding in open sun (hp %.0f)" % player.health.value)
		_check(world.tomas.mode == HumanNpc.Mode.DRAINED, "Tomas drained after feed")
		await _wait_memory()
		_check(main.memory_view.title_text().begins_with("Nine Sets"), "a terrified Tomas gives a DIFFERENT memory (afraid variant): %s" % main.memory_view.title_text())
		_check(not world.stash.discovered, "terror blood does not reveal the buried key")
		await _dismiss_memory()

	print("[TEST] --- SAME PERSON, CALM: A DIFFERENT MEMORY ---")
	# Deterministic: rested world, calm Tomas, vampire adjacent in the open. (No approach time counted.)
	get_tree().call_group(&"npcs", &"new_day")
	player.health.revive(1.0)
	player.sunlight.reset()
	# Tomas faces west; approach from behind (east) so he is not looking at the vampire.
	_place(Vector3(10.5, 0, 11.0), 90.0)
	world.tomas.awareness = 0.0
	await get_tree().physics_frame
	await _run_until_focus(world.tomas.global_position, 3.0)
	_check(world.tomas.mode == HumanNpc.Mode.CALM and world.tomas.awareness < 0.6, "approached from behind, Tomas has not noticed (awareness %.2f)" % world.tomas.awareness)
	var hp_sun0 := player.health.value
	Input.action_press(&"feed")
	await _wait(4.4)
	Input.action_release(&"feed")
	await _wait(0.3)
	var lost := hp_sun0 - player.health.value
	# Task 1 asserted "-8..-60 hp" here. With the ~3 minute sun that is obsolete by design: a feed now
	# costs *heat* (doubled while feeding), not health. Heat is what the coffin/night/shade recover.
	_check(not player.state.is_dead() and player.sunlight.model.heat > 4.0 and lost < 15.0, "feeding in open sun heats you (heat %.1f, doubled while feeding) but is survivable (-%.0f hp)" % [player.sunlight.model.heat, lost])
	await _wait_memory()
	_check(main.memory_view.title_text().begins_with("The Well"), "calm Tomas: %s" % main.memory_view.title_text())
	_check(world.stash.discovered, "calm blood revealed the buried key (blood -> information)")
	await _dismiss_memory()

	print("[TEST] --- SECRET REVEALED BY SENSE, THEN DUG ---")
	await _run_to(Vector3(3.0, 0, -3.0), 2.0, 6.0)
	await _wait(2.5)
	_check(player.sunlight.exposure < 0.1, "back in shade (exposure %.2f, meter %.2f)" % [player.sunlight.exposure, player.sunlight.model.heat])
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
	_check(SecretStash.has_flag(&"cellar_key"), "Key dug up")
	_place(Vector3(5.2, 0, -9.5), 0.0)
	await _wait(0.4)
	_check(_prompt().begins_with("Unlock"), "Hatch now says: %s" % _prompt())

	print("[TEST] --- SUN DEATH (~3 minutes, run at 8x speed) -> COFFIN ---")
	player.health.revive(1.0)
	player.sunlight.reset()
	# The two feeds above left a Bloodrush, which deliberately gives a little patience with the sun
	# (heat x0.85 at power 1). This step measures the unmodified three-minute baseline, so end it first.
	player.surge.stop(false)
	_place(Vector3(14.0, 0, 5.0), 0.0)
	_stages_seen.clear()
	Engine.max_physics_steps_per_frame = 64
	Engine.time_scale = 8.0
	var frame0 := Engine.get_physics_frames()
	var died_at := -1.0
	var shot_severe := false
	var hp_at_6 := -1.0
	var hud_checked := false
	var secs := 0.0
	while secs < 260.0:
		await get_tree().physics_frame
		secs = float(Engine.get_physics_frames() - frame0) / Engine.physics_ticks_per_second * 8.0  # game seconds (time_scale 8)
		if hp_at_6 < 0.0 and secs >= 6.0:
			hp_at_6 = player.health.value
		if not hud_checked and secs >= 40.0:
			hud_checked = true
			_check(main.hud._sun_box.visible and main.hud._sun_label.text.contains("ash in"), "HUD shows sun stage and a time-to-ash estimate: '%s'" % main.hud._sun_label.text)
		if not shot_severe and player.sunlight.stage >= 3:
			shot_severe = true
			await _shot("11_severe")
		if player.state.is_dead():
			died_at = secs
			break
	Engine.time_scale = 1.0
	Engine.max_physics_steps_per_frame = 8
	_check(hp_at_6 >= 99.0, "first seconds in sunlight are a warning, not damage (hp %.1f at 6 s)" % hp_at_6)
	var seen_up := _stages_seen.filter(func(x): return x > 0)
	_check(seen_up == [1, 2, 3, 4], "sun escalates through Initial, Prolonged, Severe, Critical (%s)" % str(seen_up))
	_check(died_at > 165.0 and died_at < 195.0, "continued exposure kills in about three minutes (%.0f s)" % died_at)
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
	Input.action_press(&"feed")
	await _wait(1.3)
	_check(player.state.mode == PlayerState.Mode.FEEDING, "feeding started on night 2")
	Input.action_release(&"feed")
	await _wait(0.4)
	_check(world.elise.mode == HumanNpc.Mode.FLEEING, "letting go early: victim tears free, terrified")
	_check(not main.memory_view.is_open(), "no memory from an interrupted feed")
	_check(player.state.mode == PlayerState.Mode.NORMAL, "control returns after interrupt")

	print("[TEST] --- REST IN COFFIN (end the night) ---")
	player.form.set_form_immediate(&"vampire")
	_place(Vector3(-4.0, 0, -11.0), -60.0)
	_face(world.coffin.global_position)
	await _wait(0.4)
	_check(_prompt().begins_with("Sleep"), "Coffin prompt: %s" % _prompt())
	await _tap(&"interact")
	await _wait(6.0)   # the lid slides off, you lie down, it closes, the world fades (was 4.5 s before the coffin animation)
	_check(player.state.mode == PlayerState.Mode.NORMAL, "control returns after resting")
	_check(world.elise.mode == HumanNpc.Mode.CALM, "resting resets the world (Elise calm again)")
	_check(player.form.is_form(&"human"), "rest returns you to Human form")

	print("[TEST] --- NIGHT 3: FULL LOOP AGAIN, NO MANUAL FIXING ---")
	await _become_vampire()
	_place(Vector3(-20.4, 0, 5.5), 90.0)
	await _run_until_focus(world.elise.global_position, 3.0)
	Input.action_press(&"feed")
	await _wait(4.6)
	Input.action_release(&"feed")
	await _wait(0.4)
	await _wait_memory()
	_check(world.elise.mode == HumanNpc.Mode.DRAINED and main.memory_view.is_open(), "night 3: Elise fed on again, memory shown")
	await _dismiss_memory()

	print("[TEST] --- HUMAN FORM IS SAFE IN SUN ---")
	player.form.set_form_immediate(&"human")
	_place(Vector3(14.0, 0, 5.0), 0.0)
	player.health.revive(1.0)
	await _wait(3.5)
	_check(player.sunlight.stage == 0 and player.health.value >= 99.0, "Human takes no sun damage (hp %.0f)" % player.health.value)
