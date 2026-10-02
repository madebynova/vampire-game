class_name Hunter
extends FeedSource
## A vampire hunter: the first thing in Blackthorn that fights back. Deliberately one archetype, kept simple
## enough to read at a glance and dangerous enough to respect.
##
## He keeps a camp, arrives at dusk and walks a round by lantern; he sees you in a cone, further where it is lit
## and less far in the dark, hears you by how fast you move, and feels you if you are right behind him. Notice
## builds (a "?"), and when it fills he hunts: he runs you down by a route through the world's doorways (he
## cannot climb or pass a window), raises his blade where you can see it, and swings. A blow staggers you.
## Lose him - out of sight, through a window, up onto a roof, or by turning human - and he searches, then
## goes back to his round, warier. He withdraws at dawn.
##
## Hurt him enough and he goes down, alive and helpless; a vampire can drink from him (rich blood, a memory of
## his own), or leave him - and he will be back. Everything numeric is a HunterProfile; this is behaviour.
## He answers the FeedSource interface (so feeding needs no special case), the "hurtable" interface that
## PlayerCombat strikes (can_be_struck / strike_point / is_unaware / receive_strike), and Sense's hooks.

enum State { AWAY, PATROL, SUSPICIOUS, HUNTING, SEARCHING, RETIRING, DOWNED, FEEDING, DEAD }
enum Swing { NONE, WINDUP, RECOVER }

## Tests and tools can switch every hunter off (they stand down and stay away).
static var enabled := true
## Hunters keep their hours when NPC routines are frozen (tests that freeze the villagers but want the hunt).
static var always_on := false

signal state_changed(new_state: State)
## He has seen you and is coming.
signal noticed_player
signal hurt(info: HitInfo, amount: float)
signal went_down
## He has been drunk dry.
signal drained
## A swing came down; `landed` says whether it hit.
signal swung(landed: bool)

@export var profile: HunterProfile
@export var placement: HunterPlacement
@export var gravity := 20.0

## Set by WorldBuilder: the shared waypoint graph.
var nav: HuntNav
var state: State = State.AWAY
var swing: Swing = Swing.NONE
var health := 0.0
var awareness := 0.0
## Seconds left in which he is warier than usual (after losing you, or being hurt).
var wary_left := 0.0
var last_known := Vector3.ZERO
var model: HumanoidModel
## The player has learned who he is.
var known := false
## Observable by tests: how often he has killed the player, swung, landed.
var times_killed_player := 0
var swings := 0
var landed := 0

var _player: Player
var _tod: TimeOfDay
var _gear: Dictionary = {}
var _light: OmniLight3D
var _flame: MeshInstance3D
var _shape: CollisionShape3D
var _sense: SenseTarget
var _interactable: HunterInteractable
var _alert: Label3D
var _speech: Label3D
var _speech_t := 0.0
var _overhead: Node3D
var _hp_back: Sprite3D
var _hp_fill: Sprite3D
var _aw_back: Sprite3D
var _aw_fill: Sprite3D
var _hp_shown := -1.0
var _aw_shown := -1.0

var _path := PackedVector3Array()
var _goal := Vector3.ZERO
var _repath_t := 0.0
var _patrol_i := 0
var _patrol_dir := 1
var _linger := 0.0
var _linger_yaw := 0.0
var _swing_t := 0.0
var _atk_cd := 0.0
var _track_yaw := true
var _stagger_t := 0.0
var _flinch_t := 0.0
var _pause_t := 0.0
var _kb := Vector3.ZERO
var _feed_progress := 0.0
var _clock_t := 0.0
var _frames := 0

var _los := false
var _direct := false
var _los_t := 0.0
var _lit := 0.0
var _lit_t := 0.0
var _seen_now := false
var _cue_pos := Vector3.ZERO
var _susp_phase := 0
var _susp_t := 0.0
var _search_phase := 0
var _search_t := 0.0
var _lost_t := 0.0
var _unreach_t := 0.0
var _human_t := 0.0
var _saw_climb := false
var _stuck_t := 0.0
var _stuck_ref := Vector3.ZERO
var _stuck_n := 0
var _step := 0.0
var _clink_t := 4.0
var _flare := 0.0
var _seed := randf() * 10.0
## Test and tool hooks: `hold` = on his round he stands where he is (but still watches and reacts);
## `inert` = he does nothing at all (no senses, no moves), whatever state he is in.
var hold := false
var inert := false

static var _white: ImageTexture

## The floating readout is a constant size on screen (like Sense's labels), so it reads at 30 m and does not
## swallow the screen at 2 m. Sizes are in screen pixels; stacked upward with `offset`.
const BAR_W := 150.0
const BAR_H := 9.0
const READOUT_PIXEL := 0.0011


func _ready() -> void:
	add_to_group(&"hunters")
	add_to_group(&"hurtable")
	collision_layer = 4
	collision_mask = 1 | 2
	health = profile.max_health
	_shape = CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.35
	cap.height = 1.8
	_shape.shape = cap
	_shape.position = Vector3(0, 0.9, 0)
	add_child(_shape)
	model = HumanoidModel.new()
	model.name = "Model"
	add_child(model)
	model.apply_look(profile.skin_color, profile.coat_color, profile.pants_color, profile.hat_color, Color(0.1, 0.07, 0.05), 0.0, false, false)
	_gear = HunterGear.dress(model, profile)
	_light = _gear["light"]
	_flame = _gear["flame"]
	WorldLight.register(_light)
	# Vampiric Sense: a slow, trained heart.
	_sense = SenseTarget.new()
	_sense.kind = &"living"
	_sense.max_range = profile.sense_range
	_sense.label_range = 20.0
	_sense.label_offset = Vector3(0, 1.0, 0)
	_sense.heartbeat_audio = true
	_sense.position = Vector3(0, 1.2, 0)
	add_child(_sense)
	_interactable = HunterInteractable.new()
	_interactable.hunter = self
	_interactable.interact_range = 2.4
	_interactable.position = Vector3(0, 0.7, 0)
	add_child(_interactable)
	_build_overhead()
	rotation.y = deg_to_rad(placement.yaw_degrees) if placement != null else 0.0
	_go_away()


