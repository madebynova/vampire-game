class_name HumanNpc
extends CharacterBody3D
## A living human with a daily routine (NpcProfile.schedule), a light personality and a heartbeat.
##
## CALM      going about their schedule; notices a Vampire that is in view (or right behind them)
## SLEEPING  in bed during their sleep block; wakes to noise, does not notice you by sight
## FOLLOWING trusts you (Human form, 3rd chat) and walks with you for a while
## STUNNED   trusting follower who just watched you transform: frozen for a few seconds
## FLEEING   terrified; runs away
## ENTRANCED being fed on
## DRAINED   unconscious after a full feed (until the next night)

enum Mode { CALM, FLEEING, ENTRANCED, DRAINED, SLEEPING, FOLLOWING, STUNNED }

signal mode_changed(new_mode: Mode)

## Tests/tools can freeze routines: NPCs then stand at their spawn spot.
static var schedules_enabled := true
## Which blood-memories the player has already tasted: npc id -> {memory condition: true}. Survives
## nights (discoveries persist); Vampiric Sense uses it to hint at what is still unheard.
static var tasted: Dictionary = {}


static func reset_tasted() -> void:
	tasted.clear()

@export var profile: NpcProfile
@export var close_notice_radius := 2.2
@export var flee_speed := 5.6
@export var flee_duration := 9.0
@export var walk_speed := 1.9
@export var follow_speed := 3.4
@export var follow_duration := 45.0
@export var stun_duration := 4.0
@export var gravity := 20.0

@onready var model: HumanoidModel = $Model
@onready var alert_label: Label3D = $AlertLabel
@onready var speech_label: Label3D = $SpeechLabel
@onready var body_shape: CollisionShape3D = $CollisionShape3D

var mode: Mode = Mode.CALM
var awareness := 0.0
var blood_left := 1.0
var trust := 0.0
var known := false          ## Sense shows their name once you have talked to or fed on them
var was_afraid_when_grabbed := false
var was_asleep := false
var was_trusting := false

var _player: Player
var _tod: TimeOfDay
var _lantern: OmniLight3D
var _home_pos := Vector3.ZERO
var _home_yaw := 0.0
var _entry: ScheduleEntry
var _route: PackedVector3Array = PackedVector3Array()
var _route_i := 0
var _route_dir := 1
var _pause := 0.0
var _arrived := false
var _sched_timer := 0.0
var _woken_timer := 0.0
var _sleep_noise := 0.0
var _flee_timer := 0.0
var _speed_mult := 1.0
var _follow_timer := 0.0
var _stun_timer := 0.0
var _talk_cooldown := 0.0
var _line_index := 0
var _speech_timer := 0.0
var _feed_progress := 0.0
var _stuck_timer := 0.0
var _stuck_ref := Vector3.ZERO
var _seed := randf() * 10.0
var _transform_hooked := false
var _chill_timer := 0.0
var _chill_origin := Vector3.ZERO


func _ready() -> void:
	add_to_group(&"npcs")
	collision_layer = 4
	collision_mask = 1 | 2
	_home_pos = global_position
	_home_yaw = rotation.y
	model.apply_look(profile.skin_color, profile.cloth_color, profile.pants_color, profile.hair_color, Color(0.1, 0.07, 0.05), 0.0, false, false)
	alert_label.text = ""
	speech_label.text = ""
	speech_label.visible = false
	_lantern = OmniLight3D.new()
	_lantern.position = Vector3(0.0, 1.15, -0.4)
	_lantern.light_color = Color(1.0, 0.72, 0.4)
	_lantern.omni_range = 6.0
	_lantern.visible = false
	add_child(_lantern)
	snap_to_schedule()


