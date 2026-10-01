class_name Animal
extends FeedSource
## A wild animal the vampire can drink from: the second kind of blood. Deliberately simple.
##
## It keeps to a den, wanders within a few metres of it, bolts from what frightens it (a Vampire much
## more than a Human, a sprinting one most of all), and goes to ground by day if it is a night animal.
## Drink from it and it is drained, slinks off to its den and is gone for a while. Its blood is quick,
## simple and safe (quiet, hardly anyone minds) but smaller than a person's; the first drink also holds a
## memory, a creature's-eye one, and after that a fox is a meal rather than a memory.
##
## Everything that varies is data (AnimalProfile, FeedStyle `wild`, BloodDefinition `wild`); this class is
## only the behaviour. It answers the FeedSource interface, so FeedingController needs no special case.

enum Mode { SLEEPING, IDLE, WANDER, ALERT, FLEE, ENTRANCED, DRAINED, GONE }

signal mode_changed(new_mode: Mode)

@export var profile: AnimalProfile
@export var gravity := 20.0

## Where it sleeps by day and returns to.
var den := Vector3.ZERO
var mode: Mode = Mode.IDLE
var awareness := 0.0
var blood_left := 1.0
var model: AnimalModel

var _player: Player
var _tod: TimeOfDay
var _body_shape: CollisionShape3D
var _alert_label: Label3D
var _sense: SenseTarget
var _interactable: AnimalInteractable
var _target := Vector3.ZERO
var _homing := false
var _timer := 0.0
var _flee_timer := 0.0
var _flee_mult := 1.0
var _flee_total := 0.0
var _gone_timer := 0.0
var _away_left := 0.0
var _stuck_timer := 0.0
var _stuck_ref := Vector3.ZERO
var _was_asleep := false
var _was_hunted := false
var _seed := randf() * 10.0


func _ready() -> void:
	add_to_group(&"animals")
	collision_layer = 0
	collision_mask = 1
	if den == Vector3.ZERO:
		den = global_position
	_body_shape = CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.2
	cap.height = 0.56
	_body_shape.shape = cap
	_body_shape.position = Vector3(0, 0.28, 0)
	add_child(_body_shape)
	model = AnimalModel.new()
	add_child(model)
	model.setup(profile.fur_color, profile.belly_color, profile.tail_tip_color, profile.dark_color, profile.body_scale)
	_alert_label = Label3D.new()
	_alert_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_alert_label.no_depth_test = true
	_alert_label.modulate = Color(1.0, 0.8, 0.3)
	_alert_label.outline_modulate = Color(0, 0, 0, 1)
	_alert_label.font_size = 72
	_alert_label.pixel_size = 0.005
	_alert_label.outline_size = 10
	_alert_label.position = Vector3(0, 0.95, 0)
	_alert_label.text = ""
	add_child(_alert_label)
	# Vampiric Sense: a small, quick heart.
	_sense = SenseTarget.new()
	_sense.kind = &"living"
	_sense.max_range = 34.0
	_sense.label_range = 16.0
	_sense.label_offset = Vector3(0, 0.8, 0)
	_sense.heartbeat_audio = true
	_sense.position = Vector3(0, 0.3, 0)
	add_child(_sense)
	_interactable = AnimalInteractable.new()
	_interactable.animal = self
	_interactable.interact_range = 2.3
	_interactable.position = Vector3(0, 0.3, 0)
	add_child(_interactable)
	snap_to_schedule()


# ---------------------------------------------------------------- the day

## The animal's own clock: a night animal sleeps when it is light, a day animal when it is dark.
func is_sleepy() -> bool:
	if _tod == null:
		_tod = get_tree().get_first_node_in_group(&"time_of_day") as TimeOfDay
	if _tod == null:
		return false
	return (_tod.darkness() < 0.3) == profile.nocturnal