# ---------------------------------------------------------------- the floating readout

func _bar_sprite(color: Color, priority: int, height: float, y_offset: float) -> Sprite3D:
	if _white == null:
		var img := Image.create(256, 16, false, Image.FORMAT_RGBA8)
		img.fill(Color.WHITE)
		_white = ImageTexture.create_from_image(img)
	var s := Sprite3D.new()
	s.texture = _white
	s.centered = false
	s.region_enabled = true
	s.region_rect = Rect2(0, 0, BAR_W, height)
	s.pixel_size = READOUT_PIXEL
	s.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	s.fixed_size = true
	s.shaded = false
	s.no_depth_test = true
	s.render_priority = priority
	s.modulate = color
	s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	s.offset = Vector2(-BAR_W * 0.5, y_offset)
	_overhead.add_child(s)
	return s


func _build_overhead() -> void:
	_overhead = Node3D.new()
	_overhead.name = "Overhead"
	_overhead.position = Vector3(0, 2.15, 0)
	add_child(_overhead)
	_aw_back = _bar_sprite(Color(0, 0, 0, 0.6), 10, BAR_H * 0.6 + 4.0, 22.0)
	_aw_fill = _bar_sprite(Color(1.0, 0.75, 0.25, 0.95), 11, BAR_H * 0.6, 24.0)
	_hp_back = _bar_sprite(Color(0, 0, 0, 0.7), 12, BAR_H + 4.0, 0.0)
	_hp_fill = _bar_sprite(Color(0.85, 0.08, 0.12, 0.98), 13, BAR_H, 2.0)
	_alert = Label3D.new()
	_alert.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_alert.fixed_size = true
	_alert.no_depth_test = true
	_alert.modulate = Color(1.0, 0.25, 0.2)
	_alert.outline_modulate = Color(0, 0, 0, 1)
	_alert.font_size = 56
	_alert.outline_size = 10
	_alert.pixel_size = READOUT_PIXEL
	_alert.offset = Vector2(0, 52)
	_alert.text = ""
	_overhead.add_child(_alert)
	_speech = Label3D.new()
	_speech.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_speech.fixed_size = true
	_speech.no_depth_test = true
	_speech.modulate = Color(0.95, 0.9, 0.78)
	_speech.outline_modulate = Color(0, 0, 0, 1)
	_speech.font_size = 30
	_speech.outline_size = 8
	_speech.pixel_size = READOUT_PIXEL
	_speech.offset = Vector2(0, 108)
	_speech.visible = false
	_overhead.add_child(_speech)
	_update_bars()


func _set_bar(fill: Sprite3D, height: float, frac: float) -> void:
	fill.region_rect = Rect2(0, 0, maxf(BAR_W * clampf(frac, 0.0, 1.0), 0.5), height)


## Health and notice, only when they mean something: when he is hurt or hunting, and when he is starting to
## suspect you. Never on a sleeping camp or a body.
func _update_bars() -> void:
	var live := state == State.PATROL or state == State.SUSPICIOUS or state == State.HUNTING 		or state == State.SEARCHING or state == State.RETIRING
	var near := _player != null and global_position.distance_to(_player.global_position) < 34.0
	var show_hp := live and near and (health < profile.max_health - 0.5 or state == State.HUNTING or state == State.SEARCHING)
	var show_aw := live and near and awareness > 0.04 and state != State.HUNTING
	_hp_back.visible = show_hp
	_hp_fill.visible = show_hp
	_aw_back.visible = show_aw
	_aw_fill.visible = show_aw
	if show_hp:
		var f := snappedf(health / profile.max_health, 0.005)
		if f != _hp_shown:
			_hp_shown = f
			_set_bar(_hp_fill, BAR_H, f)
	if show_aw:
		var a := snappedf(awareness, 0.01)
		if a != _aw_shown:
			_aw_shown = a
			_set_bar(_aw_fill, BAR_H * 0.6, a)
			_aw_fill.modulate = Color(1.0, 0.8, 0.3).lerp(Color(1.0, 0.25, 0.15), clampf((a - 0.3) / 0.7, 0.0, 1.0))
	var glyph := ""
	match state:
		State.HUNTING:
			glyph = "!"
		State.SUSPICIOUS:
			glyph = "?"
		State.SEARCHING:
			glyph = "?"
		State.PATROL, State.RETIRING:
			glyph = "?" if awareness > 0.3 else ""
	if glyph != _alert.text:
		_alert.text = glyph
		_alert.modulate = Color(1.0, 0.22, 0.18) if state == State.HUNTING else Color(1.0, 0.8, 0.3)


func _say(lines: PackedStringArray, seconds := 1.9) -> void:
	if lines.is_empty():
		return
	_speech.text = lines[randi() % lines.size()]
	_speech.visible = true
	_speech_t = seconds


# ---------------------------------------------------------------- state

func _set_state(s: State) -> void:
	if s == state:
		return
	state = s
	state_changed.emit(s)


func _go_away() -> void:
	_set_state(State.AWAY)
	swing = Swing.NONE
	visible = false
	_shape.set_deferred("disabled", true)
	_light.visible = false
	velocity = Vector3.ZERO
	awareness = 0.0
	_path.clear()
	_alert.text = ""
	_speech.visible = false