func _physics_process(delta: float) -> void:
	if _player == null:
		_player = get_tree().get_first_node_in_group(&"player") as Player
	if _player != null and not _transform_hooked:
		_transform_hooked = true
		_player.form.transform_started.connect(_on_player_transform)
	if _tod == null:
		_tod = get_tree().get_first_node_in_group(&"time_of_day") as TimeOfDay
	_talk_cooldown = maxf(_talk_cooldown - delta, 0.0)

	match mode:
		Mode.CALM:
			_calm(delta)
		Mode.FLEEING:
			_flee(delta)
		Mode.FOLLOWING:
			_follow(delta)
		Mode.SLEEPING:
			_sleeping(delta)
		Mode.STUNNED:
			_stunned(delta)
		_:
			_brake(delta)
	if _is_lying_in_bed():
		velocity = Vector3.ZERO
	else:
		if not is_on_floor():
			velocity.y -= gravity * delta
		else:
			velocity.y = 0.0
		move_and_slide()
	if mode == Mode.CALM or mode == Mode.FLEEING or mode == Mode.FOLLOWING:
		model.animate(Vector2(velocity.x, velocity.z).length(), is_on_floor(), delta)
	if _speech_timer > 0.0:
		_speech_timer -= delta
		if _speech_timer <= 0.0:
			speech_label.visible = false
	_update_lantern()


func _brake(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, 30.0 * delta)
	velocity.z = move_toward(velocity.z, 0.0, 30.0 * delta)


# ---------------------------------------------------------------- schedule

## Put the NPC where their routine says they should be at the current hour, instantly.
func snap_to_schedule() -> void:
	_set_mode(Mode.CALM)
	velocity = Vector3.ZERO
	awareness = 0.0
	_woken_timer = 0.0
	_sleep_noise = 0.0
	_arrived = false
	_pause = 0.0
	body_shape.set_deferred("disabled", false)
	model.body.rotation = Vector3.ZERO
	model.position = Vector3.ZERO
	alert_label.text = ""
	speech_label.visible = false
	_entry = null
	if not schedules_enabled or profile.schedule.is_empty():
		global_position = _home_pos
		rotation.y = _home_yaw
		return
	var hour := _tod.hour if _tod != null else 12.0
	var e := profile.schedule_for(hour)
	if e == null or e.points.is_empty():
		global_position = _home_pos
		rotation.y = _home_yaw
		return
	_set_entry(e)
	match e.activity:
		&"patrol":
			global_position = e.points[0]
			_route_i = mini(1, e.points.size() - 1)
		&"sleep":
			global_position = e.points[e.points.size() - 1]
			rotation.y = deg_to_rad(e.face_yaw_degrees)
			_arrived = true
			_lie_down(true)
		_:
			global_position = e.points[e.points.size() - 1]
			rotation.y = deg_to_rad(e.face_yaw_degrees)
			_arrived = true


func _set_entry(e: ScheduleEntry) -> void:
	_entry = e
	_route = e.points
	_route_i = 0
	_route_dir = 1
	_arrived = false
	_pause = 0.0


func _update_schedule(delta: float) -> void:
	if not schedules_enabled or _tod == null or profile.schedule.is_empty():
		return
	_sched_timer -= delta
	if _sched_timer > 0.0:
		return
	_sched_timer = 0.5
	var e := profile.schedule_for(_tod.hour)
	if e == null or e == _entry:
		return
	if mode == Mode.SLEEPING:
		_wake_up(false)
	_set_entry(e)


## Walk the current entry's route. Returns true while moving.
func _walk_route(delta: float) -> bool:
	if _entry == null or _route.is_empty() or _arrived:
		return false
	if _pause > 0.0:
		_pause -= delta
		return false
	var target := _route[_route_i]
	var to := target - global_position
	to.y = 0.0
	if to.length() < 0.35:
		_reached_point()
		return false
	var dir := to.normalized()
	velocity.x = dir.x * walk_speed
	velocity.z = dir.z * walk_speed
	_turn_toward(dir, delta, 6.0)
	_unstick(delta, target)
	return true


func _reached_point() -> void:
	_stuck_timer = 0.0
	if _entry.activity == &"patrol":
		_pause = randf_range(3.0, 7.0)
		var next := _route_i + _route_dir
		if next < 0 or next >= _route.size():
			_route_dir = -_route_dir
			next = _route_i + _route_dir
		_route_i = clampi(next, 0, _route.size() - 1)
		return
	if _route_i < _route.size() - 1:
		_route_i += 1
		return
	_arrived = true


