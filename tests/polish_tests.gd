extends "res://tests/test_base.gd"
## Task 1.8 - vampire world & traversal polish. Drives the real game and checks the things this pass
## changed: traversal that only ever happens on purpose (and in the direction you meant), the blood
## number and what rewards mean, controller movement that grips, what people tell you, a second
## blood source, the wall climb, the cape, and flexible rest in the coffin.
##   godot --headless --path . res://tests/polish_tests.tscn
##   godot --path . res://tests/polish_tests.tscn -- <screenshot_dir>      (windowed: screenshots)

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
	_night()
	await _wait(2.8)
	await _run()
	print("[POLISH] ===== %d checks, %d failures =====" % [checks, failures])
	get_tree().quit(1 if failures > 0 else 0)


func _check(cond: bool, msg: String) -> void:
	checks += 1
	if cond:
		print("[POLISH] PASS  ", msg)
	else:
		failures += 1
		print("[POLISH] FAIL  ", msg)


func _run() -> void:
	_fast_memory()
	if _wants("traversal"):
		await _test_traversal_directions()
		await _test_traversal_levels()
		await _test_traversal_blocked_and_hatch()
	if _wants("blood"):
		await _test_blood_number()
	if _wants("reward"):
		await _test_reward_text()
	if _wants("movement"):
		await _test_movement_feel()
	if _wants("cape"):
		await _test_cape_in_game()
	if _wants("fox"):
		await _test_fox_blood()
	if _wants("people"):
		await _test_npc_tidings()
	if _wants("coffin"):
		await _test_coffin_choices()
	if _wants("memories"):
		await _test_memories_and_clues()


## `-- only=blood,reward` runs just those sections (handy while developing); no argument runs everything.
func _wants(section: String) -> bool:
	return _only.is_empty() or _only.has(section)


# ------------------------------------------------------------------ helpers

func _night() -> void:
	main.tod.paused = true
	main.tod.sun_override = Vector3.ZERO
	main.tod.set_hour(23.0)


func _set_blood(v: float) -> void:
	player.blood._set_value(v)


func _release_all() -> void:
	for a in [&"feed", &"interact", &"sprint", &"move_forward", &"move_back", &"move_left", &"move_right", &"memory_dismiss", &"jump"]:
		Input.action_release(a)


## Everyone at their post (routines frozen), the watchman out of the way, the player fit, in control and a vampire.
func _reset_world() -> void:
	_release_all()
	main.memory_view.force_close()
	PauseControl.clear()
	HumanNpc.schedules_enabled = false
	get_tree().call_group(&"npcs", &"new_day")
	get_tree().call_group(&"secrets", &"new_day")
	world.corvin.global_position = Vector3(31, 0, 27)
	player.health.revive(1.0)
	player.sunlight.reset()
	player.abilities.deactivate_all()
	player.surge.stop(false)
	player.state.set_mode(PlayerState.Mode.NORMAL)
	player.visual.visible = true
	player.form.set_form_immediate(&"vampire")
	_set_blood(60.0)
	InputSetup.set_device_kind(InputSetup.KEYBOARD)


func _link(id: StringName) -> TraversalLink:
	for l in world.traversal_links:
		if l.placement.id == id:
			return l
	return null


## Stand `back` metres behind end `end` of a route (away from where it goes), facing along it (or away).
func _stand_for(id: StringName, end: int, back := 0.6, facing_route := true) -> void:
	var p := _link(id).placement
	var start := p.end_position(end)
	var dir3 := p.end_position(1 - end) - start
	dir3.y = 0.0
	dir3 = dir3.normalized() if dir3.length() > 0.01 else Vector3.FORWARD
	var pos := start - dir3 * back
	pos.y = start.y + 0.05
	var yaw := rad_to_deg(atan2(-dir3.x, -dir3.z))
	_place(pos, yaw if facing_route else yaw + 180.0)
	await _wait(0.45)


func _tap_and_settle(route_id: StringName, wait_extra := 0.45) -> void:
	await _tap(&"interact")
	await _wait(TraversalController.route_duration(_link(route_id).placement) + wait_extra)


# ------------------------------------------------------------------ traversal: direction

func _test_traversal_directions() -> void:
	print("[POLISH] --- TRAVERSAL: IN means in, OUT means out ---")
	_reset_world()
	var trav := player.traversal

	# From outside, facing the window: the offer is to go IN, and that is what happens.
	await _stand_for(&"manor_window", 0)
	_check(_prompt() == "Slip into the manor through the window", "outside, facing the window, the offer is to go in: %s" % _prompt())
	var done := trav.traversals_done
	await _tap_and_settle(&"manor_window")
	_check(trav.traversals_done == done + 1 and player.global_position.z < -6.3 and player.global_position.distance_to(Vector3(6.2, 0, -7.4)) < 0.8,
		"pressing it takes you inside the manor (z %.2f)" % player.global_position.z)

	# The core test: mash interact right after arriving. You were facing in; you stay in.
	var after_in := player.global_position
	await _tap(&"interact")
	await _wait(0.2)
	await _tap(&"interact")
	await _wait(1.3)
	_check(player.global_position.z < -6.3 and trav.traversals_done == done + 1, "pressing interact again, still facing inward, does NOT send you back out (z %.2f)" % player.global_position.z)
	_check(not _prompt().contains("out"), "...and no way out is offered while you face into the room: '%s'" % _prompt())

	# Turn around, face the window from inside: now the offer is OUT.
	await _stand_for(&"manor_window", 1)
	_check(_prompt() == "Slip out of the manor through the window", "inside, facing the window, the offer is to go out: %s" % _prompt())
	await _tap_and_settle(&"manor_window")
	_check(player.global_position.z > -5.0, "pressing it takes you out into the yard (z %.2f)" % player.global_position.z)

	# Inside but facing away from the window: nothing is offered and nothing happens.
	await _stand_for(&"manor_window", 1, 0.6, false)
	_check(_prompt() == "none" or not _prompt().contains("window"), "inside, back to the window: no offer (%s)" % _prompt())
	done = trav.traversals_done
	await _tap(&"interact")
	await _wait(1.3)
	_check(trav.traversals_done == done and player.global_position.z < -6.3, "...and pressing interact there does nothing")

	# Right up against the wall inside, still facing the room: not "out".
	_place(Vector3(6.2, 0, -6.55), 0.0)    # yaw 0 = looking -Z, into the room
	await _wait(0.4)
	_check(not trav.can_start(_link(&"manor_window"), 0), "inside by the sill, the OUTSIDE end of the window can never be started")
	_check(trav.problem(_link(&"manor_window"), 0) == &"side", "...because you are on the wrong side of the wall (%s)" % trav.problem(_link(&"manor_window"), 0))
	# Same from outside by the sill.
	_place(Vector3(6.2, 0, -5.45), 180.0)
	await _wait(0.4)
	_check(trav.problem(_link(&"manor_window"), 1) == &"side", "outside by the sill, the INSIDE end can never be started (%s)" % trav.problem(_link(&"manor_window"), 1))

	# Every window both ways, by explicit input: ends on the far side, never the near one.
	var ok := true
	var report := []
	for id in [&"manor_window", &"cottage_window", &"gatehouse_window"]:
		for end in [0, 1]:
			var p := _link(id).placement
			await _stand_for(id, end)
			var before := player.global_position
			await _tap_and_settle(id)
			var dest := p.end_position(1 - end)
			var good := player.global_position.distance_to(dest) < 0.9 and player.global_position.distance_to(p.end_position(end)) > 1.5
			ok = ok and good
			if not good:
				report.append("%s/%d %s -> %s" % [id, end, str(before.snapped(Vector3(0.1, 0.1, 0.1))), str(player.global_position.snapped(Vector3(0.1, 0.1, 0.1)))])
	_check(ok, "all three windows take you to the far side from each end %s" % str(report))
	_reset_world()


# ------------------------------------------------------------------ traversal: levels (roofs vs rooms)

