extends "res://tests/test_base.gd"
## Task 1.5 gameplay scenarios: routines, sleeping victims, blood-memory variants, trust and
## following, witnessing a transformation, tiered Sense, sun embers, night freedom, coffin sleep.
## Drives the real game through real input. Run:
##   godot --path . res://tests/scenario_tests.tscn -- <screenshot_dir>
## or headless: godot --headless --path . res://tests/scenario_tests.tscn

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	out_dir = args[0] if args.size() > 0 else ""
	HumanNpc.schedules_enabled = true
	main = load("res://scenes/main.tscn").instantiate()
	main.capture_mouse = false
	add_child(main)
	player = main.player
	world = main.world
	_fast_memory()
	main.tod.paused = true
	await _wait(2.8)
	await _run()
	print("[SCENARIO] ===== %d checks, %d failures =====" % [checks, failures])
	get_tree().quit(1 if failures > 0 else 0)


func _check(cond: bool, msg: String) -> void:
	checks += 1
	if cond:
		print("[SCENARIO] PASS  ", msg)
	else:
		failures += 1
		print("[SCENARIO] FAIL  ", msg)


func _set_time(h: float) -> void:
	main.tod.set_hour(h)
	get_tree().call_group(&"npcs", &"new_day")
	get_tree().call_group(&"secrets", &"new_day")


func _hold_feed(seconds: float) -> void:
	Input.action_press(&"feed")
	await _wait(seconds)
	Input.action_release(&"feed")


func _in_box(p: Vector3, x0: float, x1: float, z0: float, z1: float) -> bool:
	return p.x > x0 and p.x < x1 and p.z > z0 and p.z < z1


