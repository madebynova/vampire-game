class_name HumanNpc
extends CharacterBody3D
## A living human. Calm until a Vampire-form player is seen close by; then afraid and
## fleeing. Feed-able. Heart rate follows emotional state (visible/audible via Vampiric Sense).

enum Mode { CALM, FLEEING, ENTRANCED, DRAINED }

signal mode_changed(new_mode: Mode)

@export var profile: NpcProfile
@export var notice_radius := 10.0
@export var close_notice_radius := 2.2
@export var flee_speed := 5.6
@export var flee_duration := 9.0
@export var gravity := 20.0

@onready var model: HumanoidModel = $Model
@onready var alert_label: Label3D = $AlertLabel
@onready var speech_label: Label3D = $SpeechLabel

var mode: Mode = Mode.CALM
var awareness := 0.0
var blood_left := 1.0
var was_afraid_when_grabbed := false

var _player: Player
var _home_pos := Vector3.ZERO
var _home_yaw := 0.0
var _flee_timer := 0.0
var _speed_mult := 1.0
var _returning := false
var _line_index := 0
var _speech_timer := 0.0
var _feed_progress := 0.0
var _seed := randf() * 10.0


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


func _physics_process(delta: float) -> void:
	if _player == null:
		_player = get_tree().get_first_node_in_group(&"player") as Player
	match mode:
		Mode.CALM:
			_calm(delta)
		Mode.FLEEING:
			_flee(delta)
		_:
			velocity.x = move_toward(velocity.x, 0.0, 30.0 * delta)
			velocity.z = move_toward(velocity.z, 0.0, 30.0 * delta)
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = 0.0
	move_and_slide()
	if mode == Mode.CALM or mode == Mode.FLEEING:
		model.animate(Vector2(velocity.x, velocity.z).length(), is_on_floor(), delta)
	if _speech_timer > 0.0:
		_speech_timer -= delta
		if _speech_timer <= 0.0:
			speech_label.visible = false


# ---------------------------------------------------------------- behaviour

func _calm(delta: float) -> void:
	var d := INF
	if _player != null:
		d = global_position.distance_to(_player.global_position)
	_update_awareness(delta, d)

	if _returning:
		var to_home := _home_pos - global_position
		to_home.y = 0.0
		if to_home.length() < 0.3:
			_returning = false
		else:
			var dir := to_home.normalized()
			velocity.x = dir.x * 2.2
			velocity.z = dir.z * 2.2
			_turn_toward(dir, delta, 6.0)
			return
	velocity.x = move_toward(velocity.x, 0.0, 20.0 * delta)
	velocity.z = move_toward(velocity.z, 0.0, 20.0 * delta)

	# Idle: glance at a human-looking visitor, otherwise look about slowly.
	if _player != null and d < 6.5 and not _player.form.current.frightens_humans:
		_turn_toward((_player.global_position - global_position), delta, 3.0)
	else:
		var want := _home_yaw + sin(Time.get_ticks_msec() / 1000.0 * 0.4 + _seed) * 0.7
		rotation.y = lerp_angle(rotation.y, want, minf(1.0, 1.5 * delta))


func _update_awareness(delta: float, d: float) -> void:
	var frightening := _player != null and _player.form.current.frightens_humans and not _player.state.is_dead()
	var seen := false
	if frightening and d < notice_radius:
		var to := _player.global_position - global_position
		to.y = 0.0
		var facing := (-global_transform.basis.z).dot(to.normalized()) if to.length() > 0.05 else 1.0
		if facing > -0.2 or d < close_notice_radius:
			var from := global_position + Vector3(0, 1.6, 0)
			var target := _player.global_position + Vector3(0, 1.4, 0)
			var query := PhysicsRayQueryParameters3D.create(from, target, 1)
			seen = get_world_3d().direct_space_state.intersect_ray(query).is_empty()
	if seen:
		awareness += lerpf(0.3, 1.3, 1.0 - d / notice_radius) * delta
	else:
		awareness -= (0.25 if frightening else 0.5) * delta
	awareness = clampf(awareness, 0.0, 1.0)
	alert_label.text = "?" if awareness > 0.2 else ""
	if awareness >= 1.0:
		_start_fleeing()


func _flee(delta: float) -> void:
	_flee_timer -= delta
	var away := Vector3.FORWARD
	if _player != null:
		away = global_position - _player.global_position
	away.y = 0.0
	if away.length() < 0.1:
		away = -global_transform.basis.z
	var dir := away.normalized()
	var speed := flee_speed * _speed_mult
	velocity.x = dir.x * speed
	velocity.z = dir.z * speed
	_turn_toward(dir, delta, 10.0)
	var far := _player == null or global_position.distance_to(_player.global_position) > 16.0
	if _flee_timer <= 0.0 and far:
		_set_mode(Mode.CALM)
		awareness = 0.0
		alert_label.text = ""
		_returning = true
		_speed_mult = 1.0


