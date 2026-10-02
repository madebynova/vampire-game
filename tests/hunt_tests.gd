extends "res://tests/test_base.gd"
## v0.2.0 - THE HUNT. Drives the real game and checks the first real gameplay loop: a hunter who keeps a camp and
## walks a round by lantern, sees you by cone / light / sound, runs you down through the doorways, telegraphs
## his blade and staggers you with it; the vampire's one attack and what makes it land harder; what breaks a
## chase (windows, roofs, the dark, turning human); what happens when he goes down (drink him, or leave him);
## the objective that reads the world; and the existing vampire systems still doing their jobs around it.
##   godot --headless --path . res://tests/hunt_tests.tscn
##   godot --headless --path . res://tests/hunt_tests.tscn -- only=rules,nav        (some sections)
##   godot --path . res://tests/hunt_tests.tscn -- <screenshot_dir>                  (windowed: screenshots)

var _only: PackedStringArray = PackedStringArray()
var hunter: Hunter
var _profile_backup: Dictionary = {}


func _ready() -> void:
	GameSettings.persist = false
	for a in OS.get_cmdline_user_args():
		if a.begins_with("only="):
			_only = a.trim_prefix("only=").split(",")
		else:
			out_dir = a
	HumanNpc.schedules_enabled = false     # villagers at their posts ...
	Hunter.always_on = true                # ... but the hunter keeps his hours
	main = load("res://scenes/main.tscn").instantiate()
	main.capture_mouse = false
	add_child(main)
	player = main.player
	world = main.world
	hunter = world.hunters[0]
	main.tod.paused = true
	_night()
	await _wait(2.8)
	await _run()
	print("[HUNT] ===== %d checks, %d failures =====" % [checks, failures])
	get_tree().quit(1 if failures > 0 else 0)


func _check(cond: bool, msg: String) -> void:
	checks += 1
	if cond:
		print("[HUNT] PASS  ", msg)
	else:
		failures += 1
		print("[HUNT] FAIL  ", msg)


func _run() -> void:
	_fast_memory()
	if _wants("rules"):
		_test_rules()
	if _wants("data"):
		await _test_data()
	if _wants("nav"):
		await _test_nav()
	if _wants("strike"):
		await _test_strike()
	if _wants("senses"):
		await _test_senses()
	if _wants("combat"):
		await _test_hunter_combat()
	if _wants("escape"):
		await _test_escape()
	if _wants("down"):
		await _test_down_and_feed()
	if _wants("objective"):
		await _test_objective()
	if _wants("hours"):
		await _test_hours()
	if _wants("consequence"):
		await _test_consequences()
	if _wants("hud"):
		await _test_hud()
	if _wants("regress"):
		await _test_regressions()


func _wants(section: String) -> bool:
	return _only.is_empty() or _only.has(section)


# ------------------------------------------------------------------ helpers

func _night(hour := 23.0) -> void:
	main.tod.paused = true
	main.tod.sun_override = Vector3.ZERO
	main.tod.set_hour(hour)


func _set_blood(v: float) -> void:
	player.blood._set_value(v)


func _release_all() -> void:
	for a in [&"feed", &"interact", &"sprint", &"move_forward", &"move_back", &"move_left", &"move_right", &"memory_dismiss", &"jump", &"attack"]:
		Input.action_release(a)


## A clean stage: villagers at their posts, the player a fit vampire with some blood, the hunter stood down and
## harmless, the clock at night.
func _reset(hour := 23.0) -> void:
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
	player.combat.reset()
	player.combat.swings = 0
	player.combat.hits = 0
	player.state.set_mode(PlayerState.Mode.NORMAL)
	player.visual.visible = true
	player.form.set_form_immediate(&"vampire")
	_set_blood(60.0)
	InputSetup.set_device_kind(InputSetup.KEYBOARD)
	hunter.inert = true
	hunter.hold = false
	hunter.profile.max_health = 120.0
	hunter.health = 120.0
	hunter.wary_left = 0.0
	hunter.times_killed_player = 0
	hunter.swings = 0
	hunter.landed = 0
	hunter._go_away()
	HumanNpc.tasted.erase(hunter.profile.id)
	_night(hour)


## Stage the hunter at `pos` facing `yaw` (degrees; 0 faces north, -Z). `state` as given; he stands (hold) unless
## `walk`. `live` lets him think; otherwise he is inert.
func _stage(pos: Vector3, yaw: float, state: Hunter.State = Hunter.State.PATROL, live := true, walk := false) -> void:
	hunter.deploy(pos, yaw, state)
	hunter.hold = not walk
	hunter.inert = not live
	hunter.health = hunter.profile.max_health


func _player_at(pos: Vector3, yaw := 0.0) -> void:
	player.place_at(pos, deg_to_rad(yaw))
	player.set_facing(deg_to_rad(yaw))


## Walk or run the player toward `target` until within `dist` or `timeout`. Returns the seconds taken.
func _go(target: Vector3, dist := 1.0, timeout := 6.0, run := false) -> float:
	var t := 0.0
	if run:
		Input.action_press(&"sprint")
	Input.action_press(&"move_forward")
	while t < timeout:
		_face(target)
		var flat := Vector2(target.x - player.global_position.x, target.z - player.global_position.z)
		if flat.length() < dist:
			break
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
	Input.action_release(&"move_forward")
	Input.action_release(&"sprint")
	return t


## Wait until `cond` is true or `timeout` seconds pass. Returns whether it became true.
func _until(cond: Callable, timeout := 4.0) -> bool:
	var t := 0.0
	while t < timeout:
		if cond.call():
			return true
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
	return cond.call()


## One press of the attack control, as the hardware would send it: key R, left mouse button, or the right bumper.
func _real_attack(how: String) -> void:
	await get_tree().process_frame
	var down: InputEvent
	var up: InputEvent
	match how:
		"key":
			down = InputEventKey.new()
			down.physical_keycode = KEY_R
			down.keycode = KEY_R
			up = InputEventKey.new()
			up.physical_keycode = KEY_R
			up.keycode = KEY_R
		"mouse":
			down = InputEventMouseButton.new()
			down.button_index = MOUSE_BUTTON_LEFT
			up = InputEventMouseButton.new()
			up.button_index = MOUSE_BUTTON_LEFT
		_:
			down = InputEventJoypadButton.new()
			down.button_index = JOY_BUTTON_RIGHT_SHOULDER
			down.device = 0
			up = InputEventJoypadButton.new()
			up.button_index = JOY_BUTTON_RIGHT_SHOULDER
			up.device = 0
	down.pressed = true
	up.pressed = false
	Input.parse_input_event(down)
	await get_tree().process_frame
	await get_tree().process_frame
	Input.parse_input_event(up)
	await get_tree().process_frame


func _near(a: float, b: float, eps := 0.01) -> bool:
	return absf(a - b) <= eps


# ------------------------------------------------------------------ pure rules

func _test_rules() -> void:
	print("[HUNT] --- RULES: damage, hunger, reach, senses (pure arithmetic) ---")
	var base := 20.0
	_check(_near(CombatRules.strike_damage(base, &"rend", false, 1.0, 0.0), 20.0), "a plain Rend is 20")
	_check(_near(CombatRules.strike_damage(base, &"lunge", false, 1.0, 0.0), 25.0), "a pounce (struck at a run) is 25")
	_check(_near(CombatRules.strike_damage(base, &"plunge", false, 1.0, 0.0), 30.0), "a plunge (struck falling) is 30")
	_check(_near(CombatRules.strike_damage(base, &"rend", true, 1.0, 0.0), 60.0), "an ambush (he did not know you were there) is triple: 60")
	_check(_near(CombatRules.strike_damage(base, &"plunge", true, 1.0, 0.0), 90.0), "an ambush from above is 90")
	_check(_near(CombatRules.hunger_factor(false, false), 1.0) and _near(CombatRules.hunger_factor(true, false), 0.8) and _near(CombatRules.hunger_factor(true, true), 0.6), "hunger weakens a strike: fed x1, hungry x0.8, starving x0.6")
	_check(_near(CombatRules.strike_damage(base, &"rend", false, 0.6, 0.0), 12.0), "a starving vampire strikes for 12")
	_check(_near(CombatRules.strike_damage(base, &"rend", false, 1.0, 0.25), 25.0), "a full Bloodrush adds a quarter: 25")
	_check(CombatRules.strike_kind(false, false) == &"rend" and CombatRules.strike_kind(true, false) == &"lunge" and CombatRules.strike_kind(true, true) == &"plunge" and CombatRules.strike_kind(false, true) == &"plunge", "running makes a pounce, falling makes a plunge, falling beats running")
	var o := Vector3.ZERO
	var fwd := Vector3(0, 0, -1)
	_check(CombatRules.in_cone(o, fwd, Vector3(0, 0, -2), 2.5, 60.0), "straight ahead and in reach is hit")
	_check(not CombatRules.in_cone(o, fwd, Vector3(0, 0, -3), 2.5, 60.0), "beyond reach is not")
	_check(not CombatRules.in_cone(o, fwd, Vector3(0, 0, 2), 2.5, 60.0), "behind is not")
	_check(not CombatRules.in_cone(o, fwd, Vector3(2.2, 0, -0.5), 2.5, 60.0), "far off to the side is not")
	_check(CombatRules.in_cone(o, fwd, Vector3(0.4, 0, 0.5), 2.5, 60.0, 1.0), "but at your elbow it counts whichever way it lies")
	var p: HunterProfile = hunter.profile
	var still := CombatRules.hearing_radius(0.0, p.hear_still, p.hear_walk, p.hear_run)
	var walk := CombatRules.hearing_radius(4.2, p.hear_still, p.hear_walk, p.hear_run)
	var run := CombatRules.hearing_radius(9.0, p.hear_still, p.hear_walk, p.hear_run)
	_check(still < walk and walk < run, "you are heard further the faster you move: %.1f < %.1f < %.1f m" % [still, walk, run])
	_check(CombatRules.sight_radius(15.0, 0.55, 0.0) < CombatRules.sight_radius(15.0, 0.55, 1.0), "he sees less far in the dark than in lamplight")
	_check(_near(CombatRules.sight_radius(15.0, 0.55, 0.0), 8.25) and _near(CombatRules.sight_radius(15.0, 0.55, 1.0), 15.0), "8.25 m in full dark, 15 m in full light")
	_check(CombatRules.sight_radius(15.0, 0.55, 0.0, 1.35) > 11.0, "wariness widens it")
	var near_r := CombatRules.notice_rate(2.0, true, 15.0, false, 0.0, false, 0.35, 2.2, 0.9)
	var far_r := CombatRules.notice_rate(14.0, true, 15.0, false, 0.0, false, 0.35, 2.2, 0.9)
	_check(near_r > far_r * 4.0, "noticing builds faster the closer you are (%.2f vs %.2f per second)" % [near_r, far_r])
	_check(CombatRules.notice_rate(10.0, false, 15.0, false, 3.0, false, 0.35, 2.2, 0.9) == 0.0, "unseen, unheard and unfelt, nothing builds")
	_check(CombatRules.notice_rate(2.0, false, 15.0, true, 9.0, false, 0.35, 2.2, 0.9) < near_r, "sound alone builds more slowly than sight")
	_check(p.is_on_duty(23.0) and p.is_on_duty(0.5) and p.is_on_duty(4.9) and p.is_on_duty(19.0), "he is on his round at night, midnight, before five and from seven")
	_check(not p.is_on_duty(5.1) and not p.is_on_duty(12.0) and not p.is_on_duty(18.9), "and not by day")


