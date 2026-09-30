extends Node
## Dev tool: measures frame time, draw calls and node count in a few representative situations.
##   godot --path . res://tests/perf_probe.tscn

func _ready() -> void:
	HumanNpc.schedules_enabled = true
	var main: Main = load("res://scenes/main.tscn").instantiate()
	main.capture_mouse = false
	add_child(main)
	await get_tree().create_timer(2.5).timeout
	var player: Player = main.player
	main.tod.paused = true
	player.form.set_form_immediate(&"vampire")
	var sense: Ability = player.abilities.get_ability(&"vampiric_sense")
	print("nodes in tree: %d" % Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	await _measure("day, yard, vampire", main, player, 12.0, Vector3(3, 0, 8), false)
	await _measure("day, yard, vampire + Sense (embers)", main, player, 12.0, Vector3(3, 0, 8), true, sense)
	await _measure("dusk, yard", main, player, 18.5, Vector3(3, 0, 8), false, sense)
	await _measure("night, yard, lamps + moon shadows + Sense", main, player, 0.0, Vector3(3, 0, 8), true, sense)
	get_tree().quit()


func _measure(label: String, main: Main, player: Player, hour: float, pos: Vector3, sense_on: bool, sense: Ability = null) -> void:
	main.tod.set_hour(hour)
	player.place_at(pos, 0.0)
	player.sunlight.reset()
	if sense != null:
		if sense_on and not sense.active:
			sense.activate()
		if not sense_on and sense.active:
			sense.deactivate()
	await get_tree().create_timer(1.0).timeout
	var frames := 0
	var t0 := Time.get_ticks_usec()
	var worst := 0.0
	var last := t0
	while Time.get_ticks_usec() - t0 < 4_000_000:
		await get_tree().process_frame
		var now := Time.get_ticks_usec()
		worst = maxf(worst, (now - last) / 1000.0)
		last = now
		frames += 1
	var avg_ms := (Time.get_ticks_usec() - t0) / 1000.0 / frames
	print("%-46s avg %.2f ms (%.0f fps)  worst %.1f ms  draw calls %d  physics obj %d" % [
		label, avg_ms, 1000.0 / avg_ms, worst,
		Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		Performance.get_monitor(Performance.PHYSICS_3D_ACTIVE_OBJECTS)])
