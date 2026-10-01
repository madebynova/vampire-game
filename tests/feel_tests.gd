extends "res://tests/test_base.gd"
## Task 1.75 - vampire feel & immersion. Drives the real game through real input (key events, pad
## events, held buttons) and checks: transformation presentation, blood and Bloodrush, feeding per
## victim state, the Blood Memory view and its input rules, Sense refinement, traversal, pause,
## HUD and controls screen, controller-only play, settings, the coffin, and the cleaned-up world.
##   godot --path . res://tests/feel_tests.tscn -- <screenshot_dir>      (windowed: screenshots)
##   godot --headless --path . res://tests/feel_tests.tscn

var _mem_defaults := {}
var _stand_shots := 0


func _ready() -> void:
	GameSettings.persist = false
	var args := OS.get_cmdline_user_args()
	out_dir = args[0] if args.size() > 0 else ""
	HumanNpc.schedules_enabled = false
	main = load("res://scenes/main.tscn").instantiate()
	main.capture_mouse = false
	add_child(main)
	player = main.player
	world = main.world
	var mv: MemoryView = main.memory_view
	_mem_defaults = {"intro": mv.intro_time, "arm": mv.arm_time, "cps": mv.chars_per_second, "hold": mv.hold_after_text, "fin": mv.fade_in, "fout": mv.fade_out}
	main.tod.paused = true
	_night()
	await _wait(2.8)
	await _run()
	print("[FEEL] ===== %d checks, %d failures =====" % [checks, failures])
	get_tree().quit(1 if failures > 0 else 0)


func _check(cond: bool, msg: String) -> void:
	checks += 1
	if cond:
		print("[FEEL] PASS  ", msg)
	else:
		failures += 1
		print("[FEEL] FAIL  ", msg)


# ------------------------------------------------------------------ helpers

## The suite's resting state: midnight-ish, no pinned sun, clock stopped.
func _night() -> void:
	main.tod.paused = true
	main.tod.sun_override = Vector3.ZERO
	main.tod.set_hour(23.0)


func _slow_memory() -> void:
	var mv: MemoryView = main.memory_view
	mv.intro_time = _mem_defaults["intro"]
	mv.arm_time = _mem_defaults["arm"]
	mv.chars_per_second = _mem_defaults["cps"]
	mv.hold_after_text = _mem_defaults["hold"]
	mv.fade_in = _mem_defaults["fin"]
	mv.fade_out = _mem_defaults["fout"]


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
	ev.device = 0
	Input.parse_input_event(ev)


func _pad_axis(axis: JoyAxis, value: float) -> void:
	var ev := InputEventJoypadMotion.new()
	ev.axis = axis
	ev.axis_value = value
	ev.device = 0
	Input.parse_input_event(ev)


func _click() -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	Input.parse_input_event(ev)
	await get_tree().process_frame
	await get_tree().process_frame
	ev = InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = false
	Input.parse_input_event(ev)
	await get_tree().process_frame


## Press and release a key the way a finger does, one frame boundary at a time.
func _press_key(code: Key) -> void:
	await get_tree().process_frame
	_key(code, true)
	await get_tree().process_frame
	await get_tree().process_frame
	_key(code, false)
	await get_tree().process_frame


func _press_pad(button: JoyButton) -> void:
	await get_tree().process_frame
	_pad(button, true)
	await get_tree().process_frame
	await get_tree().process_frame
	_pad(button, false)
	await get_tree().process_frame


func _set_blood(v: float) -> void:
	player.blood._set_value(v)


func _release_all() -> void:
	for a in [&"feed", &"interact", &"sprint", &"move_forward", &"memory_dismiss", &"jump"]:
		Input.action_release(a)
	_key(KEY_E, false)


## Everyone back at their post (routines frozen), the watchman out of the way, the player fit and in control.
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
	_set_blood(60.0)
	InputSetup.set_device_kind(InputSetup.KEYBOARD)


func _approach_elise() -> void:
	_place(Vector3(-20.4, 0, 5.5), 90.0)
	await _run_until_focus(world.elise.global_position, 3.0)


func _link(id: StringName) -> TraversalLink:
	for l in world.traversal_links:
		if l.placement.id == id:
			return l
	return null


func _rect_distance(r: Rect2, p: Vector2) -> float:
	var dx := maxf(maxf(r.position.x - p.x, 0.0), p.x - r.end.x)
	var dy := maxf(maxf(r.position.y - p.y, 0.0), p.y - r.end.y)
	return sqrt(dx * dx + dy * dy)


func _min_distance(rects: Array, p: Vector2) -> float:
	var best := INF
	for r in rects:
		best = minf(best, _rect_distance(r, p))
	return best


func _all_labels(node: Node, out: Array) -> void:
	if node is Label:
		out.append(node)
	for c in node.get_children():
		_all_labels(c, out)


func _count_type(node: Node, type_name: String) -> int:
	var n := 1 if node.get_class() == type_name or (node.get_script() != null and node.get_script().get_global_name() == type_name) else 0
	for c in node.get_children():
		n += _count_type(c, type_name)
	return n


func _run() -> void:
	await _test_clock()
	await _test_transformation()
	await _test_blood()
	await _test_feeding_calm_and_surge()
	await _test_feeding_afraid_and_witnesses()
	await _test_feeding_asleep_and_trusting()
	await _test_memory_input()
	await _test_memory_controller()
	await _test_sense()
	await _test_traversal()
	await _test_pause_and_menus()
	await _test_controller_only()
	await _test_hud()
	await _test_coffin()
	await _test_world()


# ------------------------------------------------------------------ 12-hour clock

func _test_clock() -> void:
	print("[FEEL] --- 12-HOUR CLOCK ON THE HUD ---")
	var cases := {17.72: "5:43 PM", 0.0: "12:00 AM", 12.0: "12:00 PM", 6.5: "6:30 AM", 23.99: "11:59 PM", 13.0: "1:00 PM"}
	for h in cases:
		main.tod.set_hour(h)
		main.hud._update_clock()
		_check(main.hud._clock.text == cases[h], "the HUD shows %.2f as %s (got %s)" % [h, cases[h], main.hud._clock.text])
	main.tod.set_hour(17.72)
	main.hud._update_clock()
	_check(not main.hud._clock.text.contains("17") and not main.hud._clock.text.contains("18"), "no 24-hour numbers reach the player")
	_check(absf(main.tod.hour - 17.72) < 0.01 and main.tod.clock_text() == "17:43", "the simulation itself still runs on 24-hour time")
	_night()


# ------------------------------------------------------------------ transformation