# ------------------------------------------------------------------ data

func _test_data() -> void:
	print("[HUNT] --- DATA: everything is content, nothing is hard-coded ---")
	_reset()
	var prof := ContentRegistry.get_def(&"HunterProfile", &"lamplighter") as HunterProfile
	_check(prof != null and prof.display_name == "Hollis Crane" and prof.title == "Lamplighter", "the Lamplighter is a HunterProfile in the registry")
	_check(ContentRegistry.get_def(&"HuntDefinition", &"lantern_in_the_manor") != null, "the hunt is a HuntDefinition")
	_check(ContentRegistry.get_def(&"FeedStyle", &"hunter") != null and ContentRegistry.get_def(&"BloodDefinition", &"hunter") != null, "his blood and the way it feeds are data")
	_check(prof.memories.size() == 1 and prof.memory().title == "The Lamp Is Lit", "his blood holds one memory")
	_check(prof.max_health >= 80.0 and prof.attack_damage >= 15.0 and prof.attack_windup >= 0.4, "he is dangerous (%.0f hp, %.0f damage) but fair (%.2f s tell)" % [prof.max_health, prof.attack_damage, prof.attack_windup])
	var loc := world.location
	_check(loc.hunters.size() == 1 and loc.hunters[0].hunter_id == &"lamplighter", "Blackthorn lists one hunter")
	_check(loc.hunters[0].patrol.size() >= 12, "he walks a round of %d points" % loc.hunters[0].patrol.size())
	_check(loc.nav_points.size() >= 24, "with %d waypoints to find his way by" % loc.nav_points.size())
	_check(world.hunters.size() == 1 and world.camp_clues.size() == 2, "the world spawned him and two things to read at his camp")
	_check(world.inspectables.size() == 3, "the three old clues are untouched")
	# By day he is not about.
	_reset(14.0)
	hunter._go_away()
	await _wait(0.2)
	_check(hunter.state == Hunter.State.AWAY and not hunter.visible, "by day he is away: not in the world")
	_check(not hunter.can_be_struck() and not hunter.is_sense_visible() and not hunter.can_be_fed(), "...cannot be struck, sensed or fed on")
	# Input: one new action, on a key, the mouse and a bumper.
	_check(InputMap.has_action(&"attack"), "Rend is an input action")
	var kinds := {"key": false, "mouse": false, "pad": false}
	for ev in InputMap.action_get_events(&"attack"):
		if ev is InputEventKey:
			kinds["key"] = true
		elif ev is InputEventMouseButton:
			kinds["mouse"] = true
		elif ev is InputEventJoypadButton:
			kinds["pad"] = true
	_check(kinds["key"] and kinds["mouse"] and kinds["pad"], "on a key, the left mouse button and a pad button")
	_check(InputSetup.prompt_text(&"attack", InputSetup.KEYBOARD) == "R" and InputSetup.prompt_text(&"attack", InputSetup.XBOX) == "RB" and InputSetup.prompt_text(&"attack", InputSetup.PLAYSTATION) == "R1", "R on the keyboard, RB on an Xbox pad, R1 on a PlayStation pad")
	_check(InputSetup.GAMEPLAY_ACTIONS.has(&"attack"), "it is listed with the other gameplay actions (so it is tested like them)")
	_check(InputSetup.prompt_text(&"sprint", InputSetup.XBOX) == "RT", "the run trigger is unchanged")
	_check(player.form.get_form(&"vampire").strike_damage == 20.0 and player.form.get_form(&"human").strike_damage == 0.0, "the Vampire strikes for 20; the Human cannot fight")
	# Every new sound exists.
	var missing: Array[String] = []
	for s in [&"step_boot", &"lantern_clink", &"hunter_notice", &"hunter_spot", &"hunter_windup", &"hunter_swing", &"hunter_hurt", &"hunter_down", &"rend_swing", &"rend_hit", &"hit_taken"]:
		if not Sfx.has_sound(s):
			missing.append(String(s))
	_check(missing.is_empty(), "all eleven new sounds exist %s" % str(missing))
	var all_ok := true
	for s in [&"hunter_spot", &"hunter_windup", &"rend_hit", &"hit_taken"]:
		var stream := Sfx._stream(s)
		all_ok = all_ok and stream != null and (stream as AudioStreamWAV).data.size() > 1000
	_check(all_ok, "and they synthesise to real audio")
	# The controls screen names Rend.
	var found := false
	for g in ControlsPanel.GROUPS:
		for r in g[1]:
			if str(r[0]).begins_with("Rend"):
				found = true
	_check(found, "the controls screen lists Rend")


# ------------------------------------------------------------------ the waypoint graph

func _test_nav() -> void:
	print("[HUNT] --- NAV: he finds his way through doorways, never through walls or windows ---")
	_reset()
	await get_tree().physics_frame
	await get_tree().physics_frame
	var space := player.get_world_3d().direct_space_state
	var nav := world.nav
	if not nav.is_built():
		nav.build(space)
	_check(nav.is_built() and nav.links >= nav.points.size(), "the graph is built: %d waypoints, %d links" % [nav.points.size(), nav.links])
	# Every waypoint is free standing room.
	var blocked := 0
	for pt in nav.points:
		var q := PhysicsShapeQueryParameters3D.new()
		var cap := CapsuleShape3D.new()
		cap.radius = 0.36
		cap.height = 1.7
		q.shape = cap
		q.transform = Transform3D(Basis(), pt + Vector3(0, 0.95, 0))
		q.collision_mask = Greybox.WORLD
		if not space.intersect_shape(q, 1).is_empty():
			blocked += 1
			print("[HUNT]   blocked waypoint at ", pt)
	_check(blocked == 0, "every waypoint is clear to stand in (%d blocked)" % blocked)
	# His round is on the graph and connected.
	var pl: HunterPlacement = world.location.hunters[0]
	var far_off := 0
	for pt in pl.patrol:
		var i := nav.nearest_point(pt)
		if Vector2(nav.points[i].x - pt.x, nav.points[i].z - pt.z).length() > 1.0:
			far_off += 1
	_check(far_off == 0, "every point of his round has a waypoint within a metre")
	var unreachable := 0
	var prev: Vector3 = pl.camp
	for pt in pl.patrol:
		var route := nav.path(space, prev, pt)
		if route.is_empty():
			unreachable += 1
			print("[HUNT]   no route from ", prev, " to ", pt)
		else:
			var len_straight := Vector2(pt.x - prev.x, pt.z - prev.z).length()
			if HuntNav.length_of(prev, route) > maxf(len_straight * 2.6, len_straight + 6.0):
				unreachable += 1
				print("[HUNT]   absurd route ", prev, " -> ", pt, ": ", HuntNav.length_of(prev, route), " for ", len_straight)
		prev = pt
	_check(unreachable == 0, "he can walk his whole round, leg by leg, without detours (%d bad legs)" % unreachable)
	# Each leg of every route is genuinely walkable.
	var bad_legs := 0
	for pt in pl.patrol:
		var route := nav.path(space, pl.camp, pt)
		var from: Vector3 = pl.camp
		for step in route:
			if not HuntNav.line_clear(space, from, step):
				bad_legs += 1
			from = step
	_check(bad_legs == 0, "every leg of every route is a clear walk (%d bad)" % bad_legs)
	# Doors are doors; windows are not.
	var out_window := Vector3(6.2, 0, -4.6)
	var in_window := Vector3(6.2, 0, -7.4)
	_check(not HuntNav.line_clear(space, out_window, in_window), "the manor window is not a way through")
	var round_trip := nav.path(space, out_window, in_window)
	var rlen := HuntNav.length_of(out_window, round_trip)
	_check(not round_trip.is_empty() and rlen > 6.5, "to get from one side of it to the other he goes round by the door (%.1f m, not 2.8)" % rlen)
	var through_door := false
	var prev_pt := out_window
	for pt in round_trip:
		# The leg that crosses the wall line (z = -6) must do it inside the doorway (x 2..4).
		if prev_pt.z > -6.0 and pt.z < -6.0:
			var k := (prev_pt.z + 6.0) / (prev_pt.z - pt.z)
			var x_at := lerpf(prev_pt.x, pt.x, k)
			through_door = x_at > 2.3 and x_at < 3.7
		prev_pt = pt
	_check(through_door, "and that route goes in through the doorway (x 2..4), not through the wall: %s" % str(round_trip))
	# He follows you indoors: the cottage, the hut and the gatehouse have doors on the graph.
	for dest in [Vector3(18, 0, 18.3), Vector3(9.9, 0, 25.7), Vector3(-21.5, 0, 5.5), Vector3(3, 0, -8)]:
		var r := nav.path(space, Vector3(3, 0, 3), dest)
		_check(not r.is_empty(), "he can reach inside %s from the yard" % str(dest))
	# And a roof is somewhere he cannot go.
	_check(nav.path(space, Vector3(3, 0, 3), Vector3(-5, 3.9, -6.9)).is_empty(), "he cannot reach a rooftop")


