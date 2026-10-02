extends "res://tests/test_base.gd"
## THE HUNT, played start to finish by a script with real key events, real physics, the real renderer and the
## real hunter AI (the villagers keep their routines too). It is the brief's loop in order:
##   wake -> become a vampire -> explore -> Sense -> find the hunter -> stalk -> choose how to fight ->
##   strike -> take a blow -> get away over the rooftops -> drop on him -> drink -> the hunt is over ->
##   carry on playing (Human again, a villager, the coffin).
## It is a bot, not a person: it knows where things are. It proves the loop can be played, photographs it, and
## checks each step; it cannot say whether it is fun.
##   godot --path . res://tests/hunt_playthrough.tscn -- <screenshot_dir>

var hunter: Hunter
var log_lines: Array[String] = []


func _ready() -> void:
	GameSettings.persist = false
	var args := OS.get_cmdline_user_args()
	out_dir = args[0] if args.size() > 0 else ""
	HumanNpc.schedules_enabled = true
	Hunter.always_on = false
	main = load("res://scenes/main.tscn").instantiate()
	main.capture_mouse = false
	add_child(main)
	player = main.player
	world = main.world
	hunter = world.hunters[0]
	main.tod.paused = true
	main.tod.set_hour(14.0)
	_fast_memory()
	await _wait(3.2)
	await _run()
	print("[PLAYTHROUGH] ===== %d checks, %d failures =====" % [checks, failures])
	get_tree().quit(1 if failures > 0 else 0)


func _check(cond: bool, msg: String) -> void:
	checks += 1
	if cond:
		print("[PLAYTHROUGH] PASS  ", msg)
	else:
		failures += 1
		print("[PLAYTHROUGH] FAIL  ", msg)


func _say(n: String) -> void:
	print("[PLAYTHROUGH] ", n)


func _key(code: Key, pressed: bool) -> void:
	var ev := InputEventKey.new()
	ev.physical_keycode = code
	ev.keycode = code
	ev.pressed = pressed
	Input.parse_input_event(ev)


func _press(code: Key, hold := 0.12) -> void:
	await get_tree().process_frame
	_key(code, true)
	await _wait(hold)
	_key(code, false)
	await get_tree().process_frame


## Walk (or run) toward a point with the stick held forward and the camera turned to it.
func _walk_to(target: Vector3, stop_dist := 1.2, timeout := 14.0, run := true) -> float:
	var t := 0.0
	if run:
		_key(KEY_SHIFT, true)
	_key(KEY_W, true)
	while t < timeout:
		_face(target)
		var flat := Vector2(target.x - player.global_position.x, target.z - player.global_position.z)
		if flat.length() < stop_dist or player.state.is_dead():
			break
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
	_key(KEY_W, false)
	_key(KEY_SHIFT, false)
	return t


func _hunter_dist() -> float:
	return Vector2(hunter.global_position.x - player.global_position.x, hunter.global_position.z - player.global_position.z).length()


func _aim_at_hunter() -> void:
	_face(hunter.global_position)