## Back to its routine, whole and rested (a new night: the player slept). Used at spawn too.
func snap_to_schedule() -> void:
	blood_left = 1.0
	awareness = 0.0
	_flee_total = 0.0
	_homing = false
	visible = true
	_body_shape.set_deferred("disabled", false)
	model.limp = 0.0
	_alert_label.text = ""
	velocity = Vector3.ZERO
	if is_sleepy():
		global_position = den
		_set_mode(Mode.SLEEPING)
	else:
		_set_mode(Mode.IDLE)
		_timer = randf_range(0.5, 2.0)


func new_day() -> void:
	snap_to_schedule()


func _set_mode(m: Mode) -> void:
	if m == mode:
		return
	mode = m
	mode_changed.emit(m)


func _physics_process(delta: float) -> void:
	if _player == null:
		_player = get_tree().get_first_node_in_group(&"player") as Player
	if _tod == null:
		_tod = get_tree().get_first_node_in_group(&"time_of_day") as TimeOfDay
	match mode:
		Mode.SLEEPING:
			_sleeping(delta)
		Mode.IDLE:
			_idle(delta)
		Mode.WANDER:
			_wander(delta)
		Mode.ALERT:
			_alert(delta)
		Mode.FLEE:
			_flee(delta)
		Mode.DRAINED:
			_drained(delta)
		Mode.GONE:
			_gone(delta)
			return
		_:
			_brake(delta)
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = 0.0
	move_and_slide()
	var flat := Vector2(velocity.x, velocity.z).length()
	if mode != Mode.ENTRANCED:
		model.asleep = move_toward(model.asleep, 1.0 if mode == Mode.SLEEPING else 0.0, delta * 2.0)
	model.animate(flat, delta)


func _brake(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, 30.0 * delta)
	velocity.z = move_toward(velocity.z, 0.0, 30.0 * delta)


func _sleeping(delta: float) -> void:
	_brake(delta)
	_notice(delta)
	if mode == Mode.SLEEPING and not is_sleepy():
		_timer -= delta
		if _timer <= 0.0:
			_set_mode(Mode.IDLE)
			_timer = randf_range(1.0, 3.0)
	else:
		_timer = randf_range(1.0, 5.0)


func _idle(delta: float) -> void:
	_brake(delta)
	_notice(delta)
	if mode != Mode.IDLE:
		return
	# Sniff about: look around slowly.
	rotation.y += sin(Time.get_ticks_msec() / 1000.0 * 0.9 + _seed) * 0.4 * delta
	if is_sleepy():
		_head_home()
		return
	_timer -= delta
	if _timer <= 0.0:
		_pick_wander_target()
		_set_mode(Mode.WANDER)


func _wander(delta: float) -> void:
	_notice(delta)
	if mode != Mode.WANDER:
		return
	var to := _target - global_position
	to.y = 0.0
	if to.length() < 0.35:
		_arrive()
		return
	var dir := to.normalized()
	velocity.x = dir.x * profile.walk_speed
	velocity.z = dir.z * profile.walk_speed
	_turn_toward(dir, delta, 7.0)
	# Blocked? Pick somewhere else rather than paw at a wall.
	_stuck_timer += delta
	if _stuck_timer > 1.2:
		if global_position.distance_to(_stuck_ref) < 0.25:
			_pick_wander_target()
		_stuck_ref = global_position
		_stuck_timer = 0.0


func _arrive() -> void:
	velocity.x = 0.0
	velocity.z = 0.0
	if _homing and is_sleepy():
		_homing = false
		_set_mode(Mode.SLEEPING)
		_timer = randf_range(1.0, 4.0)
	else:
		_set_mode(Mode.IDLE)
		_timer = randf_range(1.5, 4.5)


func _head_home() -> void:
	if global_position.distance_to(den) < 0.6:
		_homing = true
		_arrive()
		return
	_target = den
	_homing = true
	_stuck_timer = 0.0
	_stuck_ref = global_position
	_set_mode(Mode.WANDER)


