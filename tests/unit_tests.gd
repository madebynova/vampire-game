extends Node
## Fast logic tests that need no player/world: time of day, day/night profile, sunlight model,
## content registry (including a generated mod). Run headless:
##   godot --headless --path . res://tests/unit_tests.tscn

var checks := 0
var failures := 0


func _ready() -> void:
	GameSettings.persist = false     # tests never touch the player's real settings file
	_test_time_of_day()
	_test_clock_12h()
	_test_blood_tuning()
	_test_input_map()
	_test_no_hardcoded_devices()
	_test_feed_styles_and_content()
	_test_traversal_math()
	_test_settings_and_audio()
	_test_feed_style_mod()
	_test_blood_gauge_polygons()
	_test_profile_sampling()
	_test_sunlight_model()
	_test_registry()
	_test_mod_override()
	_test_example_mod()
	print("[UNIT] ===== %d checks, %d failures =====" % [checks, failures])
	get_tree().quit(1 if failures > 0 else 0)


func _check(cond: bool, msg: String) -> void:
	checks += 1
	if cond:
		print("[UNIT] PASS  ", msg)
	else:
		failures += 1
		print("[UNIT] FAIL  ", msg)


func _approx(a: float, b: float, tol := 0.01) -> bool:
	return absf(a - b) <= tol


func _make_tod(hour: float) -> TimeOfDay:
	var t := TimeOfDay.new()
	t.start_hour = hour
	add_child(t)
	t.paused = true
	return t


# ---------------------------------------------------------------- day / night

func _test_time_of_day() -> void:
	print("[UNIT] --- day/night: sun path ---")
	var t := _make_tod(6.0)
	_check(_approx(t.sun_elevation_degrees(), 0.0, 0.5), "sunrise (06:00): sun on the horizon (%.2f deg)" % t.sun_elevation_degrees())
	_check(t.sun_direction().x > 0.99, "sunrise is in the east (x=%.2f)" % t.sun_direction().x)
	t.set_hour(12.0)
	_check(_approx(t.sun_elevation_degrees(), t.max_sun_elevation_degrees, 0.5), "noon: sun at its maximum (%.1f deg)" % t.sun_elevation_degrees())
	_check(t.sun_direction().z < -0.5, "noon sun is in the northern sky (z=%.2f)" % t.sun_direction().z)
	t.set_hour(18.0)
	_check(_approx(t.sun_elevation_degrees(), 0.0, 0.5), "sunset (18:00): sun on the horizon")
	_check(t.sun_direction().x < -0.99, "sunset is in the west")
	t.set_hour(0.0)
	_check(t.sun_elevation_degrees() < -40.0, "midnight: sun far below the horizon (%.1f deg)" % t.sun_elevation_degrees())
	_check(_approx(t.moon_elevation_degrees(), -t.sun_elevation_degrees(), 0.01), "moon is opposite the sun (moon %.1f deg)" % t.moon_elevation_degrees())
	var unit_ok := true
	for h in range(0, 24):
		t.set_hour(float(h))
		unit_ok = unit_ok and _approx(t.sun_direction().length(), 1.0, 0.001)
	_check(unit_ok, "sun direction is a unit vector at every hour")

	print("[UNIT] --- day/night: strength & darkness ---")
	t.set_hour(12.0)
	_check(_approx(t.sun_strength(), 1.0, 0.001) and _approx(t.darkness(), 0.0, 0.001), "noon: full sun strength, zero darkness")
	t.set_hour(0.0)
	_check(_approx(t.sun_strength(), 0.0, 0.001) and _approx(t.darkness(), 1.0, 0.001), "midnight: zero sun strength, full darkness")
	t.set_hour(21.0)
	_check(t.sun_strength() == 0.0, "no sunlight after dark (21:00)")
	var last := -1.0
	var mono := true
	for i in range(0, 61):
		t.set_hour(15.0 + i * 0.1)  # 15:00 -> 21:00
		var d := t.darkness()
		if d < last - 0.0001:
			mono = false
		last = d
	_check(mono, "darkness only increases from 15:00 to 21:00")

	print("[UNIT] --- day/night: phases ---")
	var expect := {3.0: TimeOfDay.NIGHT, 5.75: TimeOfDay.DAWN, 6.0: TimeOfDay.DAWN, 12.0: TimeOfDay.DAY, 17.9: TimeOfDay.DUSK, 18.0: TimeOfDay.DUSK, 22.0: TimeOfDay.NIGHT, 0.0: TimeOfDay.NIGHT}
	for h in expect:
		t.set_hour(h)
		_check(t.phase() == expect[h], "%05.2f is %s (got %s)" % [h, expect[h], t.phase()])

	print("[UNIT] --- day/night: transitions ---")
	var phases: Array[StringName] = []
	t.phase_changed.connect(func(n, _o): phases.append(n))
	t.set_hour(12.0)
	phases.clear()
	# Advance 14 game-hours in small steps: day -> dusk -> night.
	for i in 140:
		t.advance_hours(0.1)
	_check(phases == [TimeOfDay.DUSK, TimeOfDay.NIGHT], "12:00 -> 02:00 passes through dusk then night (%s)" % str(phases))
	phases.clear()
	for i in 80:
		t.advance_hours(0.1)  # -> 10:00
	_check(phases == [TimeOfDay.DAWN, TimeOfDay.DAY], "then dawn then day (%s)" % str(phases))

	print("[UNIT] --- day/night: clock ---")
	t.set_hour(20.0)
	var d0 := t.day_count
	t.advance_hours(5.0)
	_check(_approx(t.hour, 1.0, 0.001) and t.day_count == d0 + 1, "advancing past midnight wraps the clock and counts a day (%.2f, day+%d)" % [t.hour, t.day_count - d0])
	t.set_hour(10.0)
	t.day_length_seconds = 100.0
	t.paused = false
	t._process(50.0)  # half a day
	_check(_approx(t.hour, 22.0, 0.001), "day_length_seconds drives the clock (50/100 s = 12 h: %.2f)" % t.hour)
	t.paused = true
	t.skip_to(19.0)
	_check(_approx(t.hour, 19.0, 0.001), "skip_to jumps to a target hour (sleeping)")
	t.set_hour(10.0)
	_check(_approx(t.hours_until(19.0), 9.0, 0.001) and _approx(t.hours_until(8.0), 22.0, 0.001), "hours_until handles wrap-around")
	t.sun_override = Vector3(0, 1, 0)
	_check(_approx(t.sun_elevation_degrees(), 90.0, 0.01), "sun_override pins the sun (debug hook)")
	t.queue_free()