## If a route point is unreachable (blocked), hop to it rather than pace at a wall forever.
func _unstick(delta: float, target: Vector3) -> void:
	_stuck_timer += delta
	if _stuck_timer < 2.5:
		return
	if global_position.distance_to(_stuck_ref) < 0.4:
		global_position = Vector3(target.x, global_position.y, target.z)
	_stuck_ref = global_position
	_stuck_timer = 0.0


func _calm(delta: float) -> void:
	var d := INF
	if _player != null:
		d = global_position.distance_to(_player.global_position)
	_update_awareness(delta, d)
	if mode != Mode.CALM:
		return
	# A chill: someone changed shape nearby. They stop, glance toward it, and wonder.
	if _chill_timer > 0.0:
		_chill_timer -= delta
		alert_label.text = "?"
		_brake(delta)
		_turn_toward(_chill_origin - global_position, delta, 4.0)
		return
	_update_schedule(delta)
	_woken_timer = maxf(_woken_timer - delta, 0.0)
	velocity.x = move_toward(velocity.x, 0.0, 20.0 * delta)
	velocity.z = move_toward(velocity.z, 0.0, 20.0 * delta)
	if _walk_route(delta):
		return
	# Arrived at a bed: lie down (unless recently woken).
	if _arrived and _entry != null and _entry.activity == &"sleep" and _woken_timer <= 0.0:
		_lie_down(false)
		return
	# Standing about: glance at a friendly visitor, otherwise look around slowly.
	if _player != null and d < 6.5 and not _player.form.current.frightens_humans:
		_turn_toward(_player.global_position - global_position, delta, 3.0)
	elif _arrived and _entry != null:
		rotation.y = lerp_angle(rotation.y, deg_to_rad(_entry.face_yaw_degrees) + sin(Time.get_ticks_msec() / 1000.0 * 0.4 + _seed) * 0.45, minf(1.0, 1.5 * delta))
	else:
		rotation.y = lerp_angle(rotation.y, _home_yaw + sin(Time.get_ticks_msec() / 1000.0 * 0.4 + _seed) * 0.7, minf(1.0, 1.5 * delta))


# ---------------------------------------------------------------- awareness

func _notice_radius() -> float:
	return profile.notice_radius + profile.night_notice_bonus * _darkness()


func _darkness() -> float:
	return _tod.darkness() if _tod != null else 0.0


func _update_awareness(delta: float, d: float) -> void:
	var frightening := _player != null and _player.form.current.frightens_humans and not _player.state.is_dead()
	var rate := 0.0
	if frightening and d < _notice_radius():
		var to := _player.global_position - global_position
		to.y = 0.0
		var facing := (-global_transform.basis.z).dot(to.normalized()) if to.length() > 0.05 else 1.0
		var in_view := facing > -0.2
		if in_view or d < close_notice_radius:
			if _line_of_sight_to_player():
				# Sensed-not-seen (someone right behind you) builds slowly.
				rate = lerpf(0.3, 1.3, 1.0 - d / _notice_radius()) if in_view else 0.35
	if rate > 0.0:
		awareness += rate * delta
	else:
		awareness -= (0.25 if frightening else 0.5) * delta
	awareness = clampf(awareness, 0.0, 1.0)
	alert_label.text = "?" if awareness > 0.2 else ""
	if awareness >= 1.0:
		_start_fleeing()


func _line_of_sight_to_player() -> bool:
	var from := global_position + Vector3(0, 1.6, 0)
	var target := _player.global_position + Vector3(0, 1.4, 0)
	var query := PhysicsRayQueryParameters3D.create(from, target, 1)
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()


## Someone changed shape in front of us.
func _on_player_transform(to_form: FormData) -> void:
	if not to_form.frightens_humans or _player == null:
		return
	if mode == Mode.DRAINED or mode == Mode.ENTRANCED or mode == Mode.FLEEING:
		return
	var d := global_position.distance_to(_player.global_position)
	if mode == Mode.SLEEPING:
		if d < 3.0:
			_wake_up(true)
		return
	var sees := d < 3.0
	if not sees and d < 16.0:
		var to := _player.global_position - global_position
		to.y = 0.0
		var in_view := (-global_transform.basis.z).dot(to.normalized()) > -0.2 if to.length() > 0.05 else true
		sees = in_view and _line_of_sight_to_player()
	if not sees:
		return
	if mode == Mode.FOLLOWING:
		_stun()
	else:
		awareness = 1.0
		_start_fleeing()