func _test_traversal_levels() -> void:
	print("[POLISH] --- TRAVERSAL: a roof is not the room below it ---")
	_reset_world()
	var trav := player.traversal

	# Inside the manor under the roof end of the wall climb: the "drop from the roof" must not be offered.
	_place(Vector3(-5.0, 0, -7.2), 180.0)
	await _wait(0.5)
	_check(_prompt() == "none" or not _prompt().contains("roof"), "inside the manor under the roof's edge, no roof route is offered (%s)" % _prompt())
	var done := trav.traversals_done
	await _tap(&"interact")
	await _wait(1.6)
	_check(trav.traversals_done == done and player.global_position.y < 0.3, "...and pressing interact there does nothing (y %.2f)" % player.global_position.y)
	_check(trav.problem(_link(&"manor_roof"), 1) == &"level", "the roof end is on another level from the hall floor (%s)" % trav.problem(_link(&"manor_roof"), 1))

	# Up on the roof directly above the front window: the window is not offered.
	_place(Vector3(6.2, 3.9, -6.0), 180.0)
	await _wait(0.6)
	_check(player.is_on_floor() or player.global_position.y > 3.7, "standing on the roof above the manor window (y %.2f)" % player.global_position.y)
	_check(not trav.can_start(_link(&"manor_window"), 0), "on the roof, the window below is not available (%s)" % trav.problem(_link(&"manor_window"), 0))
	_check(_prompt() == "none" or not _prompt().contains("window"), "...no window prompt on the roof (%s)" % _prompt())
	done = trav.traversals_done
	await _tap(&"interact")
	await _wait(1.2)
	_check(trav.traversals_done == done and player.global_position.y > 3.5, "...and pressing interact on the roof does not vault you through it")

	# On the roof above the cellar hatch: the hatch is a floor-level thing.
	_place(Vector3(5.2, 3.9, -10.4), 0.0)
	await _wait(0.6)
	_check(not _prompt().to_lower().contains("hatch"), "on the roof above the cellar hatch, it is not offered (%s)" % _prompt())
	# ...but it is offered from the hall floor beside it.
	_place(Vector3(5.2, 0, -9.7), 0.0)
	await _wait(0.5)
	_check(_prompt().to_lower().contains("hatch"), "on the floor beside the cellar hatch it is (%s)" % _prompt())

	# Roof edge: standing at it offers a drop only when you face it, never by itself.
	_reset_world()
	await _stand_for(&"cottage_roof", 0)
	await _tap_and_settle(&"cottage_roof", 0.8)
	_check(player.global_position.y > 2.9, "the cottage wall climb ends on the roof (y %.2f)" % player.global_position.y)
	done = trav.traversals_done
	_place(Vector3(23.1, 3.1, 18.0), 90.0)       # on the roof, looking back over the roof (+X is the edge; yaw 90 looks -X)
	await _wait(0.5)
	_check(_prompt() == "none" or not _prompt().contains("Drop"), "on the roof but facing away from the edge, no drop is offered (%s)" % _prompt())
	_place(Vector3(23.1, 3.1, 18.0), -90.0)      # facing the edge (toward +X)
	await _wait(0.5)
	_check(_prompt() == "Drop from the cottage roof to the yard", "facing the edge, it is (%s)" % _prompt())
	await _tap_and_settle(&"cottage_roof", 0.6)
	_check(player.global_position.y < 0.3 and player.global_position.x > 24.3, "...and it drops you to the yard on the outside (x %.2f, y %.2f)" % [player.global_position.x, player.global_position.y])

	# Walking off a roof is just falling: it never starts a traversal.
	_reset_world()
	await _stand_for(&"manor_roof", 0)
	await _tap_and_settle(&"manor_roof", 0.8)
	_check(player.global_position.y > 3.7, "the manor wall climb ends on the roof (y %.2f)" % player.global_position.y)
	done = trav.traversals_done
	Input.action_press(&"move_forward")
	player.camera_rig.yaw = PI          # look (and run) toward +Z, the roof's front edge
	await _wait(1.6)
	Input.action_release(&"move_forward")
	_check(trav.traversals_done == done, "running off the roof edge does not trigger a route")
	_reset_world()


# ------------------------------------------------------------------ traversal: blocked landings and the hatch

func _test_traversal_blocked_and_hatch() -> void:
	print("[POLISH] --- TRAVERSAL: blocked landings, the broken roof ---")
	_reset_world()
	var trav := player.traversal
	var block := StaticBody3D.new()
	block.collision_layer = 1
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(3.0, 2.0, 3.0)
	cs.shape = box
	block.add_child(cs)
	world.add_child(block)
	block.global_position = Vector3(6.2, 1.0, -7.4)
	await get_tree().physics_frame
	await _stand_for(&"manor_window", 0)
	_check(trav.problem(_link(&"manor_window"), 0) == &"blocked", "with the landing spot filled, the route is refused (%s)" % trav.problem(_link(&"manor_window"), 0))
	_check(_prompt() == "none" or not _prompt().contains("window"), "...and it is not offered (%s)" % _prompt())
	var at := player.global_position
	var done := trav.traversals_done
	await _tap(&"interact")
	await _wait(1.3)
	_check(trav.traversals_done == done and player.global_position.distance_to(at) < 0.3, "...pressing interact leaves you exactly where you were")
	_check(not trav.start(_link(&"manor_window"), 0), "start() refuses a blocked route too")
	# The fallback still guarantees a clear body if something fills the exit mid-route.
	block.queue_free()
	await get_tree().physics_frame
	await _stand_for(&"manor_window", 0)
	_check(trav.start(_link(&"manor_window"), 0), "with it clear again, it starts")
	await _wait(0.3)
	var blocker := StaticBody3D.new()
	blocker.collision_layer = 1
	var cs2 := CollisionShape3D.new()
	cs2.shape = box
	blocker.add_child(cs2)
	world.add_child(blocker)
	blocker.global_position = Vector3(6.2, 1.0, -7.4)
	var blocked_signals := []
	trav.blocked.connect(func(_l): blocked_signals.append(1))
	await _wait(1.2)
	_check(trav.is_clear(player.global_position) and player.state.mode == PlayerState.Mode.NORMAL, "if the exit fills up mid-route the body is NOT left inside it (%s)" % str(player.global_position.snapped(Vector3(0.1, 0.1, 0.1))))
	_check(blocked_signals.size() == 1, "...it returns to the start and says so")
	blocker.queue_free()
	await get_tree().physics_frame

	# The broken roof: out through it from the hall, and back down through it from the roof.
	_reset_world()
	await _stand_for(&"manor_hatch", 0)
	_check(_prompt() == "Climb out through the broken roof", "under the hole in the hall: %s" % _prompt())
	await _tap_and_settle(&"manor_hatch", 0.7)
	_check(player.global_position.y > 3.7 and player.is_on_floor() and trav.is_clear(player.global_position), "it puts you on the roof, standing (y %.2f)" % player.global_position.y)
	_check(_prompt() == "none", "...and with your back to the hole nothing is offered, so a second press cannot send you straight back down (%s)" % _prompt())
	await _stand_for(&"manor_hatch", 1)
	_check(_prompt() == "Drop through the broken roof into the hall", "on the roof facing the hole: %s" % _prompt())
	await _tap_and_settle(&"manor_hatch", 0.7)
	_check(player.global_position.y < 0.3 and absf(player.global_position.x - 6.55) < 0.8 and player.global_position.z < -12.8, "it drops you into the hall under the hole (%s)" % str(player.global_position.snapped(Vector3(0.1, 0.1, 0.1))))
	# Nobody falls through it by accident: run straight at the hole on the roof.
	_reset_world()
	_place(Vector3(6.55, 3.9, -9.5), 0.0)
	await _wait(0.6)
	player.camera_rig.yaw = 0.0
	Input.action_press(&"move_forward")
	Input.action_press(&"sprint")
	await _wait(1.6)
	Input.action_release(&"move_forward")
	Input.action_release(&"sprint")
	_check(player.global_position.y > 3.7, "running straight at the hole in the roof: the rim holds, you stay on the roof (y %.2f, z %.2f)" % [player.global_position.y, player.global_position.z])
	_reset_world()


# ------------------------------------------------------------------ blood: the number

func _approach_elise() -> void:
	_place(Vector3(-20.4, 0, 5.5), 90.0)
	await _run_until_focus(world.elise.global_position, 3.0)