func _test_profile_sampling() -> void:
	print("[UNIT] --- day/night profile ---")
	var p := ContentRegistry.get_def(&"DayNightProfile", &"default") as DayNightProfile
	_check(p != null, "default DayNightProfile is registered")
	var noon := p.sample(12.0)
	var night := p.sample(0.0)
	_check((noon["sky_top"] as Color).b > (night["sky_top"] as Color).b, "noon sky is brighter than midnight sky")
	_check(float(noon["star_strength"]) == 0.0 and float(night["star_strength"]) == 1.0, "stars only at night")
	_check(float(night["ambient_energy"]) < float(noon["ambient_energy"]), "night ambient is darker than day ambient")
	var a := p.sample(0.0)
	var b := p.sample(23.999)
	_check(_approx(float(a["ambient_energy"]), float(b["ambient_energy"]), 0.001), "profile wraps smoothly at midnight")
	var mid := p.sample(3.0)
	_check(float(mid["moon_energy"]) > 0.0, "moonlight present at 03:00")


# ---------------------------------------------------------------- sunlight

func _test_sunlight_model() -> void:
	print("[UNIT] --- sunlight model ---")
	var profile := ContentRegistry.get_def(&"SunlightProfile", &"default") as SunlightProfile
	_check(profile != null, "default SunlightProfile is registered")
	if profile == null:
		return
	# Full exposure until death (100 hp, 0.05 s steps).
	var m := SunlightModel.new(profile)
	var hp := 100.0
	var t := 0.0
	var stages_seen: Array[int] = []
	while hp > 0.0 and t < 600.0:
		hp -= m.step(0.05, 1.0)
		t += 0.05
		if not stages_seen.has(m.stage):
			stages_seen.append(m.stage)
	_check(t > 165.0 and t < 195.0, "full sun kills in about three minutes (%.0f s)" % t)
	_check(stages_seen == [1, 2, 3, 4], "stages escalate 1->2->3->4 in order (%s)" % str(stages_seen))

	# Half exposure roughly doubles survival.
	m = SunlightModel.new(profile)
	hp = 100.0
	t = 0.0
	while hp > 0.0 and t < 1200.0:
		hp -= m.step(0.1, 0.5)
		t += 0.1
	_check(t > 2.0 * 165.0 and t < 2.0 * 200.0, "half exposure lasts about twice as long (%.0f s)" % t)

	# Resistance (strength multiplier) scales survival.
	m = SunlightModel.new(profile)
	hp = 100.0
	t = 0.0
	while hp > 0.0 and t < 2000.0:
		hp -= m.step(0.1, 1.0 * 0.25)
		t += 0.1
	_check(t > 4.0 * 165.0, "75%% resistance lasts over four times as long (%.0f s)" % t)

	# Early exposure is a warning, not damage.
	m = SunlightModel.new(profile)
	var early := 0.0
	for i in 140:
		early += m.step(0.05, 1.0)  # 7 s
	_check(early < 0.5 and m.stage == 1, "first ~7 s: warning only, no meaningful damage (%.2f hp, stage %d)" % [early, m.stage])
	# Shade cools it down.
	for i in 400:
		m.step(0.05, 0.0)  # 20 s
	_check(m.heat < 0.001 or m.stage == 0, "20 s in shade fully cools a 7 s exposure (heat %.2f)" % m.heat)
	# Stage 0 with no heat and no light.
	m = SunlightModel.new(profile)
	m.step(0.1, 0.0)
	_check(m.stage == 0, "shade with no heat is Safe")
	# Damage needs light: smouldering heat alone does no damage.
	m = SunlightModel.new(profile)
	for i in 1500:
		m.step(0.1, 1.0)  # 150 s => critical heat
	var smoulder := m.step(1.0, 0.0)
	_check(smoulder == 0.0 and m.stage >= 3, "after leaving the light, heat lingers (stage %d) but deals no damage" % m.stage)
	_check(m.speed_multiplier() < 1.0, "lingering critical heat still slows you (x%.2f)" % m.speed_multiplier())
	_check(m.seconds_to_death(50.0, 1.0) > 0.0 and m.seconds_to_death(50.0, 1.0) < 60.0, "critical heat, 50 hp: estimate is short (%.0f s)" % m.seconds_to_death(50.0, 1.0))