# ---------------------------------------------------------------- fleeing / following / stunned

func _flee(delta: float) -> void:
	_flee_timer -= delta
	var away := Vector3.FORWARD
	if _player != null:
		away = global_position - _player.global_position
	away.y = 0.0
	if away.length() < 0.1:
		away = -global_transform.basis.z
	var dir := away.normalized()
	# Don't run into walls: slide along them, or turn along the wall if head-on.
	if is_on_wall():
		var n := get_wall_normal()
		n.y = 0.0
		if n.length() > 0.01:
			var slid := dir.slide(n.normalized())
			dir = slid.normalized() if slid.length() > 0.25 else n.normalized().rotated(Vector3.UP, PI * 0.5 * (1.0 if sin(_seed) > 0.0 else -1.0))
	var speed := flee_speed * _speed_mult
	velocity.x = dir.x * speed
	velocity.z = dir.z * speed
	_turn_toward(dir, delta, 10.0)
	var far := _player == null or global_position.distance_to(_player.global_position) > 16.0
	if _flee_timer <= 0.0 and far:
		_set_mode(Mode.CALM)
		awareness = 0.0
		alert_label.text = ""
		_speed_mult = 1.0
		if _entry != null:
			_set_entry(_entry)  # walk back to the routine


func _start_fleeing() -> void:
	if mode != Mode.CALM and mode != Mode.FOLLOWING and mode != Mode.STUNNED:
		return
	_set_mode(Mode.FLEEING)
	_flee_timer = flee_duration
	awareness = 1.0
	alert_label.text = "!"
	Sfx.play_at(&"gasp", global_position + Vector3(0, 1.5, 0), -2.0)
	_say("...Something's wrong with you!", 2.5)


func _follow(delta: float) -> void:
	_follow_timer -= delta
	var d := INF
	if _player != null:
		d = global_position.distance_to(_player.global_position)
	_update_awareness(delta, d)  # a vampire seen later still scares them
	if mode != Mode.FOLLOWING:
		return
	if _follow_timer <= 0.0 or _player == null:
		_end_follow("I should get back to it. Good talk.")
		return
	var to := _player.global_position - global_position
	to.y = 0.0
	if d > 2.8:
		var dir := to.normalized()
		var speed := follow_speed if d > 6.0 else walk_speed * 1.5
		velocity.x = dir.x * speed
		velocity.z = dir.z * speed
		_turn_toward(dir, delta, 6.0)
	else:
		velocity.x = move_toward(velocity.x, 0.0, 20.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 20.0 * delta)
		_turn_toward(to, delta, 4.0)


func _end_follow(line: String) -> void:
	if mode != Mode.FOLLOWING:
		return
	_set_mode(Mode.CALM)
	_say(line, 3.0)
	if _entry != null:
		_set_entry(_entry)


func _stun() -> void:
	_set_mode(Mode.STUNNED)
	_stun_timer = stun_duration
	awareness = 0.3
	velocity = Vector3.ZERO
	alert_label.text = "..."
	Sfx.play_at(&"gasp", global_position + Vector3(0, 1.5, 0), -4.0)
	_say("You... what ARE you?", stun_duration)


func _stunned(delta: float) -> void:
	_brake(delta)
	_stun_timer -= delta
	if _player != null:
		_turn_toward(_player.global_position - global_position, delta, 5.0)
	if _stun_timer <= 0.0:
		_start_fleeing()


# ---------------------------------------------------------------- sleeping

func is_lying() -> bool:
	return model.body.rotation.x > 0.5 and mode != Mode.FLEEING and mode != Mode.CALM


func _is_lying_in_bed() -> bool:
	return _entry != null and _entry.activity == &"sleep" and _arrived \
		and model.body.rotation.x > 1.2 and (mode == Mode.SLEEPING or mode == Mode.DRAINED or mode == Mode.ENTRANCED)