func _appear() -> void:
	deploy(placement.camp, placement.yaw_degrees)
	_patrol_i = 0
	_patrol_dir = 1
	_resume_patrol()


## Put him on his feet at `pos`, facing `yaw_degrees`, in `st` (his camp at dusk; also how tests and tools stage him).
func deploy(pos: Vector3, yaw_degrees: float, st: State = State.PATROL) -> void:
	global_position = pos
	rotation.y = deg_to_rad(yaw_degrees)
	visible = true
	_shape.set_deferred("disabled", false)
	_light.visible = true
	model.body.rotation = Vector3.ZERO
	model.position = Vector3.ZERO
	velocity = Vector3.ZERO
	awareness = 0.0
	swing = Swing.NONE
	_stagger_t = 0.0
	_flinch_t = 0.0
	_pause_t = 0.0
	_kb = Vector3.ZERO
	_atk_cd = 0.0
	_path.clear()
	_linger = 0.0
	_interactable.position = Vector3(0, 0.7, 0)
	_set_state(st)


func is_active() -> bool:
	return state != State.AWAY and state != State.DEAD


func is_alive() -> bool:
	return state != State.DEAD and state != State.DOWNED and state != State.FEEDING


## Is he out, awake and on his feet (as opposed to away, down or dead)?
func is_up() -> bool:
	return state == State.PATROL or state == State.SUSPICIOUS or state == State.HUNTING \
		or state == State.SEARCHING or state == State.RETIRING


func is_engaged() -> bool:
	return state == State.HUNTING


## A fresh night, or the player died: rested (the player slept) or wary (the player was killed).
func player_rested(kind: StringName) -> void:
	if state == State.DEAD:
		return
	var missing := profile.max_health - health
	if kind == &"death":
		health += missing * 0.25
		wary_left = profile.wary_seconds * 1.5
	else:
		health += missing * 0.6
		wary_left = 0.0
	if state == State.DOWNED or state == State.FEEDING:
		# Someone left lying there is found, patched up and back on his feet by the next dusk.
		health = maxf(health, profile.max_health * (0.25 if kind == &"death" else 0.6))
	awareness = 0.0
	swing = Swing.NONE
	_stagger_t = 0.0
	if state == State.DOWNED or state == State.FEEDING:
		model.body.rotation = Vector3.ZERO
		model.position = Vector3.ZERO
		_interactable.position = Vector3(0, 0.7, 0)
	if kind == &"death" and is_up():
		_resume_patrol()
	else:
		_go_away()
		_clock_t = 0.0


# ---------------------------------------------------------------- the clock

func _check_hours() -> void:
	if state == State.DEAD or state == State.DOWNED or state == State.FEEDING:
		return
	if _tod == null:
		return
	if inert:
		return
	if not enabled or not (HumanNpc.schedules_enabled or always_on):
		if state != State.AWAY:
			_go_away()
		return
	var h := _tod.hour
	var on := profile.is_on_duty(h)
	match state:
		State.AWAY:
			if on:
				_appear()
		State.PATROL, State.SUSPICIOUS, State.SEARCHING:
			if not on:
				_begin_retire()
		State.HUNTING:
			# A fight that runs into the small hours goes on; the sky ends it.
			if not on and not _in_late_window(h):
				_begin_retire()


func _in_late_window(h: float) -> bool:
	return h >= profile.active_until and h < profile.dawn_hour


func _begin_retire() -> void:
	_set_state(State.RETIRING)
	swing = Swing.NONE
	awareness = 0.0
	_path = _route_to(placement.camp)


# ---------------------------------------------------------------- per-frame

func _physics_process(delta: float) -> void:
	_frames += 1
	if _player == null:
		_player = get_tree().get_first_node_in_group(&"player") as Player
	if _tod == null:
		_tod = get_tree().get_first_node_in_group(&"time_of_day") as TimeOfDay
	if nav != null and not nav.is_built() and _frames >= 3:
		nav.build(get_world_3d().direct_space_state)
	_clock_t -= delta
	if _clock_t <= 0.0:
		_clock_t = 0.4
		_check_hours()
	if _speech_t > 0.0:
		_speech_t -= delta
		if _speech_t <= 0.0:
			_speech.visible = false
	if state == State.AWAY:
		return
	wary_left = maxf(wary_left - delta, 0.0)
	_flare = move_toward(_flare, 0.0, delta * 3.0)
	if _pause_t > 0.0:
		_pause_t -= delta
		return
	_atk_cd = maxf(_atk_cd - delta, 0.0)
	_kb = _kb.move_toward(Vector3.ZERO, 26.0 * delta)
	if inert:
		_flat_velocity(Vector3.ZERO, delta, 40.0)
		if not is_on_floor():
			velocity.y -= gravity * delta
		else:
			velocity.y = 0.0
		move_and_slide()
		_present(delta)
		_update_bars()
		return
	_refresh_senses(delta)
	if is_up() and _player != null:
		_perceive(delta)
	_flinch_t = maxf(_flinch_t - delta, 0.0)
	if _stagger_t > 0.0:
		_stagger_t -= delta
	match state:
		State.PATROL:
			_patrol(delta)
		State.SUSPICIOUS:
			_suspicious(delta)
		State.HUNTING:
			_hunting(delta)
		State.SEARCHING:
			_searching(delta)
		State.RETIRING:
			_retiring(delta)
		_:
			_flat_velocity(Vector3.ZERO, delta, 40.0)
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = 0.0
	move_and_slide()
	_present(delta)
	_update_bars()