# ---------------------------------------------------------------- content registry

func _test_registry() -> void:
	print("[UNIT] --- content registry ---")
	_check(ContentRegistry.form(&"human") != null and ContentRegistry.form(&"vampire") != null, "core forms load")
	_check(ContentRegistry.get_def(&"AbilityDefinition", &"vampiric_sense") != null, "vampiric_sense ability definition loads")
	var sense := ContentRegistry.get_def(&"AbilityDefinition", &"vampiric_sense") as AbilityDefinition
	_check(sense.behavior != null and sense.parameters.has("sense_range"), "ability data carries behavior script + tunables")
	_check(ContentRegistry.npc(&"tomas") != null and ContentRegistry.npc(&"elise") != null, "core NPCs load")
	var tomas := ContentRegistry.npc(&"tomas")
	_check(tomas.memories.size() == 3 and tomas.memory_for(&"asleep").title == "A Dream of Ink", "NPC blood memories are data (asleep variant)")
	_check(tomas.memory_for(&"nonsense") != null, "unknown condition falls back to a memory")
	_check(not tomas.schedule.is_empty() and tomas.schedule_for(12.0).activity == &"patrol" and tomas.schedule_for(23.0).activity == &"sleep", "NPC schedule is data (noon patrol, 23:00 asleep)")
	_check(tomas.schedule_for(3.0) != null, "schedule entries wrap past midnight")
	_check(ContentRegistry.get_def(&"LocationData", &"blackthorn") != null, "location data loads")
	_check(ContentRegistry.list(&"FormData").size() >= 2, "list() returns registered forms")


func _test_mod_override() -> void:
	print("[UNIT] --- mod content ---")
	var base := "user://mods/unit_test_mod/content/forms"
	DirAccess.make_dir_recursive_absolute(base)
	var extra := FormData.new()
	extra.id = &"unit_test_form"
	extra.display_name = "Test Form"
	extra.walk_speed = 9.0
	ResourceSaver.save(extra, base + "/unit_test_form.tres")
	var override := FormData.new()
	override.id = &"human"
	override.display_name = "Overridden Human"
	ResourceSaver.save(override, base + "/human_override.tres")
	ContentRegistry.reload()
	_check(ContentRegistry.mods.has("unit_test_mod"), "registry discovers a mod folder in user://mods")
	var f := ContentRegistry.form(&"unit_test_form")
	_check(f != null and f.walk_speed == 9.0 and f.source == "unit_test_mod", "mod adds new content (source tracked)")
	_check(ContentRegistry.form(&"human").display_name == "Overridden Human", "mod content with a core id replaces it")
	_check(ContentRegistry.form(&"vampire").source == "core", "untouched content stays core")
	# Clean up and restore core.
	DirAccess.remove_absolute(base + "/unit_test_form.tres")
	DirAccess.remove_absolute(base + "/human_override.tres")
	DirAccess.remove_absolute(base)
	DirAccess.remove_absolute("user://mods/unit_test_mod/content")
	DirAccess.remove_absolute("user://mods/unit_test_mod")
	ContentRegistry.reload()
	_check(ContentRegistry.form(&"human").display_name == "Human" and ContentRegistry.form(&"unit_test_form") == null, "removing the mod restores core content")