# ------------------------------------------------------------------ the vampire's strike

func _test_strike() -> void:
	print("[HUNT] --- REND: one attack, with a cost, a cooldown and four ways to land ---")
	_reset()
	var combat := player.combat
	# A human cannot fight.
	player.form.set_form_immediate(&"human")
	_player_at(Vector3(0, 0, -19), 0.0)
	await _wait(0.3)
	await _tap(&"attack")
	await _wait(0.2)
	_check(combat.swings == 0 and combat.phase == PlayerCombat.Phase.IDLE, "a Human pressing attack does nothing")
	player.form.set_form_immediate(&"vampire")
	await _wait(0.2)
	# A swing: wind-up, strike, recovery, back to ready - and it costs blood.
	var blood0 := player.blood.value
	_stage(Vector3(0, 0, -30), 0.0, Hunter.State.PATROL, false)     # out of the way
	await _tap(&"attack")
	await get_tree().physics_frame
	_check(combat.swings == 1, "pressing attack starts one swing")
	_check(combat.phase != PlayerCombat.Phase.IDLE and combat.is_attacking(), "it takes time (phase %s)" % PlayerCombat.Phase.keys()[combat.phase])
	_check(player.blood.value < blood0 - 0.5, "and costs a little blood (%.1f -> %.1f)" % [blood0, player.blood.value])
	var total := combat.total_time()
	_check(total > 0.4 and total < 0.75, "a whole swing takes %.2f s" % total)
	var ready := await _until(func(): return combat.phase == PlayerCombat.Phase.IDLE, 1.2)
	_check(ready and combat.progress() == 1.0, "afterwards it is ready again")
	# No spamming: a second press early in the swing does not start a second swing.
	combat.swings = 0
	await _wait(0.3)
	await _tap(&"attack")
	await _wait(0.06)
	await _tap(&"attack")
	await _wait(0.9)
	_check(combat.swings == 1, "a second press mid-swing does not start a second swing (%d)" % combat.swings)
	# ...but a press in the last moments of recovery is remembered, so you never feel the game ignored you.
	combat.swings = 0
	await _tap(&"attack")
	await _wait(0.36)
	await _tap(&"attack")
	await _wait(0.45)
	_check(combat.swings == 2, "a press made as the swing finishes is remembered and becomes the next swing (%d)" % combat.swings)
	await _wait(1.0)
	_release_all()
	combat.swings = 0
	# Rend answers each device's real events: R on the keyboard, a click of the mouse, the right bumper.
	for how in ["key", "mouse", "pad"]:
		combat.reset()
		combat.swings = 0
		await _wait(0.25)
		await _real_attack(how)
		await _wait(0.2)
		_check(combat.swings == 1, "a real %s event starts a swing" % how)
		await _wait(0.6)
	# A target: an ambush from behind.
	_reset()
	_stage(Vector3(0, 0, -19), 180.0)       # facing south, +Z
	hunter.inert = true
	_player_at(Vector3(0, 0, -20.6), 0.0)    # north of him: behind him, facing him
	player.camera_rig.yaw = 0.0
	await _wait(0.4)
	var blood1 := player.blood.value
	var h0 := hunter.health
	await _tap(&"attack")
	await _wait(0.5)
	_check(combat.hits == 1, "the swing connects")
	_check(_near(h0 - hunter.health, 60.0, 0.5), "an ambush from behind on an unaware hunter does 60 of his 120 (%.0f)" % (h0 - hunter.health))
	_check(combat.last_info != null and combat.last_info.ambush and combat.last_info.strong, "it is an ambush and a strong blow")
	_check(player.blood.value > blood1 - 0.2, "a landed blow gives a taste back: +2.5 against the 1 it cost (%.1f -> %.1f)" % [blood1, player.blood.value])
	_check(hunter.state == Hunter.State.HUNTING, "and now he knows you are there")
	_check(hunter._stagger_t > 0.0 or hunter._flinch_t > 0.0 or hunter._pause_t > 0.0, "the blow staggers him")
	# A plain strike on a hunter who is hunting: 20.
	await _wait(1.0)
	_reset()
	_stage(Vector3(0, 0, -19), 0.0, Hunter.State.HUNTING, false)
	hunter._spot()
	hunter.inert = true
	_player_at(Vector3(0, 0, -17.4), 0.0)       # south of him, looking north at him
	player.camera_rig.yaw = 0.0
	await _wait(0.4)
	h0 = hunter.health
	await _tap(&"attack")
	await _wait(0.45)
	_check(_near(h0 - hunter.health, 20.0, 0.5), "a plain Rend on a hunter who is watching you does 20 (%.0f)" % (h0 - hunter.health))
	_check(combat.last_info.kind == &"rend" and not combat.last_info.ambush, "a plain strike, not an ambush")
	# Hunger weakens it.
	await _wait(1.0)
	_set_blood(20.0)
	hunter.health = 120.0
	await _wait(0.2)
	h0 = hunter.health
	await _tap(&"attack")
	await _wait(0.45)
	_check(_near(h0 - hunter.health, 16.0, 0.5), "hungry (20 blood) it does 16 (%.0f)" % (h0 - hunter.health))
	await _wait(0.9)
	_set_blood(5.0)
	hunter.health = 120.0
	h0 = hunter.health
	await _tap(&"attack")
	await _wait(0.45)
	_check(_near(h0 - hunter.health, 12.0, 0.5), "starving (5 blood) it does 12 (%.0f)" % (h0 - hunter.health))
	# A Bloodrush strengthens it.
	await _wait(0.9)
	_set_blood(60.0)
	player.surge.start(1.0, 40.0, "Bloodrush")
	await _wait(0.9)
	hunter.health = 120.0
	h0 = hunter.health
	await _tap(&"attack")
	await _wait(0.45)
	var with_rush := h0 - hunter.health
	_check(with_rush > 22.0 and with_rush <= 25.1, "in a Bloodrush it does more: %.1f" % with_rush)
	player.surge.stop(false)
	# Out of reach and out of the cone: it whiffs.
	await _wait(0.9)
	hunter.health = 120.0
	h0 = hunter.health
	_player_at(Vector3(0, 0, -15.0), 0.0)     # 4 m away, looking at him
	player.camera_rig.yaw = 0.0
	await _wait(0.3)
	await _tap(&"attack")
	await _wait(0.5)
	_check(hunter.health == h0, "4 m away, the claws find nothing")
	await _wait(0.9)
	_player_at(Vector3(0, 0, -17.4), 180.0)   # 1.6 m away but looking the other way
	player.camera_rig.yaw = PI
	await _wait(0.3)
	await _tap(&"attack")
	await _wait(0.5)
	_check(hunter.health == h0, "facing away from him, they find nothing either")
	# A wall in between stops it.
	await _wait(0.9)
	_stage(Vector3(0, 0, -14.4), 0.0, Hunter.State.HUNTING, false)     # inside the manor hall, north wall at z=-16
	hunter._spot()
	hunter.inert = true
	_player_at(Vector3(0, 0, -17.2), 180.0)    # outside the north wall, hunter 2.8 m away through it
	player.camera_rig.yaw = PI
	await _wait(0.3)
	h0 = hunter.health
	await _tap(&"attack")
	await _wait(0.5)
	_check(hunter.health == h0, "a wall between you and him stops the blow")
	# Pounce: striking at a run is a lunge for 25, and carries you forward.
	await _wait(0.9)
	_stage(Vector3(0, 0, -19), 0.0, Hunter.State.HUNTING, false)
	hunter._spot()
	hunter.inert = true
	_player_at(Vector3(0, 0, -11.0), 0.0)   # inside the hall? no: use the open strip instead
	_player_at(Vector3(-6.5, 0, -19), 270.0)
	_stage(Vector3(0, 0, -19), 0.0, Hunter.State.HUNTING, false)
	hunter._spot()
	hunter.inert = true
	player.camera_rig.yaw = deg_to_rad(270.0)
	await _wait(0.3)
	h0 = hunter.health
	Input.action_press(&"sprint")
	Input.action_press(&"move_forward")
	player.camera_rig.yaw = -PI * 0.5            # facing +X, toward him
	await _wait(0.5)
	var x_before := player.global_position.x
	await _tap(&"attack")
	await _wait(0.5)
	Input.action_release(&"move_forward")
	Input.action_release(&"sprint")
	_check(combat.last_info != null and combat.last_info.kind == &"lunge", "striking at a run is a lunge (%s)" % (str(combat.last_info.kind) if combat.last_info else "none"))
	_check(_near(h0 - hunter.health, 25.0, 0.6), "which does 25 (%.0f)" % (h0 - hunter.health))
	_check(player.global_position.x > x_before + 0.8, "and carries you forward")
	# Plunge: falling onto him from a roof is a plunge for 30.
	await _wait(1.0)
	_reset()
	_stage(Vector3(0, 0, -19), 0.0, Hunter.State.HUNTING, false)
	hunter._spot()
	hunter.inert = true
	player.place_at(Vector3(0, 4.2, -17.8), 0.0)
	player.camera_rig.yaw = 0.0
	player.velocity = Vector3(0, -6.0, 0)
	await get_tree().physics_frame
	h0 = hunter.health
	var fell := await _until(func(): return player.velocity.y < -3.5 and player.global_position.y < 3.6, 1.0)
	if fell:
		await _tap(&"attack")
	await _wait(0.5)
	_check(combat.last_info != null and combat.last_info.kind == &"plunge" and hunter.health < h0, "falling onto him is a plunge (%s, -%.0f)" % [str(combat.last_info.kind) if combat.last_info else "none", h0 - hunter.health])
	# Down: enough blows put him on the ground, alive.
	await _wait(1.2)
	_reset()
	_stage(Vector3(0, 0, -19), 0.0, Hunter.State.HUNTING, false)
	hunter._spot()
	hunter.inert = true
	_player_at(Vector3(0, 0, -17.4), 0.0)
	player.camera_rig.yaw = 0.0
	hunter.health = 30.0
	var down_signals := [0]
	hunter.went_down.connect(func(): down_signals[0] += 1, CONNECT_ONE_SHOT)
	await _wait(0.3)
	await _tap(&"attack")
	await _wait(0.45)
	await _tap(&"attack")
	await _wait(0.6)
	_check(hunter.state == Hunter.State.DOWNED and hunter.health <= 0.0, "enough blows put him down (%s)" % hunter.describe())
	_check(down_signals[0] == 1, "once")
	_check(not hunter.can_be_struck(), "a man on the ground cannot be struck again")
	_check(hunter.can_be_fed() and hunter.is_lying(), "but he can be drunk from")
	_reset()