func _test_blood_number() -> void:
	print("[POLISH] --- BLOOD: a number under the vessel that is the real amount ---")
	_reset_world()
	var gauge: BloodGauge = main.hud._gauge
	for v in [100.0, 73.0, 41.0, 18.0, 4.0, 0.0]:
		_set_blood(v)
		await _wait(1.8)
		_check(gauge.number_text() == "%d / 100" % roundi(player.blood.value) and gauge.displayed_amount() == roundi(v), "blood %d shows as '%s'" % [roundi(v), gauge.number_text()])
	_check(gauge.size.y >= 200.0, "there is room under the vessel for it (gauge %.0f x %.0f)" % [gauge.size.x, gauge.size.y])
	# The vessel is still the thing: the liquid level and the number agree.
	_set_blood(64.0)
	await _wait(1.8)
	_check(absf(gauge.displayed_blood() - 0.64) < 0.02 and gauge.displayed_amount() == 64, "the vessel and the number tell the same story (%.2f full, %d)" % [gauge.displayed_blood(), gauge.displayed_amount()])

	# Real-time drain, as the player lives it.
	player.form.set_form_immediate(&"human")
	_set_blood(50.0)
	var h0 := player.blood.value
	await _wait(5.0)
	var lost_h := h0 - player.blood.value
	_check(lost_h > 0.05 and lost_h < 0.25, "a Human loses %.2f blood in 5 s (0.02/s): a background fact" % lost_h)
	player.form.set_form_immediate(&"vampire")
	_set_blood(50.0)
	var v0 := player.blood.value
	await _wait(5.0)
	var lost_v := v0 - player.blood.value
	_check(lost_v > 0.6 and lost_v < 1.1, "a Vampire loses %.2f blood in 5 s (0.16/s)" % lost_v)

	# Feeding: the number climbs with the liquid instead of jumping.
	_reset_world()
	HumanNpc.reset_tasted()
	_set_blood(30.0)
	await _wait(1.8)
	await _approach_elise()
	var seen: Array[int] = []
	var b0 := player.blood.value
	Input.action_press(&"feed")
	var t := 0.0
	while t < 5.2 and player.state.mode != PlayerState.Mode.MEMORY:
		await get_tree().process_frame
		t += get_process_delta_time()
		var n := gauge.displayed_amount()
		if seen.is_empty() or seen[seen.size() - 1] != n:
			seen.append(n)
	Input.action_release(&"feed")
	var rising := true
	for i in range(1, seen.size()):
		rising = rising and seen[i] >= seen[i - 1]
	_check(seen.size() >= 8 and rising, "feeding makes the number climb through %d steps rather than jump (%d -> %d)" % [seen.size(), seen[0] if seen.size() > 0 else -1, seen[seen.size() - 1] if seen.size() > 0 else -1])
	_check(player.blood.value > b0 + 25.0, "feeding restores real blood (%.0f -> %.0f)" % [b0, player.blood.value])
	_check(await _wait_memory(3.0), "the memory opens")
	await _dismiss_memory()
	await _wait(1.8)
	_check(gauge.displayed_amount() == roundi(player.blood.value), "afterwards the number matches the amount (%s vs %.1f)" % [gauge.number_text(), player.blood.value])
	_reset_world()


# ------------------------------------------------------------------ rewards you can read