## The cheap, cached questions: is there a clear line to the player, and how lit are they.
func _refresh_senses(delta: float) -> void:
	if _player == null:
		return
	_los_t -= delta
	if _los_t <= 0.0:
		_los_t = 0.1
		_los = _compute_los()
		if state == State.HUNTING and nav != null:
			_direct = _los and HuntNav.line_clear(get_world_3d().direct_space_state, global_position, _player.global_position)
	_lit_t -= delta
	if _lit_t <= 0.0:
		_lit_t = 0.25
		var ambient := 0.0
		if _tod != null:
			ambient = (1.0 - _tod.darkness()) * 0.85
		_lit = WorldLight.at(_player.global_position, ambient, get_world_3d().direct_space_state)


func _compute_los() -> bool:
	var mode := _player.state.mode
	if _player.state.is_dead() or mode == PlayerState.Mode.TRAVERSING or mode == PlayerState.Mode.RESTING:
		return false
	var from := global_position + Vector3(0, 1.65, 0)
	var to := _player.global_position + Vector3(0, 1.2, 0)
	var q := PhysicsRayQueryParameters3D.create(from, to, Greybox.WORLD)
	return get_world_3d().direct_space_state.intersect_ray(q).is_empty()


# ---------------------------------------------------------------- noticing

## Build or lose awareness of the player from what he can see (a cone, as far as the light lets him), hear (by
## how fast you move) and feel (right behind him). A human is nothing to a hunter of vampires.
func _perceive(delta: float) -> void:
	if _player.state.is_dead():
		awareness = maxf(awareness - 0.4 * delta, 0.0)
		_seen_now = false
		return
	var vampire := _player.form.current.frightens_humans
	var mist := _player.state.mode == PlayerState.Mode.TRAVERSING or _player.state.mode == PlayerState.Mode.RESTING
	var to := _player.global_position - global_position
	var flat := Vector2(to.x, to.z).length()
	var speed := Vector2(_player.velocity.x, _player.velocity.z).length()
	var wary := 1.35 if wary_left > 0.0 else 1.0
	var sight := CombatRules.sight_radius(profile.sight_range, profile.dark_sight_factor, _lit, wary)
	var hear := CombatRules.hearing_radius(speed, profile.hear_still, profile.hear_walk, profile.hear_run) * wary
	var fwd := -global_transform.basis.z
	var in_cone := CombatRules.in_cone(global_position, fwd, _player.global_position, sight, profile.sight_half_angle_degrees, 0.0)
	var seen := in_cone and _los and vampire and not mist
	var heard := flat <= (hear if _los else hear * 0.5) and vampire and not mist and absf(to.y) < 2.4
	var felt := flat <= profile.feel_radius and _los and vampire and not mist
	_seen_now = seen
	var rate := CombatRules.notice_rate(flat, seen, sight, heard, hear, felt,
		profile.notice_rate_far, profile.notice_rate_near, profile.notice_rate_heard)
	if rate > 0.0:
		awareness = minf(awareness + rate * delta * (1.0 if state != State.SEARCHING else 1.4), 1.0)
		_cue_pos = _player.global_position
	else:
		awareness = maxf(awareness - (0.7 if not vampire else 0.22) * delta, 0.0)
	if seen and state == State.HUNTING:
		last_known = _player.global_position


func is_unaware() -> bool:
	return state == State.PATROL or state == State.SUSPICIOUS or state == State.SEARCHING or state == State.RETIRING


## He has seen you: the chase begins.
func _spot() -> void:
	var fresh := state != State.HUNTING
	_set_state(State.HUNTING)
	awareness = 1.0
	wary_left = profile.wary_seconds
	_lost_t = 0.0
	_unreach_t = 0.0
	_human_t = 0.0
	_saw_climb = false
	_repath_t = 0.0
	last_known = _player.global_position if _player != null else global_position
	swing = Swing.NONE
	if fresh:
		Sfx.play(&"hunter_spot", -5.0)
		Haptics.pulse(0.3, 0.5, 0.15)
		_say(profile.lines_spot, 2.2)
		if _player != null:
			_player.camera_rig.kick_fov(3.5, 6.0)
		noticed_player.emit()


# ---------------------------------------------------------------- moving

func _flat_velocity(v: Vector3, delta: float, accel := 22.0) -> void:
	var cur := Vector3(velocity.x, 0.0, velocity.z) - _kb
	cur = cur.move_toward(Vector3(v.x, 0.0, v.z), accel * delta)
	velocity.x = cur.x + _kb.x
	velocity.z = cur.z + _kb.z


func _turn_toward(dir: Vector3, delta: float, rate: float) -> void:
	if Vector2(dir.x, dir.z).length() < 0.01:
		return
	rotation.y = lerp_angle(rotation.y, atan2(-dir.x, -dir.z), minf(1.0, rate * delta))


func _route_to(goal: Vector3) -> PackedVector3Array:
	_goal = goal
	if nav == null:
		return PackedVector3Array([goal])
	return nav.path(get_world_3d().direct_space_state, global_position, goal)


## Walk the current route. Returns true while there is still somewhere to go.
func _walk(speed: float, delta: float) -> bool:
	while not _path.is_empty():
		var to := _path[0] - global_position
		to.y = 0.0
		var last := _path.size() == 1
		if to.length() < (0.45 if last else 0.8):
			_path.remove_at(0)
			_stuck_n = 0
			continue
		var dir := to.normalized()
		_flat_velocity(dir * speed, delta)
		_turn_toward(dir, delta, 8.0)
		_watch_for_stuck(delta)
		return true
	_flat_velocity(Vector3.ZERO, delta, 30.0)
	return false


## Held up by something the graph did not know about: look again, and if that fails hop on.
func _watch_for_stuck(delta: float) -> void:
	_stuck_t += delta
	if _stuck_t < 1.0:
		return
	_stuck_t = 0.0
	if Vector2(global_position.x - _stuck_ref.x, global_position.z - _stuck_ref.z).length() < 0.15:
		_stuck_n += 1
		if _stuck_n >= 3 and not _path.is_empty():
			global_position = Vector3(_path[0].x, global_position.y, _path[0].z)
			_stuck_n = 0
		else:
			_path = _route_to(_goal)
	_stuck_ref = global_position