func _test_transformation() -> void:
	print("[FEEL] --- TRANSFORMATION: Human -> Vampire, then back ---")
	_reset_world()
	player.form.set_form_immediate(&"human")
	_place(Vector3(3.0, 0, -3.0), 0.0)
	await _wait(0.6)
	var fx: ScreenFX = main.screen_fx
	var cam := player.camera_rig
	var pulses0 := Haptics.pulse_count
	var min_fov := 0.0
	var max_morph := 0.0
	var max_pose := 0.0
	var max_muffle := 0.0
	var peak_color := Color.BLACK
	var swapped_at := -1.0
	var min_time_scale := 1.0
	var t := 0.0
	var clock := Time.get_ticks_msec()
	player.form.request_form(&"vampire")
	while t < 1.4:
		await get_tree().process_frame
		t = (Time.get_ticks_msec() - clock) / 1000.0
		min_fov = minf(min_fov, cam.fov_offset)
		if fx.morph > max_morph:
			max_morph = fx.morph
			peak_color = fx.morph_color
		max_pose = maxf(max_pose, player.visual.pose_amount)
		max_muffle = maxf(max_muffle, AudioBuses.muffle_of(AudioBuses.AMBIENCE))
		min_time_scale = minf(min_time_scale, Engine.time_scale)
		if swapped_at < 0.0 and player.form.is_form(&"vampire"):
			swapped_at = t
	_check(player.transform_fx.last_direction == &"to_vampire", "the presentation knows this is the Human -> Vampire change")
	_check(min_fov < -8.0, "the wind-up tightens the camera (FOV offset %.1f)" % min_fov)
	_check(max_morph > 0.5, "the world narrows to a red-black tunnel (strength %.2f)" % max_morph)
	_check(peak_color.r < 0.35 and peak_color.g < 0.1, "...a dark blood colour (%s)" % str(peak_color))
	_check(max_pose > 0.5, "the body rises and arches into the change (pose %.2f)" % max_pose)
	_check(max_muffle > 0.5, "the sound of the world is pushed away (muffle %.2f)" % max_muffle)
	_check(min_time_scale < 0.6, "a hit-stop stutters time at the swap (min time scale %.2f)" % min_time_scale)
	_check(swapped_at > 0.35 and swapped_at < 0.9, "the form swaps about half way through, %.2f s in" % swapped_at)
	_check(Haptics.pulse_count - pulses0 >= 2, "the pad is told (%d vibration pulses)" % (Haptics.pulse_count - pulses0))
	_check(player.form.transform_time <= 1.5, "it stays quick: %.2f s" % player.form.transform_time)
	await _wait(1.6)
	_check(player.form.is_form(&"vampire") and player.state.mode == PlayerState.Mode.NORMAL, "control returns when it ends")
	_check(cam.fov_offset == 0.0 and cam.distance_offset == 0.0 and fx.morph == 0.0 and fx.chroma == 0.0, "every presentation offset is cleaned up")
	_check(Engine.time_scale == 1.0 and AudioBuses.muffle_of(AudioBuses.AMBIENCE) < 0.05, "time and sound are back to normal")
	_check(player.visual.pose_amount == 0.0 and player.visual.position.y == 0.0, "the body is back on the ground")
	_check(AudioServer.is_bus_effect_enabled(AudioServer.get_bus_index(AudioBuses.AMBIENCE), 1), "a vampire hears the night with more depth (ambience reverb on)")
	_check(fx.level(&"vamp") > 0.6, "the world keeps a cold vampire rim (%.2f)" % fx.level(&"vamp"))
	await _shot("f01_vampire_after")

	var max_morph_h := 0.0
	var max_fov_h := 0.0
	var peak_h := Color.BLACK
	clock = Time.get_ticks_msec()
	t = 0.0
	player.form.request_form(&"human")
	while t < 1.4:
		await get_tree().process_frame
		t = (Time.get_ticks_msec() - clock) / 1000.0
		if fx.morph > max_morph_h:
			max_morph_h = fx.morph
			peak_h = fx.morph_color
		max_fov_h = maxf(max_fov_h, cam.fov_offset)
	_check(player.transform_fx.last_direction == &"to_human", "going back is its own presentation")
	_check(max_morph_h > 0.1 and max_morph_h < max_morph, "...quieter than becoming a vampire (%.2f vs %.2f)" % [max_morph_h, max_morph])
	_check(peak_h.r > 0.6, "...pale and warm instead of blood-dark (%s)" % str(peak_h))
	_check(max_fov_h > 2.0, "...the view opens instead of tightening (FOV offset +%.1f)" % max_fov_h)
	await _wait(1.2)
	_check(player.form.is_form(&"human") and not AudioServer.is_bus_effect_enabled(AudioServer.get_bus_index(AudioBuses.AMBIENCE), 1), "as a Human the extra depth in the night is gone")
	await _wait(2.0)
	_check(fx.level(&"vamp") < 0.1, "...and so is the vampire rim")

	# People nearby who did not see it still feel something change.
	_reset_world()
	_place(Vector3(-24.0, 0, 12.0), 0.0)
	world.elise.awareness = 0.0
	await _wait(0.3)
	player.form.request_form(&"vampire")
	await _wait(0.4)
	_check(world.elise.mode == HumanNpc.Mode.CALM and world.elise.awareness <= 0.4 and world.elise._chill_timer > 0.5 and world.elise.alert_label.text == "?", "someone behind a wall stops, glances over and wonders - but does not run (awareness %.2f)" % world.elise.awareness)
	await _wait(1.2)


# ------------------------------------------------------------------ blood and Bloodrush

func _test_blood() -> void:
	print("[FEEL] --- BLOOD: slow as a Human, faster as a Vampire, Sense costs something ---")
	_reset_world()
	player.form.set_form_immediate(&"human")
	_set_blood(50.0)
	player.blood._process(100.0)
	var lost_h := 50.0 - player.blood.value
	_check(lost_h > 1.5 and lost_h < 2.6, "a Human loses about %.1f blood in 100 s: barely noticeable" % lost_h)
	player.form.set_form_immediate(&"vampire")
	_set_blood(50.0)
	player.blood._process(100.0)
	var lost_v := 50.0 - player.blood.value
	_check(lost_v > 14.0 and lost_v < 18.0 and lost_v > lost_h * 5.0, "a Vampire loses %.1f in 100 s: a steady, patient pressure" % lost_v)
	_set_blood(10.0)
	player.blood._process(0.1)
	_check(player.speed_modifiers.has(&"hunger") and absf(player.speed_modifiers[&"hunger"] - 0.85) < 0.01, "a hungry Vampire slows a little (x%.2f)" % player.speed_modifiers.get(&"hunger", 1.0))
	player.form.set_form_immediate(&"human")
	_set_blood(10.0)
	player.blood._process(0.1)
	_check(not player.speed_modifiers.has(&"hunger"), "a hungry Human is not slowed")
	player.form.set_form_immediate(&"vampire")
	_reset_world()
	var sense: VampiricSense = player.abilities.get_ability(&"vampiric_sense")
	player.form.set_form_immediate(&"vampire")
	_set_blood(80.0)
	sense.activate()
	var after_on := player.blood.value
	_check(absf((80.0 - after_on) - sense.activation_cost) < 0.05, "switching Sense on costs %.1f up front" % (80.0 - after_on))
	sense._process(10.0)
	var spent := after_on - player.blood.value
	_check(spent > 5.0 and spent < 6.0, "ten seconds of Sense cost %.1f blood (%.2f/s): it is spent, not crippling" % [spent, spent / 10.0])
	main.hud._update_side(0.1)
	_check(main.hud._sense_label.text.begins_with("SENSE") and main.hud._sense_label.text.contains("blood/s"), "the HUD tells you what it costs: %s" % main.hud._sense_label.text)
	sense.deactivate()
	_set_blood(3.0)
	_check(sense.why_not() == "" or sense.why_not().contains("hungry"), "Sense refuses politely when nearly empty: '%s'" % sense.why_not())
	_set_blood(0.0)
	_check(sense.why_not().contains("hungry") or sense.why_not().contains("nothing left"), "...and explains why: '%s'" % sense.why_not())

	# The Bloodrush: what a good feed leaves behind.
	_reset_world()
	player.form.set_form_immediate(&"vampire")
	_set_blood(60.0)
	var heat_base := player.sunlight.heat_multiplier()
	player.surge.start(1.0, 30.0, "Test Rush")
	player.surge._process(1.0)
	_check(player.surge.active and player.surge.intensity() > 0.9, "a Bloodrush ramps in (%.2f)" % player.surge.intensity())
	_check(player.speed_modifiers.get(&"surge", 1.0) > 1.12, "you are quicker (x%.2f)" % player.speed_modifiers.get(&"surge", 1.0))
	_check(player.jump_multiplier > 1.05, "...and jump higher (x%.2f)" % player.jump_multiplier)
	_check(player.sunlight.heat_multiplier() < heat_base, "...and the sun is a little easier to bear (heat x%.2f)" % player.sunlight.heat_multiplier())
	sense.activate()
	var before := player.blood.value
	sense._process(10.0)
	_check(is_equal_approx(before, player.blood.value) and sense.current_cost_per_sec() == 0.0, "Sense is free while the blood is in you")
	main.hud._update_side(0.1)
	_check(main.hud._sense_label.text.contains("free"), "...and the HUD says so: %s" % main.hud._sense_label.text)
	_check(main.hud._surge_label.text.begins_with("Test Rush"), "the surge is named and timed: %s" % main.hud._surge_label.text)
	sense.deactivate()
	player.health.value = 50.0
	var hp0 := player.health.value
	var blood_pre_heal := player.blood.value
	player.health._process(2.0)
	var healed_rush := player.health.value - hp0
	var blood_free := is_equal_approx(player.blood.value, blood_pre_heal)
	player.surge.stop(false)
	player.health.value = 50.0
	player.health._process(2.0)
	var healed_plain := player.health.value - 50.0
	_check(healed_rush > healed_plain * 1.5 and blood_free and player.blood.value < blood_pre_heal, "wounds close faster during a Bloodrush (%.0f vs %.0f hp) and for free" % [healed_rush, healed_plain])
	_check(not player.speed_modifiers.has(&"surge") and player.jump_multiplier == 1.0 and is_equal_approx(player.sunlight.heat_multiplier(), heat_base), "when it ends everything it touched is restored")
	player.surge.start(1.0, 10.0, "Test")
	player.form.set_form_immediate(&"human")
	_check(not player.surge.active, "becoming human ends it")
	player.form.set_form_immediate(&"vampire")