func _test_example_mod() -> void:
	print("[UNIT] --- example mod (examples/example_mod) ---")
	var blood := ContentRegistry.get_def(&"BloodDefinition", &"aged") as BloodDefinition
	_check(blood != null and blood.yield_multiplier > 1.0, "core blood definitions load (aged x%.2f)" % (blood.yield_multiplier if blood else 0.0))
	_check(ContentRegistry.npc(&"tomas").blood_definition().id == &"aged", "NPC profiles reference blood by id")
	var core := ContentRegistry.get_def(&"SunlightProfile", &"default") as SunlightProfile
	var core_t := _survival_seconds(core)
	_copy_dir("res://examples/example_mod", "user://mods/example_mod")
	ContentRegistry.reload()
	_check(ContentRegistry.mods.has("example_mod") and ContentRegistry.mod_info["example_mod"]["name"] == "Gentle Sun", "mod.cfg manifest is read (%s)" % str(ContentRegistry.mod_info.get("example_mod", {}).get("name", "?")))
	_check(ContentRegistry.get_def(&"BloodDefinition", &"sweet") != null, "the mod added a new blood type")
	var modded := ContentRegistry.get_def(&"SunlightProfile", &"default") as SunlightProfile
	_check(modded.source == "example_mod", "the mod replaced the core sunlight profile")
	var mod_t := _survival_seconds(modded)
	_check(mod_t > core_t * 1.8 and mod_t < core_t * 2.2, "gentle sun roughly doubles survival (%.0f s -> %.0f s)" % [core_t, mod_t])
	_remove_dir("user://mods/example_mod")
	ContentRegistry.reload()
	_check(not ContentRegistry.mods.has("example_mod") and ContentRegistry.get_def(&"BloodDefinition", &"sweet") == null, "removing the mod removes its content")
	_check(_approx(_survival_seconds(ContentRegistry.get_def(&"SunlightProfile", &"default")), core_t, 1.0), "core sunlight is restored")


func _survival_seconds(profile: SunlightProfile) -> float:
	var m := SunlightModel.new(profile)
	var hp := 100.0
	var t := 0.0
	while hp > 0.0 and t < 3000.0:
		hp -= m.step(0.1, 1.0)
		t += 0.1
	return t


func _copy_dir(src: String, dst: String) -> void:
	DirAccess.make_dir_recursive_absolute(dst)
	var d := DirAccess.open(src)
	for sub_dir in d.get_directories():
		_copy_dir("%s/%s" % [src, sub_dir], "%s/%s" % [dst, sub_dir])
	for f in d.get_files():
		var name := f.trim_suffix(".remap")
		var data := FileAccess.get_file_as_bytes("%s/%s" % [src, name])
		var out := FileAccess.open("%s/%s" % [dst, name], FileAccess.WRITE)
		out.store_buffer(data)
		out.close()


func _remove_dir(path: String) -> void:
	var d := DirAccess.open(path)
	if d == null:
		return
	for sub_dir in d.get_directories():
		_remove_dir("%s/%s" % [path, sub_dir])
	for f in d.get_files():
		DirAccess.remove_absolute("%s/%s" % [path, f])
	DirAccess.remove_absolute(path)


# ---------------------------------------------------------------- Task 1.75: pure logic

func _test_clock_12h() -> void:
	print("[UNIT] --- 12-hour clock (display only) ---")
	var cases := {
		0.0: "12:00 AM", 0.5: "12:30 AM", 1.0: "1:00 AM", 9.25: "9:15 AM", 11.99: "11:59 AM",
		12.0: "12:00 PM", 12.5: "12:30 PM", 13.25: "1:15 PM", 17.72: "5:43 PM", 23.0: "11:00 PM",
		23.99: "11:59 PM", 24.0: "12:00 AM", -1.0: "11:00 PM",
	}
	for h in cases:
		_check(TimeOfDay.format_12h(h) == cases[h], "%.2f -> %s (got %s)" % [h, cases[h], TimeOfDay.format_12h(h)])
	var t := _make_tod(17.72)
	_check(t.clock_text_12h() == "5:43 PM", "TimeOfDay.clock_text_12h follows the clock: %s" % t.clock_text_12h())
	_check(t.clock_text() == "17:43" and _approx(t.hour, 17.72, 0.001), "the simulation still runs on 24-hour time (%s, hour %.2f)" % [t.clock_text(), t.hour])
	t.set_hour(0.0)
	_check(t.clock_text_12h() == "12:00 AM" and t.clock_text() == "00:00", "midnight is 12:00 AM (internal 00:00)")
	t.set_hour(12.0)
	_check(t.clock_text_12h() == "12:00 PM", "noon is 12:00 PM")
	t.queue_free()