func _step_sounds(delta: float) -> void:
	var speed := Vector2(velocity.x, velocity.z).length()
	if speed < 0.4 or not is_on_floor():
		return
	_step += speed * delta
	if _step >= 1.75:
		_step = 0.0
		Sfx.play_at(&"step_boot", global_position, -15.0 + minf(speed, 6.0) * 0.8, randf_range(0.9, 1.1))
	_clink_t -= delta
	if _clink_t <= 0.0:
		_clink_t = randf_range(3.5, 7.0)
		Sfx.play_at(&"lantern_clink", global_position + Vector3(-0.3, 1.0, -0.2), -17.0, randf_range(0.9, 1.15))


# ---------------------------------------------------------------- patrol

func _resume_patrol() -> void:
	_set_state(State.PATROL)
	_path.clear()
	_linger = 0.0
	awareness = minf(awareness, 0.2)
	if placement.patrol.is_empty():
		return
	# Pick up the round at the nearest point of it.
	var best := 0
	var best_d := INF
	for i in placement.patrol.size():
		var d := Vector2(placement.patrol[i].x - global_position.x, placement.patrol[i].z - global_position.z).length()
		if d < best_d:
			best_d = d
			best = i
	_patrol_i = best
	_path = _route_to(placement.patrol[_patrol_i])
	_stuck_ref = global_position


func _next_patrol_leg() -> void:
	if placement.patrol.is_empty():
		return
	var next := _patrol_i + _patrol_dir
	if next < 0 or next >= placement.patrol.size():
		_patrol_dir = -_patrol_dir
		next = _patrol_i + _patrol_dir
	_patrol_i = clampi(next, 0, placement.patrol.size() - 1)
	_path = _route_to(placement.patrol[_patrol_i])
	_stuck_ref = global_position
	_stuck_n = 0


func _patrol(delta: float) -> void:
	if awareness >= 1.0:
		_spot()
		return
	if awareness >= 0.3 and _player != null and not _player.state.is_dead():
		_become_suspicious()
		return
	if _linger > 0.0:
		_linger -= delta
		_flat_velocity(Vector3.ZERO, delta, 30.0)
		rotation.y = _linger_yaw + sin(Time.get_ticks_msec() / 1000.0 * 0.9 + _seed) * 0.75
		if _linger <= 0.0:
			_next_patrol_leg()
		return
	if hold:
		_flat_velocity(Vector3.ZERO, delta, 30.0)
		return
	var speed := profile.patrol_speed * (1.15 if wary_left > 0.0 else 1.0)
	if _walk(speed, delta):
		_step_sounds(delta)
		return
	if placement.patrol.is_empty():
		return
	_linger = placement.pause_at(_patrol_i)
	_linger_yaw = rotation.y


func _become_suspicious() -> void:
	_set_state(State.SUSPICIOUS)
	_susp_phase = 0
	_susp_t = 0.0
	_path.clear()
	Sfx.play_at(&"hunter_notice", global_position + Vector3(0, 1.8, 0), -2.0)
	_say(profile.lines_suspicious, 1.8)


func _suspicious(delta: float) -> void:
	if awareness >= 1.0:
		_spot()
		return
	_susp_t += delta
	match _susp_phase:
		0:
			_flat_velocity(Vector3.ZERO, delta, 30.0)
			_turn_toward(_cue_pos - global_position, delta, 5.0)
			if _susp_t >= 0.8:
				_susp_phase = 1
				_susp_t = 0.0
				_path = _route_to(_cue_pos)
				_stuck_ref = global_position
		1:
			if not _walk(profile.investigate_speed, delta) or _susp_t > 7.0:
				_susp_phase = 2
				_susp_t = 0.0
			else:
				_step_sounds(delta)
		2:
			_flat_velocity(Vector3.ZERO, delta, 30.0)
			rotation.y += sin(Time.get_ticks_msec() / 1000.0 * 1.3 + _seed) * 1.2 * delta
			if _susp_t >= 3.0 and awareness < 0.3:
				wary_left = maxf(wary_left, profile.wary_seconds * 0.5)
				_resume_patrol()


# ---------------------------------------------------------------- the hunt

func _hunting(delta: float) -> void:
	if _player == null or _player.state.is_dead():
		_resume_patrol()
		return
	var to := _player.global_position - global_position
	var flat := Vector2(to.x, to.z).length()
	var vampire := _player.form.current.frightens_humans
	# A swing in progress: it is the only thing he is doing.
	if swing != Swing.NONE:
		_swinging(delta)
		return
	if _stagger_t > 0.0 or _flinch_t > 0.0:
		_flat_velocity(Vector3.ZERO, delta, 18.0)
		return
	# Lost sight of you?
	if _seen_now or (_los and flat < 4.0):
		_lost_t = 0.0
		last_known = _player.global_position
		_saw_climb = to.y >= 1.6
	else:
		_lost_t += delta
	# You turned into a person: for a moment he is not sure what he saw.
	if not vampire:
		_human_t += delta
		if _human_t > 2.0:
			_begin_search(last_known)
			return
	else:
		_human_t = 0.0
	# (He does not lose someone he watched go up a wall and who is still up there: he waits at the foot of it.)
	if _lost_t > 3.0 and not (_saw_climb and to.y >= 1.6):
		_say(profile.lines_lost, 2.0)
		_begin_search(last_known)
		return
	var reachable := to.y < 1.6
	if not reachable:
		_stand_under(to, flat, delta)
		return
	_unreach_t = 0.0
	# In reach and facing: raise the blade.
	if flat <= profile.attack_range and _los and _atk_cd <= 0.0 and absf(to.y) < 1.5 and vampire:
		_begin_swing()
		return
	# Chase: straight at you if the way is clear, otherwise through the doorways.
	var target := _player.global_position if _los else last_known
	_repath_t -= delta
	if _direct or nav == null:
		_path = PackedVector3Array([target])
	elif _repath_t <= 0.0 or _path.is_empty():
		_repath_t = 0.4
		_path = _route_to(target)
	if _path.is_empty():
		_flat_velocity(Vector3.ZERO, delta, 30.0)
		_turn_toward(to, delta, 8.0)
		return
	if flat > 1.6 or not _los:
		_walk(profile.chase_speed * (1.1 if wary_left > 0.0 else 1.0), delta)
		_step_sounds(delta)
	else:
		_flat_velocity(Vector3.ZERO, delta, 30.0)
		_turn_toward(to, delta, 10.0)