func _lie_down(instant: bool) -> void:
	_set_mode(Mode.SLEEPING)
	velocity = Vector3.ZERO
	body_shape.set_deferred("disabled", true)
	rotation.y = deg_to_rad(_entry.face_yaw_degrees)
	var rest := Vector3(0.0, _entry.rest_height + 0.15, -0.85)
	if instant:
		model.body.rotation.x = PI * 0.5
		model.position = rest
	else:
		var tw := create_tween().set_parallel(true)
		tw.tween_property(model.body, "rotation:x", PI * 0.5, 0.9)
		tw.tween_property(model, "position", rest, 0.9)


func _wake_up(groggy: bool) -> void:
	_set_mode(Mode.CALM)
	body_shape.set_deferred("disabled", false)
	_woken_timer = 40.0
	_sleep_noise = 0.0
	var tw := create_tween().set_parallel(true)
	tw.tween_property(model.body, "rotation:x", 0.0, 0.5)
	tw.tween_property(model, "position", Vector3.ZERO, 0.5)
	if groggy:
		awareness = 0.45
		_say("Mm? Who's there...?", 2.5)
		Sfx.play_at(&"gasp", global_position + Vector3(0, 1.0, 0), -8.0, 0.8)


func _sleeping(delta: float) -> void:
	velocity = Vector3.ZERO
	_update_schedule(delta)
	if mode != Mode.SLEEPING or _player == null:
		return
	var spd := Vector2(_player.velocity.x, _player.velocity.z).length()
	var radius := (1.6 + spd * 0.5) * profile.light_sleeper
	var d := global_position.distance_to(_player.global_position)
	if d < radius:
		_sleep_noise += (1.0 - d / radius) * 0.8 * delta
	else:
		_sleep_noise = maxf(_sleep_noise - 0.4 * delta, 0.0)
	if _sleep_noise >= 1.0:
		_wake_up(true)


# ---------------------------------------------------------------- misc behaviour

func _turn_toward(dir: Vector3, delta: float, rate: float) -> void:
	if Vector2(dir.x, dir.z).length() < 0.01:
		return
	rotation.y = lerp_angle(rotation.y, atan2(-dir.x, -dir.z), minf(1.0, rate * delta))


func _set_mode(m: Mode) -> void:
	mode = m
	mode_changed.emit(m)


func _say(text: String, seconds: float) -> void:
	speech_label.text = text
	speech_label.visible = true
	_speech_timer = seconds


func _update_lantern() -> void:
	var want := _entry != null and _entry.lantern and _darkness() > 0.35 \
		and (mode == Mode.CALM or mode == Mode.FOLLOWING or mode == Mode.STUNNED)
	_lantern.visible = want
	if want:
		_lantern.light_energy = 1.1 + sin(Time.get_ticks_msec() / 1000.0 * 8.0 + _seed) * 0.08


# ---------------------------------------------------------------- social (Human form)

func trust_tier() -> int:
	return 0 if trust < 0.34 else (1 if trust < 0.67 else 2)


func is_following() -> bool:
	return mode == Mode.FOLLOWING


func talk(actor: Player) -> void:
	_turn_toward(actor.global_position - global_position, 1.0, 1.0)
	known = true
	if mode == Mode.FOLLOWING:
		_end_follow("Right. I'll get back to it.")
		Sfx.play_at(&"blip", global_position + Vector3(0, 1.6, 0), -4.0, 1.0)
		return
	var tier := trust_tier()
	var pool := profile.greeting_lines
	if tier == 1 and not profile.familiar_lines.is_empty():
		pool = profile.familiar_lines
	elif tier >= 2 and profile.can_follow and not profile.trust_lines.is_empty():
		pool = profile.trust_lines
	elif tier == 0 and _darkness() > 0.5 and not profile.night_lines.is_empty():
		pool = profile.night_lines
	if not pool.is_empty():
		var line := pool[_line_index % pool.size()]
		_line_index += 1
		_say("%s: \"%s\"" % [profile.display_name, line], 5.0)
	Sfx.play_at(&"blip", global_position + Vector3(0, 1.6, 0), -4.0, randf_range(0.9, 1.15))
	if _talk_cooldown <= 0.0:
		trust = minf(trust + 0.34, 1.0)
		_talk_cooldown = 6.0
	if tier >= 2 and profile.can_follow and not profile.trust_lines.is_empty():
		_set_mode(Mode.FOLLOWING)
		_follow_timer = follow_duration