## Somewhere within its range, with nothing in the way.
func _pick_wander_target() -> void:
	_homing = false
	_stuck_timer = 0.0
	_stuck_ref = global_position
	var space := get_world_3d().direct_space_state
	for _i in 6:
		var a := randf() * TAU
		var r := randf_range(1.0, profile.roam_radius)
		var spot := den + Vector3(cos(a) * r, 0.0, sin(a) * r)
		var q := PhysicsRayQueryParameters3D.create(global_position + Vector3(0, 0.3, 0), spot + Vector3(0, 0.3, 0), 1)
		if space.intersect_ray(q).is_empty():
			_target = spot
			return
	_target = den


# ---------------------------------------------------------------- fright

func _player_speed() -> float:
	return Vector2(_player.velocity.x, _player.velocity.z).length() if _player != null else 0.0


## How far away it notices the player right now: far for a Vampire, near for a Human, farther for a
## sprint, short while it sleeps.
func notice_radius() -> float:
	if _player == null:
		return 0.0
	var r := profile.notice_vampire if _player.form.current.frightens_humans else profile.notice_human
	r *= 1.0 + clampf(_player_speed() / 9.0, 0.0, 1.0) * 0.5
	if mode == Mode.SLEEPING:
		r *= 0.35
	return r


func _line_of_sight() -> bool:
	var from := global_position + Vector3(0, 0.35, 0)
	var q := PhysicsRayQueryParameters3D.create(from, _player.global_position + Vector3(0, 1.2, 0), 1)
	return get_world_3d().direct_space_state.intersect_ray(q).is_empty()


## Awareness of the player builds when they are close enough, in view (or loud) and in sight; it fades
## when they are not. Full awareness startles it.
func _notice(delta: float) -> void:
	var rate := 0.0
	if _player != null and not _player.state.is_dead():
		var to := _player.global_position - global_position
		to.y = 0.0
		var d := to.length()
		var radius := notice_radius()
		if d < radius:
			var facing := (-global_transform.basis.z).dot(to.normalized()) if d > 0.05 else 1.0
			var loud := _player_speed() > 6.0 and d < radius * 0.8
			if (facing > -0.2 or d < 2.6 or loud) and _line_of_sight():
				rate = lerpf(0.9, 2.6, 1.0 - d / radius)
				if mode == Mode.SLEEPING:
					rate *= 0.45   # a sleeper takes a while: there is time to creep up and drink
	if rate > 0.0:
		awareness += rate * delta
	else:
		awareness -= 0.5 * delta
	awareness = clampf(awareness, 0.0, 1.0)
	_alert_label.text = "!" if awareness > 0.5 else ("?" if awareness > 0.2 else "")
	if awareness >= 1.0:
		_startle()


func _startle() -> void:
	if mode != Mode.SLEEPING and mode != Mode.IDLE and mode != Mode.WANDER:
		return
	var was_asleep := mode == Mode.SLEEPING
	_set_mode(Mode.ALERT)
	_timer = 0.55 if was_asleep else 0.2
	velocity = Vector3.ZERO
	_flee_mult = 1.0
	_alert_label.text = "!"


func _alert(delta: float) -> void:
	_brake(delta)
	if _player != null:
		_turn_toward(_player.global_position - global_position, delta, 10.0)
	_timer -= delta
	if _timer <= 0.0:
		_set_mode(Mode.FLEE)
		_flee_timer = 5.0
		_flee_total = 0.0


func _flee(delta: float) -> void:
	_flee_timer -= delta
	_flee_total += delta
	var away := Vector3.FORWARD
	var d := INF
	if _player != null:
		away = global_position - _player.global_position
		d = Vector2(away.x, away.z).length()
	away.y = 0.0
	if away.length() < 0.1:
		away = -global_transform.basis.z
	var dir := away.normalized()
	# Once well clear, run for the den rather than away forever.
	var home := den - global_position
	home.y = 0.0
	if d > 9.0 and home.length() > 2.0:
		dir = dir.lerp(home.normalized(), 0.6).normalized()
	# Slide along walls rather than run into them.
	if is_on_wall():
		var n := get_wall_normal()
		n.y = 0.0
		if n.length() > 0.01:
			var slid := dir.slide(n.normalized())
			dir = slid.normalized() if slid.length() > 0.25 else n.normalized().rotated(Vector3.UP, PI * 0.5 * (1.0 if sin(_seed) > 0.0 else -1.0))
	velocity.x = dir.x * profile.flee_speed * _flee_mult
	velocity.z = dir.z * profile.flee_speed * _flee_mult
	_turn_toward(dir, delta, 14.0)
	if (_flee_timer <= 0.0 and d > 11.0) or _flee_total > 14.0:
		awareness = 0.0
		_alert_label.text = ""
		_flee_mult = 1.0
		_set_mode(Mode.IDLE)
		_timer = randf_range(1.0, 3.0)