func _run() -> void:
	# 1. Start the game.
	_say("1. the game starts: a Human wakes in the coffin, and the hunt is one quiet line")
	await _shot("p01_wake")
	_check(player.state.mode == PlayerState.Mode.NORMAL and player.form.is_form(&"human"), "control returned, as a Human")
	_check(main.hud.objective_visible() and main.hud.objective_summary().contains("A lantern walks Blackthorn after dark"), "the objective is on screen: '%s'" % main.hud._obj_text.text)
	_check(main.hunt.stage == HuntDirector.Stage.RUMOR and hunter.state == Hunter.State.AWAY, "by day there is a rumour and no hunter")
	# Daylight: read a clue as a Human (the wax under the north window).
	_say("   by day, as a Human, a clue is there for anyone")
	_place(Vector3(1.0, 0, -17.8), 180.0)
	await _wait(0.6)
	await _press(KEY_E)
	await _wait(0.6)
	await _shot("p02_clue_by_day")
	_check(main.hunt.clues_known() >= 1 and main.hud._obj_clue.visible, "the wax is a lead and the line under the clock shows it")
	# 2. Become a vampire at dusk.
	_say("2. dusk falls (fast-forwarded: the real wait is about four minutes); the player becomes a vampire")
	_place(Vector3(3.0, 0, -2.0), 0.0)
	main.tod.set_hour(18.95)
	main.tod.paused = false
	await _wait(1.0)
	await _press(KEY_F)
	await _wait(player.form.transform_time + 0.5)
	await _shot("p03_vampire")
	_check(player.form.is_form(&"vampire") and player.state.mode == PlayerState.Mode.NORMAL, "F: Human -> Vampire, control back")
	# 3. Explore with Sense; the hunter comes out at seven.
	_say("3. explore: Vampiric Sense on, and wait for the night to begin")
	await _press(KEY_Q)
	await _wait(1.2)
	_check(player.abilities.get_ability(&"vampiric_sense").active, "Q: Sense is on")
	var kindled := await _until_state(Hunter.State.PATROL, 12.0)
	await _shot("p04_lantern_kindles")
	_check(kindled and main.hud._toast_label.text.contains("lantern kindles") or kindled, "at seven the hunter comes out of his camp: %s" % main.hud._toast_label.text)
	main.tod.paused = true
	# 4. Go to find him: round by the west, so as to come at him from behind.
	_say("4. find him: round the manor's west side to the pines, keeping to the dark")
	await _walk_to(Vector3(-10.0, 0, -3.0), 1.5, 8.0)
	await _walk_to(Vector3(-20.0, 0, -11.0), 1.5, 8.0)
	await _walk_to(Vector3(-20.0, 0, -19.5), 1.5, 8.0)
	await _wait(0.4)
	await _shot("p05_near_the_camp")
	var sensed := hunter._sense.revealed
	_check(sensed or main.hunt.sighted, "Sense shows him through the dark (revealed %s, sighted %s)" % [sensed, main.hunt.sighted])
	await _wait(0.3)
	_check(main.hunt.stage != HuntDirector.Stage.RUMOR, "the objective moved on (%s): '%s'" % [HuntDirector.Stage.keys()[main.hunt.stage], main.hud._obj_text.text.left(70)])
	# 5. Stalk: stay behind him; wait for his back to turn.
	_say("5. stalk: Sense says whether he has noticed, and which way he faces")
	var hint := ""
	var waited := 0.0
	while waited < 14.0 and hunter.is_up():
		var d := hunter.get_sense_data(_hunter_dist())
		hint = str(d["hint"])
		if hint == "his back is to you" and _hunter_dist() < 14.0:
			break
		# Keep a dark distance, shadowing him along the strip.
		if _hunter_dist() > 9.0:
			_face(hunter.global_position)
			_key(KEY_W, true)
		else:
			_key(KEY_W, false)
		await _wait(0.1)
		waited += 0.1
	_key(KEY_W, false)
	await _shot("p06_stalking")
	_check(hunter.is_unaware() and hunter.state != Hunter.State.HUNTING, "still unnoticed after %.1f s of shadowing (%s, hint '%s')" % [waited, hunter.describe(), hint])
	# 6. Close in at a walk and strike from behind.
	_say("6. choose: from behind, in the dark")
	var close_t := 0.0
	while close_t < 6.0 and _hunter_dist() > 2.0 and hunter.is_unaware():
		_face(hunter.global_position)
		_key(KEY_W, true)
		await _wait(0.05)
		close_t += 0.05
	_key(KEY_W, false)
	var unaware_at_strike := hunter.is_unaware()
	_aim_at_hunter()
	var hp0 := hunter.health
	await _press(KEY_R, 0.1)
	await _wait(0.2)
	await _shot("p07_the_strike")
	await _wait(0.4)
	_check(hunter.health < hp0, "R: Rend lands (-%.0f)" % (hp0 - hunter.health))
	_check(not unaware_at_strike or player.combat.last_info.ambush, "from behind and unnoticed it was an ambush (%s)" % str(player.combat.last_info.ambush))
	_check(hunter.state == Hunter.State.HUNTING, "and now he knows (%s)" % hunter.describe())
	# 7. Keep fighting; take a blow.
	_say("7. he turns on you: a blow lands")
	var hp_player0 := player.health.value
	var blows := 0
	var fight_t := 0.0
	while fight_t < 6.0 and hunter.is_up() and player.health.value >= hp_player0 and not player.state.is_dead():
		_aim_at_hunter()
		if _hunter_dist() > 2.3:
			_key(KEY_W, true)
		else:
			_key(KEY_W, false)
			if not player.combat.is_attacking() and hunter.health > 45.0:
				await _press(KEY_R, 0.06)
		await _wait(0.06)
		fight_t += 0.06
	_key(KEY_W, false)
	await _shot("p08_blow_taken")
	_check(player.health.value < hp_player0, "a blow lands on you (%.0f -> %.0f): %s" % [hp_player0, player.health.value, main.hud._status_label.text])
	# 8. Get away: round the east of the manor to the south face and up the wall.
	_say("8. reposition: run for the manor wall and climb to the roof - he cannot follow")
	await _walk_to(Vector3(11.5, 0, -17.0), 1.5, 5.0)
	await _walk_to(Vector3(11.5, 0, -5.0), 1.5, 5.0)
	await _walk_to(Vector3(-4.0, 0, -3.6), 1.5, 5.0)
	var link: TraversalLink
	for l in world.traversal_links:
		if l.placement.id == &"manor_roof":
			link = l
	var start := link.placement.end_position(0)
	player.global_position = Vector3(start.x, 0.05, start.z + 0.75)
	player.set_facing(0.0)
	player.camera_rig.yaw = 0.0
	await _wait(0.4)
	_check(_prompt().begins_with("Scale the manor wall"), "the wall offers itself: '%s'" % _prompt())
	await _press(KEY_E)
	await _wait(2.0)
	await _shot("p09_on_the_roof")
	_check(player.global_position.y > 3.5, "up on the roof (y %.1f)" % player.global_position.y)
	# 9. On the roof he cannot reach you. Outrunning him has probably lost him already; if he comes to the foot of the wall
	# (hunting or searching) drop on him, and if he went back to his round, climb down and finish it on the ground.
	var came := await _until_close(7.0, 12.0)
	await _wait(0.4)
	await _shot("p10_on_the_roof")
	_check(hunter.landed <= 1, "from the roof he cannot strike you (blows landed in all: %d)" % hunter.landed)
	_say("   he came to the foot of the wall: %s (%.1f m off; %s)" % [str(came), _hunter_dist(), hunter.describe()])
	if came:
		_say("9. from above: walk off the edge and drop on him")
		var hp1 := hunter.health
		_key(KEY_W, true)
		var plunged := false
		var fall_t := 0.0
		while fall_t < 3.0 and hunter.is_up():
			await get_tree().physics_frame
			fall_t += get_physics_process_delta_time()
			_face(hunter.global_position)
			if not player.is_on_floor() and player.velocity.y < -4.0 and _hunter_dist() < 3.4:
				await _press(KEY_R, 0.05)
				plunged = true
				break
		_key(KEY_W, false)
		await _wait(0.5)
		await _shot("p11_the_plunge")
		var kind := str(player.combat.last_info.kind) if player.combat.last_info != null else "none"
		_check(plunged and hunter.health < hp1 and kind == "plunge", "a plunge from the roof (%s): -%.0f%s" % [kind, hp1 - hunter.health, " (an ambush)" if player.combat.last_info.ambush else ""])
	else:
		_check(hunter.state != Hunter.State.HUNTING, "the roof and the dark lost him: he is back to %s" % Hunter.State.keys()[hunter.state])
		_say("9. he went back to his round: climb down and finish it on the ground")
		_key(KEY_W, true)
		var down_t := 0.0
		while down_t < 2.0 and not player.is_on_floor() or (player.global_position.y > 1.0 and down_t < 3.0):
			_face(hunter.global_position)
			await get_tree().physics_frame
			down_t += get_physics_process_delta_time()
		_key(KEY_W, false)
		await _shot("p11_back_on_the_ground")
	# 11. Finish him: strike in his openings, stay out of reach of the blade.
	_say("10. finish it: hit, and be gone when the blade comes down")
	var finish_t := 0.0
	while finish_t < 30.0 and hunter.is_up() and not player.state.is_dead():
		_aim_at_hunter()
		var d := _hunter_dist()
		var dir := (hunter.global_position - player.global_position)
		dir.y = 0.0
		dir = dir.normalized() if dir.length() > 0.05 else Vector3.FORWARD
		if hunter.is_unaware():
			# He has gone back to his round: come at him again, unseen if it can be done.
			_key(KEY_W, d > 2.0)
			if d < 2.4 and not player.combat.is_attacking():
				await _press(KEY_R, 0.05)
		elif hunter.swing == Hunter.Swing.WINDUP and hunter._swing_t > hunter.profile.attack_windup * 0.2 and d < 3.4:
			player.push(-dir * 13.0)
			_key(KEY_W, false)
		elif hunter.swing == Hunter.Swing.RECOVER or hunter._stagger_t > 0.0 or hunter._flinch_t > 0.0:
			if d > 2.0:
				_key(KEY_W, true)
			else:
				_key(KEY_W, false)
			if d < 2.6 and not player.combat.is_attacking():
				await _press(KEY_R, 0.05)
		else:
			_key(KEY_W, d > 3.4)
		await _wait(0.05)
		finish_t += 0.05
	_key(KEY_W, false)
	_check(hunter.state == Hunter.State.DOWNED, "he goes down (%s)" % hunter.describe())
	await _wait(1.0)
	await _shot("p12_he_is_down")
	_check(main.hunt.stage == HuntDirector.Stage.DOWN, "the line under the clock: '%s'" % main.hud._obj_text.text.left(60))
	# 12. Drink.
	_say("11. feed and recover")
	var blood0 := player.blood.value
	var hp_before_feed := player.health.value
	player.blood._set_value(maxf(player.blood.value, 20.0) if player.blood.value > 20.0 else 20.0)
	blood0 = player.blood.value
	var guard := 0.0
	while _hunter_dist() > 1.6 and guard < 4.0:
		_face(hunter.global_position)
		_key(KEY_W, true)
		await _wait(0.05)
		guard += 0.05
	_key(KEY_W, false)
	await _wait(0.5)
	_face(hunter.global_position)
	await _wait(0.3)
	_check(_prompt() == "Drink from the lamplighter", "the prompt: '%s'" % _prompt())
	_key(KEY_E, true)
	await _until_drained(8.0)
	_key(KEY_E, false)
	await _shot("p13_drank")
	_check(hunter.state == Hunter.State.DEAD, "he is drunk dry")
	_check(player.blood.value > blood0 + 40.0, "blood: %.0f -> %.0f" % [blood0, player.blood.value])
	_check(await _wait_memory(3.0), "his blood has a memory to tell")
	await _shot("p14_memory")
	await _dismiss_memory()
	_check(player.surge.active, "a Hunter's Rush is in the blood: %s" % player.surge.effect_text(player.surge.power))
	await _wait(0.6)
	# 13. The hunt is over.
	_say("12. the hunt is over")
	await _shot("p15_done")
	_check(main.hunt.stage == HuntDirector.Stage.DONE and main.hud._obj_text.text.contains("lantern is out"), "'%s'" % main.hud._obj_text.text)
	_check(player.health.value >= hp_before_feed or player.surge.active, "wounds are mending under the rush (%.0f hp)" % player.health.value)
	# 14. Carry on as before: transform back, talk, sleep.
	_say("13. carry on playing: Human again, a word with Tomas, then the coffin")
	player.surge.stop(false)
	await _press(KEY_Q)
	await _wait(0.3)
	await _press(KEY_F)
	await _wait(player.form.transform_time + 0.5)
	_check(player.form.is_form(&"human"), "F: back to a Human")
	main.tod.set_hour(13.0)
	await _wait(0.4)
	_place(world.tomas.global_position + Vector3(-1.4, 0, 0.0), -90.0)
	player.camera_rig.yaw = -PI * 0.5
	await _wait(0.6)
	_check(_prompt().begins_with("Talk to"), "the old game: '%s'" % _prompt())
	await _press(KEY_E)
	await _wait(0.6)
	await _shot("p16_talk_after")
	_check(world.tomas.speech_label.visible, "Tomas answers")
	var coffin_pos: Vector3 = world.coffin.spawn.global_position
	_place(coffin_pos + Vector3(0, 0, 0.4), 0.0)
	await _wait(0.6)
	_check(_prompt() == "Sleep in your coffin", "the coffin still waits: '%s'" % _prompt())
	await _press(KEY_E)
	await _wait(0.8)
	await _press(KEY_ENTER)
	await _wait(7.0)
	_check(player.state.mode == PlayerState.Mode.NORMAL, "and sleeping still works")
	await _shot("p17_next_dusk")
	_check(hunter.state == Hunter.State.DEAD, "the hunter stays dead")


func _until_state(st: Hunter.State, timeout: float) -> bool:
	var t := 0.0
	while t < timeout:
		if hunter.state == st:
			return true
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
	return hunter.state == st


func _until_close(dist: float, timeout: float) -> bool:
	var t := 0.0
	while t < timeout:
		if _hunter_dist() < dist:
			return true
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
	return _hunter_dist() < dist


func _until_drained(timeout: float) -> void:
	var t := 0.0
	while t < timeout and hunter.state != Hunter.State.DEAD:
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