func _test_senses() -> void:
	print("[HUNT] --- SENSES: a cone, the light, the sound of you - and nothing from a human ---")
	_reset()
	await get_tree().physics_frame
	var space := player.get_world_3d().direct_space_state
	# Light: a lamp lights you; the dark does not.
	var lamp_spot := Vector3(-11.5, 0, -19.0)
	var dark_spot := Vector3(12.0, 0, -19.0)
	_check(WorldLight.at(lamp_spot, 0.0, space) > 0.5, "standing by the camp lamp you are lit (%.2f)" % WorldLight.at(lamp_spot, 0.0, space))
	_check(WorldLight.at(dark_spot, 0.0, space) < 0.25, "in the dark north strip you are not (%.2f)" % WorldLight.at(dark_spot, 0.0, space))
	_check(WorldLight.at(Vector3(0, 0, -11.0), 0.0, space) > 0.2, "a lit hall lights its floor, even though the lamp is behind a wall from the yard")
	_check(WorldLight.at(Vector3(0, 0, -11.0), 0.0, space) > WorldLight.at(Vector3(0, 0, -17.8), 0.0, space), "...but not the ground outside its north wall")
	# In the dark, 13 m away in his cone, he does not see you.
	_stage(Vector3(-1, 0, -19), -90.0)             # facing +X
	_player_at(dark_spot, 90.0)
	await _wait(2.2)
	_check(hunter.awareness < 0.1 and hunter.state == Hunter.State.PATROL, "in the dark, 13 m off in his cone, he does not notice you (aware %.2f)" % hunter.awareness)
	# The same distance in lamplight: he does.
	_stage(Vector3(1.5, 0, -19), 90.0)             # facing -X, toward the lamp
	_player_at(lamp_spot, -90.0)
	await _wait(2.2)
	_check(hunter.awareness > 0.25 or hunter.state != Hunter.State.PATROL, "13 m off but standing in lamplight he does (aware %.2f, %s)" % [hunter.awareness, Hunter.State.keys()[hunter.state]])
	# Behind him, still: nothing.
	_reset()
	_stage(Vector3(0, 0, -19), -90.0)              # facing +X
	_player_at(Vector3(-5.0, 0, -19), -90.0)
	await _wait(2.5)
	_check(hunter.awareness < 0.05, "standing still behind him, 5 m away, you are not noticed (aware %.2f)" % hunter.awareness)
	# Walking up behind him: heard late, if at all - an ambush is possible.
	var blood0 := player.blood.value
	_player_at(Vector3(-8.0, 0, -19), -90.0)
	await _wait(0.3)
	await _go(Vector3(-2.3, 0, -19), 0.4, 3.0)
	_check(hunter.state == Hunter.State.PATROL or hunter.state == Hunter.State.SUSPICIOUS, "walking up behind him you reach striking distance before he turns on you (%s, aware %.2f)" % [Hunter.State.keys()[hunter.state], hunter.awareness])
	var h0 := hunter.health
	player.camera_rig.yaw = -PI * 0.5
	player.combat.reset()
	await _tap(&"attack")
	await _wait(0.4)
	_check(_near(h0 - hunter.health, 60.0, 0.6), "and the blow is an ambush: 60 (%.0f)" % (h0 - hunter.health))
	# Running up behind him: heard from further, but still not enough to turn him in time. A pounce from the dark.
	_reset()
	_stage(Vector3(0, 0, -19), -90.0)
	_player_at(Vector3(-9.0, 0, -19), -90.0)
	await _wait(0.3)
	var run_t := await _go(Vector3(-2.0, 0, -19), 2.3, 3.0, true)
	var seen_during := hunter.state
	player.camera_rig.yaw = -PI * 0.5
	h0 = hunter.health
	await _tap(&"attack")
	await _wait(0.45)
	_check(seen_during != Hunter.State.HUNTING, "sprinting up behind him in %.1f s he has not yet turned (%s)" % [run_t, Hunter.State.keys()[seen_during]])
	_check(player.combat.last_info != null and player.combat.last_info.kind == &"lunge" and player.combat.last_info.ambush, "the pounce is a lunge AND an ambush")
	_check(_near(h0 - hunter.health, 75.0, 0.8), "which does 75 of his 120 (%.0f)" % (h0 - hunter.health))
	# Faster is louder: sprinting is heard from further than walking.
	_reset()
	_stage(Vector3(0, 0, -19), -90.0)
	_player_at(Vector3(-8.5, 0, -19), -90.0)
	await _wait(0.2)
	await _go(Vector3(-1.0, 0, -19), 3.0, 1.2, true)
	var heard_running := hunter.awareness
	_reset()
	_stage(Vector3(0, 0, -19), -90.0)
	_player_at(Vector3(-8.5, 0, -19), -90.0)
	await _wait(0.2)
	await _go(Vector3(-1.0, 0, -19), 3.0, 1.2, false)
	var heard_walking := hunter.awareness
	_check(heard_running > heard_walking, "a runner behind him is heard sooner than a walker (%.2f vs %.2f)" % [heard_running, heard_walking])
	# In front, close, in the dark: seen quickly. He goes from unaware to suspicious to hunting.
	_reset()
	_stage(Vector3(0, 0, -19), 180.0)              # facing +Z (south): player south of him is in front
	_player_at(Vector3(0, 0, -16.8), 0.0)
	var seq: Array[int] = []
	hunter.state_changed.connect(func(s): seq.append(s))
	await _wait(0.1)
	var spotted := await _until(func(): return hunter.state == Hunter.State.HUNTING, 3.0)
	_check(spotted, "close in front of him he notices you within seconds (%s)" % hunter.describe())
	_check(seq.has(Hunter.State.SUSPICIOUS) or seq.has(Hunter.State.HUNTING), "noticing is a progression: %s" % str(seq))
	# A human is nothing to him.
	_reset()
	player.form.set_form_immediate(&"human")
	_stage(Vector3(0, 0, -19), 180.0)
	_player_at(Vector3(0, 0, -16.8), 0.0)
	await _wait(2.5)
	_check(hunter.awareness < 0.05 and hunter.state == Hunter.State.PATROL, "a Human standing in front of him, 2 m away, is just a person (aware %.2f)" % hunter.awareness)
	player.form.set_form_immediate(&"vampire")
	await _wait(1.2)
	_check(hunter.awareness > 0.3 or hunter.state != Hunter.State.PATROL, "...become a vampire in view and he notices (aware %.2f)" % hunter.awareness)
	# A wall hides you.
	_reset()
	_stage(Vector3(0, 0, -13.0), 0.0)               # in the hall, facing the north wall
	_player_at(Vector3(0, 0, -17.2), 180.0)         # outside it, 4 m away
	await _wait(2.5)
	_check(hunter.awareness < 0.05, "4 m away but behind a wall you are neither seen nor heard (aware %.2f)" % hunter.awareness)
	# Mist: slipping through a window, you cannot be seen.
	_reset()
	_stage(Vector3(0, 0, -19), 180.0)
	_player_at(Vector3(0, 0, -17.2), 0.0)
	player.state.set_mode(PlayerState.Mode.TRAVERSING)
	await _wait(1.5)
	_check(hunter.awareness < 0.05 and hunter.state == Hunter.State.PATROL, "as mist, 1.8 m in front of him, you are not there at all")
	player.state.set_mode(PlayerState.Mode.NORMAL)
	# What Sense tells you about him.
	_reset()
	_stage(Vector3(0, 0, -19), -90.0)               # facing +X
	_player_at(Vector3(-6.0, 0, -19), -90.0)        # behind him
	await _wait(0.4)
	var data := hunter.get_sense_data(6.0)
	_check(str(data["detail"]).contains("unaware of you"), "Sense says he is unaware of you: '%s'" % data["detail"])
	_check(data["hint"] == "his back is to you", "...and that his back is to you: '%s'" % data["hint"])
	var calm_color: Color = data["color"]
	hunter._spot()
	hunter.inert = true
	var hot := hunter.get_sense_data(6.0)
	_check(str(hot["detail"]).contains("hunting you") and hot["bpm"] > data["bpm"] * 1.4, "once he hunts you his heart races: %d -> %d bpm" % [roundi(data["bpm"]), roundi(hot["bpm"])])
	_check((hot["color"] as Color).r > 0.9 and (hot["color"] as Color).g < 0.3 and calm_color.g > 0.7, "and the silhouette goes from pale gold to hot red")
	_check(str(hunter.get_sense_data(25.0)["title"]) == "" and str(hunter.get_sense_data(15.0)["title"]) == "a hunter", "far off Sense gives only a heartbeat; nearer, 'a hunter'")
	_check(str(hunter.get_sense_data(6.0)["title"]) == "A hunter", "a stranger until you know his name")
	hunter.known = true
	_check(str(hunter.get_sense_data(6.0)["title"]) == "Hollis Crane, lamplighter", "...and then he has one")
	_reset()