func _test_blood_tuning() -> void:
	print("[UNIT] --- blood: Human slow, Vampire faster, Sense usable ---")
	var human := ContentRegistry.form(&"human")
	var vamp := ContentRegistry.form(&"vampire")
	_check(human.blood_drain_per_sec > 0.0 and human.blood_drain_per_sec <= 0.05, "Human blood drains, but very slowly (%.3f/s)" % human.blood_drain_per_sec)
	_check(vamp.blood_drain_per_sec >= 0.1 and vamp.blood_drain_per_sec >= human.blood_drain_per_sec * 4.0, "Vampire blood drains clearly faster (%.3f/s vs %.3f/s)" % [vamp.blood_drain_per_sec, human.blood_drain_per_sec])
	var minutes_full := 100.0 / vamp.blood_drain_per_sec / 60.0
	_check(minutes_full >= 7.0, "a full vessel lasts a vampire %.1f minutes at rest: background pressure, not a chore" % minutes_full)
	_check(not human.hunger_slows and vamp.hunger_slows, "hunger slows the Vampire only")
	var sense := ContentRegistry.get_def(&"AbilityDefinition", &"vampiric_sense") as AbilityDefinition
	_check(sense.blood_cost_per_sec >= 0.3 and sense.blood_cost_per_sec <= 0.8, "Sense costs blood but is tuned down from 1.4/s (%.2f/s)" % sense.blood_cost_per_sec)
	_check(sense.activation_cost > 0.0 and sense.activation_cost <= 4.0, "switching Sense on has a small up-front price (%.1f)" % sense.activation_cost)
	var seconds := 55.0 / (sense.blood_cost_per_sec + vamp.blood_drain_per_sec)
	_check(seconds >= 60.0, "from the starting 55 blood a player can sense for over a minute (%.0f s)" % seconds)


func _test_input_map() -> void:
	print("[UNIT] --- input map: controller-first, named actions ---")
	for a in InputSetup.GAMEPLAY_ACTIONS:
		_check(InputMap.has_action(a) and InputMap.action_get_events(a).size() > 0, "action %s is registered with bindings" % a)
	var pad_needed: Array[StringName] = [&"move_forward", &"move_back", &"move_left", &"move_right", &"look_up", &"look_down",
		&"look_left", &"look_right", &"sprint", &"sprint_toggle", &"jump", &"interact", &"feed", &"transform", &"vampiric_sense",
		&"pause", &"toggle_help", &"memory_dismiss"]
	for a in pad_needed:
		var has_pad := false
		for ev in InputMap.action_get_events(a):
			if ev is InputEventJoypadButton or ev is InputEventJoypadMotion:
				has_pad = true
		_check(has_pad, "%s works without a keyboard (pad binding)" % a)
	var key_needed: Array[StringName] = [&"move_forward", &"move_back", &"move_left", &"move_right", &"sprint", &"jump", &"interact", &"feed",
		&"transform", &"vampiric_sense", &"pause", &"toggle_help", &"memory_dismiss"]
	for a in key_needed:
		var has_key := false
		for ev in InputMap.action_get_events(a):
			if ev is InputEventKey:
				has_key = true
		_check(has_key, "%s still works on the keyboard" % a)
	for a in [&"ui_accept", &"ui_cancel", &"ui_up", &"ui_down", &"ui_left", &"ui_right"]:
		var has_pad_ui := false
		for ev in InputMap.action_get_events(a):
			if ev is InputEventJoypadButton or ev is InputEventJoypadMotion:
				has_pad_ui = true
		_check(has_pad_ui, "menu action %s is navigable with a pad (A accepts, B backs out, D-pad / stick move)" % a)
	var all_devices := true
	for a in InputSetup.GAMEPLAY_ACTIONS:
		for ev in InputMap.action_get_events(a):
			if ev.device != -1:
				all_devices = false
	_check(all_devices, "every binding matches ANY connected device (second pad, hot-swap)")
	_check(InputSetup.classify_joypad("Xbox Wireless Controller") == InputSetup.XBOX, "an Xbox pad is Xbox-style")
	_check(InputSetup.classify_joypad("XInput Gamepad") == InputSetup.XBOX, "an XInput pad is Xbox-style")
	_check(InputSetup.classify_joypad("GameSir G7 SE") == InputSetup.XBOX, "an unknown Xbox-layout pad falls back to Xbox-style with no special casing")
	_check(InputSetup.classify_joypad("PS5 Controller") == InputSetup.PLAYSTATION, "a PS5 pad is PlayStation-style")
	_check(InputSetup.classify_joypad("DualSense Wireless Controller") == InputSetup.PLAYSTATION, "a DualSense is PlayStation-style")
	var expect := {
		[&"interact", InputSetup.XBOX]: "X", [&"transform", InputSetup.XBOX]: "Y", [&"jump", InputSetup.XBOX]: "A",
		[&"vampiric_sense", InputSetup.XBOX]: "LB", [&"pause", InputSetup.XBOX]: "Menu", [&"toggle_help", InputSetup.XBOX]: "View",
		[&"interact", InputSetup.PLAYSTATION]: "Square", [&"transform", InputSetup.PLAYSTATION]: "Triangle", [&"jump", InputSetup.PLAYSTATION]: "Cross",
		[&"vampiric_sense", InputSetup.PLAYSTATION]: "L1", [&"pause", InputSetup.PLAYSTATION]: "Options",
		[&"interact", InputSetup.KEYBOARD]: "E", [&"transform", InputSetup.KEYBOARD]: "F", [&"vampiric_sense", InputSetup.KEYBOARD]: "Q",
		[&"pause", InputSetup.KEYBOARD]: "Esc", [&"sprint", InputSetup.KEYBOARD]: "Shift",
	}
	for k in expect:
		_check(InputSetup.prompt_text(k[0], k[1]) == expect[k], "%s on %s is %s (got %s)" % [k[0], k[1], expect[k], InputSetup.prompt_text(k[0], k[1])])
	_check(InputSetup.prompt_text(&"sprint", InputSetup.XBOX) == "RT", "run is on the right trigger (hold), L3 latches it")
	var latch := InputSetup.bindings_for(&"sprint_toggle", InputSetup.XBOX)
	_check(not latch.is_empty() and latch[0]["text"] == "L3", "left-stick click is the run latch")
	_check(InputSetup.prompt_text(&"no_such_action", InputSetup.XBOX) == "?", "an unknown action degrades to a question mark instead of crashing")
	var before := InputSetup.device_kind
	InputSetup.set_device_kind(InputSetup.PLAYSTATION)
	_check(InputSetup.prompt_text(&"interact") == "Square", "prompts follow the last-used device (PlayStation)")
	InputSetup.set_device_kind(InputSetup.KEYBOARD)
	_check(InputSetup.prompt_text(&"interact") == "E", "...and switch back to the keyboard")
	InputSetup.set_device_kind(before)