# ------------------------------------------------------------------ feeding: calm + surge + memory tasted

func _test_feeding_calm_and_surge() -> void:
	print("[FEEL] --- FEEDING: an unaware victim ---")
	_reset_world()
	HumanNpc.reset_tasted()
	player.form.set_form_immediate(&"vampire")
	_set_blood(40.0)
	await _approach_elise()
	_check(_prompt().begins_with("Feed"), "the prompt offers to feed: %s" % _prompt())
	await _wait(0.2)
	_check(main.hud._prompt_glyph.action == &"feed", "...with the feed button shown (action %s)" % main.hud._prompt_glyph.action)
	var hint := String(world.elise.get_sense_data(4.0)["hint"])
	_check(hint == "a memory waits", "close up, Sense tells you there is a memory you have not heard: '%s'" % hint)
	var b0 := player.blood.value
	var pulses0 := Haptics.pulse_count
	Input.action_press(&"feed")
	await _wait(1.6)   # (the prompt is held for 0.45 s before the feed begins)
	_check(player.state.mode == PlayerState.Mode.FEEDING and player.feeding.style.id == &"calm", "feeding starts, styled as a calm one")
	_check(player.blood.value > b0 + 5.0, "blood rises while you drink (%.0f -> %.0f)" % [b0, player.blood.value])
	_check(Haptics.pulse_count - pulses0 >= 2, "your heartbeat reaches your hands (%d pulses)" % (Haptics.pulse_count - pulses0))
	_check(main.screen_fx.feed_target == 1.0, "the screen is a red tunnel")
	await _wait(3.4)
	Input.action_release(&"feed")
	_check(await _wait_memory(3.0), "when the feed ends the memory takes over: %s" % main.memory_view.title_text())
	_check(world.elise.mode == HumanNpc.Mode.DRAINED, "the victim is drained, alive")
	_check(player.surge.active and absf(player.surge.power - 1.0) < 0.01 and player.surge.seconds_left > 40.0, "a Bloodrush has begun (%s, %.0f s)" % [player.surge.surge_name, player.surge.seconds_left])
	_check(player.blood.value > b0 + 25.0, "the blood is restored meaningfully (%.0f -> %.0f)" % [b0, player.blood.value])
	_check(get_tree().paused and PauseControl.has_reason(&"memory"), "the world is frozen while the memory plays")
	var blood_frozen := player.blood.value
	var heat_frozen := player.sunlight.model.heat
	await _wait(1.0)
	_check(is_equal_approx(player.blood.value, blood_frozen) and is_equal_approx(player.sunlight.model.heat, heat_frozen), "blood and sunlight do not advance during a memory")
	_check(not main.hud._root.visible, "the HUD steps out of the way")
	_check(AudioBuses.muffle_of(AudioBuses.AMBIENCE) > 0.5, "the room's sound recedes (muffle %.2f)" % AudioBuses.muffle_of(AudioBuses.AMBIENCE))
	_check(main.memory_view.style.id == &"calm" and main.screen_fx.level(&"memory") > 0.3, "the memory is tinted and the world drains into it")
	await _dismiss_memory()
	_check(not get_tree().paused and player.state.mode == PlayerState.Mode.NORMAL and main.hud._root.visible, "closing it unfreezes the world and returns control")
	_check(AudioBuses.muffle_of(AudioBuses.AMBIENCE) < 0.05, "...and the sound comes back")
	await _wait(1.0)
	_check(player.speed_modifiers.get(&"surge", 1.0) > 1.1, "you come out of it quicker (x%.2f)" % player.speed_modifiers.get(&"surge", 1.0))
	await _tap(&"vampiric_sense")
	await _wait(0.3)
	var sense: VampiricSense = player.abilities.get_ability(&"vampiric_sense")
	_check(sense.active and sense.current_cost_per_sec() == 0.0, "Sense is free after a feed: a reason to want one")
	await _tap(&"vampiric_sense")
	get_tree().call_group(&"npcs", &"new_day")
	_check(String(world.elise.get_sense_data(4.0)["hint"]) == "" and HumanNpc.tasted[&"elise"].has(&"calm"), "the memory you have heard is remembered: Sense stops hinting at it")
	_check(String(world.tomas.get_sense_data(4.0)["hint"]) != "", "an untouched person still promises a memory: '%s'" % world.tomas.get_sense_data(4.0)["hint"])
	_check(world.elise.mode == HumanNpc.Mode.CALM and world.elise.can_be_fed() and world.elise.blood_left == 1.0 and world.elise.trust == 0.0, "after the night the victim is whole again: nothing is permanently broken")


# ------------------------------------------------------------------ feeding: afraid, noise, witnesses

func _test_feeding_afraid_and_witnesses() -> void:
	print("[FEEL] --- FEEDING: a terrified victim is loud, and people who see it run ---")
	_reset_world()
	HumanNpc.reset_tasted()
	player.form.set_form_immediate(&"vampire")
	var tomas := world.tomas
	var elise := world.elise
	# Noise only: Tomas is taken near the gatehouse; Elise, facing away inside, cannot see but hears.
	tomas.global_position = Vector3(-13.0, 0, 6.5)
	tomas.awareness = 0.9
	_place(Vector3(-11.6, 0, 6.5), 90.0)
	elise.awareness = 0.0
	await get_tree().physics_frame
	var calm_yield := float(tomas.get_feed_result()["yield"])
	tomas.awareness = 0.9
	Input.action_press(&"feed")
	player.feeding.start(tomas)
	await _wait(0.4)
	_check(player.state.mode == PlayerState.Mode.FEEDING and player.feeding.style.id == &"afraid", "a frightened victim is fed on as a terrified one")
	_check(elise.mode == HumanNpc.Mode.CALM and elise.awareness > 0.12, "someone who only HEARS the scream is alarmed, not running yet (awareness %.2f)" % elise.awareness)
	_check(float(tomas.get_feed_result()["yield"]) > calm_yield * 1.15, "fear pays more blood (%.0f vs %.0f)" % [float(tomas.get_feed_result()["yield"]), calm_yield])
	await _wait(3.5)
	Input.action_release(&"feed")
	_check(await _wait_memory(3.0), "the terrified memory plays")
	_check(main.screen_fx.memory_fragmentation > 0.9 and main.memory_view.style.id == &"afraid", "...fragmented and violent, unlike the calm one (%.1f)" % main.screen_fx.memory_fragmentation)
	_check(absf(player.surge.power - 1.35) < 0.01 and player.surge.seconds_left < 40.0, "...and its rush is hot and short (power %.2f, %.0f s)" % [player.surge.power, player.surge.seconds_left])
	await _dismiss_memory()

	# A witness: Elise outside, looking straight at it.
	_reset_world()
	HumanNpc.reset_tasted()
	player.form.set_form_immediate(&"vampire")
	var flees := []
	player.feeding.witnessed.connect(func(n): flees.append(n))
	tomas.global_position = Vector3(6.5, 0, 11.0)
	elise.global_position = Vector3(0.0, 0, 8.0)
	elise.rotation.y = atan2(-(6.5 - 0.0), -(11.0 - 8.0))
	var elise_yaw := elise._home_yaw
	elise._home_yaw = elise.rotation.y   # idle people drift back to their own facing; keep her watching
	_place(Vector3(10.5, 0, 11.0), 90.0)
	await get_tree().physics_frame
	await _run_until_focus(tomas.global_position, 3.0)
	Input.action_press(&"feed")
	await _wait(0.9)
	_check(elise.mode == HumanNpc.Mode.FLEEING and player.feeding.witness_count >= 1 and flees.size() >= 1, "someone who SEES a feeding runs (witnesses: %d)" % player.feeding.witness_count)
	_check(main.hud._toast_label.text.begins_with("Someone saw"), "the game tells you: %s" % main.hud._toast_label.text)
	await _wait(3.2)
	Input.action_release(&"feed")
	await _wait_memory(3.0)
	await _dismiss_memory()
	elise._home_yaw = elise_yaw   # put her back: later sections rely on her facing away from the road


# ------------------------------------------------------------------ feeding: asleep and trusting

func _set_time(h: float) -> void:
	main.tod.set_hour(h)
	get_tree().call_group(&"npcs", &"new_day")
	get_tree().call_group(&"secrets", &"new_day")