func _turn_toward(dir: Vector3, delta: float, rate: float) -> void:
	if Vector2(dir.x, dir.z).length() < 0.01:
		return
	rotation.y = lerp_angle(rotation.y, atan2(-dir.x, -dir.z), minf(1.0, rate * delta))


# ---------------------------------------------------------------- after a feed

func _drained(delta: float) -> void:
	_brake(delta)
	_gone_timer -= delta
	if _gone_timer <= 0.0:
		_vanish()


## Slinks off to its den and out of sight for a good while.
func _vanish() -> void:
	_set_mode(Mode.GONE)
	visible = false
	_body_shape.set_deferred("disabled", true)
	_alert_label.text = ""
	_away_left = profile.away_seconds
	velocity = Vector3.ZERO


func _gone(delta: float) -> void:
	_away_left -= delta
	if _away_left <= 0.0:
		snap_to_schedule()


func is_away() -> bool:
	return mode == Mode.GONE


# ---------------------------------------------------------------- FeedSource

func can_be_fed() -> bool:
	return mode != Mode.ENTRANCED and mode != Mode.DRAINED and mode != Mode.GONE


func begin_feed(_feeder: Node3D) -> void:
	_was_asleep = mode == Mode.SLEEPING
	_was_hunted = mode == Mode.FLEE or mode == Mode.ALERT or awareness > 0.6
	_set_mode(Mode.ENTRANCED)
	velocity = Vector3.ZERO
	awareness = 0.0
	_alert_label.text = ""


func feed_tick(progress: float) -> void:
	blood_left = 1.0 - progress
	model.limp = lerpf(0.0, 0.8, progress)


func finish_feed() -> Dictionary:
	_set_mode(Mode.DRAINED)
	blood_left = 0.0
	var result := get_feed_result()
	_mark_tasted()
	model.limp = 1.0
	_gone_timer = 2.2
	return result


## Let go early: it tears free and bolts, faster than before.
func interrupt_feed() -> void:
	model.limp = 0.0
	_set_mode(Mode.FLEE)
	_flee_timer = 6.0
	_flee_total = 0.0
	_flee_mult = 1.15
	awareness = 1.0
	_alert_label.text = "!"


func feed_style() -> FeedStyle:
	var st := ContentRegistry.get_def(&"FeedStyle", profile.feed_style) as FeedStyle
	if st == null:
		st = ContentRegistry.get_def(&"FeedStyle", &"calm") as FeedStyle
	return st


func feed_seconds() -> float:
	return profile.feed_seconds


func feed_focus_height() -> float:
	return 0.35


func feed_camera_distance() -> float:
	return 2.0


func feed_stand_distance() -> float:
	return 0.8


func feed_stand_side() -> float:
	return 0.5


func feed_camera_pitch() -> float:
	return -0.5


func feed_camera_yaw() -> float:
	return -1.0


func feed_crouch() -> float:
	return 1.0


func _memory() -> BloodMemory:
	return profile.memory_for(&"calm")


func has_unheard_memory() -> bool:
	var mem := _memory()
	return mem != null and not HumanNpc.tasted.get(profile.id, {}).has(mem.condition)