# ---------------------------------------------------------------- feeding

func can_be_fed() -> bool:
	return mode != Mode.DRAINED and mode != Mode.ENTRANCED


func begin_feed(feeder: Node3D) -> void:
	was_asleep = mode == Mode.SLEEPING
	was_afraid_when_grabbed = mode == Mode.FLEEING or awareness > 0.6
	was_trusting = not was_afraid_when_grabbed and not was_asleep \
		and (mode == Mode.STUNNED or mode == Mode.FOLLOWING or trust_tier() >= 2)
	_set_mode(Mode.ENTRANCED)
	known = true
	_feed_progress = 0.0
	velocity = Vector3.ZERO
	awareness = 0.0
	alert_label.text = ""
	speech_label.visible = false
	if not was_asleep:
		_turn_toward(feeder.global_position - global_position, 1.0, 1.0)
		create_tween().tween_property(model.body, "rotation:x", 0.32, 0.5)


func feed_tick(progress: float) -> void:
	_feed_progress = progress
	blood_left = 1.0 - progress


func finish_feed() -> Dictionary:
	_set_mode(Mode.DRAINED)
	blood_left = 0.0
	var result_pre := get_feed_result()
	_mark_tasted()
	if not was_asleep:
		var tw := create_tween().set_parallel(true)
		tw.tween_property(model.body, "rotation:x", PI * 0.5, 0.9)
		tw.tween_property(model, "position:y", 0.2, 0.9)
	return result_pre


## Feeding stopped early: they wrench free, dizzy but terrified.
func interrupt_feed() -> void:
	body_shape.set_deferred("disabled", false)
	_set_mode(Mode.FLEEING)
	_flee_timer = flee_duration
	_speed_mult = 0.6
	awareness = 1.0
	alert_label.text = "!"
	var tw := create_tween().set_parallel(true)
	tw.tween_property(model.body, "rotation:x", 0.0, 0.3)
	tw.tween_property(model, "position", Vector3.ZERO, 0.3)
	Sfx.play_at(&"gasp", global_position + Vector3(0, 1.5, 0), -2.0)


## What state the victim was in when grabbed decides which memory the blood holds.
func feed_condition() -> StringName:
	if was_asleep:
		return &"asleep"
	if was_afraid_when_grabbed:
		return &"afraid"
	# Trusting victims share the calm memory unless the profile gives them a memory of their own.
	return &"trusting" if was_trusting and profile.has_memory(&"trusting") else &"calm"


## Which FeedStyle this feed plays as (calm / asleep / afraid / trusting).
func feed_style_id() -> StringName:
	if was_asleep:
		return &"asleep"
	if was_afraid_when_grabbed:
		return &"afraid"
	return &"trusting" if was_trusting else &"calm"


func feed_style() -> FeedStyle:
	var st := ContentRegistry.get_def(&"FeedStyle", feed_style_id()) as FeedStyle
	if st == null:
		st = ContentRegistry.get_def(&"FeedStyle", &"calm") as FeedStyle
	return st


## The FeedStyle this person would give if you grabbed them right now (for Sense hints).
func potential_style_id() -> StringName:
	match mode:
		Mode.SLEEPING:
			return &"asleep"
		Mode.FLEEING:
			return &"afraid"
		Mode.STUNNED, Mode.FOLLOWING:
			return &"trusting"
	if awareness > 0.6:
		return &"afraid"
	return &"trusting" if trust_tier() >= 2 else &"calm"


func _memory_condition_for(style_id: StringName) -> StringName:
	match style_id:
		&"asleep":
			return &"asleep"
		&"afraid":
			return &"afraid"
		&"trusting":
			return &"trusting" if profile.has_memory(&"trusting") else &"calm"
	return &"calm"


func _mark_tasted() -> void:
	var mem := profile.memory_for(feed_condition())
	if mem == null:
		return
	if not tasted.has(profile.id):
		tasted[profile.id] = {}
	tasted[profile.id][mem.condition] = true