func _test_feeding_asleep_and_trusting() -> void:
	print("[FEEL] --- FEEDING: a sleeper, and someone who trusted you ---")
	_reset_world()
	HumanNpc.reset_tasted()
	HumanNpc.schedules_enabled = true
	_set_time(22.0)
	player.form.set_form_immediate(&"vampire")
	var tomas := world.tomas
	_place(Vector3(14.4, 0.0, 18.4), -90.0)
	await _wait(0.5)
	await _run_until_focus(tomas.global_position, 12.0, false)
	_check(tomas.mode == HumanNpc.Mode.SLEEPING and _prompt().contains("asleep"), "a heavy sleeper can be approached: %s" % _prompt())
	var dream_hint := String(tomas.get_sense_data(4.0)["hint"])
	_check(dream_hint == "a dream waits", "Sense promises a dream: '%s'" % dream_hint)
	Input.action_press(&"feed")
	await _wait(1.4)
	_check(player.feeding.style.id == &"asleep" and player.feeding.style.noise_radius == 0.0 and player.feeding.style.feed_volume_db < -10.0, "a sleeper is fed on quietly (%.0f dB, no scream)" % player.feeding.style.feed_volume_db)
	await _wait(3.6)
	Input.action_release(&"feed")
	_check(await _wait_memory(3.0) and main.memory_view.style.id == &"asleep", "the dream plays: %s" % main.memory_view.title_text())
	_check(player.surge.seconds_left > 60.0 and absf(player.surge.power - 0.8) < 0.01, "a long, gentle rush (%.0f s, power %.1f)" % [player.surge.seconds_left, player.surge.power])
	_check(main.screen_fx.memory_fragmentation == 0.0, "the dream is smooth, not torn")
	await _dismiss_memory()

	# Someone who trusted you.
	_reset_world()
	HumanNpc.reset_tasted()
	player.form.set_form_immediate(&"human")
	_place(Vector3(5.2, 0.0, 11.0), -90.0)
	await _wait(0.5)
	for i in 3:
		tomas._talk_cooldown = 0.0
		await _tap(&"interact")
		await _wait(0.3)
	_check(tomas.mode == HumanNpc.Mode.FOLLOWING, "three friendly chats and Tomas follows you")
	player.form.request_form(&"vampire")
	await _wait(0.9)
	_check(tomas.mode == HumanNpc.Mode.STUNNED, "he sees what you are and freezes")
	await _run_until_focus(tomas.global_position, 2.0)
	Input.action_press(&"feed")
	await _wait(1.0)
	_check(player.feeding.style.id == &"trusting" and String(tomas.get_feed_result()["taste_note"]).contains("trust"), "it is a different feed: %s" % tomas.get_feed_result()["taste_note"])
	await _wait(3.6)
	Input.action_release(&"feed")
	await _wait_memory(3.0)
	_check(main.memory_view.title_text() == "Flour on Her Hands", "trust gives the memory only trust opens: %s" % main.memory_view.title_text())
	await _dismiss_memory()
	_reset_world()


# ------------------------------------------------------------------ Blood Memory: input rules

func _fresh_result(npc: HumanNpc, style_id: StringName) -> Dictionary:
	var r := npc.get_feed_result()
	r["style"] = ContentRegistry.get_def(&"FeedStyle", style_id)
	r["style_id"] = style_id
	return r


func _test_memory_input() -> void:
	print("[FEEL] --- BLOOD MEMORY: readable, never auto-dismissed, dismissed only on purpose ---")
	_slow_memory()
	_reset_world()
	HumanNpc.reset_tasted()
	player.form.set_form_immediate(&"vampire")
	var mv: MemoryView = main.memory_view
	await _approach_elise()
	# Hold E exactly as a player does: one key that feeds, interacts and (later) would dismiss.
	_key(KEY_E, true)
	var t := 0.0
	while t < 6.0 and not mv.is_open():
		await get_tree().process_frame
		t += get_process_delta_time()
	_check(mv.is_open() and player.state.mode == PlayerState.Mode.MEMORY, "the memory opens while E is STILL held")
	await _wait(0.5)
	_check(mv.is_open() and not mv.can_dismiss(), "the held feed key does not close it")
	await _wait(2.4)
	_check(mv.is_open() and not mv.can_dismiss(), "still open after the intro: the same key held all the way is not a dismissal")
	await _shot("m01_intro")
	await _wait(3.4)
	_check(mv.is_open() and not mv.text_complete(), "it is being told, a few words at a time (%d of %d characters)" % [mv._body.visible_characters, mv._total_chars])
	_key(KEY_E, false)
	await _wait(0.2)
	await _shot("m02_telling")
	await _press_key(KEY_E)
	_check(mv.is_open() and mv.text_complete(), "a press DURING the telling finishes the text instead of closing it")
	await _press_key(KEY_E)
	_check(mv.is_open(), "an immediate second press does not close it either (lock %.1f s)" % mv._skip_lock)
	await _wait(1.8)
	_check(mv.can_dismiss() and mv._prompt_row.modulate.a > 0.5, "after time to read, the prompt appears and it can be closed")
	await _shot("m03_ready")
	await _press_key(KEY_E)
	await _wait(1.3)
	_check(not mv.is_open() and not get_tree().paused and player.state.mode == PlayerState.Mode.NORMAL, "a deliberate press closes it and control returns")

	# No timeout, ever.
	_reset_world()
	mv.present(player, _fresh_result(world.elise, &"calm"))
	Engine.time_scale = 8.0
	await _wait_real(3.8)   # about 30 s of memory time
	Engine.time_scale = 1.0
	_check(mv.is_open() and mv.seconds_open() > 25.0 and mv.text_complete(), "nothing dismisses it on a timer (still open after %.0f s)" % mv.seconds_open())
	await _press_key(KEY_SPACE)
	await _wait(1.2)
	_check(not mv.is_open(), "Space closes it (keyboard)")

	# A press during the intro does nothing.
	_reset_world()
	mv.present(player, _fresh_result(world.tomas, &"asleep"))
	await _wait(0.5)
	await _press_key(KEY_E)
	_check(mv.is_open(), "a press half a second in is ignored")
	await _press_pad(JOY_BUTTON_A)
	await _wait(0.8)
	await _press_key(KEY_ENTER)
	_check(mv.is_open() and not mv.text_complete(), "...and so is Enter during the intro (%.1f s)" % mv.seconds_open())
	mv.force_close()
	_check(not mv.is_open() and not get_tree().paused, "forcing it closed (death, scene change) always unfreezes the world")
	_fast_memory()


func _test_memory_controller() -> void:
	print("[FEEL] --- BLOOD MEMORY: controller dismissal ---")
	_fast_memory()
	var mv: MemoryView = main.memory_view
	var cases := [["pad A", JOY_BUTTON_A], ["pad B", JOY_BUTTON_B], ["pad X", JOY_BUTTON_X]]
	for c in cases:
		_reset_world()
		mv.present(player, _fresh_result(world.elise, &"calm"))
		var t := 0.0
		while t < 10.0 and not mv.can_dismiss():
			await get_tree().process_frame
			t += get_process_delta_time()
		_check(mv.can_dismiss(), "%s: ready to close after %.1f s" % [c[0], mv.seconds_open()])
		await _press_pad(c[1])
		await _wait(0.6)
		_check(not mv.is_open(), "%s closes the memory" % c[0])
	_reset_world()
	mv.present(player, _fresh_result(world.elise, &"afraid"))
	var t2 := 0.0
	while t2 < 10.0 and not mv.can_dismiss():
		await get_tree().process_frame
		t2 += get_process_delta_time()
	await _click()
	await _wait(0.6)
	_check(not mv.is_open(), "a mouse click closes it too")
	# Each state looks and sounds different.
	var seen_tints := {}
	for style_id in [&"calm", &"asleep", &"afraid"]:
		_reset_world()
		mv.present(player, _fresh_result(world.elise, style_id))
		await _wait(0.4)
		seen_tints[style_id] = main.screen_fx.memory_tint
		_check(Sfx.is_loop_playing(mv.style.memory_bed), "%s plays its own sound bed (%s)" % [style_id, mv.style.memory_bed])
		mv.force_close()
	_check(seen_tints[&"calm"] != seen_tints[&"afraid"] and seen_tints[&"asleep"] != seen_tints[&"calm"], "calm, asleep and afraid memories are tinted differently")
	# Readability.
	mv.present(player, _fresh_result(world.tomas, &"calm"))
	await _wait(0.3)
	_check(mv._body.get_theme_font_size(&"font_size") >= 20 and mv._title.get_theme_font_size(&"font_size") >= 30 and mv._meta.get_theme_font_size(&"font_size") >= 15, "no tiny text: body %d, title %d" % [mv._body.get_theme_font_size(&"font_size"), mv._title.get_theme_font_size(&"font_size")])
	var body_col := mv._body.get_theme_color(&"font_color")
	_check(body_col.get_luminance() > 0.8, "the words are near-white over a dark rise (luminance %.2f)" % body_col.get_luminance())
	mv.force_close()
	_reset_world()