# Later sections are added below by their own functions.
func _test_hunter_combat() -> void:
	print("[HUNT] --- HIS BLADE: a tell, a blow that staggers, a grace period, and a death that costs ---")
	_reset()
	var combat := player.combat
	var p: HunterProfile = hunter.profile
	# He hunts you down and swings: first the tell, then the damage - never the other way round. (In the open
	# yard, so there is room to be thrown back.)
	_stage(Vector3(3, 0, 0), 180.0, Hunter.State.HUNTING, true, true)
	hunter._spot()
	_player_at(Vector3(3, 0, 1.9), 0.0)
	player.camera_rig.yaw = 0.0
	var windup := await _until(func(): return hunter.swing == Hunter.Swing.WINDUP, 3.0)
	_check(windup, "he raises the blade (%s)" % hunter.describe())
	var hp_at_tell := player.health.value
	await _wait(p.attack_windup * 0.5)
	_check(player.health.value == hp_at_tell and hunter.swing == Hunter.Swing.WINDUP, "half way through the wind-up you have not been touched")
	var t0 := Time.get_ticks_msec()
	var hurt_seen := [false]
	var pos_at_hit := [Vector3.ZERO]
	combat.hurt.connect(func(_i, _a):
		hurt_seen[0] = true
		pos_at_hit[0] = player.global_position, CONNECT_ONE_SHOT)
	var landed_in_time := await _until(func(): return hurt_seen[0], 1.0)
	var tell_time := (Time.get_ticks_msec() - t0) / 1000.0 + p.attack_windup * 0.5
	_check(landed_in_time, "then the blade comes down and lands")
	_check(tell_time > p.attack_windup - 0.1 and tell_time < p.attack_windup + 0.3, "after %.2f s of tell (profile: %.2f)" % [tell_time, p.attack_windup])
	_check(_near(hp_at_tell - player.health.value, p.attack_damage, 0.1), "for %.0f damage (100 -> %.0f)" % [p.attack_damage, player.health.value])
	_check(player.state.mode == PlayerState.Mode.STAGGERED, "and you are staggered (%s)" % PlayerState.Mode.keys()[player.state.mode])
	await _wait(0.15)
	var thrown: float = player.global_position.distance_to(pos_at_hit[0])
	_check(thrown > 0.5, "and thrown back (%.2f m in the first moments)" % thrown)
	await _wait(0.4)
	_check(player.state.mode == PlayerState.Mode.NORMAL, "in control again after a third of a second")
	_check(hunter.landed == 1 and hunter.swings >= 1, "the hunter counts one blow landed")
	# Grace: a second blow straight after is refused; after the grace it lands.
	var info := HitInfo.new()
	info.amount = 10.0
	info.origin = hunter.global_position
	info.knockback = 0.0
	info.stagger = 0.0
	combat.invulnerable_left = 0.5
	var hp := player.health.value
	_check(not combat.take_hit(info) and player.health.value == hp, "while the grace lasts a second blow does nothing")
	combat.invulnerable_left = 0.0
	_check(combat.take_hit(info) and _near(player.health.value, hp - 10.0, 0.1), "afterwards it does")
	# Dodge: leave his reach during the wind-up and the blow finds air.
	_reset()
	_stage(Vector3(0, 0, -19), 180.0, Hunter.State.HUNTING, true, true)
	hunter._spot()
	_player_at(Vector3(0, 0, -16.9), 0.0)
	await _until(func(): return hunter.swing == Hunter.Swing.WINDUP, 3.0)
	var swung_hit := [null]
	hunter.swung.connect(func(h): swung_hit[0] = h, CONNECT_ONE_SHOT)
	var hp1 := player.health.value
	_player_at(Vector3(0, 0, -13.0), 0.0)         # 6 m away, in a hurry
	await _until(func(): return swung_hit[0] != null, 1.0)
	_check(swung_hit[0] == false and player.health.value == hp1, "if you are not there when it comes down, it misses")
	# The opening: right after a miss he is in his recovery, and a Rend lands.
	_check(hunter.swing == Hunter.Swing.RECOVER, "he is left recovering")
	_player_at(Vector3(0, 0, -17.2), 0.0)
	player.camera_rig.yaw = 0.0
	hunter.inert = true
	var h0 := hunter.health
	player.combat.reset()
	combat.begin()
	await _wait(0.4)
	_check(hunter.health < h0, "...and a counter-strike into that opening hurts him (%.0f -> %.0f)" % [h0, hunter.health])
	# A plain Rend does not break a wind-up that has started; a strong blow does.
	_reset()
	_stage(Vector3(0, 0, -19), 180.0, Hunter.State.HUNTING, false)
	hunter._spot()
	hunter.inert = true
	hunter._begin_swing()
	var plain := HitInfo.new()
	plain.amount = 20.0
	plain.origin = Vector3(0, 0, -17)
	plain.strong = false
	hunter.receive_strike(plain)
	_check(hunter.swing == Hunter.Swing.WINDUP, "a plain Rend does not stop a swing already begun - trading blows is dangerous")
	var strong := HitInfo.new()
	strong.amount = 20.0
	strong.origin = Vector3(0, 0, -17)
	strong.strong = true
	hunter.receive_strike(strong)
	_check(hunter.swing == Hunter.Swing.NONE and hunter._stagger_t > 0.5, "a lunge, plunge or ambush does: he is staggered for %.1f s" % hunter._stagger_t)
	# He cannot spam it: swings are spaced by the wind-up, the recovery and the gap.
	_reset()
	_stage(Vector3(0, 0, -19), 180.0, Hunter.State.HUNTING, true, true)
	hunter._spot()
	_player_at(Vector3(0, 0, -17.2), 0.0)
	combat.invulnerable_left = 99.0
	await _wait(4.3)
	var spacing := p.attack_windup + p.attack_recovery + p.attack_gap
	_check(hunter.swings >= 2 and hunter.swings <= int(4.3 / spacing) + 1, "in 4.3 s he swung %d times (at most one every %.2f s)" % [hunter.swings, spacing])
	combat.invulnerable_left = 0.0
	# Mist: nothing touches a vampire slipping through a window.
	_reset()
	player.state.set_mode(PlayerState.Mode.TRAVERSING)
	var hp2 := player.health.value
	_check(not combat.take_hit(info) and player.health.value == hp2, "a vampire turned to mist cannot be hurt")
	player.state.set_mode(PlayerState.Mode.NORMAL)
	# A blow tears you off a victim.
	_reset()
	_place(Vector3(6.2, 0, 9.4), 180.0)
	await _wait(0.4)
	Input.action_press(&"feed")
	player.feeding.start(world.tomas)
	await _wait(0.6)
	_check(player.feeding.is_feeding(), "feeding on Tomas")
	info.amount = 5.0
	info.knockback = 3.0
	info.stagger = 0.3
	combat.invulnerable_left = 0.0
	combat.take_hit(info)
	await _wait(0.2)
	Input.action_release(&"feed")
	_check(not player.feeding.is_feeding() and world.tomas.mode == HumanNpc.Mode.FLEEING, "a blow tears you off him mid-feed, and he runs")
	await _wait(0.6)
	# A Human is not attacked.
	_reset()
	player.form.set_form_immediate(&"human")
	_stage(Vector3(0, 0, -19), 180.0, Hunter.State.HUNTING, true, true)
	hunter._spot()
	_player_at(Vector3(0, 0, -17.2), 0.0)
	var hp3 := player.health.value
	await _wait(1.8)
	_check(player.health.value == hp3 and hunter.swings == 0, "a Human right in front of a hunting hunter is not attacked")
	# Dying to him: the banner, the coffin, and what he keeps.
	_reset()
	_stage(Vector3(0, 0, -19), 180.0, Hunter.State.HUNTING, true, true)
	hunter._spot()
	hunter.health = 60.0
	_player_at(Vector3(0, 0, -17.2), 0.0)
	player.health.value = 20.0
	var died := [&""]
	player.health.died.connect(func(c): died[0] = c, CONNECT_ONE_SHOT)
	var dead := await _until(func(): return player.state.is_dead(), 3.0)
	_check(dead and died[0] == &"hunter", "his blade can kill you: died of '%s'" % died[0])
	await _wait(0.4)
	_check(main.hud._banner.text == "THE HUNTER GOT YOU", "the banner says so: '%s'" % main.hud._banner.text)
	await _wait(5.5)
	_check(not player.state.is_dead() and player.form.is_form(&"human"), "you wake in the coffin as a Human")
	_check(player.health.value > 50.0 and player.health.value < 60.0, "weaker than before (%.0f)" % player.health.value)
	_check(hunter.times_killed_player == 1, "he remembers he killed you")
	_check(hunter.health > 60.0 and hunter.health < 80.0, "but his wounds are not forgotten: he mends only a quarter of what he lost (60 -> %.0f)" % hunter.health)
	_check(hunter.wary_left > 60.0, "and he is wary (%.0f s)" % hunter.wary_left)
	_reset()