func _script_files(path: String, out: Array) -> void:
	var d := DirAccess.open(path)
	if d == null:
		return
	for sub in d.get_directories():
		_script_files("%s/%s" % [path, sub], out)
	for f in d.get_files():
		if f.ends_with(".gd"):
			out.append("%s/%s" % [path, f])


func _test_no_hardcoded_devices() -> void:
	print("[UNIT] --- gameplay reads actions, never devices or keycodes ---")
	var files: Array = []
	_script_files("res://scripts", files)
	var device_hits: Array[String] = []
	var key_hits: Array[String] = []
	for f in files:
		var text := FileAccess.get_file_as_string(f)
		if text.to_lower().contains("gamesir"):
			device_hits.append(f)
		if f.ends_with("input_setup.gd"):
			continue
		for needle in ["keycode ==", "KEY_", "JOY_BUTTON_", "JOY_AXIS_", "event.keycode"]:
			if text.contains(needle):
				key_hits.append("%s (%s)" % [f, needle])
	_check(device_hits.is_empty(), "no script names a specific controller model (%d files scanned) %s" % [files.size(), str(device_hits)])
	_check(key_hits.is_empty(), "no gameplay script hard-codes keys or pad buttons outside InputSetup %s" % str(key_hits))


func _test_feed_styles_and_content() -> void:
	print("[UNIT] --- Task 1.75 content is data ---")
	for id in [&"calm", &"asleep", &"afraid", &"trusting"]:
		var st := ContentRegistry.get_def(&"FeedStyle", id) as FeedStyle
		_check(st != null and st.id == id, "FeedStyle %s is data under content/feeding" % id)
	var calm := ContentRegistry.get_def(&"FeedStyle", &"calm") as FeedStyle
	var asleep := ContentRegistry.get_def(&"FeedStyle", &"asleep") as FeedStyle
	var afraid := ContentRegistry.get_def(&"FeedStyle", &"afraid") as FeedStyle
	_check(afraid.noise_radius > 0.0 and calm.noise_radius == 0.0 and asleep.noise_radius == 0.0, "only a terrified victim carries a scream")
	_check(asleep.feed_volume_db < calm.feed_volume_db and calm.feed_volume_db < afraid.feed_volume_db, "sleepers are fed on quietly, screamers loudly (%.0f < %.0f < %.0f dB)" % [asleep.feed_volume_db, calm.feed_volume_db, afraid.feed_volume_db])
	_check(afraid.yield_multiplier > calm.yield_multiplier and afraid.surge_power > calm.surge_power and afraid.surge_seconds < calm.surge_seconds, "fear pays more, hotter and shorter")
	_check(asleep.surge_seconds > calm.surge_seconds and asleep.memory_pace < calm.memory_pace, "dreams last longer and are told slowly")
	_check(afraid.memory_fragmentation > calm.memory_fragmentation and afraid.memory_tint != calm.memory_tint, "a frightened memory looks different: fragmented, its own colour")
	_check(ContentRegistry.get_def(&"BloodDefinition", &"iron") != null and ContentRegistry.npc(&"corvin") != null, "the night watchman and his iron blood load from content")
	var corvin := ContentRegistry.npc(&"corvin")
	_check(corvin.memories.size() == 3 and corvin.memory_for(&"asleep").title == "The Long Road", "Corvin has calm / asleep / afraid blood memories")
	for p in [ContentRegistry.npc(&"tomas"), ContentRegistry.npc(&"elise"), corvin]:
		var covered := true
		var h := 0.0
		while h < 24.0:
			covered = covered and p.schedule_for(h) != null
			h += 0.25
		_check(covered, "%s has a routine for every hour of the day" % p.display_name)
	var vamp := ContentRegistry.form(&"vampire")
	var human := ContentRegistry.form(&"human")
	_check(vamp.traversal.has("window") and vamp.traversal.has("climb") and human.traversal.is_empty(), "the Vampire can slip through windows and climb; the Human cannot (FormData.traversal)")
	var loc := ContentRegistry.get_def(&"LocationData", &"blackthorn") as LocationData
	var types := {}
	for tr in loc.traversals:
		types[tr.type] = true
	_check(loc.traversals.size() >= 5 and types.has(TraversalPlacement.Type.WINDOW) and types.has(TraversalPlacement.Type.CLIMB), "the location lists windows and climbs as data (%d routes)" % loc.traversals.size())


