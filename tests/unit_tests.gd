extends Node
## Fast logic tests that need no player/world: time of day, day/night profile, sunlight model,
## content registry (including a generated mod). Run headless:
##   godot --headless --path . res://tests/unit_tests.tscn

var checks := 0
var failures := 0


func _ready() -> void:
	_test_time_of_day()
	_test_profile_sampling()
	_test_sunlight_model()
	_test_registry()
	_test_mod_override()
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