## You are somewhere he cannot climb to. He goes to the foot of it and glares up, then gives up.
func _stand_under(to: Vector3, flat: float, delta: float) -> void:
	# He is patient at the foot of the wall; on the way there (it may be the long way round) the clock barely runs.
	_unreach_t += delta if flat <= 3.5 else delta * 0.25
	_turn_toward(to, delta, 6.0)
	if flat > 2.6:
		_repath_t -= delta
		if _repath_t <= 0.0 or _path.is_empty():
			_repath_t = 0.5
			var ground := Vector3(_player.global_position.x, global_position.y, _player.global_position.z)
			var route := _route_to(ground)
			# If getting there means a long way round (the spot is inside a building), go to the foot of the wall.
			if route.is_empty() or HuntNav.length_of(global_position, route) > flat * 1.8 + 3.0:
				route = PackedVector3Array([_approach_point(ground)])
			_path = route
		if not _walk(profile.chase_speed * 0.8, delta):
			_flat_velocity(Vector3.ZERO, delta, 30.0)
		else:
			_step_sounds(delta)
	else:
		_flat_velocity(Vector3.ZERO, delta, 30.0)
	if _unreach_t >= profile.give_up_unreachable:
		_say(profile.lines_lost, 2.0)
		_begin_search(last_known)


## The furthest point toward `target` that he can walk to in a straight line: the foot of the wall he cannot pass.
func _approach_point(target: Vector3) -> Vector3:
	var space := get_world_3d().direct_space_state
	if HuntNav.line_clear(space, global_position, target):
		return target
	var lo := 0.0
	var hi := 1.0
	for _i in 6:
		var mid := (lo + hi) * 0.5
		if HuntNav.line_clear(space, global_position, global_position.lerp(target, mid)):
			lo = mid
		else:
			hi = mid
	return global_position.lerp(target, lo)


func _begin_swing() -> void:
	swing = Swing.WINDUP
	_swing_t = 0.0
	_track_yaw = true
	swings += 1
	_flare = 1.0
	Sfx.play_at(&"hunter_windup", global_position + Vector3(0, 1.4, 0), 0.0)
	Haptics.pulse(0.2, 0.0, 0.1)


func _swinging(delta: float) -> void:
	_swing_t += delta
	_flat_velocity(Vector3.ZERO, delta, 40.0)
	if swing == Swing.WINDUP:
		# He tracks you while the blade goes up, then commits: the last of the wind-up is a fair tell.
		if _swing_t < profile.attack_windup * 0.6 and _player != null:
			_turn_toward(_player.global_position - global_position, delta, 12.0)
		_flare = 1.0
		if _swing_t >= profile.attack_windup:
			_strike()
	elif swing == Swing.RECOVER:
		if _swing_t >= profile.attack_recovery:
			swing = Swing.NONE
			_atk_cd = profile.attack_gap


## The blade comes down. It lands only if you are still there.
func _strike() -> void:
	swing = Swing.RECOVER
	_swing_t = 0.0
	Sfx.play_at(&"hunter_swing", global_position + Vector3(0, 1.3, 0), 1.0)
	var hit := false
	if _player != null and not _player.state.is_dead():
		var to := _player.global_position - global_position
		var fwd := -global_transform.basis.z
		if absf(to.y) < 1.5 and CombatRules.in_cone(global_position, fwd, _player.global_position, profile.attack_reach, 52.0, 0.8):
			var q := PhysicsRayQueryParameters3D.create(global_position + Vector3(0, 1.3, 0), _player.global_position + Vector3(0, 1.1, 0), Greybox.WORLD)
			if get_world_3d().direct_space_state.intersect_ray(q).is_empty():
				var info := HitInfo.new()
				info.amount = profile.attack_damage
				info.kind = &"blade"
				info.source = self
				info.origin = global_position
				info.knockback = profile.knockback
				info.stagger = profile.stagger_seconds
				info.strong = true
				hit = _player.combat.take_hit(info)
				if hit and _player.state.is_dead():
					times_killed_player += 1
	if hit:
		landed += 1
	swung.emit(hit)


# ---------------------------------------------------------------- losing you

func _begin_search(at: Vector3) -> void:
	_set_state(State.SEARCHING)
	swing = Swing.NONE
	_search_phase = 0
	_search_t = profile.search_seconds
	awareness = minf(awareness, 0.5)
	_path = _route_to(at)
	_stuck_ref = global_position
	wary_left = maxf(wary_left, profile.wary_seconds)


func _searching(delta: float) -> void:
	if awareness >= 1.0:
		_spot()
		return
	if _search_phase == 0:
		if _walk(profile.investigate_speed * 1.2, delta):
			_step_sounds(delta)
		else:
			_search_phase = 1
		return
	_flat_velocity(Vector3.ZERO, delta, 30.0)
	_search_t -= delta
	rotation.y += sin(Time.get_ticks_msec() / 1000.0 * 1.6 + _seed) * 1.7 * delta
	if _search_t <= 0.0:
		_resume_patrol()