func _test_escape() -> void:
	print("[HUNT] --- ESCAPE: roofs, windows, the dark, a human face - the vampire's moves matter ---")
	_reset()
	var prof: HunterProfile = hunter.profile
	var give_up_backup := prof.give_up_unreachable
	var search_backup := prof.search_seconds
	prof.give_up_unreachable = 2.5
	prof.search_seconds = 1.5
	# A roof is out of his reach: he goes to its foot, cannot strike, and gives up.
	player.place_at(Vector3(-5.0, 3.95, -6.9), PI)
	await _wait(0.4)
	_check(player.is_on_floor() and player.global_position.y > 3.5, "standing on the manor roof (y %.1f)" % player.global_position.y)
	_stage(Vector3(-5.0, 0, -2.0), 0.0, Hunter.State.HUNTING, true, true)
	hunter._spot()
	var hp := player.health.value
	await _wait(2.0)
	var d_flat := Vector2(hunter.global_position.x - player.global_position.x, hunter.global_position.z - player.global_position.z).length()
	_check(d_flat < 3.5, "he comes to the foot of the wall and stands glaring up (%.1f m off)" % d_flat)
	_check(hunter.swings == 0 and player.health.value == hp, "but he cannot strike a roof")
	var gave_up := await _until(func(): return hunter.state == Hunter.State.SEARCHING or hunter.state == Hunter.State.PATROL, 4.0)
	_check(gave_up, "and after a few seconds he gives up on you (%s)" % hunter.describe())
	# Through a window: he has to go round by the door.
	_reset()
	prof.give_up_unreachable = 2.5
	prof.search_seconds = 1.5
	var link: TraversalLink
	for l in world.traversal_links:
		if l.placement.id == &"manor_window":
			link = l
	_stage(Vector3(6.2, 0, -1.6), 0.0, Hunter.State.HUNTING, true, true)    # outside, facing the window
	hunter._spot()
	_player_at(Vector3(6.2, 0.05, -4.0), 0.0)
	player.camera_rig.yaw = 0.0
	await _wait(0.3)
	_check(player.traversal.start(link, 0), "slipping in through the manor window")
	await _wait(TraversalController.route_duration(link.placement) + 0.5)
	_check(player.global_position.z < -6.8, "now inside the manor (z %.1f)" % player.global_position.z)
	_player_at(Vector3(-1.0, 0, -9.0), 0.0)      # out of line of the window
	hunter._los = false
	await _wait(0.7)
	_check(hunter.global_position.z > -5.6, "he cannot follow through the window: after a moment he is still outside (z %.1f)" % hunter.global_position.z)
	var door_dist := Vector2(hunter.global_position.x - 3.0, hunter.global_position.z + 5.0).length()
	_check(door_dist < 4.0, "heading for the door instead (%.1f m from it)" % door_dist)
	var came_in := await _until(func(): return hunter.global_position.z < -6.4, 6.0)
	_check(came_in, "and he does come in by the door (z %.1f)" % hunter.global_position.z)
	# Losing him: out of sight three seconds and he starts searching, then goes back to his round, warier.
	_reset()
	prof.search_seconds = 1.5
	_stage(Vector3(0, 0, -19), 180.0, Hunter.State.HUNTING, true, true)
	hunter._spot()
	_player_at(Vector3(-5.0, 0, -10.0), 0.0)      # inside the crypt, behind walls
	await _wait(0.5)
	_check(hunter.state == Hunter.State.HUNTING, "still hunting a moment after you vanish")
	var searching := await _until(func(): return hunter.state == Hunter.State.SEARCHING, 5.0)
	_check(searching, "after a few seconds out of sight he is searching, not hunting")
	_player_at(Vector3(25.0, 0, -15.0), 0.0)       # slip well away while he searches the spot
	var patrol_again := await _until(func(): return hunter.state == Hunter.State.PATROL, 14.0)
	_check(patrol_again and hunter.wary_left > 30.0, "then he gives up and returns to his round, wary (%.0f s)" % hunter.wary_left)
	# A human face: change shape and he is not sure what he saw.
	_reset()
	prof.search_seconds = 1.5
	_stage(Vector3(0, 0, -19), 180.0, Hunter.State.HUNTING, true, true)
	hunter._spot()
	_player_at(Vector3(6.0, 0, -19.0), 0.0)
	await _wait(0.3)
	player.form.set_form_immediate(&"human")
	var hp4 := player.health.value
	var unsure := await _until(func(): return hunter.state == Hunter.State.SEARCHING, 4.0)
	_check(unsure and player.health.value == hp4, "turning human mid-chase: after a couple of seconds he is searching, and has not struck you (%s)" % hunter.describe())
	prof.give_up_unreachable = give_up_backup
	prof.search_seconds = search_backup
	_reset()


func _test_down_and_feed() -> void:
	print("[HUNT] --- DOWN: drink him, or leave him and he returns ---")
	_reset()
	_stage(Vector3(0, 0, -19), 180.0, Hunter.State.DOWNED, false)
	hunter.health = 0.0
	_player_at(Vector3(1.4, 0, -19.4), 90.0)
	player.camera_rig.yaw = deg_to_rad(90.0)
	await _wait(0.7)
	_check(hunter.is_lying() and hunter.can_be_fed() and not hunter.can_be_struck(), "he lies there, alive")
	_check(_prompt() == "Drink from the lamplighter", "the prompt: '%s'" % _prompt())
	_check(hunter.get_sense_data(5.0)["hint"] == "his memory waits", "Sense says his memory waits")
	# Human: nothing to do with him.
	player.form.set_form_immediate(&"human")
	await _wait(0.5)
	_check(_prompt() == "none", "a Human has no prompt for him ('%s')" % _prompt())
	player.form.set_form_immediate(&"vampire")
	await _wait(0.4)
	# What his blood is worth, against a person's and a fox's.
	var his: Dictionary = hunter.get_feed_result()
	var tomas_yield: float = world.tomas.get_feed_result()["yield"]
	var fox_yield: float = world.animals[0].get_feed_result()["yield"]
	_check(float(his["yield"]) > tomas_yield and tomas_yield > fox_yield, "worth more than a person, who is worth more than a fox: %.0f > %.0f > %.0f" % [his["yield"], tomas_yield, fox_yield])
	var fury := ContentRegistry.get_def(&"FeedStyle", &"afraid") as FeedStyle
	_check(float(his["surge_power"]) > fury.surge_power and float(his["surge_seconds"]) > fury.surge_seconds, "and leaves the strongest, longest Bloodrush: %s %.2f for %.0f s" % [his["surge_name"], his["surge_power"], his["surge_seconds"]])
	# An early release leaves him as he was.
	_set_blood(20.0)
	Input.action_press(&"feed")
	await _until(func(): return player.feeding.is_feeding(), 2.0)
	await _wait(0.8)
	Input.action_release(&"feed")
	await _wait(0.4)
	_check(hunter.state == Hunter.State.DOWNED and not player.feeding.is_feeding(), "let go early and he is still down, still alive")
	var partial := player.blood.value - 20.0
	_check(partial > 5.0 and partial < 30.0, "having taken only part (%.0f blood)" % partial)
	# Drink him dry.
	_set_blood(20.0)
	var drained := [false]
	hunter.drained.connect(func(): drained[0] = true, CONNECT_ONE_SHOT)
	Input.action_press(&"feed")
	await _until(func(): return drained[0], 7.0)
	Input.action_release(&"feed")
	_check(drained[0] and hunter.state == Hunter.State.DEAD, "held to the end, he is drunk dry: dead")
	_check(player.blood.value >= 20.0 + 55.0 and player.blood.value <= 100.0, "that fills the vessel: 20 -> %.0f" % player.blood.value)
	_check(await _wait_memory(3.0), "and his blood has something to say")
	_check(main.memory_view._title.text == "The Lamp Is Lit", "the memory is 'The Lamp Is Lit'")
	await _dismiss_memory()
	_check(player.surge.active and player.surge.surge_name == "Hunter's Rush" and player.surge.power > 1.4, "a Hunter's Rush follows (%.2f x %.0f s)" % [player.surge.power, player.surge.seconds_left])
	await _wait(0.8)
	_check(player.get_speed_multiplier() > 1.1, "it makes you faster (x%.2f)" % player.get_speed_multiplier())
	_check(not hunter.is_sense_visible() and not hunter.can_be_struck() and not hunter.can_be_fed(), "he is gone to Sense, to blows and to feeding")
	_check(HumanNpc.tasted.get(&"lamplighter", {}).has(&"hunter"), "his memory is marked as heard")
	_check(hunter.get_feed_result()["memory"] == "", "and would not be told again")
	await _wait(0.4)
	_check(main.hunt.stage == HuntDirector.Stage.DONE, "the hunt reads DONE")
	_check(main.hud.objective_summary().contains(main.hunt.definition.text_done), "and the line under the clock says the lantern is out")
	player.surge.stop(false)
	# Left alive, he returns - mended but not whole.
	_reset()
	_stage(Vector3(0, 0, -19), 180.0, Hunter.State.DOWNED, false)
	hunter.health = 0.0
	hunter.inert = false
	await _wait(0.3)
	_check(hunter.state == Hunter.State.DOWNED, "left alone (even through the hours) he stays down")
	world.coffin.wake(player, &"rest", 19.5)
	await _wait(6.5)
	_check(hunter.health >= hunter.profile.max_health * 0.59, "after you sleep he has mended most of the way (%.0f of %.0f)" % [hunter.health, hunter.profile.max_health])
	var back := await _until(func(): return hunter.state == Hunter.State.PATROL, 3.0)
	_check(back and hunter.visible, "and at dusk he is back on his round (%s)" % hunter.describe())
	_check(hunter.model.body.rotation.x < 0.2, "on his feet")
	_reset()


