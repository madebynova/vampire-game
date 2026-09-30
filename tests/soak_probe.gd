extends "res://tests/test_base.gd"
## Dev tool: fast-forwards through two full days (8x) while the player wanders, transforms, senses,
## feeds whoever is nearby and sleeps, so runtime errors in long-running systems (schedules, dusk and
## dawn, sunlight, coffin, memories, pause) show up in the log.
##   godot --headless --path . res://tests/soak_probe.tscn

func _ready() -> void:
	GameSettings.persist = false
	HumanNpc.schedules_enabled = true
	main = load("res://scenes/main.tscn").instantiate()
	main.capture_mouse = false
	add_child(main)
	player = main.player
	world = main.world
	_fast_memory()
	await _wait(3.0)
	Engine.max_physics_steps_per_frame = 64
	Engine.time_scale = 8.0
	var day0 := main.tod.day_count
	var spots := [Vector3(3, 0, 5), Vector3(-18, 0, 5.5), Vector3(14, 0, 18.4), Vector3(8, 0, 10), Vector3(3, 0, 26), Vector3(-5, 0, -4), Vector3(20, 0, 2)]
	var step := 0
	var counts := {"deaths": 0, "feeds": 0, "memories": 0}   # (lambdas capture locals by value; a Dictionary is shared)
	player.health.died.connect(func(_c): counts["deaths"] += 1)
	player.feeding.feed_completed.connect(func(_n, _r): counts["feeds"] += 1)
	main.memory_view.opened.connect(func(): counts["memories"] += 1)
	var t := 0.0
	while main.tod.day_count < day0 + 2 and t < 300.0:
		await _wait_real(2.0)
		t += 2.0
		step += 1
		if main.memory_view.is_open():
			await _dismiss_memory(20.0)
		if player.state.mode != PlayerState.Mode.NORMAL:
			continue
		var spot: Vector3 = spots[step % spots.size()]
		_place(spot, float((step * 70) % 360))
		match step % 6:
			0:
				if player.form.is_form(&"human"):
					player.form.request_form(&"vampire")
			1:
				if player.form.is_form(&"vampire"):
					await _tap(&"vampiric_sense")
			2, 4:
				await _feed_nearest()
			3:
				if player.abilities.get_ability(&"vampiric_sense").active:
					await _tap(&"vampiric_sense")
			5:
				if step % 12 == 5 and player.form.is_form(&"vampire"):
					player.form.request_form(&"human")
				await _tap(&"interact")
	Engine.time_scale = 1.0
	print("[SOAK] %.0f s real, %d days, steps=%d deaths=%d feeds=%d memories=%d hour=%s" % [t, main.tod.day_count - day0, step, counts["deaths"], counts["feeds"], counts["memories"], main.tod.clock_text()])
	print("[SOAK] OK")
	get_tree().quit()


## Teleport beside the nearest person who can be fed on and hold the feed button through it.
func _feed_nearest() -> void:
	if not player.form.is_form(&"vampire"):
		return
	var best: HumanNpc = null
	var best_d := INF
	for n in get_tree().get_nodes_in_group(&"npcs"):
		var npc := n as HumanNpc
		if npc.can_be_fed():
			var d := npc.global_position.distance_to(player.global_position)
			if d < best_d:
				best_d = d
				best = npc
	if best == null:
		return
	var off := Vector3(1.3, 0, 0.0)
	_place(best.global_position + off, 90.0)
	_face(best.global_position)
	await _wait_real(0.4)
	Input.action_press(&"feed")
	await _wait_real(1.6)
	Input.action_release(&"feed")