func _run() -> void:
	var tomas := world.tomas
	var elise := world.elise
	var sense: VampiricSense = player.abilities.get_ability(&"vampiric_sense")

	print("[SCENARIO] --- ROUTINES (data-driven schedules) ---")
	_set_time(12.0)
	await _wait(0.5)
	_check(tomas.mode == HumanNpc.Mode.CALM and tomas.global_position.z > 5.0 and tomas.global_position.x < 14.5, "12:00 Tomas is working the yard (%s)" % str(tomas.global_position.snapped(Vector3(0.1, 0.1, 0.1))))
	_check(elise.mode == HumanNpc.Mode.CALM and elise.global_position.x < -19.5, "12:00 Elise is inside the gatehouse")
	_set_time(22.0)
	await _wait(0.5)
	_check(tomas.mode == HumanNpc.Mode.SLEEPING and tomas.is_lying() and _in_box(tomas.global_position, 16.0, 24.0, 15.0, 21.0), "22:00 Tomas is asleep in his cottage bed")
	_check(elise.mode == HumanNpc.Mode.CALM and elise.global_position.x > -19.5 and elise._lantern.visible, "22:00 Elise keeps watch outside with a lantern")
	_set_time(1.0)
	await _wait(0.5)
	_check(elise.mode == HumanNpc.Mode.SLEEPING and elise.global_position.x < -19.5, "01:00 Elise is asleep inside the gatehouse")
	# Live transitions: the clock moves and people walk to their next place.
	_set_time(19.3)
	await _wait(0.5)
	tomas.global_position = Vector3(9.3, 0.0, 10.0)
	main.tod.set_hour(20.7)
	await _wait(28.0)
	_check(tomas.mode == HumanNpc.Mode.SLEEPING and _in_box(tomas.global_position, 16.0, 24.0, 15.0, 21.0), "at 20:30 Tomas walks home and goes to bed by himself (%s)" % str(tomas.global_position.snapped(Vector3(0.1, 0.1, 0.1))))
	main.tod.set_hour(5.7)
	await _wait(4.0)
	_check(tomas.mode == HumanNpc.Mode.CALM and not tomas.is_lying(), "at dawn Tomas wakes and gets up")

	print("[SCENARIO] --- SLEEPING VICTIM: DIFFERENT BLOOD, NO FLIGHT, NIGHT SAFE ---")
	_set_time(22.0)
	player.form.set_form_immediate(&"vampire")
	_place(Vector3(14.4, 0.0, 18.4), -90.0)
	await _wait(0.6)
	var hp0 := player.health.value
	var t := await _run_until_focus(tomas.global_position, 12.0, false)
	_check(tomas.mode == HumanNpc.Mode.SLEEPING, "a slow, quiet approach does not wake a heavy sleeper (t=%.1fs)" % t)
	_check(_prompt().contains("asleep"), "prompt: %s" % _prompt())
	Input.action_press(&"feed")
	await _wait(2.0)
	_check(player.state.mode == PlayerState.Mode.FEEDING and tomas.was_asleep, "feeding a sleeper starts (no struggle)")
	await _shot("s1_feeding_sleeper")
	_check(player.sunlight.heat_multiplier() >= 2.0, "feeding multiplies sunlight heat (x%.1f)" % player.sunlight.heat_multiplier())
	await _wait(3.0)
	Input.action_release(&"feed")
	await _wait(0.5)
	_check(tomas.mode == HumanNpc.Mode.DRAINED and tomas.is_lying(), "the sleeper stays in bed, drained")
	await _wait_memory()
	_check(main.memory_view.title_text() == "A Dream of Ink", "asleep blood gives the DREAM memory: %s" % main.memory_view.title_text())
	_check(world.secrets[&"cottage_ledger"].discovered and not world.secrets[&"well_key"].discovered, "the dream revealed the ledger, not the well key")
	_check(player.sunlight.heat_multiplier() < 1.01, "heat multiplier returns to normal after feeding")
	_check(player.health.value >= hp0 - 0.01 and player.sunlight.model.heat == 0.0, "night: the vampire takes no sun damage or heat at all")
	await _dismiss_memory()
	# Sense shows the secret; dig it up.
	_place(Vector3(18.6, 0.0, 18.4), 180.0)
	await _tap(&"vampiric_sense")
	await _wait(2.2)
	_check(world.secrets[&"cottage_ledger"].get_node("SenseTarget").revealed, "Sense now shows the hidden ledger")
	await _shot("s2_sense_night_cottage")
	await _tap(&"vampiric_sense")
	_face(world.secrets[&"cottage_ledger"].global_position)
	await _wait(0.4)
	_check(_prompt().contains("Pry up"), "prompt: %s" % _prompt())
	await _tap(&"interact")
	await _wait(0.3)
	_check(SecretStash.has_flag(&"ledger_read"), "ledger found: a new world flag is set")

	print("[SCENARIO] --- NOISE WAKES SLEEPERS ---")
	_set_time(1.0)
	_place(Vector3(-21.0, 0.0, 3.2), 90.0)
	await _wait(0.4)
	var sprint_t := 0.0
	var flip := false
	Input.action_press(&"sprint")
	Input.action_press(&"move_forward")
	while sprint_t < 6.0 and elise.mode == HumanNpc.Mode.SLEEPING:
		flip = fmod(sprint_t, 1.0) > 0.5
		_face(Vector3(-26.0 if not flip else -20.0, 0.0, 3.2))
		await get_tree().physics_frame
		sprint_t += get_physics_process_delta_time()
	Input.action_release(&"move_forward")
	Input.action_release(&"sprint")
	_check(elise.mode != HumanNpc.Mode.SLEEPING, "a sprinting vampire wakes a light sleeper (after %.1fs)" % sprint_t)

	print("[SCENARIO] --- HUMAN: TRUST, INFORMATION, LURE ---")
	HumanNpc.schedules_enabled = false
	_set_time(12.0)
	player.form.set_form_immediate(&"human")
	_place(Vector3(5.2, 0.0, 11.0), -90.0)
	await _wait(0.5)
	var tiers: Array[int] = []
	for i in 2:
		tomas._talk_cooldown = 0.0
		await _tap(&"interact")
		await _wait(0.3)
		tiers.append(tomas.trust_tier())
	_check(tiers == [1, 2], "each friendly conversation builds trust: tiers %s" % str(tiers))
	_check(tomas.known, "Tomas now knows who you are (name shown by Sense later)")
	tomas._talk_cooldown = 0.0
	await _tap(&"interact")
	await _wait(0.3)
	_check(tomas.mode == HumanNpc.Mode.FOLLOWING, "a trusting Tomas agrees to walk with you: '%s'" % tomas.speech_label.text)
	_place(Vector3(-4.0, 0.0, 11.0), -90.0)
	await _wait(5.0)
	_check(tomas.global_position.distance_to(player.global_position) < 5.0, "he follows (%.1f m away)" % tomas.global_position.distance_to(player.global_position))
	player.form.request_form(&"vampire")
	await _wait(0.6)
	_check(tomas.mode == HumanNpc.Mode.STUNNED, "he watches you transform and freezes in shock (not fleeing)")
	await _shot("s3_stunned_follower")
	await _wait(0.8)
	var lunge := await _run_until_focus(tomas.global_position, 2.0)
	_check(_prompt().begins_with("Feed"), "the stunned follower can be fed on: %s (%.2fs)" % [_prompt(), lunge])
	Input.action_press(&"feed")
	await _wait(1.0)
	_check(player.state.mode == PlayerState.Mode.FEEDING, "seized while stunned")
	await _wait(3.6)
	Input.action_release(&"feed")
	await _wait(0.4)
	await _wait_memory()
	_check(main.memory_view.title_text() == "Flour on Her Hands", "trust opened the memory only trust opens: %s" % main.memory_view.title_text())
	_check(world.secrets[&"well_key"].discovered, "...and it revealed the well key too (trust is a way to the key as well)")
	await _dismiss_memory()

	_set_time(12.0)
	player.form.set_form_immediate(&"human")
	_place(Vector3(5.2, 0.0, 11.0), -90.0)
	await _wait(0.5)
	for i in 3:
		tomas._talk_cooldown = 0.0
		await _tap(&"interact")
		await _wait(0.3)
	player.form.request_form(&"vampire")
	await _wait(7.0)
	_check(tomas.mode == HumanNpc.Mode.FLEEING, "if you do not act, the shocked follower bolts")

	print("[SCENARIO] --- WITNESSES ---")
	_set_time(12.0)
	player.form.set_form_immediate(&"human")
	_place(Vector3(-21.6, 0.0, 5.5), 90.0)
	await _wait(0.5)
	player.form.request_form(&"vampire")
	await _wait(0.7)
	_check(elise.mode == HumanNpc.Mode.FLEEING, "transforming in front of someone terrifies them")
	_set_time(12.0)
	player.form.set_form_immediate(&"human")
	_place(Vector3(-24.0, 0.0, 12.0), 0.0)
	await _wait(0.5)
	player.form.request_form(&"vampire")
	await _wait(0.7)
	_check(elise.mode == HumanNpc.Mode.CALM, "transforming out of sight (a wall between) is safe")
	await _wait(0.6)

	print("[SCENARIO] --- SENSE: INFORMATION DEPENDS ON DISTANCE ---")
	_set_time(12.0)
	tomas.known = false
	var far: Dictionary = tomas.get_sense_data(25.0)
	var mid: Dictionary = tomas.get_sense_data(15.0)
	var near: Dictionary = tomas.get_sense_data(9.0)
	var close: Dictionary = tomas.get_sense_data(4.0)
	_check(far["label"] == "" and far["bpm"] > 0.0, "far: only a pulse, no text")
	_check(String(mid["label"]).contains("heartbeat") and not String(mid["label"]).contains("Tomas"), "mid: 'a heartbeat' and its rate: %s" % mid["label"])
	_check(String(near["label"]).contains("stranger") and not String(near["label"]).contains("smoky"), "near: an unknown stranger's mood, no blood yet")
	_check(String(close["label"]).contains("Aged and smoky"), "close: the blood itself")
	_check(absf(float(tomas.get_feed_result()["yield"]) - 45.0 * 1.15) < 0.01 and tomas.get_feed_result()["blood_type"] == "Aged", "blood type shapes the yield (Aged x1.15 = %.1f)" % float(tomas.get_feed_result()["yield"]))
	_check((tomas.get_sense_data(4.0)["color"] as Color).is_equal_approx(ContentRegistry.get_def(&"BloodDefinition", &"aged").sense_color), "Sense colours a calm person by their blood type")
	tomas.known = true
	_check(String(tomas.get_sense_data(9.0)["label"]).contains("Tomas Reeve"), "once you know someone, Sense shows their name")
	HumanNpc.schedules_enabled = true
	_set_time(22.0)
	var sleeping: Dictionary = tomas.get_sense_data(4.0)
	_check(tomas.mode == HumanNpc.Mode.SLEEPING and sleeping["bpm"] < tomas.profile.base_heart_rate * 0.7 and (sleeping["color"] as Color).b > 0.8, "sleepers have a slow, blue heartbeat (%.0f bpm)" % sleeping["bpm"])
	_check(sense.sense_range == 28.0 and sense.ability_id == &"vampiric_sense", "the ability was built from its AbilityDefinition resource")

	print("[SCENARIO] --- SENSE: EMBERS SHOW WHERE THE SUN BITES (daytime only) ---")
	main.tod.set_hour(10.0)
	player.form.set_form_immediate(&"vampire")
	_place(Vector3(3.0, 0.0, 12.0), 0.0)
	await get_tree().physics_frame
	sense._embers.refresh(player.global_position, player.sunlight.to_sun(), player.sunlight.sun_intensity())
	var lit := 0
	for i in SenseEmbers.GRID * SenseEmbers.GRID:
		if sense._embers.tile_alpha[i] > 0.05:
			lit += 1
	_check(lit > 20, "in the open by day many tiles smoulder (%d)" % lit)
	_place(Vector3(-5.0, 0.0, -10.0), 0.0)
	await get_tree().physics_frame
	sense._embers.refresh(player.global_position, player.sunlight.to_sun(), player.sunlight.sun_intensity())
	var centre := SenseEmbers.GRID / 2 * SenseEmbers.GRID + SenseEmbers.GRID / 2
	_check(sense._embers.tile_alpha[centre] < 0.01, "under the crypt roof the ground under you is dark")
	main.tod.set_hour(0.0)
	sense._embers.refresh(player.global_position, player.sunlight.to_sun(), player.sunlight.sun_intensity())
	var night_lit := 0
	for i in SenseEmbers.GRID * SenseEmbers.GRID:
		if sense._embers.tile_alpha[i] > 0.01:
			night_lit += 1
	_check(night_lit == 0, "at night there are no embers")

	print("[SCENARIO] --- NIGHT VS DAY FOR A VAMPIRE ---")
	main.tod.set_hour(0.0)
	_place(Vector3(14.0, 0.0, 5.0), 0.0)
	player.sunlight.reset()
	await _wait(4.0)
	_check(player.sunlight.model.heat == 0.0 and player.health.value >= 99.9 and player.sunlight.stage == 0, "midnight in the open yard: perfectly safe")
	await _shot("s4_night_yard")
	main.tod.set_hour(12.0)
	await _wait(4.0)
	_check(player.sunlight.strength > 0.5 and player.sunlight.model.heat > 2.0, "noon in the same spot: heat builds (heat %.1f)" % player.sunlight.model.heat)
	main.tod.set_hour(0.0)
	await _wait(0.5)
	main.hud._update_clock()
	_check(main.hud.clock_summary().contains("Sunrise in") and main.hud.clock_summary().contains("Night"), "the HUD counts down to sunrise: %s" % main.hud.clock_summary().replace("\n", " | "))

	print("[SCENARIO] --- HUMAN VS VAMPIRE VISION AT NIGHT ---")
	player.form.set_form_immediate(&"human")
	await _wait(1.2)
	var human_ambient := main.atmosphere._env.ambient_light_energy
	player.form.set_form_immediate(&"vampire")
	await _wait(1.2)
	var vamp_ambient := main.atmosphere._env.ambient_light_energy
	_check(vamp_ambient > human_ambient * 4.0, "at night the vampire sees far better (ambient %.2f vs human %.2f)" % [vamp_ambient, human_ambient])
	await _shot("s5_vampire_night_vision")
	player.form.set_form_immediate(&"human")
	await _wait(1.2)
	await _shot("s6_human_night")

	print("[SCENARIO] --- COFFIN SLEEP SKIPS TO DUSK ---")
	main.tod.set_hour(10.0)
	player.form.set_form_immediate(&"vampire")
	_place(Vector3(-4.0, 0.0, -11.0), -60.0)
	var day0 := main.tod.day_count
	world.coffin.wake(player, &"rest")
	await _wait(6.5)
	_check(absf(main.tod.hour - 19.0) < 0.3 and main.tod.day_count == day0, "sleeping by day wakes you at dusk (%s)" % main.tod.clock_text())
	_check(player.state.mode == PlayerState.Mode.NORMAL and player.form.is_form(&"human"), "you wake as Human, in control")
	main.tod.set_hour(22.0)
	day0 = main.tod.day_count
	world.coffin.wake(player, &"rest")
	await _wait(6.5)
	_check(main.tod.day_count == day0 + 1 and absf(main.tod.hour - 19.0) < 0.3, "sleeping at night skips to the NEXT dusk (day %d)" % (main.tod.day_count + 1))
	HumanNpc.schedules_enabled = true
	get_tree().call_group(&"npcs", &"new_day")
	await _wait(0.5)
	_check(tomas.mode == HumanNpc.Mode.CALM and tomas.global_position.z > 5.0, "the world is on its dusk routine after sleeping")

	print("[SCENARIO] --- SHOWCASE (screenshots only) ---")
	HumanNpc.schedules_enabled = true
	_set_time(22.0)
	player.form.set_form_immediate(&"vampire")
	_place(Vector3(-10.0, 0.0, 6.5), 90.0)
	await _tap(&"vampiric_sense")
	await _wait(3.0)
	await _shot("s7_night_sense_far")
	_place(Vector3(-14.0, 0.0, 5.5), 90.0)
	await _wait(1.0)
	await _shot("s8_night_sense_near")
	await _tap(&"vampiric_sense")