func _test_objective() -> void:
	print("[HUNT] --- OBJECTIVE: one line, read off the world; the clues are things already there ---")
	_reset(14.0)
	Inspectable.reset()
	HumanNpc.heard.clear()
	main.hunt.sighted = false
	_player_at(Vector3(3, 0, 3), 0.0)
	player.form.set_form_immediate(&"human")
	await _wait(0.6)
	var hunt := main.hunt
	var def := hunt.definition
	_check(hunt.active() and def != null and hunt.hunter == hunter, "the hunt is running and knows its quarry")
	_check(hunt.stage == HuntDirector.Stage.RUMOR, "by day, before anything is known: a rumour")
	_check(main.hud.objective_visible() and main.hud.objective_summary().contains("THE HUNT") and main.hud.objective_summary().contains(def.text_rumor), "the line says so: '%s'" % main.hud.objective_summary().replace("\n", " | ").left(110))
	_check(hunt.clue_count() == 6 and hunt.clues_known() == 0, "six leads, none known")
	# Read the wax under the north window.
	_place(Vector3(1.0, 0, -17.8), 180.0)
	await _wait(0.6)
	await _tap(&"interact")
	await _wait(0.6)
	_check(hunt.clues_known() == 1 and main.hud.objective_summary().contains("Learned: Wax and lavender oil"), "reading the wax is a lead, and the line shows it")
	_check(main.hud._obj_title.text.contains("1 of 6"), "'%s'" % main.hud._obj_title.text)
	# Something Elise says (told at night).
	HumanNpc.heard[&"elise"] = {&"lantern": true}
	await _wait(0.6)
	_check(hunt.clues_known() == 2 and main.hud.objective_summary().contains("A lantern moves behind the manor"), "a villager's word is a lead too")
	# The camp.
	_place(Vector3(-12.2, 0, -19.3), 0.0)
	player.camera_rig.yaw = 0.0
	await _wait(0.6)
	_check(_prompt() == "Read the hunter's journal", "at the hunter's camp: '%s'" % _prompt())
	await _tap(&"interact")
	await _wait(0.6)
	_check(hunt.clues_known() == 3 and hunter.known, "the journal is a lead, and tells you his name")
	_check(main.hud._toast_label.text.contains("Lavender on my boots"), "...and what he thinks")
	# After dark with him about: sighted, engaged, wary, down, done, withdrawn.
	_reset()
	player.form.set_form_immediate(&"vampire")
	_stage(Vector3(0, 0, -19), -90.0)
	_player_at(Vector3(-7.0, 0, -19), -90.0)
	var sense := player.abilities.get_ability(&"vampiric_sense")
	sense.activate()
	await _wait(1.0)
	_check(hunt.sighted and hunt.stage == HuntDirector.Stage.SIGHTED, "Sensing him with a hunter on his round: sighted (%s)" % HuntDirector.Stage.keys()[hunt.stage])
	_check(main.hud._obj_text.text == def.text_sighted, "the line changes: '%s'" % main.hud._obj_text.text.left(60))
	sense.deactivate()
	hunter._spot()
	hunter.inert = true
	await _wait(0.6)
	_check(hunt.stage == HuntDirector.Stage.ENGAGED and main.hud._obj_text.text == def.text_engaged, "when he sees you: engaged")
	_check(main.hud._toast_label.text == "He has seen you.", "with a plain word on the screen")
	hunter._begin_search(Vector3(0, 0, -19))
	hunter.inert = true
	await _wait(0.6)
	_check(hunt.stage == HuntDirector.Stage.WARY and main.hud._obj_text.text == def.text_wary, "when he loses you: wary")
	hunter._resume_patrol()
	await _wait(0.6)
	_check(hunt.stage == HuntDirector.Stage.SIGHTED, "when he gives up, you are back to watching him")
	var big := HitInfo.new()
	big.amount = 500.0
	big.origin = Vector3(0, 0, -17)
	big.strong = true
	hunter.receive_strike(big)
	await _wait(0.6)
	_check(hunter.state == Hunter.State.DOWNED and hunt.stage == HuntDirector.Stage.DOWN and main.hud._obj_text.text == def.text_down, "down: drink him or leave him")
	hunter.begin_feed(player)
	hunter.finish_feed()
	await _wait(0.6)
	_check(hunt.stage == HuntDirector.Stage.DONE and main.hud._toast_label.text.contains("The lantern goes out"), "dead: the hunt is over")
	HumanNpc.tasted.erase(&"lamplighter")
	_reset()
	await _wait(0.6)
	_check(hunt.stage == HuntDirector.Stage.WITHDRAWN and main.hud._obj_text.text == def.text_withdrawn, "away for the day, having been seen: he will be back at dusk")
	hunt.sighted = false
	Inspectable.reset()
	HumanNpc.heard.clear()
	_reset()


func _test_hours() -> void:
	print("[HUNT] --- HOURS: dusk to dawn, and the sky ends it ---")
	_reset(14.0)
	_player_at(Vector3(30.0, 0, 20.0), 0.0)      # nowhere near his camp
	hunter.inert = false
	await _wait(0.7)
	_check(hunter.state == Hunter.State.AWAY and not hunter.visible, "by day he is not in the world")
	main.tod.set_hour(19.2)
	await _wait(0.9)
	_check(hunter.state == Hunter.State.PATROL and hunter.visible, "at dusk he comes out (%s)" % hunter.describe())
	_check(hunter.global_position.distance_to(world.location.hunters[0].camp) < 8.0, "from his camp in the pines")
	_check(main.hud._toast_label.text.contains("lantern kindles"), "and the screen says where: '%s'" % main.hud._toast_label.text)
	await _wait(1.5)
	_check(Vector2(hunter.velocity.x, hunter.velocity.z).length() > 0.5 or hunter._linger > 0.0, "he is walking his round")
	main.tod.set_hour(5.2)
	await _wait(0.8)
	_check(hunter.state == Hunter.State.RETIRING, "at five, if nothing is happening, he starts back to camp")
	hunter.global_position = world.location.hunters[0].camp + Vector3(1.0, 0, 0.5)
	var gone := await _until(func(): return hunter.state == Hunter.State.AWAY, 3.0)
	_check(gone and not hunter.visible, "and when he is home he is gone")
	# A fight at dawn goes on until the sky says otherwise.
	_night(5.2)
	_stage(Vector3(0, 0, -19), 180.0, Hunter.State.HUNTING, true, true)
	hunter._spot()
	_player_at(Vector3(0, 0, -5.0), 0.0)        # far from him, behind walls
	await _wait(0.9)
	_check(hunter.state == Hunter.State.HUNTING or hunter.state == Hunter.State.SEARCHING, "a hunt in progress at 5:12 is not dropped (%s)" % hunter.describe())
	main.tod.set_hour(5.9)
	await _wait(0.9)
	_check(hunter.state == Hunter.State.RETIRING or hunter.state == Hunter.State.AWAY, "but by 5:54 the dawn drives him off (%s)" % hunter.describe())
	# Switched off, he stays away; switched on, he returns.
	_night(23.0)
	_stage(Vector3(0, 0, -19), 180.0)
	hunter.hold = true
	Hunter.enabled = false
	await _wait(0.7)
	_check(hunter.state == Hunter.State.AWAY, "with hunters disabled he stands down")
	Hunter.enabled = true
	await _wait(0.8)
	_check(hunter.state == Hunter.State.PATROL, "and when they are enabled he is back")
	# The sun is still a vampire's master: at day, outdoors, it burns whether or not there is a hunter.
	_reset(7.5)
	_player_at(Vector3(3, 0, 3), 0.0)
	await _wait(1.5)
	_check(player.sunlight.strength > 0.0 and player.sunlight.stage >= 0, "at 7:30 in the open the sun still bites (strength %.2f)" % player.sunlight.strength)
	_reset()