# ------------------------------------------------------------------ Sense

func _test_sense() -> void:
	print("[FEEL] --- VAMPIRIC SENSE: a perception, not an outline ---")
	_reset_world()
	HumanNpc.reset_tasted()
	player.form.set_form_immediate(&"vampire")
	_set_blood(90.0)
	var elise := world.elise
	elise.known = false
	world.tomas.known = false
	var sense: VampiricSense = player.abilities.get_ability(&"vampiric_sense")
	_place(Vector3(-13.0, 0, 5.5), 90.0)
	player.camera_rig.yaw = PI * 0.5
	await _wait(0.6)
	var pulses0 := Haptics.pulse_count
	await _tap(&"vampiric_sense")
	_check(sense.active and player.camera_rig._fov_kick > 1.0, "switching it on is a camera breath (kick %.1f)" % player.camera_rig._fov_kick)
	_check(Haptics.pulse_count > pulses0, "...and a rumble in the hands")
	var target: SenseTarget = elise.get_node("SenseTarget")
	var max_flash := 0.0
	var t := 0.0
	while t < 2.6:
		await get_tree().process_frame
		t += get_process_delta_time()
		max_flash = maxf(max_flash, target._flash)
	_check(target.revealed and max_flash > 0.6, "the scan wave reaching someone makes them flare (%.2f)" % max_flash)
	_check(sense.focus_target != null and sense.focus_target.get_parent() == elise, "the one you are facing is the one you attend to")
	_check(target.priority == 1.0, "...bright, with the full readout")
	var corvin_target: SenseTarget = world.corvin.get_node("SenseTarget")
	if corvin_target.revealed:
		_check(corvin_target.priority < 0.9, "...while everyone else recedes (%.1f)" % corvin_target.priority)
	else:
		_check(true, "the watchman is out of range from here, so nothing competes for attention")
	var data := elise.get_sense_data(4.0)
	_check(data["title"] == "A stranger" and not data["known"], "someone you have not met is a stranger: %s" % data["title"])
	elise.known = true
	var known_data := elise.get_sense_data(4.0)
	_check(known_data["title"] == "Elise Marrow" and known_data["known"] and known_data["hint"] == "a memory waits", "...someone you know has a name (and the gold hint still shows)")
	_check(String(known_data["label"]).contains("bpm") and String(known_data["blood"]).contains("Bright"), "the blood is described once you are close")
	var far := elise.get_sense_data(25.0)
	_check(far["title"] == "" and far["bpm"] > 0.0, "far away it is only a pulse")
	_check(elise.get_sense_data(4.0)["state"] == &"calm" and elise._state_name() == &"calm", "the heartbeat knows its mood")
	elise.awareness = 0.5
	_check(elise.get_sense_data(4.0)["state"] == &"afraid", "...a frightened heart sounds and looks different")
	elise.awareness = 0.0
	# Very close: the heart is in your chest.
	_place(Vector3(-21.0, 0, 5.5), 90.0)
	player.camera_rig.yaw = PI * 0.5
	var near0 := Haptics.pulse_count
	await _wait(3.2)
	_check(Haptics.pulse_count - near0 >= 3, "a heart within a few metres throbs through the pad (%d pulses in 3 s)" % (Haptics.pulse_count - near0))
	await _shot("x01_sense_close")
	await _tap(&"vampiric_sense")
	_reset_world()


# ------------------------------------------------------------------ traversal

func _use_route(id: StringName, end: int) -> Dictionary:
	var l := _link(id)
	var p := l.placement
	var start := p.end_position(end)
	var dest := p.end_position(1 - end)
	var dir := dest - start
	dir.y = 0.0
	dir = dir.normalized()
	var stand := start - dir * (0.2 if start.y > 0.5 else 0.6)    # just behind the end (a wall top is only 0.6 m thick)
	stand.y = start.y + 0.05
	_place(stand, rad_to_deg(atan2(-dir.x, -dir.z)))
	await _wait(0.45)
	var prompt := _prompt()
	var act := main.hud._prompt_glyph.action
	await _tap(&"interact")
	await _wait(0.25)
	var mid_mode := player.state.mode
	await _wait(TraversalController.route_duration(p) + 0.45)
	var pos := player.global_position
	return {"prompt": prompt, "action": act, "mid_mode": mid_mode, "pos": pos, "dest": dest,
		"ok": player.state.mode == PlayerState.Mode.NORMAL and pos.distance_to(dest) < 1.0 and player.traversal.is_clear(pos)}


