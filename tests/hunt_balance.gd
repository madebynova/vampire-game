extends "res://tests/test_base.gd"
## A tuning probe, not a regression suite: plays the same fight with three simple "players" and prints how it
## went, so the numbers (a hunter's 120 health and 26 damage, Rend's 20) can be judged against the brief -
## dangerous enough that nobody ignores him, beatable without a perfect run.
##   godot --headless --path . res://tests/hunt_balance.tscn
## Policies:  mash  - stands in front of him and presses Rend whenever it is ready
##            kite  - hits, then backs out of reach as the blade rises, and comes back into his recovery
##            stalk - ambushes him from behind, then finishes the fight by kiting
## Every figure is from the real code (the hunter's AI, Rend, damage, knock-back, grace); only the human is faked.

var hunter: Hunter
const RUNS := 4


func _ready() -> void:
	GameSettings.persist = false
	HumanNpc.schedules_enabled = false
	Hunter.always_on = true
	main = load("res://scenes/main.tscn").instantiate()
	main.capture_mouse = false
	add_child(main)
	player = main.player
	world = main.world
	hunter = world.hunters[0]
	main.tod.paused = true
	main.tod.set_hour(23.0)
	await _wait(2.8)
	for policy in ["mash", "kite", "stalk"]:
		var wins := 0
		var lost_total := 0.0
		var time_total := 0.0
		var hits_taken := 0
		var deaths := 0
		for i in RUNS:
			var r: Dictionary = await _fight(policy)
			if r["won"]:
				wins += 1
			if r["died"]:
				deaths += 1
			lost_total += r["hp_lost"]
			time_total += r["seconds"]
			hits_taken += r["hits_taken"]
			print("[BAL]   %s #%d: %s in %.1f s, lost %d hp, %d blows taken" % [policy, i + 1, "won" if r["won"] else ("DIED" if r["died"] else "timed out"), r["seconds"], r["hp_lost"], r["hits_taken"]])
		print("[BAL] %-6s  won %d/%d  died %d  avg %.1f s  avg hp lost %.0f  avg blows taken %.1f" % [policy, wins, RUNS, deaths, time_total / RUNS, lost_total / RUNS, float(hits_taken) / RUNS])
	get_tree().quit()


func _fight(policy: String) -> Dictionary:
	for a in [&"feed", &"interact", &"sprint", &"move_forward", &"attack"]:
		Input.action_release(a)
	player.health.revive(1.0)
	player.sunlight.reset()
	player.combat.reset()
	player.surge.stop(false)
	player.state.set_mode(PlayerState.Mode.NORMAL)
	player.form.set_form_immediate(&"vampire")
	player.blood._set_value(70.0)
	hunter.inert = false
	hunter.hold = false
	hunter.health = hunter.profile.max_health
	hunter.wary_left = 0.0
	hunter.times_killed_player = 0
	hunter.swings = 0
	hunter.landed = 0
	var spot := Vector3(3, 0, 1.0)
	hunter.deploy(spot, 180.0, Hunter.State.PATROL)
	hunter.hold = true
	player.combat.hits = 0
	var hits_taken := [0]
	var on_hurt := func(_i, _a): hits_taken[0] += 1
	player.combat.hurt.connect(on_hurt)
	if policy == "stalk":
		hunter.deploy(spot, -90.0, Hunter.State.PATROL)
		hunter.hold = true
		player.place_at(Vector3(spot.x - 2.0, 0, spot.z), -PI * 0.5)
		player.camera_rig.yaw = -PI * 0.5
	else:
		hunter._spot()
		hunter.hold = false
		player.place_at(Vector3(spot.x, 0, spot.z + 1.9), 0.0)
		player.camera_rig.yaw = 0.0
	await _wait(0.3)
	var t := 0.0
	var step := 0
	while t < 30.0 and hunter.is_up() and not player.state.is_dead():
		await get_tree().physics_frame
		var dt := get_physics_process_delta_time()
		t += dt
		var to := hunter.global_position - player.global_position
		to.y = 0.0
		var d := to.length()
		var dir := to.normalized() if d > 0.05 else Vector3.FORWARD
		player.camera_rig.yaw = atan2(-dir.x, -dir.z)
		match policy:
			"mash":
				if d > 2.2 and player.state.mode == PlayerState.Mode.NORMAL:
					Input.action_press(&"move_forward")
				else:
					Input.action_release(&"move_forward")
				if not player.combat.is_attacking() and d < 2.6:
					player.combat.begin()
			"kite", "stalk":
				if hunter.swing == Hunter.Swing.WINDUP and hunter._swing_t > hunter.profile.attack_windup * 0.2 and d < 3.2:
					# Out of reach as the blade comes down.
					player.push(-dir * 13.0)
				elif hunter.swing == Hunter.Swing.RECOVER or hunter._stagger_t > 0.0 or hunter._flinch_t > 0.0 or not hunter.is_engaged():
					if d > 2.0:
						Input.action_press(&"move_forward")
					else:
						Input.action_release(&"move_forward")
					if d < 2.6 and not player.combat.is_attacking():
						player.combat.begin()
				else:
					Input.action_release(&"move_forward")
					if d > 3.5:
						Input.action_press(&"move_forward")
		step += 1
	Input.action_release(&"move_forward")
	player.combat.hurt.disconnect(on_hurt)
	var out := {
		"won": not hunter.is_up() and not player.state.is_dead(),
		"died": player.state.is_dead(),
		"seconds": t,
		"hp_lost": 100.0 - player.health.value if not player.state.is_dead() else 100.0,
		"hits_taken": hits_taken[0],
	}
	if player.state.is_dead():
		await _wait(5.5)
	return out