func _test_consequences() -> void:
	print("[HUNT] --- CONSEQUENCES: noise, wounds, blood - lightly, not as punishment ---")
	_reset()
	var tomas := world.tomas
	# A fight is loud: Tomas, awake nearby, grows uneasy or runs.
	_stage(Vector3(6.5, 0, 6.0), 180.0, Hunter.State.HUNTING, false)
	hunter._spot()
	hunter.inert = true
	_player_at(Vector3(6.5, 0, 7.7), 0.0)
	player.camera_rig.yaw = 0.0
	tomas.awareness = 0.0
	await _wait(0.4)
	await _tap(&"attack")
	await _wait(0.6)
	_check(tomas.awareness > 0.3 or tomas.mode == HumanNpc.Mode.FLEEING, "a fight 3 m from Tomas is heard: he is uneasy or running (aware %.2f, %s)" % [tomas.awareness, HumanNpc.Mode.keys()[tomas.mode]])
	# Being hurt costs: the body mends on blood, so a wound is a debt.
	_reset()
	_player_at(Vector3(0, 0, -19), 0.0)
	player.health.value = 50.0
	player.health.changed.emit(50.0, 100.0)
	_set_blood(60.0)
	var b0 := player.blood.value
	await _wait(3.0)
	var healed := player.health.value - 50.0
	var spent := b0 - player.blood.value
	_check(healed > 8.0, "a wounded vampire mends: +%.0f health in three seconds" % healed)
	_check(spent > healed * 0.4, "and it costs blood: %.1f spent for %.0f health" % [spent, healed])
	# In a Bloodrush wounds close faster and free.
	_reset()
	player.health.value = 50.0
	_set_blood(60.0)
	player.surge.start(1.0, 30.0, "Bloodrush")
	await _wait(0.8)
	var b1 := player.blood.value
	var h1 := player.health.value
	await _wait(2.0)
	_check(player.health.value - h1 > 9.0 and b1 - player.blood.value < 1.0, "in a Bloodrush wounds close twice as fast and free (+%.0f hp for %.1f blood)" % [player.health.value - h1, b1 - player.blood.value])
	player.surge.stop(false)
	# He is warier after you: he sees further.
	var p: HunterProfile = hunter.profile
	_check(CombatRules.sight_radius(p.sight_range, p.dark_sight_factor, 0.0, 1.35) > CombatRules.sight_radius(p.sight_range, p.dark_sight_factor, 0.0, 1.0) * 1.3, "a wary hunter sees a third further in the dark")
	# A hunter who is hurt stays angry.
	_reset()
	_stage(Vector3(0, 0, -19), -90.0)
	var plain := HitInfo.new()
	plain.amount = 10.0
	plain.origin = Vector3(-3, 0, -19)
	hunter.receive_strike(plain)
	_check(hunter.state == Hunter.State.HUNTING and hunter.wary_left > 60.0, "a hurt hunter is a hunting, wary one")
	_reset()


func _test_hud() -> void:
	print("[HUNT] --- HUD: you can always tell what is happening ---")
	_reset()
	var hud := main.hud
	var cm: CombatHud = hud._combat
	# The ring.
	_stage(Vector3(0, 0, -19), -90.0)
	_player_at(Vector3(-4.0, 0, -19), -90.0)
	cm._recent = 0.0
	await _wait(0.8)
	_check(cm.ring_visible(), "a vampire with a hunter about sees the strike ring")
	_check(cm.hint_text().contains("Ambush") and cm.hint_text().contains("R"), "and, with an unaware hunter in reach, the one word that tells you: '%s'" % cm.hint_text())
	player.form.set_form_immediate(&"human")
	cm._recent = 0.0
	await _wait(0.9)
	_check(not cm.ring_visible() and cm.hint_text() == "", "a Human has neither")
	player.form.set_form_immediate(&"vampire")
	hunter._spot()
	hunter.inert = true
	await _wait(0.9)
	_check(cm.hint_text() == "", "once he is hunting there is nothing to ambush")
	_reset()
	await _wait(0.9)
	cm._recent = 0.0
	await _wait(0.9)
	_check(not cm.ring_visible(), "with nobody about the ring is gone")
	# The ring runs while Rend swings.
	_stage(Vector3(0, 0, -30), 0.0, Hunter.State.PATROL, false)
	cm._recent = 4.0
	await _tap(&"attack")
	await _wait(0.25)
	_check(player.combat.progress() > 0.1 and player.combat.progress() < 1.0, "mid-swing the ring shows %.0f%%" % (player.combat.progress() * 100.0))
	await _wait(0.6)
	# Chips and status.
	_check(hud._chip_rend.visible, "the Rend chip is on the HUD for a vampire")
	player.form.set_form_immediate(&"human")
	await _wait(0.3)
	_check(not hud._chip_rend.visible, "...not for a Human")
	player.form.set_form_immediate(&"vampire")
	player.health.value = 72.0
	player.health.changed.emit(72.0, 100.0)
	await _wait(0.4)
	_check(hud._status_label.text.contains("WOUNDED"), "'%s' beside the vessel" % hud._status_label.text)
	player.health.revive(1.0)
	# The hunter's own readout.
	_reset()
	_stage(Vector3(0, 0, -19), 180.0, Hunter.State.PATROL, false)
	_player_at(Vector3(0, 0, -14.0), 0.0)
	await _wait(0.3)
	_check(not hunter._hp_fill.visible and not hunter._aw_fill.visible, "an untroubled hunter shows no bars")
	hunter.awareness = 0.5
	await _wait(0.2)
	_check(hunter._aw_fill.visible and hunter._alert.text == "?", "suspecting you: a '?' and an amber bar")
	hunter.awareness = 0.0
	hunter._spot()
	hunter.inert = true
	await _wait(0.2)
	_check(hunter._alert.text == "!" and hunter._hp_fill.visible, "hunting you: a '!' and his health")
	var h_full := hunter._hp_fill.region_rect.size.x
	var hit := HitInfo.new()
	hit.amount = 60.0
	hit.origin = Vector3(0, 0, -17)
	hunter.receive_strike(hit)
	await _wait(0.2)
	_check(_near(hunter._hp_fill.region_rect.size.x, h_full * 0.5, 2.0), "hurt for half, the bar is half (%.0f of %.0f px)" % [hunter._hp_fill.region_rect.size.x, h_full])
	_check(hunter.get_node_or_null("Overhead") != null, "the readout hangs over his head, in the world")
	var numbers := 0
	for c in hunter.get_children():
		if c is Label3D and (c as Label3D).text.begins_with("-"):
			numbers += 1
	_check(numbers >= 1, "and the blow showed its number, rising off him")
	hunter.health = 0.0
	hunter._set_state(Hunter.State.DEAD)
	await _wait(0.2)
	_check(not hunter._hp_fill.visible and hunter._alert.text == "", "dead, he has no readout")
	# Where a blow came from.
	_reset()
	var info := HitInfo.new()
	info.amount = 5.0
	info.origin = player.global_position + Vector3(5, 0, 0)
	player.camera_rig.yaw = 0.0
	player.combat.take_hit(info)
	await _wait(0.1)
	_check(cm.hurt_arcs() >= 1, "a red arc points at whoever hit you")
	# The edges of the screen stay red while you are badly hurt.
	_reset()
	player.health.value = 20.0
	await _wait(1.8)
	_check(main.screen_fx.level(&"wound") > 0.3, "badly wounded, the edges of the world stay red (%.2f)" % main.screen_fx.level(&"wound"))
	player.health.revive(1.0)
	_reset()


func _test_regressions() -> void:
	print("[HUNT] --- THE OLD GAME: Sense, feeding, change, the coffin - still themselves ---")
	_reset()
	_stage(Vector3(11.5, 0, -5.5), 0.0, Hunter.State.PATROL, true)
	_player_at(Vector3(6.5, 0, 5.0), 0.0)
	_set_blood(60.0)
	var sense := player.abilities.get_ability(&"vampiric_sense")
	sense.activate()
	await _wait(1.8)
	_check(world.tomas.get_node("SenseTarget").revealed and hunter._sense.revealed, "Sense reveals the villagers and the hunter alike")
	_check(str(world.tomas.get_sense_data(6.0)["detail"]).contains("bpm") and str(hunter.get_sense_data(8.0)["detail"]).contains("bpm"), "each with a pulse")
	_check(player.abilities.get_ability(&"vampiric_sense").current_cost_per_sec() > 0.0, "and Sense still costs blood while it runs")
	sense.deactivate()
	# Feeding on a person is as before.
	_reset()
	_place(Vector3(6.2, 0, 9.4), 180.0)
	_set_blood(30.0)
	await _wait(0.5)
	Input.action_press(&"feed")
	await _until(func(): return player.feeding.is_feeding(), 2.0)
	await _until(func(): return not player.feeding.is_feeding() and world.tomas.mode == HumanNpc.Mode.DRAINED, 7.0)
	Input.action_release(&"feed")
	_check(world.tomas.mode == HumanNpc.Mode.DRAINED and player.blood.value > 30.0 + 40.0, "feeding on Tomas still fills the vessel: 30 -> %.0f" % player.blood.value)
	await _dismiss_memory()
	_check(player.surge.active, "and still leaves a Bloodrush")
	player.surge.stop(false)
	# Changing shape still works with a hunter about.
	_reset()
	_stage(Vector3(0, 0, -30), 0.0, Hunter.State.PATROL, false)
	player.form.set_form_immediate(&"human")
	player.form.request_toggle()
	await _wait(player.form.transform_time + 0.4)
	_check(player.form.is_form(&"vampire") and player.state.mode == PlayerState.Mode.NORMAL, "the transformation still plays out and hands control back")
	# The coffin still rests and wakes.
	world.coffin.wake(player, &"rest", 19.5)
	await _wait(6.5)
	_check(player.state.mode == PlayerState.Mode.NORMAL and main.tod.hour >= 19.4, "sleeping in the coffin still skips to the hour you chose")
	_reset()