func _test_traversal() -> void:
	print("[FEEL] --- TRAVERSAL: routes only a vampire can take ---")
	_reset_world()
	player.form.set_form_immediate(&"vampire")
	_set_blood(90.0)
	var window := _link(&"manor_window")
	_check(window != null and world.traversal_links.size() >= 6, "the world has %d designated routes" % world.traversal_links.size())
	var r: Dictionary = await _use_route(&"manor_window", 0)
	_check(r["prompt"] == "Slip into the manor through the window" and r["action"] == &"interact", "the vampire is offered the window: %s" % r["prompt"])
	_check(r["mid_mode"] == PlayerState.Mode.TRAVERSING, "it takes over the body for a moment")
	_check(r["ok"], "and puts the vampire clear on the other side (%s)" % str(r["pos"].snapped(Vector3(0.1, 0.1, 0.1))))
	_check(player.visual.visible and player.traversal.traversals_done == 1, "the body re-forms; one traversal done")
	await _shot("t01_inside_window")
	r = await _use_route(&"manor_window", 1)
	_check(r["prompt"] == "Slip out of the manor through the window" and r["ok"], "it works both ways: %s" % r["prompt"])

	# A Human: the route does not exist.
	player.form.set_form_immediate(&"human")
	_place(Vector3(6.2, 0, -4.0), 180.0)
	await _wait(0.5)
	var done := player.traversal.traversals_done
	_check(_prompt() == "none" and not player.traversal.can_use(window), "a Human is offered nothing at the window")
	await _tap(&"interact")
	await _wait(0.6)
	_check(not player.traversal.active and player.traversal.traversals_done == done and player.global_position.distance_to(Vector3(6.2, 0, -4.0)) < 0.6, "...and pressing interact does nothing")
	_check(not window.is_sense_visible(), "...nor does Sense (the human has none) show it")
	_check(not player.form.current.traversal.has("window") and not player.form.current.traversal.has("climb"), "FormData.traversal is empty for humans")

	# Invalid attempts.
	player.form.set_form_immediate(&"vampire")
	_place(Vector3(6.2, 0, 8.0), 180.0)
	await _wait(0.4)
	_check(_prompt() == "none" or not _prompt().contains("window"), "far from a route there is no prompt")
	_check(not player.traversal.start(window, 0), "start() refuses when you are not at the route")
	_place(Vector3(6.2, 0, -4.0), 0.0)     # facing the window (north)
	await _wait(0.4)
	player.state.set_mode(PlayerState.Mode.TRANSFORMING)
	_check(not player.traversal.can_use(window), "it cannot begin in the middle of a transformation")
	player.state.set_mode(PlayerState.Mode.FEEDING)
	_check(not player.traversal.can_use(window), "...or a feeding")
	player.state.set_mode(PlayerState.Mode.NORMAL)
	await _wait(0.3)
	_check(player.traversal.start(window, 0), "at the window it begins")
	_check(not player.traversal.start(window, 0), "...and cannot begin twice")
	await _wait(1.4)
	_reset_world()
	player.form.set_form_immediate(&"vampire")

	# Every route, both ways, never stuck.
	var all_ok := true
	var report := []
	for l in world.traversal_links:
		for end in [0, 1]:
			var res: Dictionary = await _use_route(l.placement.id, end)
			var ok: bool = res["ok"]
			all_ok = all_ok and ok
			if not ok:
				report.append("%s/%d -> %s" % [l.placement.id, end, str(res["pos"].snapped(Vector3(0.1, 0.1, 0.1)))])
	_check(all_ok, "all %d routes work in both directions and leave the body clear of geometry %s" % [world.traversal_links.size(), str(report)])
	for l in world.traversal_links:
		_check(player.traversal.is_clear(l.placement.end_position(0)) and player.traversal.is_clear(l.placement.end_position(1)), "both ends of %s have room to stand" % l.placement.id)

	# Roof: climb, stand, walk, drop.
	_reset_world()
	player.form.set_form_immediate(&"vampire")
	r = await _use_route(&"manor_roof", 0)
	_check(r["prompt"] == "Scale the manor wall to the roof" and r["ok"], "the vampire climbs to the manor roof: %s" % r["prompt"])
	await _wait(0.8)
	_check(player.global_position.y > 3.7 and player.is_on_floor(), "and stands on it (y %.2f)" % player.global_position.y)
	Input.action_press(&"move_forward")
	player.camera_rig.yaw = PI
	await _wait(0.5)
	Input.action_release(&"move_forward")
	_check(player.global_position.y > 3.6, "the roof holds a walking vampire (no falling through)")
	await _shot("t02_on_the_roof")
	r = await _use_route(&"manor_roof", 1)
	_check(r["prompt"] == "Drop from the manor roof to the yard" and r["ok"] and player.global_position.y < 0.3, "the drop lands in the yard")

	# Blocked exit: nothing may leave the player inside an object.
	_reset_world()
	player.form.set_form_immediate(&"vampire")
	var block := StaticBody3D.new()
	block.collision_layer = 1
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(3.0, 2.0, 3.0)
	cs.shape = box
	block.add_child(cs)
	world.add_child(block)
	block.global_position = Vector3(6.2, 1.0, -7.4)
	var blocked_count := []
	player.traversal.blocked.connect(func(_l): blocked_count.append(1))
	await get_tree().physics_frame
	r = await _use_route(&"manor_window", 0)
	_check(player.traversal.is_clear(player.global_position) and player.state.mode == PlayerState.Mode.NORMAL, "with the exit blocked the player is NOT left inside it (%s)" % str(player.global_position.snapped(Vector3(0.1, 0.1, 0.1))))
	_check(blocked_count.is_empty() and r["prompt"] == "none" and player.global_position.distance_to(Vector3(6.2, 0, -4.0)) < 0.7, "the blocked route is not offered, so nothing starts and you stay where you were (see polish_tests for a route that fills up mid-way)")
	block.queue_free()

	# Discoverable by Sense.
	_reset_world()
	player.form.set_form_immediate(&"vampire")
	_set_blood(90.0)
	_place(Vector3(6.2, 0, -2.6), 0.0)
	await _wait(0.4)
	await _tap(&"vampiric_sense")
	await _wait(2.2)
	var revealed_ends := window.sense_targets.filter(func(t): return t.revealed).size()
	var far_end: SenseTarget = _link(&"cottage_window").sense_targets[0]
	_check(revealed_ends >= 1 and String(window.get_sense_data()["label"]) == "Window", "Sense reveals the window to the one who can use it (%d ends in range)" % revealed_ends)
	_check(not far_end.revealed, "...and only where it actually is: a window across the estate stays quiet")
	await _shot("t03_sense_route")
	await _tap(&"vampiric_sense")
	_reset_world()


# ------------------------------------------------------------------ pause and menus

func _focus_text() -> String:
	var f := get_viewport().gui_get_focus_owner()
	return (f as Button).text if f is Button else (str(f.name) if f else "none")


func _test_pause_and_menus() -> void:
	print("[FEEL] --- PAUSE MENU ---")
	_reset_world()
	var pm: PauseMenu = main.pause_menu
	HumanNpc.schedules_enabled = true
	main.tod.paused = false
	main.tod.set_hour(23.0)
	main.tod.sun_override = Vector3.ZERO
	get_tree().call_group(&"npcs", &"new_day")
	player.form.set_form_immediate(&"vampire")
	_place(Vector3(3.0, 0, 30.0 - 3.0), 0.0)   # near the gate, away from the watchman's first post
	await _wait(3.0)
	var corvin := world.corvin
	var c0 := corvin.global_position
	await _wait(2.0)
	_check(corvin.global_position.distance_to(c0) > 0.8, "unpaused, the watchman walks his round (%.1f m in 2 s)" % corvin.global_position.distance_to(c0))
	var hour0 := main.tod.hour
	await _wait(1.0)
	_check(main.tod.hour > hour0, "...and the clock runs")
	# Open with the keyboard.
	await _press_key(KEY_ESCAPE)
	_check(pm.is_open() and get_tree().paused and PauseControl.has_reason(&"menu"), "Esc opens the pause menu and freezes the tree")
	_check(_focus_text() == "Resume", "Resume is focused: %s" % _focus_text())
	var frozen := {"hour": main.tod.hour, "blood": player.blood.value, "corvin": corvin.global_position, "heat": player.sunlight.model.heat, "pos": player.global_position}
	await _shot("p01_pause")
	# Gameplay input must not leak through.
	Input.action_press(&"move_forward")
	await _press_key(KEY_F)
	await _press_key(KEY_Q)
	await _press_pad(JOY_BUTTON_Y)
	await _press_pad(JOY_BUTTON_LEFT_SHOULDER)
	await _wait(2.0)
	Input.action_release(&"move_forward")
	_check(player.form.is_form(&"vampire") and not player.abilities.get_ability(&"vampiric_sense").active, "transform and Sense do not fire behind the menu")
	_check(player.global_position.distance_to(frozen["pos"]) < 0.01 and absf(player.velocity.y) < 0.01, "the player does not move or jump")
	_check(absf(main.tod.hour - frozen["hour"]) < 0.0001, "time is stopped (%.4f -> %.4f)" % [frozen["hour"], main.tod.hour])
	_check(is_equal_approx(player.blood.value, frozen["blood"]) and is_equal_approx(player.sunlight.model.heat, frozen["heat"]), "blood and sunlight are stopped")
	_check(corvin.global_position.distance_to(frozen["corvin"]) < 0.01, "NPC simulation is stopped")
	_check(AudioBuses.muffle_of(AudioBuses.AMBIENCE) > 0.3, "the world's sound is pushed back")
	# Navigate with a pad: D-pad down, A on Controls.
	await _press_pad(JOY_BUTTON_DPAD_DOWN)
	_check(_focus_text() == "Controls" and pm._controls_panel.visible, "D-pad down moves to Controls, which previews on the right")
	await _press_pad(JOY_BUTTON_A)
	_check(pm.current_view() == PauseMenu.View.CONTROLS and pm._controls_panel.visible, "A opens the controls screen")
	var panel_rect: Rect2 = pm._controls_panel.get_global_rect()
	_check(panel_rect.position.x > get_viewport().get_visible_rect().size.x * 0.4, "...on the right side of the screen (x %.0f)" % panel_rect.position.x)
	await _shot("p02_controls")
	await _press_pad(JOY_BUTTON_B)
	_check(pm.current_view() == PauseMenu.View.LIST and pm.is_open(), "B goes back one level")
	await _press_pad(JOY_BUTTON_DPAD_DOWN)
	await _press_pad(JOY_BUTTON_A)
	_check(pm.current_view() == PauseMenu.View.OPTIONS and pm._options_panel.visible and get_viewport().gui_get_focus_owner() is HSlider, "the Options screen puts focus on its first slider")
	await _shot("p03_options")
	var master := GameSettings.master_volume
	await _press_pad(JOY_BUTTON_DPAD_RIGHT)
	_check(absf(GameSettings.master_volume - master) > 0.001, "D-pad right moves a slider with the pad (%.2f -> %.2f)" % [master, GameSettings.master_volume])
	GameSettings.set_option(&"master_volume", master)
	await _press_pad(JOY_BUTTON_B)
	_check(pm.current_view() == PauseMenu.View.LIST, "B leaves Options")
	_check(not pm._quit_btn.disabled and pm._quit_btn.text == "Quit to Title", "Quit to Title is a real, enabled option")
	# Resume with the pad's Menu button.
	await _press_pad(JOY_BUTTON_START)
	await _wait(0.2)
	_check(not pm.is_open() and not get_tree().paused, "Menu resumes the game")
	var h1 := main.tod.hour
	await _wait(1.0)
	_check(main.tod.hour > h1 and AudioBuses.muffle_of(AudioBuses.AMBIENCE) < 0.05, "time runs again and the sound returns")
	# Pressing pause again (keyboard) also resumes; the mouse works too.
	await _press_key(KEY_ESCAPE)
	_check(pm.is_open(), "Esc opens it again")
	await _press_key(KEY_ESCAPE)
	_check(not pm.is_open() and not get_tree().paused, "pressing pause again resumes")
	await _press_key(KEY_ESCAPE)
	await _press_key(KEY_DOWN)
	await _press_key(KEY_DOWN)
	_check(_focus_text() == "Options", "arrow keys navigate (%s)" % _focus_text())
	pm._resume.pressed.emit()
	_check(not pm.is_open(), "clicking Resume resumes")
	# The title screen a quit lands on is real.
	var title: Control = load("res://scenes/title.tscn").instantiate()
	add_child(title)
	await _wait(0.4)
	var play_ok := false
	for b in title.find_children("*", "Button", true, false):
		if (b as Button).text == "Play" and not (b as Button).disabled:
			play_ok = true
	_check(play_ok and _focus_text() == "Play", "a Title screen exists with Play focused (Quit to Title goes there)")
	title.queue_free()
	await _wait(0.2)
	_night()
	_reset_world()