func _test_traversal_math() -> void:
	print("[UNIT] --- traversal paths ---")
	var loc := ContentRegistry.get_def(&"LocationData", &"blackthorn") as LocationData
	for p in loc.traversals:
		var ends_ok := true
		var continuous := true
		for from_end in [0, 1]:
			var s := TraversalController.sample(p, from_end, 0.0)
			var e := TraversalController.sample(p, from_end, 1.0)
			ends_ok = ends_ok and s.distance_to(p.end_position(from_end)) < 0.001 and e.distance_to(p.end_position(1 - from_end)) < 0.001
			var prev := s
			for i in range(1, 101):
				var q := TraversalController.sample(p, from_end, i / 100.0)
				continuous = continuous and q.distance_to(prev) < 0.45
				prev = q
		_check(ends_ok, "%s runs exactly from one end to the other, both ways" % p.id)
		_check(continuous, "%s moves in small steps (no teleport through geometry)" % p.id)
		_check(p.prompt_a != "" and p.prompt_b != "" and p.end_position(0).distance_to(p.end_position(1)) > 1.5, "%s has prompts for both ends and real length" % p.id)
		_check(TraversalController.route_duration(p) >= 0.7 and TraversalController.route_duration(p) <= 2.0, "%s takes %.2f s: quick, not a cutscene" % [p.id, TraversalController.route_duration(p)])
		if p.type == TraversalPlacement.Type.CLIMB:
			var lo := minf(p.a.y, p.b.y)
			var never_below := true
			for i in range(0, 101):
				never_below = never_below and TraversalController.sample(p, 0 if p.a.y < p.b.y else 1, i / 100.0).y >= lo - 0.01
			_check(never_below and absf(p.a.y - p.b.y) > 1.5, "%s climbs %.1f m and never dips below the ground" % [p.id, absf(p.a.y - p.b.y)])