func _retiring(delta: float) -> void:
	# Withdrawing at the end of the night, he will still turn on someone who attacks him before the sky is light.
	if awareness >= 1.0 and _tod != null and _in_late_window(_tod.hour):
		_spot()
		return
	if _walk(profile.retreat_speed, delta):
		_step_sounds(delta)
		return
	_go_away()


# ---------------------------------------------------------------- presentation

func _present(delta: float) -> void:
	var flat_speed := Vector2(velocity.x, velocity.z).length()
	var down := state == State.DOWNED or state == State.FEEDING or state == State.DEAD
	if down:
		model.body.rotation.x = lerpf(model.body.rotation.x, PI * 0.5, minf(1.0, 6.0 * delta))
		model.position = model.position.lerp(Vector3(0, 0.2, -0.85), minf(1.0, 6.0 * delta))
	else:
		model.animate(flat_speed, is_on_floor(), delta)
		var recoil := (0.35 if (_flinch_t > 0.0 or _stagger_t > 0.0) else 0.0)
		model.body.rotation.x = lerpf(model.body.rotation.x, -recoil, minf(1.0, 14.0 * delta))
		# The lantern arm: out in front, raised to peer when he is looking for you.
		var peering := state == State.SUSPICIOUS or state == State.SEARCHING
		model.arm_pose(false, 1.5 if peering else 0.75, -0.12)
		match swing:
			Swing.WINDUP:
				var k := clampf(_swing_t / profile.attack_windup, 0.0, 1.0)
				model.arm_pose(true, lerpf(0.3, 2.95, k * k), 0.1)
				model.arm_pose(false, 0.4, -0.4)
			Swing.RECOVER:
				var k := clampf(_swing_t / 0.14, 0.0, 1.0)
				model.arm_pose(true, lerpf(2.95, 0.9, k), 0.0)
	# The lantern breathes, and flares when he commits to a blow.
	var t := Time.get_ticks_msec() / 1000.0
	var base := 1.7 if state != State.DOWNED else 0.5
	if state == State.DEAD:
		base = 0.0
	_light.light_energy = base * (1.0 + 0.07 * sin(t * 9.0 + _seed)) + _flare * 2.2
	(_flame.material_override as StandardMaterial3D).emission_energy_multiplier = (5.0 if state != State.DEAD else 0.0) + _flare * 4.0
	_light.visible = state != State.AWAY and state != State.DEAD


# ---------------------------------------------------------------- being struck (the "hurtable" interface)

func can_be_struck() -> bool:
	return is_up()


## Where a blow aims: the middle of his chest.
func strike_point() -> Vector3:
	return global_position + Vector3(0, 1.1, 0)


func receive_strike(info: HitInfo) -> void:
	if not can_be_struck():
		return
	health = maxf(health - info.amount, 0.0)
	_pop_number(info)
	hurt.emit(info, info.amount)
	if health <= 0.0:
		_go_down(info)
		return
	var fresh := state != State.HUNTING
	awareness = 1.0
	wary_left = profile.wary_seconds
	last_known = info.origin
	if fresh:
		_spot()
	var strong := info.strong or info.ambush
	if strong:
		swing = Swing.NONE
		_stagger_t = profile.stagger_hit_seconds
		_atk_cd = maxf(_atk_cd, 0.35)
	elif swing != Swing.WINDUP:
		_flinch_t = profile.flinch_seconds
	var away := global_position - info.origin
	away.y = 0.0
	away = away.normalized() if away.length() > 0.05 else -global_transform.basis.z
	_kb = away * info.knockback
	_pause_t = 0.05
	Sfx.play_at(&"hunter_hurt", global_position + Vector3(0, 1.5, 0), 0.0, randf_range(0.9, 1.1))
	if randf() < 0.45:
		_say(profile.lines_hurt, 1.5)


## A number that rises off him and fades: the plain answer to "did that hit, and how hard".
func _pop_number(info: HitInfo) -> void:
	var l := Label3D.new()
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.text = "-%d" % roundi(info.amount) + ("  AMBUSH" if info.ambush else ("  PLUNGE" if info.kind == &"plunge" else ""))
	l.modulate = Color(1.0, 0.82, 0.4) if (info.ambush or info.kind == &"plunge") else Color(1.0, 0.45, 0.4)
	l.outline_modulate = Color(0, 0, 0, 1)
	l.font_size = 54 if info.ambush else 42
	l.outline_size = 10
	l.fixed_size = true
	l.pixel_size = READOUT_PIXEL
	l.top_level = true
	add_child(l)
	l.global_position = global_position + Vector3(randf_range(-0.25, 0.25), 2.0, randf_range(-0.2, 0.2))
	var tw := create_tween().set_parallel(true)
	tw.tween_property(l, "global_position:y", l.global_position.y + 0.9, 0.8)
	tw.tween_property(l, "modulate:a", 0.0, 0.8).set_delay(0.25)
	tw.chain().tween_callback(l.queue_free)


func _go_down(_info: HitInfo) -> void:
	_set_state(State.DOWNED)
	swing = Swing.NONE
	awareness = 0.0
	_path.clear()
	_stagger_t = 0.0
	_flinch_t = 0.0
	velocity = Vector3.ZERO
	_alert.text = ""
	_say(profile.lines_down, 2.6)
	Sfx.play_at(&"hunter_down", global_position + Vector3(0, 1.0, 0), 2.0)
	Haptics.pulse(0.6, 0.8, 0.2)
	_interactable.position = Vector3(0, 0.45, 0)
	went_down.emit()