## True while the memory this person would give in their current state has not been heard yet.
func has_unheard_memory() -> bool:
	var mem := profile.memory_for(_memory_condition_for(potential_style_id()))
	return mem != null and not tasted.get(profile.id, {}).has(mem.condition)


func tasted_count() -> int:
	return tasted.get(profile.id, {}).size()


func get_feed_result() -> Dictionary:
	var memory := profile.memory_for(feed_condition())
	var style := feed_style()
	var blood := profile.blood_definition()
	return {
		"name": profile.display_name,
		"occupation": profile.occupation,
		"blood": profile.blood_description,
		"taste_note": style.taste_note,
		"title": memory.title if memory else "Nothing",
		"memory": memory.text if memory else "",
		"facts": memory.facts if memory else PackedStringArray(),
		"reveals": memory.reveals_secret if memory else &"",
		"condition": feed_condition(),
		"style": style,
		"style_id": style.id,
		"blood_type": _blood_name(),
		"yield": profile.blood_yield * _yield_multiplier() * style.yield_multiplier,
		"surge_name": style.surge_name,
		"surge_power": style.surge_power * (blood.surge_power_multiplier if blood else 1.0),
		"surge_seconds": style.surge_seconds * (blood.surge_seconds_multiplier if blood else 1.0),
		"first_time": (not tasted.get(profile.id, {}).has(memory.condition)) if memory else false,
	}


func _blood_name() -> String:
	var b := profile.blood_definition()
	return b.display_name if b else "Common"


func _yield_multiplier() -> float:
	var b := profile.blood_definition()
	return b.yield_multiplier if b else 1.0


# ---------------------------------------------------------------- reacting to vampiric acts

## Could this person see `point` right now? (Close, or in front of them with a clear line.)
func _can_see_point(point: Vector3) -> bool:
	var to := point - global_position
	to.y = 0.0
	var d := to.length()
	if d > 0.05 and d >= 3.0 and (-global_transform.basis.z).dot(to.normalized()) <= -0.2:
		return false
	var query := PhysicsRayQueryParameters3D.create(global_position + Vector3(0, 1.6, 0), point + Vector3(0, 1.4, 0), 1)
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()


## Something supernatural happened at `origin` (a feeding, a climb). With `needs_sight` only someone who
## can see the spot reacts, and they panic; otherwise it is heard: `strength` is the awareness gained by
## this one call (closer = more, up to `radius`); the caller scales it by how long the noise lasted.
## Returns true if this person was sent running (or frozen) by it.
func perceive_vampiric_act(origin: Vector3, strength: float, radius: float, needs_sight: bool) -> bool:
	if radius <= 0.0 or strength <= 0.0:
		return false
	if mode == Mode.DRAINED or mode == Mode.ENTRANCED or mode == Mode.FLEEING:
		return false
	var d := global_position.distance_to(origin)
	if d > radius:
		return false
	if mode == Mode.SLEEPING:
		if not needs_sight:
			_sleep_noise += strength * (1.0 - d / radius) * profile.light_sleeper
			if _sleep_noise >= 1.0:
				_wake_up(true)
		return false
	if needs_sight:
		if not _can_see_point(origin):
			return false
		if mode == Mode.FOLLOWING:
			_stun()
		else:
			awareness = 1.0
			_start_fleeing()
		return true
	awareness = minf(awareness + strength * (1.0 - 0.5 * d / radius), 1.0)
	_turn_toward(origin - global_position, 1.0, 1.0)
	if awareness >= 1.0:
		_start_fleeing()
		return true
	return false


## The air changes when a vampire is born nearby: people who did not see it still feel a chill.
func feel_transformation(origin: Vector3, to_vampire: bool) -> void:
	if not to_vampire:
		return
	var d := global_position.distance_to(origin)
	if d > 10.0:
		return
	if mode == Mode.SLEEPING:
		_sleep_noise = minf(_sleep_noise + 0.3 * (1.0 - d / 10.0), 0.95)
	elif mode == Mode.CALM:
		awareness = minf(awareness + 0.28 * (1.0 - d / 12.0), 0.4)
		_chill_timer = 2.2
		_chill_origin = origin
		_turn_toward(origin - global_position, 1.0, 1.0)