func _test_settings_and_audio() -> void:
	print("[UNIT] --- settings and audio buses ---")
	_check(AudioServer.get_bus_index(AudioBuses.EFFECTS) != -1 and AudioServer.get_bus_index(AudioBuses.AMBIENCE) != -1 and AudioServer.get_bus_index(AudioBuses.MUSIC) != -1, "Effects / Ambience / Music buses exist")
	AudioBuses.set_muffle(AudioBuses.AMBIENCE, 1.0)
	_check(AudioBuses.muffle_of(AudioBuses.AMBIENCE) > 0.95, "muffling the world closes the low-pass")
	AudioBuses.set_muffle(AudioBuses.AMBIENCE, 0.0)
	_check(AudioBuses.muffle_of(AudioBuses.AMBIENCE) == 0.0, "...and opens it again (effect disabled: no CPU cost)")
	GameSettings.set_option(&"effects_volume", 0.5)
	_check(absf(AudioServer.get_bus_volume_db(AudioServer.get_bus_index(AudioBuses.EFFECTS)) - linear_to_db(0.5)) < 0.05, "the Effects slider sets the bus volume")
	var pulses := Haptics.pulse_count
	GameSettings.set_option(&"vibration", false)
	Haptics.pulse(1.0, 1.0, 0.1)
	_check(Haptics.pulse_count == pulses, "vibration off: no pulse is sent")
	GameSettings.set_option(&"vibration", true)
	Haptics.pulse(0.5, 0.5, 0.1)
	_check(Haptics.pulse_count == pulses + 1, "vibration on: pulses go out")
	GameSettings.persist = true
	GameSettings.path = "user://unit_test_settings.cfg"
	GameSettings.set_option(&"master_volume", 0.33)
	GameSettings.set_option(&"mouse_sensitivity", 1.75)
	GameSettings.set_option(&"vibration", false)
	GameSettings.master_volume = 0.9
	GameSettings.mouse_sensitivity = 1.0
	GameSettings.vibration = true
	GameSettings.load_settings()
	_check(absf(GameSettings.master_volume - 0.33) < 0.001 and absf(GameSettings.mouse_sensitivity - 1.75) < 0.001 and not GameSettings.vibration, "settings survive a save / load round trip")
	DirAccess.remove_absolute(GameSettings.path)
	GameSettings.persist = false
	GameSettings.path = GameSettings.DEFAULT_PATH
	GameSettings.reset_defaults()
	_check(GameSettings.master_volume > 0.5 and GameSettings.vibration and GameSettings.mouse_sensitivity == 1.0, "reset restores defaults")
	GameSettings.set_option(&"not_a_setting", 1)   # warns, must not crash
	_check(true, "an unknown option is ignored safely")


func _test_feed_style_mod() -> void:
	print("[UNIT] --- a mod can add and replace feeding styles and routes ---")
	var base := "user://mods/unit_feed_mod/content/feeding"
	DirAccess.make_dir_recursive_absolute(base)
	var drunk := FeedStyle.new()
	drunk.id = &"drunk"
	drunk.display_name = "Drunk"
	drunk.yield_multiplier = 0.7
	drunk.surge_name = "Borrowed Courage"
	ResourceSaver.save(drunk, base + "/drunk.tres")
	var calm_override := FeedStyle.new()
	calm_override.id = &"calm"
	calm_override.yield_multiplier = 2.0
	ResourceSaver.save(calm_override, base + "/calm_override.tres")
	ContentRegistry.reload()
	var d := ContentRegistry.get_def(&"FeedStyle", &"drunk") as FeedStyle
	_check(d != null and d.source == "unit_feed_mod" and d.surge_name == "Borrowed Courage", "a mod adds a new feeding style")
	_check((ContentRegistry.get_def(&"FeedStyle", &"calm") as FeedStyle).yield_multiplier == 2.0, "a mod replaces a core feeding style by id")
	_check((ContentRegistry.get_def(&"FeedStyle", &"afraid") as FeedStyle).source == "core", "the rest stay core")
	DirAccess.remove_absolute(base + "/drunk.tres")
	DirAccess.remove_absolute(base + "/calm_override.tres")
	DirAccess.remove_absolute(base)
	DirAccess.remove_absolute("user://mods/unit_feed_mod/content")
	DirAccess.remove_absolute("user://mods/unit_feed_mod")
	ContentRegistry.reload()
	_check(ContentRegistry.get_def(&"FeedStyle", &"drunk") == null and (ContentRegistry.get_def(&"FeedStyle", &"calm") as FeedStyle).yield_multiplier == 1.0, "removing the mod restores the core styles")


func _test_blood_gauge_polygons() -> void:
	print("[UNIT] --- the blood vessel always draws (polygon sweep) ---")
	var g := BloodGauge.new()
	var bad := []
	var level := 0.0
	while level <= 1.0001:
		for amp in [0.0, 2.0, 4.5, 9.0]:
			for t in [0.0, 0.7, 2.9, 11.3]:
				g._t = t
				var pts := g._liquid(level, 48.0, amp)
				if pts.size() >= 3 and Geometry2D.triangulate_polygon(pts).is_empty():
					bad.append("%.2f/%.1f/%.1f" % [level, amp, t])
		level += 0.01
	_check(bad.is_empty(), "the liquid outline triangulates at every blood level, wave size and time %s" % str(bad.slice(0, 6)))
	g.free()