# ------------------------------------------------------------------ controller-only play

func _test_controller_only() -> void:
	print("[FEEL] --- CONTROLLER: the whole game without a keyboard ---")
	_reset_world()
	HumanNpc.schedules_enabled = false
	player.form.set_form_immediate(&"human")
	_place(Vector3(3.0, 0, -2.0), 180.0)
	await _wait(0.5)
	# Move with the left stick, look with the right, jump with A, run with RT.
	var p0 := player.global_position
	_pad_axis(JOY_AXIS_LEFT_Y, -1.0)
	await _wait(0.7)
	_pad_axis(JOY_AXIS_LEFT_Y, 0.0)
	_check(player.global_position.distance_to(p0) > 1.0, "the left stick walks (%.1f m)" % player.global_position.distance_to(p0))
	var yaw0 := player.camera_rig.yaw
	_pad_axis(JOY_AXIS_RIGHT_X, 1.0)
	await _wait(0.5)
	_pad_axis(JOY_AXIS_RIGHT_X, 0.0)
	_check(absf(player.camera_rig.yaw - yaw0) > 0.3, "the right stick turns the camera (%.2f rad)" % absf(player.camera_rig.yaw - yaw0))
	await _press_pad(JOY_BUTTON_A)
	await _wait(0.1)
	_check(player.velocity.y > 0.5 or not player.is_on_floor(), "A jumps")
	await _wait(1.0)
	_place(Vector3(3.0, 0, -2.0), 180.0)
	await _wait(0.4)
	_pad_axis(JOY_AXIS_LEFT_Y, -1.0)
	_pad_axis(JOY_AXIS_TRIGGER_RIGHT, 1.0)
	await _wait(0.5)
	var run_speed := Vector2(player.velocity.x, player.velocity.z).length()
	_pad_axis(JOY_AXIS_TRIGGER_RIGHT, 0.0)
	await _wait(0.5)
	var walk_speed := Vector2(player.velocity.x, player.velocity.z).length()
	_pad_axis(JOY_AXIS_LEFT_Y, 0.0)
	_check(run_speed > walk_speed + 1.0, "the right trigger runs (%.1f vs %.1f m/s)" % [run_speed, walk_speed])
	# The left-stick click latches run while you keep moving.
	await _press_pad(JOY_BUTTON_LEFT_STICK)
	_pad_axis(JOY_AXIS_LEFT_Y, -1.0)
	await _wait(0.7)
	var latched := Vector2(player.velocity.x, player.velocity.z).length()
	_pad_axis(JOY_AXIS_LEFT_Y, 0.0)
	await _wait(0.6)
	_check(latched > walk_speed + 1.0 and not player._run_latched, "a stick click latches the run, and stopping releases it (%.1f m/s)" % latched)
	# Y transforms, LB senses, X feeds, Menu pauses, View shows controls.
	await _press_pad(JOY_BUTTON_Y)
	await _wait(1.6)
	_check(player.form.is_form(&"vampire"), "Y transforms")
	_check(InputSetup.device_kind == InputSetup.XBOX, "the game noticed a pad is in use (prompts switch to pad glyphs)")
	_place(Vector3(-13.0, 0, 5.5), 90.0)
	await _press_pad(JOY_BUTTON_LEFT_SHOULDER)
	await _wait(0.4)
	var sense: VampiricSense = player.abilities.get_ability(&"vampiric_sense")
	_check(sense.active, "LB toggles Sense")
	await _press_pad(JOY_BUTTON_LEFT_SHOULDER)
	await _wait(0.2)
	_check(not sense.active, "...and LB again turns it off")
	await _press_pad(JOY_BUTTON_RIGHT_STICK)
	await _wait(0.2)
	_check(sense.active, "R3 is an alternative Sense button")
	await _press_pad(JOY_BUTTON_RIGHT_STICK)
	await _wait(0.2)
	await _approach_elise()
	_check(_prompt().begins_with("Feed") and main.hud._prompt_glyph.text_now() == "X", "the prompt shows the pad's X: %s [%s]" % [_prompt(), main.hud._prompt_glyph.text_now()])
	_pad(JOY_BUTTON_X, true)
	await _wait(1.4)
	_check(player.state.mode == PlayerState.Mode.FEEDING, "holding X feeds")
	await _wait(3.6)
	_pad(JOY_BUTTON_X, false)
	_check(await _wait_memory(3.0), "the memory opens")
	await _dismiss_memory()
	_check(not main.memory_view.is_open(), "...and is dismissed with the pad")
	# Coffin with the pad.
	_place(Vector3(-4.0, 0, -11.0), -60.0)
	_face(world.coffin.global_position)
	await _wait(0.5)
	_check(_prompt().begins_with("Sleep") and main.hud._prompt_glyph.text_now() == "X", "the coffin asks for X: %s" % _prompt())
	# Menu / View.
	await _press_pad(JOY_BUTTON_BACK)
	var help_before := main.hud._help.visible
	await _press_pad(JOY_BUTTON_BACK)
	_check(main.hud._help.visible != help_before, "View toggles the controls screen")
	await _press_pad(JOY_BUTTON_START)
	_check(main.pause_menu.is_open(), "Menu opens the pause menu")
	await _press_pad(JOY_BUTTON_START)
	_check(not main.pause_menu.is_open(), "...and closes it")
	# A DualSense shows its own symbols.
	InputSetup.set_device_kind(InputSetup.PLAYSTATION)
	await _wait(0.3)
	_check(main.hud._prompt_glyph.text_now() == "Square", "a PlayStation pad shows Square for interact (%s)" % main.hud._prompt_glyph.text_now())
	InputSetup.set_device_kind(InputSetup.KEYBOARD)
	await _wait(0.3)
	_check(main.hud._prompt_glyph.text_now() == "E", "...and the keyboard shows E")
	_reset_world()


# ------------------------------------------------------------------ HUD and controls screen