func _start_fleeing() -> void:
	if mode != Mode.CALM:
		return
	_set_mode(Mode.FLEEING)
	_flee_timer = flee_duration
	_returning = false
	awareness = 1.0
	alert_label.text = "!"
	Sfx.play_at(&"gasp", global_position + Vector3(0, 1.5, 0), -2.0)
	_say("...Something's wrong with you!", 2.5)


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


# ---------------------------------------------------------------- social (Human form)

func talk(actor: Player) -> void:
	_turn_toward(actor.global_position - global_position, 1.0, 1.0)
	if profile.greeting_lines.is_empty():
		return
	var line := profile.greeting_lines[_line_index % profile.greeting_lines.size()]
	_line_index += 1
	_say("%s: \"%s\"" % [profile.display_name, line], 5.0)
	Sfx.play_at(&"blip", global_position + Vector3(0, 1.6, 0), -4.0, randf_range(0.9, 1.15))


# ---------------------------------------------------------------- feeding

func can_be_fed() -> bool:
	return mode == Mode.CALM or mode == Mode.FLEEING


func begin_feed(feeder: Node3D) -> void:
	was_afraid_when_grabbed = mode == Mode.FLEEING or awareness > 0.3
	_set_mode(Mode.ENTRANCED)
	_feed_progress = 0.0
	velocity = Vector3.ZERO
	awareness = 0.0
	alert_label.text = ""
	speech_label.visible = false
	_turn_toward(feeder.global_position - global_position, 1.0, 1.0)
	var tw := create_tween()
	tw.tween_property(model.body, "rotation:x", 0.32, 0.5)


func feed_tick(progress: float) -> void:
	_feed_progress = progress
	blood_left = 1.0 - progress


func finish_feed() -> Dictionary:
	_set_mode(Mode.DRAINED)
	blood_left = 0.0
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(model.body, "rotation:x", PI * 0.5, 0.9)
	tw.tween_property(model, "position:y", 0.2, 0.9)
	return get_feed_result()


## Feeding stopped early: they wrench free, dizzy but terrified.
func interrupt_feed() -> void:
	_set_mode(Mode.FLEEING)
	_flee_timer = flee_duration
	_speed_mult = 0.6
	awareness = 1.0
	alert_label.text = "!"
	var tw := create_tween()
	tw.tween_property(model.body, "rotation:x", 0.0, 0.3)
	Sfx.play_at(&"gasp", global_position + Vector3(0, 1.5, 0), -2.0)


func get_feed_result() -> Dictionary:
	return {
		"name": profile.display_name,
		"occupation": profile.occupation,
		"blood": profile.blood_description,
		"taste_note": "Sharp with adrenaline: fear has a flavour." if was_afraid_when_grabbed else "Steady and warm; they never saw it coming.",
		"title": profile.memory_title,
		"memory": profile.memory_text,
		"facts": profile.facts,
		"yield": profile.blood_yield * (1.25 if was_afraid_when_grabbed else 1.0),
	}


## A new night: everyone is back where they started, rested and forgetful.
func new_day() -> void:
	global_position = _home_pos
	rotation.y = _home_yaw
	velocity = Vector3.ZERO
	model.body.rotation = Vector3.ZERO
	model.position = Vector3.ZERO
	_set_mode(Mode.CALM)
	awareness = 0.0
	blood_left = 1.0
	_returning = false
	_speed_mult = 1.0
	alert_label.text = ""
	speech_label.visible = false


# ---------------------------------------------------------------- Vampiric Sense hooks

func get_heart_rate() -> float:
	match mode:
		Mode.FLEEING:
			return profile.base_heart_rate * 2.0
		Mode.ENTRANCED:
			return lerpf(profile.base_heart_rate * 1.7, profile.base_heart_rate * 0.8, _feed_progress)
		Mode.DRAINED:
			return profile.base_heart_rate * 0.55
	return profile.base_heart_rate * (1.0 + awareness * 0.7)


func _mood() -> String:
	match mode:
		Mode.FLEEING:
			return "terrified"
		Mode.ENTRANCED:
			return "swooning"
		Mode.DRAINED:
			return "drained, unconscious"
	return "uneasy" if awareness > 0.25 else "calm"


func get_sense_data() -> Dictionary:
	var bpm := get_heart_rate()
	var col := Color(0.85, 0.04, 0.1)
	match mode:
		Mode.FLEEING:
			col = Color(1.0, 0.35, 0.1)
		Mode.DRAINED:
			col = Color(0.45, 0.1, 0.5)
		_:
			if awareness > 0.25:
				col = Color(1.0, 0.2, 0.12)
	return {
		"label": "%s\n%d bpm, %s\n%s" % [profile.display_name, roundi(bpm), _mood(), profile.blood_description],
		"color": col,
		"bpm": bpm,
	}