# ---------------------------------------------------------------- FeedSource: the blood of a hunter

func can_be_fed() -> bool:
	return state == State.DOWNED


func begin_feed(_feeder: Node3D) -> void:
	_set_state(State.FEEDING)
	_feed_progress = 0.0


func feed_tick(progress: float) -> void:
	_feed_progress = progress


## Drunk dry: the hunt's quarry is dead. The lantern goes out.
func finish_feed() -> Dictionary:
	var result := get_feed_result()
	_mark_tasted()
	health = 0.0
	_set_state(State.DEAD)
	_light.visible = false
	drained.emit()
	return result


## The vampire let go: he is still out cold.
func interrupt_feed() -> void:
	_set_state(State.DOWNED)


func is_lying() -> bool:
	return state == State.DOWNED or state == State.FEEDING or state == State.DEAD


func feed_style() -> FeedStyle:
	var st := ContentRegistry.get_def(&"FeedStyle", profile.feed_style) as FeedStyle
	if st == null:
		st = ContentRegistry.get_def(&"FeedStyle", &"calm") as FeedStyle
	return st


func feed_seconds() -> float:
	return profile.feed_seconds


func _memory() -> BloodMemory:
	return profile.memory()


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


func get_feed_result() -> Dictionary:
	var style := feed_style()
	var blood := profile.blood_definition()
	var mem := _memory()
	var first := has_unheard_memory()
	var told := mem != null and first
	return {
		"name": profile.display_name,
		"occupation": "vampire hunter",
		"blood": profile.blood_description,
		"taste_note": style.taste_note,
		"title": mem.title if told else "",
		"memory": mem.text if told else "",
		"facts": mem.facts if told else PackedStringArray(),
		"reveals": mem.reveals_secret if told else &"",
		"condition": &"hunter",
		"style": style,
		"style_id": style.id,
		"blood_type": blood.display_name if blood else "Hunter",
		"blood_note": blood.description if blood else "",
		"yield": profile.blood_yield * (blood.yield_multiplier if blood else 1.0) * style.yield_multiplier,
		"surge_name": style.surge_name,
		"surge_power": style.surge_power * (blood.surge_power_multiplier if blood else 1.0),
		"surge_seconds": style.surge_seconds * (blood.surge_seconds_multiplier if blood else 1.0),
		"first_time": first,
	}


# ---------------------------------------------------------------- Vampiric Sense hooks

func is_sense_visible() -> bool:
	return state != State.AWAY and state != State.DEAD


func get_heart_rate() -> float:
	match state:
		State.HUNTING:
			return profile.base_heart_rate * (2.0 if swing != Swing.NONE else 1.7)
		State.SUSPICIOUS, State.SEARCHING:
			return profile.base_heart_rate * 1.3
		State.DOWNED, State.FEEDING:
			return profile.base_heart_rate * 0.55
	return profile.base_heart_rate * (1.0 + awareness * 0.4)


## What Sense tells you about the man himself - the thing it is best at: whether he knows you are there, and
## which way he is looking.
func mood() -> String:
	match state:
		State.HUNTING:
			return "hunting you"
		State.SUSPICIOUS:
			return "suspicious"
		State.SEARCHING:
			return "searching"
		State.DOWNED, State.FEEDING:
			return "down"
		State.RETIRING:
			return "withdrawing"
	return "uneasy" if awareness > 0.25 else "unaware of you"


func get_sense_data(dist := 0.0) -> Dictionary:
	var bpm := get_heart_rate()
	var col := Color(0.95, 0.88, 0.55)
	match state:
		State.HUNTING:
			col = Color(1.0, 0.12, 0.08)
		State.SUSPICIOUS, State.SEARCHING:
			col = Color(1.0, 0.55, 0.15)
		State.DOWNED, State.FEEDING:
			col = Color(0.5, 0.2, 0.55)
		_:
			if awareness > 0.25:
				col = Color(1.0, 0.7, 0.25)
	var label := ""
	var title := ""
	var detail := ""
	var blood := ""
	var hint := ""
	if dist > 20.0:
		label = ""
	elif dist > 12.0:
		title = "a hunter"
		detail = "%d bpm" % roundi(bpm)
		label = "a hunter, %d bpm" % roundi(bpm)
	else:
		title = ("%s, %s" % [profile.display_name, profile.title.to_lower()]) if known else "A hunter"
		detail = "%d bpm, %s" % [roundi(bpm), mood()]
		label = "%s\n%s" % [title, detail]
		if dist < 8.0:
			blood = profile.blood_description
			label += "\n" + blood
		if state == State.DOWNED and has_unheard_memory():
			hint = "his memory waits"
		elif is_unaware() and _player != null:
			var to := _player.global_position - global_position
			to.y = 0.0
			if to.length() > 0.1 and (-global_transform.basis.z).dot(to.normalized()) < -0.25:
				hint = "his back is to you"
	return {"label": label, "title": title, "detail": detail, "blood": blood, "hint": hint,
		"known": known, "tasted": HumanNpc.tasted.get(profile.id, {}).size(), "color": col, "bpm": bpm,
		"state": _sense_state(), "label_offset": Vector3(0, 0.7 if is_lying() else 2.5, 0)}


func _sense_state() -> StringName:
	match state:
		State.HUNTING, State.SUSPICIOUS, State.SEARCHING:
			return &"afraid"
		State.DOWNED, State.FEEDING:
			return &"asleep"
		State.DEAD:
			return &"drained"
	return &"calm"


## Test hook: a one-line description of what he is doing.
func describe() -> String:
	return "%s swing=%s aware=%.2f hp=%.0f" % [State.keys()[state], Swing.keys()[swing], awareness, health]