func _mark_tasted() -> void:
	var mem := _memory()
	if mem == null:
		return
	if not HumanNpc.tasted.has(profile.id):
		HumanNpc.tasted[profile.id] = {}
	HumanNpc.tasted[profile.id][mem.condition] = true


## A creature's blood tells its memory the first time only; afterwards the result carries no memory, and
## the feed is just a drink (no frozen world, no reading).
func get_feed_result() -> Dictionary:
	var style := feed_style()
	var blood := profile.blood_definition()
	var mem := _memory()
	var first := has_unheard_memory()
	var told := mem != null and first
	return {
		"name": profile.display_name,
		"occupation": "wild %s" % profile.species,
		"blood": profile.blood_description,
		"taste_note": style.taste_note,
		"title": mem.title if told else "",
		"memory": mem.text if told else "",
		"facts": mem.facts if told else PackedStringArray(),
		"reveals": mem.reveals_secret if told else &"",
		"condition": &"wild",
		"style": style,
		"style_id": style.id,
		"blood_type": blood.display_name if blood else "Wild",
		"blood_note": blood.description if blood else "",
		"yield": profile.blood_yield * (blood.yield_multiplier if blood else 1.0) * style.yield_multiplier,
		"surge_name": style.surge_name,
		"surge_power": style.surge_power * (blood.surge_power_multiplier if blood else 1.0),
		"surge_seconds": style.surge_seconds * (blood.surge_seconds_multiplier if blood else 1.0),
		"first_time": first,
	}


# ---------------------------------------------------------------- Vampiric Sense hooks

func is_sense_visible() -> bool:
	return mode != Mode.GONE


func get_heart_rate() -> float:
	match mode:
		Mode.FLEE, Mode.ALERT:
			return profile.base_heart_rate * 1.8
		Mode.SLEEPING:
			return profile.base_heart_rate * 0.5
		Mode.ENTRANCED:
			return lerpf(profile.base_heart_rate * 1.6, profile.base_heart_rate * 0.8, 1.0 - blood_left)
		Mode.DRAINED:
			return profile.base_heart_rate * 0.5
	return profile.base_heart_rate * (1.0 + awareness * 0.6)


func _mood() -> String:
	match mode:
		Mode.FLEE, Mode.ALERT:
			return "frightened"
		Mode.SLEEPING:
			return "asleep"
		Mode.ENTRANCED, Mode.DRAINED:
			return "limp"
	return "wary" if awareness > 0.25 else "calm"


func _state_name() -> StringName:
	match mode:
		Mode.FLEE, Mode.ALERT:
			return &"afraid"
		Mode.SLEEPING:
			return &"asleep"
		Mode.DRAINED:
			return &"drained"
	return &"afraid" if awareness > 0.25 else &"calm"


## Far: nothing. Mid: that something small and quick has a heart. Near: what it is, how it feels, what its
## blood is like, and whether a memory waits - the same tiers as a person.
func get_sense_data(dist := 0.0) -> Dictionary:
	var bpm := get_heart_rate()
	var blood := profile.blood_definition()
	var col: Color = blood.sense_color if blood else Color(0.9, 0.6, 0.1)
	var label := ""
	var title := ""
	var detail := ""
	var blood_text := ""
	var hint := ""
	if dist > 18.0:
		label = ""
	elif dist > 10.0:
		title = "something small and quick"
		detail = "%d bpm" % roundi(bpm)
		label = "something small and quick, %d bpm" % roundi(bpm)
	else:
		title = profile.sense_label
		detail = "%d bpm, %s" % [roundi(bpm), _mood()]
		label = "%s\n%s" % [title, detail]
		if dist < 7.0:
			blood_text = profile.blood_description
			label += "\n" + blood_text
			if mode != Mode.DRAINED and has_unheard_memory():
				hint = "a memory waits"
	return {"label": label, "title": title, "detail": detail, "blood": blood_text, "hint": hint,
		"known": true, "tasted": HumanNpc.tasted.get(profile.id, {}).size(), "color": col, "bpm": bpm, "state": _state_name(),
		"label_offset": Vector3(0, 0.7, 0)}