func _test_reward_text() -> void:
	print("[POLISH] --- BLOODRUSH: what it is, what it does, how long ---")
	_reset_world()
	HumanNpc.reset_tasted()
	_set_blood(40.0)
	await _approach_elise()
	Input.action_press(&"feed")
	await _wait(5.2)
	Input.action_release(&"feed")
	_check(await _wait_memory(3.0), "a memory opens after the feed")
	await _wait(2.0)
	var mv: MemoryView = main.memory_view
	_check(mv._reward.text.contains("blood restored") and mv._reward.text.contains("+"), "the memory says how much blood you got: '%s'" % mv._reward.text.replace("
", " | "))
	_check(mv._reward.text.contains(player.surge.surge_name) and mv._reward.text.contains("speed") and mv._reward.text.contains("Sense is free"), "...and what the rush does for you")
	_check(mv._reward.text.contains("0:") or mv._reward.text.contains(":"), "...and for how long")
	_check(mv._meta.text.contains("Bright blood.") and mv._meta.text.contains("Young, quick and heady"), "the blood's own nature is named, not just a colour word: '%s'" % mv._meta.text.replace("
", " | "))
	_check(mv._body.text.length() > 80 and not mv._body.text.contains("+"), "the memory itself stays a mystery: no numbers in the story")
	main.memory_view.force_close()
	_reset_world()
	player.form.set_form_immediate(&"vampire")
	player.surge.start(1.35, 32.0, "Fury")
	await _wait(1.0)
	var hud: Hud = main.hud
	_check(hud._surge_label.text.begins_with("Fury") and hud._surge_label.text.contains("left") and hud._surge_label.text.contains("0:3"), "the HUD names the rush and counts it down: '%s'" % hud._surge_label.text)
	_check(hud._surge_detail.text.to_lower().contains("faster") and hud._surge_detail.text.to_lower().contains("sense"), "...with what it does underneath: '%s'" % hud._surge_detail.text)
	_check(hud._toast_label.text.contains("Fury") and hud._toast_label.text.contains("+22% speed"), "starting one tells you the numbers: '%s'" % hud._toast_label.text)
	var s0 := player.surge.seconds_left
	await _wait(2.0)
	_check(s0 - player.surge.seconds_left > 1.7 and s0 - player.surge.seconds_left < 2.3, "the timer really counts seconds down (%.1f -> %.1f)" % [s0, player.surge.seconds_left])
	player.surge.seconds_left = 0.6
	await _wait(1.4)
	_check(not player.surge.active and not player.speed_modifiers.has(&"surge") and player.jump_multiplier == 1.0, "when it runs out it ends cleanly")
	_check(hud._surge_label.text == "" and hud._surge_detail.text == "", "...and the HUD lets go of it")
	_check(player.surge.effect_text(1.0) == "+16% speed, +10% jump, Sense is free, sun burns 15% slower", "the description is generated from the real tuning: %s" % player.surge.effect_text(1.0))
	_reset_world()


# ------------------------------------------------------------------ controller movement

func _pad_axis(axis: JoyAxis, value: float) -> void:
	var ev := InputEventJoypadMotion.new()
	ev.axis = axis
	ev.axis_value = value
	ev.device = 0
	Input.parse_input_event(ev)


func _pad(button: JoyButton, pressed: bool) -> void:
	var ev := InputEventJoypadButton.new()
	ev.button_index = button
	ev.pressed = pressed
	ev.device = 0
	Input.parse_input_event(ev)


func _flat_speed() -> float:
	return Vector2(player.velocity.x, player.velocity.z).length()


## Right after letting go: how long and how far the body keeps going.
func _measure_stop() -> Dictionary:
	var start := player.global_position
	var t := 0.0
	while t < 1.5:
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
		if _flat_speed() < 0.25:
			break
	return {"time": t, "dist": Vector2(player.global_position.x - start.x, player.global_position.z - start.z).length()}


func _test_movement_feel() -> void:
	print("[POLISH] --- CONTROLLER: grip, not ice ---")
	_reset_world()
	# A clear stretch of road, running south (+Z). Yaw 180 faces +Z; the stick's "up" follows the camera.
	_place(Vector3(3.0, 0, 5.0), 180.0)
	await _wait(0.6)

	# Full-tilt pad run: reaches speed, then lets go.
	_pad_axis(JOY_AXIS_LEFT_Y, -1.0)
	_pad_axis(JOY_AXIS_TRIGGER_RIGHT, 1.0)
	await _wait(0.06)
	_check(_flat_speed() > 0.5 and _flat_speed() < player.form.current.run_speed * 0.9, "getting going is quick but not instant (%.1f m/s after 0.06 s)" % _flat_speed())
	await _wait(1.0)
	var top := _flat_speed()
	_check(top > player.form.current.run_speed * 0.95 and top < player.form.current.run_speed * 1.02, "the right trigger gives the vampire's run (%.1f m/s)" % top)
	_pad_axis(JOY_AXIS_LEFT_Y, 0.0)
	_pad_axis(JOY_AXIS_TRIGGER_RIGHT, 0.0)
	var stop: Dictionary = await _measure_stop()
	_check(stop["time"] < 0.3 and stop["dist"] < 1.0, "letting go of a full run stops you in %.2f s / %.2f m (was ~1.5 m of sliding)" % [stop["time"], stop["dist"]])
	_check(stop["dist"] > 0.15, "...but not dead on the spot: there is weight (%.2f m)" % stop["dist"])

	# Keyboard gives the same grip.
	_place(Vector3(3.0, 0, 5.0), 180.0)
	await _wait(0.5)
	Input.action_press(&"move_forward")
	Input.action_press(&"sprint")
	await _wait(1.0)
	Input.action_release(&"move_forward")
	Input.action_release(&"sprint")
	stop = await _measure_stop()
	_check(stop["time"] < 0.3 and stop["dist"] < 1.0, "the keyboard stops just as crisply (%.2f s / %.2f m)" % [stop["time"], stop["dist"]])

	# A human feels the same: crisp, not skating.
	player.form.set_form_immediate(&"human")
	_place(Vector3(3.0, 0, 5.0), 180.0)
	await _wait(0.5)
	Input.action_press(&"move_forward")
	Input.action_press(&"sprint")
	await _wait(1.0)
	var human_top := _flat_speed()
	Input.action_release(&"move_forward")
	Input.action_release(&"sprint")
	stop = await _measure_stop()
	_check(human_top > 5.2 and stop["time"] < 0.25 and stop["dist"] < 0.7, "a Human runs at %.1f m/s and stops in %.2f s / %.2f m" % [human_top, stop["time"], stop["dist"]])
	player.form.set_form_immediate(&"vampire")

	# Analog: a gentle push is a gentle walk, and it settles steadily.
	_place(Vector3(3.0, 0, 5.0), 180.0)
	await _wait(0.5)
	_pad_axis(JOY_AXIS_LEFT_Y, -0.6)
	await _wait(0.8)
	var half := _flat_speed()
	_pad_axis(JOY_AXIS_LEFT_Y, -1.0)
	await _wait(0.8)
	var full := _flat_speed()
	_pad_axis(JOY_AXIS_LEFT_Y, 0.0)
	await _measure_stop()
	_check(half > 0.3 * full and half < 0.8 * full and full > player.form.current.walk_speed * 0.95, "a part-tilted stick is a part-speed walk (%.1f of %.1f m/s)" % [half, full])
	# The stick's small drift does nothing (deadzone).
	_place(Vector3(3.0, 0, 5.0), 180.0)
	await _wait(0.4)
	var p0 := player.global_position
	_pad_axis(JOY_AXIS_LEFT_X, 0.12)
	_pad_axis(JOY_AXIS_LEFT_Y, -0.1)
	await _wait(0.6)
	_check(player.global_position.distance_to(p0) < 0.05, "a resting stick that reads a little off-centre does not move you (%.2f m)" % player.global_position.distance_to(p0))
	_pad_axis(JOY_AXIS_LEFT_X, 0.0)
	_pad_axis(JOY_AXIS_LEFT_Y, 0.0)

	# Camera-relative: stick up goes where the camera looks, whichever way that is.
	_place(Vector3(3.0, 0, 8.0), 90.0)     # looking -X
	await _wait(0.4)
	var x0 := player.global_position.x
	_pad_axis(JOY_AXIS_LEFT_Y, -1.0)
	await _wait(0.5)
	_pad_axis(JOY_AXIS_LEFT_Y, 0.0)
	await _measure_stop()
	_check(player.global_position.x < x0 - 1.0 and absf(player.global_position.z - 8.0) < 0.4, "stick up moves along the camera's view (x %.1f -> %.1f)" % [x0, player.global_position.x])

	# A hard turn at a run: the old direction does not linger.
	_place(Vector3(3.0, 0, 5.0), 180.0)
	await _wait(0.5)
	Input.action_press(&"move_forward")
	Input.action_press(&"sprint")
	await _wait(0.9)
	Input.action_release(&"move_forward")
	Input.action_press(&"move_right")
	await _wait(0.22)
	var old_dir := absf(player.velocity.z)
	var new_dir := absf(player.velocity.x)
	Input.action_release(&"move_right")
	Input.action_release(&"sprint")
	await _measure_stop()
	_check(old_dir < 1.5 and new_dir > 5.0, "turning 90 degrees at a run bites: old direction %.1f m/s, new %.1f m/s after 0.22 s" % [old_dir, new_dir])
	_release_all()
	_pad_axis(JOY_AXIS_LEFT_X, 0.0)
	_pad_axis(JOY_AXIS_LEFT_Y, 0.0)
	_pad_axis(JOY_AXIS_TRIGGER_RIGHT, 0.0)

	# Everything that was bound still is, and the menus still answer to the pad.
	var expected := {
		&"jump": JOY_BUTTON_A, &"interact": JOY_BUTTON_X, &"feed": JOY_BUTTON_X, &"transform": JOY_BUTTON_Y,
		&"vampiric_sense": JOY_BUTTON_LEFT_SHOULDER, &"pause": JOY_BUTTON_START, &"toggle_help": JOY_BUTTON_BACK,
		&"sprint_toggle": JOY_BUTTON_LEFT_STICK,
	}
	var all_bound := true
	var missing := []
	for action in expected:
		var found := false
		for ev in InputMap.action_get_events(action):
			if ev is InputEventJoypadButton and ev.button_index == expected[action]:
				found = true
		if not found:
			all_bound = false
			missing.append(action)
	_check(all_bound, "the pad layout is unchanged: A jump, X interact/feed, Y transform, LB Sense, Menu pause, View controls, L3 run latch %s" % str(missing))
	var every := true
	for action in InputSetup.GAMEPLAY_ACTIONS:
		every = every and InputMap.has_action(action) and not InputMap.action_get_events(action).is_empty()
	_check(every, "every gameplay action still has a binding")
	_pad(JOY_BUTTON_START, true)
	await get_tree().process_frame
	await get_tree().process_frame
	_pad(JOY_BUTTON_START, false)
	await _wait(0.3)
	_check(main.pause_menu.is_open(), "Menu opens the pause menu")
	var focus_before := get_viewport().gui_get_focus_owner()
	_pad(JOY_BUTTON_DPAD_DOWN, true)
	await get_tree().process_frame
	await get_tree().process_frame
	_pad(JOY_BUTTON_DPAD_DOWN, false)
	await _wait(0.2)
	_check(get_viewport().gui_get_focus_owner() != focus_before, "the D-pad moves between menu entries")
	_pad(JOY_BUTTON_B, true)
	await get_tree().process_frame
	await get_tree().process_frame
	_pad(JOY_BUTTON_B, false)
	await _wait(0.3)
	_check(not main.pause_menu.is_open(), "B backs out of it")
	_reset_world()


# ------------------------------------------------------------------ the cape in the real game

func _test_cape_in_game() -> void:
	print("[POLISH] --- CAPE: follows the body while you play ---")
	_reset_world()
	var vis: HumanoidModel = player.visual
	var worst := 1.0
	_place(Vector3(3.0, 0, 5.0), 180.0)
	await _wait(0.5)
	Input.action_press(&"move_forward")
	Input.action_press(&"sprint")
	var t := 0.0
	while t < 1.4:
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
		worst = minf(worst, vis.cape_clearance())
	_check(worst >= -0.01, "running: the cape stays behind the legs (worst slack %.3f m)" % worst)
	# Turning and jumping while running.
	var turn_worst := 1.0
	Input.action_release(&"move_forward")
	Input.action_press(&"move_right")
	await _tap(&"jump")
	t = 0.0
	while t < 1.0:
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
		turn_worst = minf(turn_worst, vis.cape_clearance())
	Input.action_release(&"move_right")
	Input.action_release(&"sprint")
	_check(turn_worst >= -0.01, "turning and jumping: still clear (worst slack %.3f m)" % turn_worst)
	_check(vis._cloak.visible and vis._cloak.get_parent() == vis.body, "the cape is attached to the body and visible as a vampire")
	# Transformation: the pose arches the back and flings the arms; the cape must follow.
	_reset_world()
	player.form.set_form_immediate(&"human")
	await _wait(0.3)
	_check(not vis._cloak.visible, "as a Human there is no cape")
	var tw := 1.0
	player.form.request_form(&"vampire")
	t = 0.0
	var saw_pose := false
	while t < player.form.transform_time + 0.4:
		await get_tree().process_frame
		t += get_process_delta_time()
		tw = minf(tw, vis.cape_clearance())
		saw_pose = saw_pose or vis.pose_amount > 0.3
	_check(saw_pose and tw >= -0.01, "through the transformation (arched, arms wide) the cape never passes through you (worst slack %.3f m)" % tw)
	_check(player.form.is_form(&"vampire") and vis._cloak.visible, "...and you come out a vampire, caped")
	# The cape tip trails behind.
	await _wait(0.5)
	_check(vis.cape_tip().x > 0.3, "at rest it hangs behind you (z %.2f)" % vis.cape_tip().x)
	_reset_world()


# ------------------------------------------------------------------ a second blood: the fox

func _fox(i := 0) -> Animal:
	return world.animals[i]


## Everyone back to their routine at `hour`, foxes included, the player a vampire at `where`.
func _fox_scene(hour: float, where: Vector3, yaw_deg: float) -> void:
	_reset_world()
	HumanNpc.reset_tasted()
	main.tod.set_hour(hour)
	get_tree().call_group(&"animals", &"new_day")
	_place(where, yaw_deg)
	await _wait(0.5)


func _test_fox_blood() -> void:
	print("[POLISH] --- A SECOND BLOOD: the fox ---")
	_reset_world()
	var foxes := world.animals
	_check(foxes.size() == 2 and _fox(0).profile.id == &"fox" and _fox(0) is FeedSource and world.elise is FeedSource, "two foxes live by the old wall; people and animals are both FeedSources")
	var profile: AnimalProfile = _fox(0).profile
	_check(ContentRegistry.get_def(&"AnimalProfile", &"fox") == profile and profile.blood_definition() != null and profile.blood_definition().id == &"wild" and _fox(0).feed_style().id == &"wild", "the fox is data: AnimalProfile + BloodDefinition 'wild' + FeedStyle 'wild'")
	# How it differs from a person - safer, smaller, lighter - without making people obsolete.
	var wild := _fox(0).feed_style()
	var calm := ContentRegistry.get_def(&"FeedStyle", &"calm") as FeedStyle
	var tomas := ContentRegistry.npc(&"tomas")
	var tomas_yield := tomas.blood_yield * tomas.blood_definition().yield_multiplier
	_check(wild.noise_radius == 0.0 and wild.witness_radius < calm.witness_radius * 0.7, "a fox is quiet and seldom noticed (witness radius %.0f vs %.0f m)" % [wild.witness_radius, calm.witness_radius])
	_check(float(_fox(0).get_feed_result()["yield"]) < tomas_yield * 0.7 and wild.surge_power < calm.surge_power and wild.surge_seconds < calm.surge_seconds, "...but gives less blood (%.0f vs %.0f) and a lighter, shorter rush (%s %.1f x %.0f s)" % [float(_fox(0).get_feed_result()["yield"]), tomas_yield, wild.surge_name, wild.surge_power, wild.surge_seconds])
	_check(profile.feed_seconds < player.feeding.duration, "...and is over quickly (%.1f s)" % profile.feed_seconds)

	# By day they sleep curled at the den; by night they are up.
	await _fox_scene(13.0, Vector3(19.0, 0, 3.0), 180.0)
	_check(_fox(0).mode == Animal.Mode.SLEEPING and _fox(0).global_position.distance_to(_fox(0).den) < 1.5, "by day the fox sleeps at its den (%s)" % Animal.Mode.keys()[_fox(0).mode])
	await _fox_scene(23.0, Vector3(19.0, 0, -8.0), 180.0)
	_check(_fox(0).mode != Animal.Mode.SLEEPING and _fox(1).mode != Animal.Mode.SLEEPING, "by night they are up and about (%s, %s)" % [Animal.Mode.keys()[_fox(0).mode], Animal.Mode.keys()[_fox(1).mode]])
	# They wander, but only near home.
	var far_most := 0.0
	var moved := 0.0
	var last := _fox(0).global_position
	for i in 24:
		await _wait(0.5)
		far_most = maxf(far_most, _fox(0).global_position.distance_to(_fox(0).den))
		moved += _fox(0).global_position.distance_to(last)
		last = _fox(0).global_position
	_check(moved > 1.5 and far_most <= profile.roam_radius + 2.0, "left alone at night a fox wanders (%.1f m in 12 s) but stays within %.1f m of its den" % [moved, far_most])

	# Sense finds them.
	await _fox_scene(23.0, Vector3(19.0, 0, -2.0), 180.0)
	_set_blood(80.0)
	var sense: VampiricSense = player.abilities.get_ability(&"vampiric_sense")
	await _tap(&"vampiric_sense")
	await _wait(2.6)
	var fox := _fox(0)
	var data := fox.get_sense_data(fox.global_position.distance_to(player.global_position))
	_check(fox._sense.revealed and sense.active, "Vampiric Sense reveals the fox through the dark (%.0f m)" % fox.global_position.distance_to(player.global_position))
	var near := fox.get_sense_data(5.0)
	_check(near["title"] == "A fox" and String(near["blood"]).contains("Wild") and near["hint"] == "a memory waits" and float(near["bpm"]) > 100.0, "close up it reads as a fox: a quick heart (%d bpm), wild blood, and a memory waiting" % roundi(float(near["bpm"])))
	_check(fox.get_sense_data(25.0)["title"] == "" and fox.get_sense_data(14.0)["title"] == "something small and quick", "far off you only feel that something small and quick has a heart")
	await _tap(&"vampiric_sense")

	# Skittish: a vampire spooks them, a human does not, a sprint most of all.
	await _fox_scene(23.0, Vector3(19.0, 0, 3.5), 180.0)
	fox = _fox(0)
	fox.global_position = Vector3(19.0, 0, 9.0)
	fox._set_mode(Animal.Mode.IDLE)
	fox._timer = 20.0
	player.form.set_form_immediate(&"human")
	await _wait(2.0)
	_check(fox.mode == Animal.Mode.IDLE and fox.awareness < 0.5, "a Human walking up to a fox hardly bothers it (%s, awareness %.2f)" % [Animal.Mode.keys()[fox.mode], fox.awareness])
	player.form.set_form_immediate(&"vampire")
	var d0 := fox.global_position.distance_to(player.global_position)
	Input.action_press(&"move_forward")
	Input.action_press(&"sprint")
	player.camera_rig.yaw = PI
	var spooked := false
	var t := 0.0
	while t < 3.0:
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
		if fox.mode == Animal.Mode.ALERT or fox.mode == Animal.Mode.FLEE:
			spooked = true
			break
	Input.action_release(&"move_forward")
	Input.action_release(&"sprint")
	_check(spooked, "a sprinting vampire spooks it (%s after %.1f s, %.1f m away)" % [Animal.Mode.keys()[fox.mode], t, fox.global_position.distance_to(player.global_position)])
	var gap0 := fox.global_position.distance_to(player.global_position)
	await _wait(2.0)
	_check(fox.mode == Animal.Mode.FLEE and fox.global_position.distance_to(player.global_position) > gap0 + 3.0, "...and it bolts (%.1f -> %.1f m)" % [gap0, fox.global_position.distance_to(player.global_position)])
	_check(not fox.can_be_fed() == false and fox._interactable.is_available(player), "a fleeing fox can still be seized")

	# The feed: creep up on a sleeping fox by day.
	await _fox_scene(13.0, Vector3(19.0, 0, 7.3), 180.0)
	fox = _fox(0)
	_check(fox.mode == Animal.Mode.SLEEPING, "the fox is asleep at its den")
	await _wait(0.4)
	_check(_prompt() == "Feed on the sleeping fox" and main.hud._prompt_glyph.action == &"feed", "the prompt: '%s' (feed button)" % _prompt())
	_set_blood(40.0)
	var pulses := Haptics.pulse_count
	var b0 := player.blood.value
	Input.action_press(&"feed")
	await _wait(1.1)
	_check(player.state.mode == PlayerState.Mode.FEEDING and player.feeding.style.id == &"wild" and fox.mode == Animal.Mode.ENTRANCED, "holding feed drinks from it, styled as a wild feed")
	_check(player.feeding.crouch_amount() > 0.9, "you bend right down over it (crouch %.1f)" % player.feeding.crouch_amount())
	await _wait(2.3)
	Input.action_release(&"feed")
	_check(await _wait_memory(3.0), "the first drink holds a memory: %s" % main.memory_view.title_text())
	_check(main.memory_view.title_text() == "Under the Boards" and main.memory_view._reward.text.contains("Instinct") and main.memory_view._meta.text.contains("Wild blood."), "a creature's-eye memory, with the reward spelled out: %s" % main.memory_view._reward.text.replace("\n", " | "))
	var gained := player.blood.value - b0
	_check(gained > 22.0 and gained < 30.0, "it restores blood (+%.0f): real, but less than a person" % gained)
	_check(player.surge.active and player.surge.surge_name == "Instinct" and absf(player.surge.power - 0.7) < 0.01, "and leaves a lighter rush: %s x%.1f for %.0f s" % [player.surge.surge_name, player.surge.power, player.surge.seconds_left])
	_check(Haptics.pulse_count > pulses, "your hands feel it")
	await _dismiss_memory()
	await _wait(3.0)
	_check(fox.is_away() and not fox.visible and not fox._sense.is_senseable(), "the fox slinks away and is gone from the night (hidden, and Sense no longer finds it)")
	_check(HumanNpc.tasted.get(&"fox", {}).has(&"calm") and not _fox(1).has_unheard_memory(), "its memory is remembered: the other fox holds nothing new")

	# The second drink is a meal, not a memory.
	_place(Vector3(20.4, 0, 8.0), 180.0)
	await _wait(0.5)
	var second := _fox(1)
	_check(not second.is_away(), "the other fox is still about - jumpy after what it just saw (%s)" % Animal.Mode.keys()[second.mode])
	second.global_position = Vector3(20.4, 0, 9.8)
	second._set_mode(Animal.Mode.SLEEPING)
	await _wait(0.5)
	b0 = player.blood.value
	Input.action_press(&"feed")
	await _wait(3.6)
	Input.action_release(&"feed")
	await _wait(1.2)
	_check(not main.memory_view.is_open() and player.state.mode == PlayerState.Mode.NORMAL and not get_tree().paused, "the second fox is a meal: no frozen world, control straight back")
	_check(player.blood.value > b0 + 20.0 and String(second.get_feed_result().get("memory", "x")) == "", "...it still fills you (+%.0f)" % (player.blood.value - b0))
	_check(main.hud._surge_label.text.begins_with("Instinct") and main.hud._surge_detail.text.to_lower().contains("faster"), "the HUD names the rush and says what it does: '%s' / '%s'" % [main.hud._surge_label.text, main.hud._surge_detail.text])

	# They come back: after a night's sleep.
	get_tree().call_group(&"animals", &"new_day")
	await _wait(0.3)
	_check(_fox(0).visible and not _fox(0).is_away() and _fox(0).blood_left == 1.0 and _fox(0).can_be_fed(), "after you sleep the fox is back at its den, whole again")

	# People who SEE it still care, but only close by.
	await _fox_scene(13.0, Vector3(19.0, 0, 7.3), 180.0)
	var elise := world.elise
	elise.global_position = Vector3(19.0, 0, 3.8)
	elise.rotation.y = PI    # facing +Z, toward the den
	elise._home_yaw = elise.rotation.y
	await _wait(0.3)
	Input.action_press(&"feed")
	await _wait(1.4)
	_check(elise.mode == HumanNpc.Mode.FLEEING, "someone a few metres away who sees you drink from a fox still runs (%s)" % HumanNpc.Mode.keys()[elise.mode])
	await _wait(2.6)
	Input.action_release(&"feed")
	await _wait_memory(2.0)
	await _dismiss_memory()
	await _fox_scene(13.0, Vector3(19.0, 0, 7.3), 180.0)
	elise = world.elise
	elise.global_position = Vector3(19.0, 0, -4.5)     # ~14 m north of the feed, in the open, facing it
	elise.rotation.y = PI
	elise._home_yaw = elise.rotation.y
	await _wait(0.3)
	Input.action_press(&"feed")
	await _wait(1.4)
	_check(elise.mode == HumanNpc.Mode.CALM, "...but from across the grounds nobody minds (%s): foxes are the safe meal" % HumanNpc.Mode.keys()[elise.mode])
	await _wait(2.6)
	Input.action_release(&"feed")
	await _wait_memory(2.0)
	await _dismiss_memory()
	_reset_world()


# ------------------------------------------------------------------ people have things to tell you

func _talk_to(npc: HumanNpc) -> void:
	await _tap(&"interact")
	await _wait(0.4)


func _stand_by(npc: HumanNpc, from_west := true) -> void:
	var p := npc.global_position + Vector3(-1.5 if from_west else 1.5, 0, 0)
	_place(p, -90.0 if from_west else 90.0)
	await _wait(0.5)


func _test_npc_tidings() -> void:
	print("[POLISH] --- PEOPLE: a conversation tells you something ---")
	_reset_world()
	HumanNpc.reset_tasted()
	for n in world.npcs.values():
		n.known = false     # (earlier sections fed on people, which makes them known)
	main.tod.set_hour(13.0)
	player.form.set_form_immediate(&"human")
	var tomas := world.tomas
	var hud: Hud = main.hud
	_check(tomas.profile.tidings.size() >= 3 and world.elise.profile.tidings.size() >= 3 and world.corvin.profile.tidings.size() >= 3, "everyone has things to tell (%d / %d / %d)" % [tomas.profile.tidings.size(), world.elise.profile.tidings.size(), world.corvin.profile.tidings.size()])
	var every_learned := true
	for p in [tomas.profile, world.elise.profile, world.corvin.profile]:
		for t in p.tidings:
			every_learned = every_learned and t.text.length() > 40 and t.learned != "" and t.id != &""
	_check(every_learned, "each is something said aloud, with a plain takeaway")

	await _stand_by(tomas)
	_check(_prompt() == "Talk to the stranger (something to tell)", "before you speak, you can tell they have news: '%s'" % _prompt())
	_check(world.corvin.get_sense_data(5.0)["title"] == "A stranger", "(Corvin is still a stranger to Sense)")
	await _talk_to(tomas)
	_check(tomas.speech_label.visible and tomas.speech_label.text.contains("Foxes"), "first they tell you about the foxes: '%s'" % tomas.speech_label.text.left(60))
	_check(hud._toast_label.text.begins_with("Learned: Foxes den under the ruined wall"), "...and the HUD spells out what you learned: '%s'" % hud._toast_label.text)
	_check(HumanNpc.heard.get(&"tomas", {}).has(&"foxes") and tomas.tidings_told() == 1, "it is remembered as told")
	await _wait(6.5)
	await _talk_to(tomas)
	_check(tomas.speech_label.text.contains("Corvin Hale") and tomas.speech_label.text.contains("hut"), "once they know you they tell you about the night watchman: '%s'" % tomas.speech_label.text.left(70))
	_check(world.corvin.known and world.corvin.get_sense_data(5.0)["title"] == "Corvin Hale", "...and Vampiric Sense now calls him by name instead of 'a stranger'")
	_check(hud._toast_label.text.contains("sleeps in the hut by the gate"), "the takeaway is a schedule you can use: '%s'" % hud._toast_label.text)
	_check(not world.elise.known, "(Elise is still a stranger)")

	await _wait(6.5)
	await _talk_to(tomas)
	_check(world.elise.known and tomas.speech_label.text.contains("Elise"), "next, who the seamstress is")
	_check(tomas.mode == HumanNpc.Mode.FOLLOWING, "trust still works as before: a third talk and he walks with you")
	await _wait(6.5)
	await _talk_to(tomas)
	_check(tomas.mode == HumanNpc.Mode.CALM and not hud._toast_label.text.contains("names"), "...talking to him then sends him back to work")
	await _wait(6.5)
	await _talk_to(tomas)
	_check(tomas.speech_label.text.contains("names") and hud._toast_label.text.contains("a dream waits"), "later still, a clue about his blood: '%s'" % hud._toast_label.text)
	_check(tomas.tidings_told() == 4 and not tomas.has_news(), "that is all four; he has nothing further to tell")
	await _wait(6.5)
	await _talk_to(tomas)      # (he was walking with you again: this sends him back to work)
	_check(tomas.mode == HumanNpc.Mode.CALM and not tomas.has_news() and _prompt() == "Talk to Tomas Reeve", "after that it is ordinary talk again: '%s'" % _prompt())

	# Talking changed nothing about blood: the memories are all still there for the Vampire.
	player.form.set_form_immediate(&"vampire")
	await _wait(0.5)
	var data := tomas.get_sense_data(4.0)
	_check(data["title"] == "Tomas Reeve" and String(data["hint"]) != "" and tomas.profile.memories.size() == 5, "as a vampire Sense still promises his memories (hint '%s', %d memories)" % [data["hint"], tomas.profile.memories.size()])

	# Time of day matters to what is said.
	_reset_world()
	HumanNpc.reset_tasted()
	main.tod.set_hour(13.0)
	player.form.set_form_immediate(&"human")
	var elise := world.elise
	await _stand_by(elise, false)
	await _talk_to(elise)
	await _wait(6.5)
	await _talk_to(elise)
	_check(not HumanNpc.heard.get(&"elise", {}).has(&"lantern"), "by day Elise does not mention the light in the manor")
	_reset_world()
	HumanNpc.reset_tasted()
	main.tod.set_hour(21.0)
	get_tree().call_group(&"npcs", &"new_day")
	player.form.set_form_immediate(&"human")
	await _stand_by(elise, false)
	await _talk_to(elise)
	await _wait(6.5)
	await _talk_to(elise)
	_check(HumanNpc.heard.get(&"elise", {}).has(&"lantern"), "after dark she tells you about the lantern that moves in the manor: '%s'" % elise.speech_label.text.left(50))

	# What they say can point at hidden things (data, so mods can too).
	_reset_world()
	HumanNpc.reset_tasted()
	main.tod.set_hour(13.0)
	player.form.set_form_immediate(&"human")
	var t := Tiding.new()
	t.id = &"test_secret"
	t.text = "Dig by the well, you'll find something that is not mine to keep. The key, I mean. Please do not tell the Lord."
	t.learned = "A key is buried under the well."
	t.reveals_secret = &"well_key"
	var original := tomas.profile.tidings.duplicate()
	tomas.profile.tidings.insert(0, t)
	await _stand_by(tomas)
	_check(not world.secrets[&"well_key"].discovered, "(the buried key is not known yet)")
	await _talk_to(tomas)
	_check(world.secrets[&"well_key"].discovered, "a tiding can reveal a hidden thing, as a memory does")
	tomas.profile.tidings.clear()
	tomas.profile.tidings.append_array(original)

	# Three new trusting memories exist and are heard through trust, not by accident.
	for p in [tomas.profile, world.elise.profile, world.corvin.profile]:
		_check(p.has_memory(&"trusting") and p.memories.size() == 5, "%s now has a memory only trust opens (%s)" % [p.display_name, p.memory_for(&"trusting").title])
	_reset_world()
	HumanNpc.reset_tasted()
	main.tod.set_hour(13.0)
	player.form.set_form_immediate(&"human")
	await _stand_by(tomas)
	for i in 3:
		await _talk_to(tomas)
		await _wait(6.5)
	tomas.trust = 1.0
	tomas._set_mode(HumanNpc.Mode.CALM)
	tomas.awareness = 0.0
	player.form.set_form_immediate(&"vampire")
	player.feeding.start(tomas)    # straight away: a trusting person has not yet had time to be afraid
	_check(tomas.feed_condition() == &"trusting" and player.feeding.style.id == &"trusting", "feeding someone who trusts you plays as a trusting feed")
	Input.action_press(&"feed")
	await _wait(4.4)
	Input.action_release(&"feed")
	_check(await _wait_memory(3.0) and main.memory_view.title_text() == "Flour on Her Hands", "...and opens the memory only trust unlocks: %s" % main.memory_view.title_text())
	await _dismiss_memory()
	_reset_world()


# ------------------------------------------------------------------ the coffin: when will you wake?

func _key(code: Key, pressed: bool) -> void:
	var ev := InputEventKey.new()
	ev.physical_keycode = code
	ev.keycode = code
	ev.pressed = pressed
	Input.parse_input_event(ev)


## Press and release a key the way a finger does, one frame boundary at a time.
func _press_key(code: Key) -> void:
	await get_tree().process_frame
	_key(code, true)
	await get_tree().process_frame
	await get_tree().process_frame
	_key(code, false)
	await get_tree().process_frame


func _at_coffin() -> void:
	_place(Vector3(-4.0, 0, -11.0), -60.0)
	_face(world.coffin.global_position)
	await _wait(0.5)


func _test_coffin_choices() -> void:
	print("[POLISH] --- COFFIN: when will you wake? ---")
	_reset_world()
	var menu: RestMenu = world.coffin._menu
	var tod := main.tod
	tod.set_hour(14.0)
	var day0 := tod.day_count
	await _at_coffin()
	_check(_prompt().begins_with("Sleep in your coffin"), "at the coffin: '%s'" % _prompt())
	await _tap(&"interact")
	await _wait(0.4)
	_check(menu.is_open() and get_tree().paused and PauseControl.has_reason(&"rest"), "pressing interact asks when you will wake, and holds the world still")
	var labels := []
	for o in menu.options():
		labels.append(o.label)
	_check(labels == ["Until dusk", "Until midnight", "Until dawn", "Until daylight"], "the choices (from data): %s" % str(labels))
	var focused := get_viewport().gui_get_focus_owner() as Button
	_check(focused != null and focused.text.begins_with("Until dusk"), "'until dusk' - the old behaviour - is first and already selected: '%s'" % (focused.text if focused else "none"))
	_check(main.pause_menu._can_open() == false, "the pause menu does not open on top of it")
	# Staying awake changes nothing.
	await _press_key(KEY_ESCAPE)
	await _wait(0.4)
	_check(not menu.is_open() and not get_tree().paused and absf(tod.hour - 14.0) < 0.05 and player.state.mode == PlayerState.Mode.NORMAL, "Esc: you stay awake, the clock has not moved (%.2f)" % tod.hour)
	_check(player.visual.visible and player.global_position.distance_to(Vector3(-4.0, 0, -11.0)) < 1.0, "...and you are exactly where you were")

	# Until daylight: wake as a human into the day.
	await _tap(&"interact")
	await _wait(0.4)
	for i in 3:
		await _press_key(KEY_DOWN)
	_check((get_viewport().gui_get_focus_owner() as Button).text.begins_with("Until daylight"), "three presses down: '%s'" % (get_viewport().gui_get_focus_owner() as Button).text)
	await _press_key(KEY_ENTER)
	await _wait(7.2)
	_check(absf(tod.hour - 8.0) < 0.3 and tod.day_count == day0 + 1, "you sleep until 8 AM the next day (clock %s, day %d -> %d)" % [tod.clock_text_12h(), day0, tod.day_count])
	_check(player.state.mode == PlayerState.Mode.NORMAL and player.form.is_form(&"human") and player.visual.visible and player.visual.lying == 0.0 and not get_tree().paused, "you wake standing, a human, in control")
	_check(player.global_position.distance_to(world.coffin.global_position) < 4.5 and player.traversal.is_clear(player.global_position) and player.is_on_floor(), "...in the crypt beside the coffin, nowhere you could be stuck")
	_check(main.hud._toast_label.text.contains("sun is up"), "the toast says so: '%s'" % main.hud._toast_label.text)
	await _wait(2.0)
	_check(player.health.value >= player.health.max_health - 0.01 and player.sunlight.stage == 0 and player.state.mode == PlayerState.Mode.NORMAL, "daylight does not hurt you: no burn, full health (stage %d)" % player.sunlight.stage)

	# From daylight, rest until midnight; the clock and the day count follow.
	await _at_coffin()
	var day1 := tod.day_count
	await _tap(&"interact")
	await _wait(0.4)
	await _press_key(KEY_DOWN)
	await _press_key(KEY_ENTER)
	await _wait(7.2)
	_check(absf(fposmod(tod.hour + 0.2, 24.0) - 0.2) < 0.5 and tod.day_count == day1 + 1, "until midnight from the morning: %s, day %d" % [tod.clock_text_12h(), tod.day_count])

	# Default: one Enter press and it is dusk, as it always was.
	tod.set_hour(14.0)
	var day2 := tod.day_count
	await _at_coffin()
	await _tap(&"interact")
	await _wait(0.4)
	await _press_key(KEY_ENTER)
	await _wait(7.2)
	_check(absf(tod.hour - 19.0) < 0.3 and tod.day_count == day2 and main.hud._toast_label.text.contains("dusk"), "choosing the first option is the old coffin: %s, same day" % tod.clock_text_12h())
	_check(world.tomas.mode == HumanNpc.Mode.CALM and world.elise.can_be_fed(), "the world was reset for the new time (people are back on their routine)")

	# Options too close to now are not offered.
	tod.set_hour(23.5)
	await _at_coffin()
	await _tap(&"interact")
	await _wait(0.4)
	labels.clear()
	for o in menu.options():
		labels.append(o.label)
	_check(not labels.has("Until midnight") and labels.has("Until dusk"), "at 11:30 PM 'until midnight' is not offered (%s)" % str(labels))
	await _press_key(KEY_ESCAPE)
	await _wait(0.4)
	# At dusk's edge the first option changes but something is always focused.
	tod.set_hour(18.4)
	await _tap(&"interact")
	await _wait(0.4)
	_check(menu.is_open() and get_viewport().gui_get_focus_owner() is Button and not menu.options().is_empty(), "at 6:24 PM it still offers somewhere to wake (%s)" % str(menu.options().map(func(o): return o.label)))
	await _press_key(KEY_ESCAPE)
	await _wait(0.4)

	# The pad does it too.
	tod.set_hour(14.0)
	await _tap(&"interact")
	await _wait(0.4)
	var pad_down := InputEventJoypadButton.new()
	pad_down.button_index = JOY_BUTTON_DPAD_DOWN
	pad_down.pressed = true
	pad_down.device = 0
	Input.parse_input_event(pad_down)
	await get_tree().process_frame
	await get_tree().process_frame
	pad_down = InputEventJoypadButton.new()
	pad_down.button_index = JOY_BUTTON_DPAD_DOWN
	pad_down.pressed = false
	pad_down.device = 0
	Input.parse_input_event(pad_down)
	await _wait(0.2)
	_check((get_viewport().gui_get_focus_owner() as Button).text.begins_with("Until midnight"), "the D-pad moves between choices")
	var pad_b := InputEventJoypadButton.new()
	pad_b.button_index = JOY_BUTTON_B
	pad_b.pressed = true
	pad_b.device = 0
	Input.parse_input_event(pad_b)
	await get_tree().process_frame
	await get_tree().process_frame
	pad_b = InputEventJoypadButton.new()
	pad_b.button_index = JOY_BUTTON_B
	pad_b.pressed = false
	pad_b.device = 0
	Input.parse_input_event(pad_b)
	await _wait(0.4)
	_check(not menu.is_open() and not get_tree().paused, "...and B stays awake")

	# Dying in the sun still brings you home, unaffected by any of this.
	player.form.set_form_immediate(&"vampire")
	player.health.damage(10000.0, &"sunlight")
	await _wait(8.0)
	_check(player.state.mode == PlayerState.Mode.NORMAL and player.health.value > 0.0 and player.form.is_form(&"human"), "death in the sun still returns you to the coffin as before")
	_reset_world()


# ------------------------------------------------------------------ more memories, and clues in the world

func _test_memories_and_clues() -> void:
	print("[POLISH] --- MEMORIES AND CLUES: more to find ---")
	_reset_world()
	HumanNpc.reset_tasted()
	main.tod.set_hour(23.0)
	# Count and variety: how many a person can give, and from where.
	var titles := {}
	var total := 0
	for p in [ContentRegistry.npc(&"tomas"), ContentRegistry.npc(&"elise"), ContentRegistry.npc(&"corvin")]:
		for m in p.memories:
			titles[m.title] = true
			total += 1
	titles["Under the Boards"] = true
	_check(total == 15 and titles.size() == 16, "fifteen memories among three people (was nine), plus the fox's: %d distinct titles" % titles.size())
	var every_deep := true
	for p in [ContentRegistry.npc(&"tomas"), ContentRegistry.npc(&"elise"), ContentRegistry.npc(&"corvin")]:
		every_deep = every_deep and p.has_memory(&"deep") and p.memory_for(&"deep").facts.size() >= 2 and p.memory_for(&"deep").text.length() > 200
	_check(every_deep, "each person has a deepest memory, with facts to carry away")

	# The deepest memory opens only when the rest have been heard.
	var tomas := world.tomas
	HumanNpc.tasted[&"tomas"] = {&"calm": true, &"asleep": true, &"afraid": true}
	_check(not tomas._deep_ready() and tomas.feed_condition() != &"deep", "with three of four heard, the deepest stays shut")
	HumanNpc.tasted[&"tomas"][&"trusting"] = true
	_check(tomas._deep_ready() and tomas.feed_condition() == &"deep", "...once all four are heard, it opens, whatever state they are in")
	player.form.set_form_immediate(&"vampire")
	await _wait(0.4)
	_place(tomas.global_position + Vector3(-1.5, 0, 0), -90.0)
	await _wait(0.6)
	var hint := String(tomas.get_sense_data(4.0)["hint"])
	_check(hint == "the deepest memory waits", "Sense says so: '%s'" % hint)
	Input.action_press(&"feed")
	await _wait(5.0)
	Input.action_release(&"feed")
	_check(await _wait_memory(3.0) and main.memory_view.title_text() == "A Hand That Was Not His", "the next feed opens it: %s" % main.memory_view.title_text())
	_check(main.memory_view._facts.get_child_count() == 2 and tomas.tasted_count() == 5 and not tomas._deep_ready(), "it is remembered, and tells its facts (%d heard)" % tomas.tasted_count())
	await _dismiss_memory()
	_check(String(tomas.get_sense_data(4.0)["hint"]) == "", "afterwards there is nothing left to hint at")

	# Clues in the world: small, readable by anyone, backing up what people say.
	_reset_world()
	player.form.set_form_immediate(&"human")
	main.tod.set_hour(13.0)
	_check(world.inspectables.size() == 3, "three small things are worth a look")
	_place(Vector3(10.6, 0, 25.0), 42.0)        # inside the watch hut, facing the table
	await _wait(0.6)
	_check(_prompt() == "Read the watch log", "in the hut: '%s'" % _prompt())
	await _tap(&"interact")
	await _wait(0.3)
	_check(main.hud._toast_label.text.contains("All quiet") and main.hud._toast_label.text.contains("torn"), "it says what Corvin's blood remembers: '%s'" % main.hud._toast_label.text.left(60))
	await _wait(0.4)
	_check(_prompt() == "Read the watch log  (read)" and Inspectable.read_ids.has(&"watch_log"), "and the prompt remembers you read it")
	_place(Vector3(1.0, 0, -17.8), 180.0)       # behind the manor, facing the north wall
	await _wait(0.6)
	_check(_prompt() == "Examine the ground under the north window", "behind the manor: '%s'" % _prompt())
	await _tap(&"interact")
	await _wait(0.3)
	_check(main.hud._toast_label.text.contains("Candle wax") and main.hud._toast_label.text.contains("lavender"), "wax and lavender oil, as Elise's and Corvin's blood remember it")
	player.form.set_form_immediate(&"vampire")
	_place(Vector3(3.0, 0, 28.6), 0.0)          # at the gate, facing it? (+Z is south: the gate)
	player.camera_rig.yaw = PI
	await _wait(0.6)
	_check(_prompt() == "Examine the gate lock", "a vampire may read them too: '%s'" % _prompt())
	await _tap(&"interact")
	await _wait(0.3)
	_check(main.hud._toast_label.text.contains("IN, not out"), "the gate lock agrees with Corvin: '%s'" % main.hud._toast_label.text.left(50))
	_reset_world()