func _test_hud() -> void:
	print("[FEEL] --- HUD ---")
	_reset_world()
	player.form.set_form_immediate(&"human")
	await _wait(1.0)
	var hud: Hud = main.hud
	_check(hud._form_label.text == "HUMAN" and hud._gauge.vampire_blend() < 0.1, "the HUD reads HUMAN, with a small warm vessel")
	player.form.set_form_immediate(&"vampire")
	await _wait(1.5)
	_check(hud._form_label.text == "VAMPIRE" and hud._gauge.vampire_blend() > 0.9, "...and VAMPIRE, with the fuller crimson one")
	var labels: Array = []
	_all_labels(hud, labels)
	var numeric := []
	for l in labels:
		var txt: String = (l as Label).text
		if l == hud._gain_label:
			continue   # the brief "+N" that floats up while feeding
		if l == hud._toast_label or l == hud._surge_detail:
			continue   # the reward line spells out its percentages on purpose (a Bloodrush is explained, not hinted)
		if txt.contains("%") or txt.is_valid_int():
			numeric.append(txt)
	_check(numeric.is_empty(), "no stray numeric labels: blood is a living vessel with its number drawn under it, not a bar of percentages %s" % str(numeric))
	_check(hud._gauge.number_text() == "%d / 100" % hud._gauge.displayed_amount(), "the vessel carries its own number: %s" % hud._gauge.number_text())
	_set_blood(18.0)
	await _wait(0.4)
	_check(hud._status_label.text == "HUNGRY" and hud._gauge._hungry, "low blood says HUNGRY in words (and a dashed ring), not only a colour")
	_set_blood(4.0)
	await _wait(0.4)
	_check(hud._status_label.text == "STARVING", "...and STARVING when nearly empty")
	_check(main.screen_fx.level(&"hunger") > 0.05, "the world's colour drains with hunger (%.2f)" % main.screen_fx.level(&"hunger"))
	_check(player.feedback.heart_visibility > 0.5, "the heart shows at the edges of the screen when you are hungry")
	_set_blood(70.0)
	await _wait(1.0)
	_check(hud._status_label.text == "", "a fed vampire has nothing to complain about")
	# The clock carries a phase glyph and words.
	main.tod.set_hour(21.0)
	hud._update_clock()
	_check(hud._clock.text == "9:00 PM" and hud._clock_sub.text.begins_with("Night") and hud._clock_extra.text.begins_with("Sunrise in"), "clock: %s / %s / %s" % [hud._clock.text, hud._clock_sub.text, hud._clock_extra.text])
	_night()
	# The controls screen.
	await _wait(0.4)
	var help: ControlsPanel = hud._help
	var vp := get_viewport().get_visible_rect().size
	_check(help.visible and help.get_global_rect().position.x > vp.x * 0.45, "the controls screen is on the right of the screen (x %.0f of %.0f)" % [help.get_global_rect().position.x, vp.x])
	_check(_count_type(help, "InputGlyph") >= 12, "it is built from real button glyphs (%d of them)" % _count_type(help, "InputGlyph"))
	var help_labels: Array = []
	_all_labels(help, help_labels)
	var heads := []
	for l in help_labels:
		heads.append((l as Label).text)
	_check(heads.has("MOVE") and heads.has("BECOME") and heads.has("THE WORLD") and heads.has("GAME") and heads.has("CONTROLS"), "...grouped: %s" % str(heads.filter(func(x): return x == x.to_upper() and x.length() > 3)))
	_check(help.size.x >= 340 and help.size.x <= 480 and help.size.y >= 300 and help.get_global_rect().end.y <= vp.y, "...compact, with room to breathe, and on screen (%.0f x %.0f, bottom %.0f of %.0f)" % [help.size.x, help.size.y, help.get_global_rect().end.y, vp.y])
	player.form.set_form_immediate(&"human")
	await _wait(0.2)
	var dimmed := 0
	for r in help._rows:
		if (r["box"] as Control).modulate.a < 0.6:
			dimmed += 1
	_check(dimmed >= 3, "as a Human the vampire-only rows are dimmed (%d rows)" % dimmed)
	await _shot("h01_human_hud")
	await _tap(&"toggle_help")
	_check(not help.visible, "H hides it")
	await _shot("h02_human_hud_no_help")
	await _tap(&"toggle_help")
	_check(help.visible, "...and shows it again")
	player.form.set_form_immediate(&"vampire")
	await _wait(1.0)
	await _shot("h03_vampire_hud")
	await _tap(&"toggle_help")
	_reset_world()


# ------------------------------------------------------------------ coffin

func _test_coffin() -> void:
	print("[FEEL] --- COFFIN ---")
	_reset_world()
	player.form.set_form_immediate(&"vampire")
	_place(Vector3(-4.0, 0, -11.0), -60.0)
	_face(world.coffin.global_position)
	await _wait(0.5)
	_check(_prompt().begins_with("Sleep"), "approach: %s" % _prompt())
	var lid0 := world.coffin.lid_open
	await _tap(&"interact")
	await _wait(0.3)
	_check(world.coffin._menu.is_open(), "the coffin asks when you will wake")
	await _press_key(KEY_ENTER)    # the first (focused) answer is the old one: until dusk
	var max_lid := 0.0
	var lay := 0.0
	var t := 0.0
	while t < 1.5:
		await get_tree().process_frame
		t += get_process_delta_time()
		max_lid = maxf(max_lid, world.coffin.lid_open)
		lay = maxf(lay, player.visual.lying)
	_check(max_lid > 0.8 and lid0 < 0.1, "the lid slides off (%.2f open)" % max_lid)
	_check(lay > 0.9 and player.state.mode == PlayerState.Mode.RESTING, "you lie down in it")
	await _shot("c01_lying")
	await _wait(5.2)
	_check(player.state.mode == PlayerState.Mode.NORMAL and player.visual.lying == 0.0 and player.visual.visible and player.form.is_form(&"human"), "you wake as a human, standing, in control")
	_check(player.global_position.distance_to(world.coffin.global_position) < 4.5, "...beside the coffin, your home anchor")
	_reset_world()


# ------------------------------------------------------------------ the world

func _test_world() -> void:
	print("[FEEL] --- WORLD CLEANUP ---")
	var loc: LocationData = world.location
	_check(world.tree_positions.size() <= 10 and world.tree_positions.size() >= 6, "%d trees (was 16): framing, not crowding" % world.tree_positions.size())
	var blocked_path := []
	for p in world.tree_positions:
		if _min_distance(world.walkways, Vector2(p.x, p.z)) < 2.0:
			blocked_path.append(p)
	_check(blocked_path.is_empty(), "no tree stands on or beside a road or path %s" % str(blocked_path))
	var buildings := [Rect2(-8, -16, 16, 10), Rect2(-27, 2, 8, 7), Rect2(16, 15, 8, 6), Rect2(8, 23, 6, 5)]
	var near_building := []
	for p in world.tree_positions:
		if _min_distance(buildings, Vector2(p.x, p.z)) < 3.0:
			near_building.append(p)
	_check(near_building.is_empty(), "no tree clips into a building %s" % str(near_building))
	var stray_lamps := []
	for lp in loc.lamp_positions:
		if _min_distance(world.walkways, Vector2(lp.x, lp.z)) > 1.6:
			stray_lamps.append(lp)
	_check(stray_lamps.is_empty(), "every lamp stands beside a road or path, where people walk %s" % str(stray_lamps))
	var road := []
	for lp in loc.lamp_positions:
		if lp.x > 0.0 and lp.x < 6.0:
			road.append(lp.z)
	road.sort()
	var gaps_ok := road.size() >= 4
	for i in range(1, road.size()):
		var gap: float = road[i] - road[i - 1]
		gaps_ok = gaps_ok and gap > 6.0 and gap < 13.0
	_check(gaps_ok, "road lamps are evenly spaced %s" % str(road))
	_check(world.find_children("Boulder*", "", true, false).is_empty(), "the purposeless boulder is gone")
	_check(world.find_children("Bench*", "", true, false).size() >= 2 and world.find_children("Woodpile*", "", true, false).size() >= 1, "small lived-in details sit where people would use them (benches, a woodpile)")
	_check(world.corvin != null and world.npcs.size() == 3, "three people live here (the watchman is new)")
	# Opportunities through the day.
	var awake_everywhere := true
	var sleeper_hours := 0.0
	var h := 0.0
	while h < 24.0:
		var awake := 0
		var asleep := 0
		for n in world.npcs.values():
			var e: ScheduleEntry = (n as HumanNpc).profile.schedule_for(h)
			if e != null and e.activity == &"sleep":
				asleep += 1
			else:
				awake += 1
		awake_everywhere = awake_everywhere and awake >= 1
		if asleep >= 1:
			sleeper_hours += 0.5
		h += 0.5
	_check(awake_everywhere, "someone is awake at every hour")
	_check(sleeper_hours >= 17.0, "a sleeper can be found for %.1f of 24 hours" % sleeper_hours)
	var none_at_gate := true
	for l in world.traversal_links:
		none_at_gate = none_at_gate and l.placement.end_position(0).z < 30.0 and l.placement.end_position(1).z < 30.0
	_check(none_at_gate, "all routes are inside the estate")
	# The look of it, by day and by night.
	HumanNpc.schedules_enabled = true
	_set_time(23.0)
	player.form.set_form_immediate(&"vampire")
	_place(Vector3(3.0, 0, 26.0), 0.0)
	await _wait(1.6)
	await _shot("w01_night_road")
	_set_time(12.0)
	player.form.set_form_immediate(&"human")
	_place(Vector3(3.0, 0, 26.0), 0.0)
	await _wait(1.0)
	await _shot("w02_day_road")
	_reset_world()