## A new night: everyone is back on their routine, rested and forgetful.
func new_day() -> void:
	trust = 0.0
	blood_left = 1.0
	_speed_mult = 1.0
	was_asleep = false
	was_afraid_when_grabbed = false
	was_trusting = false
	snap_to_schedule()


# ---------------------------------------------------------------- Vampiric Sense hooks

func get_heart_rate() -> float:
	match mode:
		Mode.FLEEING:
			return profile.base_heart_rate * 2.0
		Mode.ENTRANCED:
			return lerpf(profile.base_heart_rate * 1.7, profile.base_heart_rate * 0.8, _feed_progress)
		Mode.DRAINED:
			return profile.base_heart_rate * 0.55
		Mode.SLEEPING:
			return profile.base_heart_rate * 0.62
		Mode.STUNNED:
			return profile.base_heart_rate * 1.6
	return profile.base_heart_rate * (1.0 + awareness * 0.7)


func _mood() -> String:
	match mode:
		Mode.FLEEING:
			return "terrified"
		Mode.ENTRANCED:
			return "swooning"
		Mode.DRAINED:
			return "drained, unconscious"
		Mode.SLEEPING:
			return "asleep"
		Mode.STUNNED:
			return "frozen with shock"
		Mode.FOLLOWING:
			return "trusting"
	return "uneasy" if awareness > 0.25 else "calm"


## How much you can read from a heartbeat depends on how close you are.
##   far   (> 20 m): just the pulse (no text)
##   mid   (> 11 m): that a heart is there, and how fast
##   near  (<= 11 m): who, mood, and (< 7 m) what their blood smells like, and whether a memory waits
## `label` is the whole thing as plain text (accessibility, tests); `title` / `detail` / `blood` /
## `hint` are the same information split for the elegant 3D presentation.
func get_sense_data(dist := 0.0) -> Dictionary:
	var bpm := get_heart_rate()
	var b := profile.blood_definition()
	var col := b.sense_color if b else Color(0.85, 0.04, 0.1)
	match mode:
		Mode.FLEEING, Mode.STUNNED:
			col = Color(1.0, 0.35, 0.1)
		Mode.DRAINED:
			col = Color(0.45, 0.1, 0.5)
		Mode.SLEEPING:
			col = Color(0.3, 0.3, 1.0)
		_:
			if awareness > 0.25:
				col = Color(1.0, 0.2, 0.12)
	var label := ""
	var title := ""
	var detail := ""
	var blood := ""
	var hint := ""
	if dist > 20.0:
		label = ""
	elif dist > 11.0:
		title = "a heartbeat"
		detail = "%d bpm" % roundi(bpm)
		label = "a heartbeat, %d bpm" % roundi(bpm)
	else:
		var who := profile.display_name if known else "A stranger"
		title = who
		detail = "%d bpm, %s" % [roundi(bpm), _mood()]
		label = "%s\n%s" % [who, detail]
		if dist < 7.0:
			blood = profile.blood_description
			label += "\n" + blood
			if mode != Mode.DRAINED and has_unheard_memory():
				hint = feed_style_hint()
	# Lying figures sit low: keep their text near the bed rather than at the ceiling.
	return {"label": label, "title": title, "detail": detail, "blood": blood, "hint": hint,
		"known": known, "tasted": tasted_count(), "color": col, "bpm": bpm, "state": _state_name(),
		"label_offset": Vector3(0, 0.7 if is_lying() else 1.9, 0)}


func feed_style_hint() -> String:
	var st := ContentRegistry.get_def(&"FeedStyle", potential_style_id()) as FeedStyle
	return st.sense_hint if st else "a memory waits"


## Coarse state for presentation: which heartbeat sound, how the silhouette flickers.
func _state_name() -> StringName:
	match mode:
		Mode.FLEEING, Mode.STUNNED:
			return &"afraid"
		Mode.SLEEPING:
			return &"asleep"
		Mode.DRAINED:
			return &"drained"
	return &"afraid" if awareness > 0.25 else &"calm"
