class_name PlayerCombat
extends PlayerComponent
## The vampire's one attack, Rend, and being on the receiving end of a blow.
##
## Rend is a short swing: a quick draw back, the strike (the only moment it can hit), a recovery you can
## see on the reticle. Where it lands decides how it lands - at a run it is a pounce (a lunge, with a
## shove forward), falling onto someone it is a plunge, and against someone who does not know you are there
## it is an ambush that hits three times as hard. It costs a little blood, gives a taste back when it
## connects, weakens with hunger and strengthens in a Bloodrush. It cannot be spammed: the swing has to
## finish, though one press during its last moments is remembered.
##
## Being hit: damage goes through Health (so the blood vessel's ring and the screen answer), the blow
## throws you back and staggers you for a moment (feeding is torn off), and you are safe from a second
## blow for a short grace. Slipping through a window or climbing is a mist: nothing can touch you.

signal strike_started(kind: StringName)
## A blow landed on `target`.
signal struck(target: Node3D, info: HitInfo)
signal whiffed
## The swing is over and Rend can be used again.
signal ready_again
## You were hit.
signal hurt(info: HitInfo, amount: float)

enum Phase { IDLE, WINDUP, STRIKE, RECOVER }

@export var windup := 0.11
@export var strike_time := 0.09
@export var recover := 0.36
## How far the claws reach, and how wide in front of you (half-angle).
@export var reach := 2.3
@export var lunge_reach_bonus := 0.7
@export var half_angle_degrees := 62.0
## Aim help: a target this close and this near the line of the camera is turned to.
@export var assist_range := 4.4
@export var assist_angle_degrees := 80.0
@export var blood_cost := 1.0
@export var blood_taste := 2.5
## Pace needed to pounce, and the shove it gives.
@export var lunge_min_speed := 5.6
@export var lunge_speed := 7.0
@export var buffer_time := 0.2
## Seconds you cannot be hit again after a blow lands.
@export var grace_seconds := 0.7
## In a fight the camera slips to over the right shoulder by this much, so the one in front of you is not
## hidden behind your own back.
@export var shoulder_offset := 0.8

var phase: Phase = Phase.IDLE
var kind: StringName = &"rend"
var invulnerable_left := 0.0
## Observable by tests: how many swings and how many landed.
var swings := 0
var hits := 0
var last_info: HitInfo

var _t := 0.0
var _elapsed := 0.0
var _buffer := 0.0
var _stagger_left := 0.0
var _freeze := 0.0
var _noise_cooldown := 0.0
var _engage_t := 0.0
var _engaged := false
var _slash: MeshInstance3D


func _on_setup() -> void:
	player.health.died.connect(func(_c): reset())
	player.form.form_changed.connect(func(_o, f: FormData):
		if f.strike_damage <= 0.0:
			reset())


func reset() -> void:
	phase = Phase.IDLE
	_t = 0.0
	_elapsed = 0.0
	_buffer = 0.0
	_stagger_left = 0.0
	_freeze = 0.0
	invulnerable_left = 0.0
	player.speed_modifiers.erase(&"strike")


# ---------------------------------------------------------------- state

func total_time() -> float:
	return windup + strike_time + recover


func can_strike() -> bool:
	return player.form.current.strike_damage > 0.0 and player.state.mode == PlayerState.Mode.NORMAL \
		and not player.traversal.active


func is_attacking() -> bool:
	return phase != Phase.IDLE


## 0..1 through the whole swing; 1 means Rend is ready.
func progress() -> float:
	return 1.0 if phase == Phase.IDLE else clampf(_elapsed / total_time(), 0.0, 1.0)


func is_staggered() -> bool:
	return _stagger_left > 0.0


## The direction the body faces, flat.
func facing() -> Vector3:
	return -Basis(Vector3.UP, player.visual.rotation.y).z


## Is a hunter running you down within a short distance (the fight is on)?
func _someone_is_hunting_me() -> bool:
	if player.form.current.strike_damage <= 0.0:
		return false
	for n in get_tree().get_nodes_in_group(&"hunters"):
		var h := n as Hunter
		if h != null and h.is_engaged() and h.global_position.distance_to(player.global_position) < 18.0:
			return true
	return false


# ---------------------------------------------------------------- the swing

func _physics_process(delta: float) -> void:
	invulnerable_left = maxf(invulnerable_left - delta, 0.0)
	_noise_cooldown = maxf(_noise_cooldown - delta, 0.0)
	_engage_t -= delta
	if _engage_t <= 0.0:
		_engage_t = 0.25
		_engaged = _someone_is_hunting_me()
	var fighting := _engaged and (player.state.mode == PlayerState.Mode.NORMAL or player.state.mode == PlayerState.Mode.STAGGERED)
	player.camera_rig.shoulder = shoulder_offset if fighting else 0.0
	if _stagger_left > 0.0:
		_stagger_left -= delta
		if _stagger_left <= 0.0 and player.state.mode == PlayerState.Mode.STAGGERED:
			player.state.set_mode(PlayerState.Mode.NORMAL)
	if Input.is_action_just_pressed(&"attack"):
		_buffer = buffer_time
	else:
		_buffer = maxf(_buffer - delta, 0.0)
	if phase == Phase.IDLE:
		if _buffer > 0.0 and can_strike():
			_buffer = 0.0
			begin()
		return
	if player.state.mode != PlayerState.Mode.NORMAL and player.state.mode != PlayerState.Mode.TRANSFORMING:
		reset()
		return
	if _freeze > 0.0:
		_freeze -= delta
		_pose()
		return
	_t += delta
	_elapsed += delta
	match phase:
		Phase.WINDUP:
			if _t >= windup:
				phase = Phase.STRIKE
				_t = 0.0
				_resolve()
		Phase.STRIKE:
			if _t >= strike_time:
				phase = Phase.RECOVER
				_t = 0.0
		Phase.RECOVER:
			player.speed_modifiers.erase(&"strike")
			if _t >= recover:
				phase = Phase.IDLE
				_t = 0.0
				ready_again.emit()
	_pose()


## Start a swing. Returns false if one cannot start now.
func begin() -> bool:
	if phase != Phase.IDLE or not can_strike():
		return false
	var speed := Vector2(player.velocity.x, player.velocity.z).length()
	var falling := not player.is_on_floor() and player.velocity.y < -3.0
	kind = CombatRules.strike_kind(speed >= lunge_min_speed, falling)
	phase = Phase.WINDUP
	_t = 0.0
	_elapsed = 0.0
	swings += 1
	player.blood.take(blood_cost)
	_aim()
	player.speed_modifiers[&"strike"] = 0.45
	if kind == &"lunge":
		player.push(facing() * lunge_speed)
	Sfx.play(&"rend_swing", -5.0, randf_range(0.93, 1.08))
	Haptics.pulse(0.15, 0.2, 0.06)
	strike_started.emit(kind)
	return true


## Turn to what is in front of the camera: the nearest living thing within reach of the swing if there is one
## (so a pad player never has to be exact), otherwise simply the way the camera looks.
func _aim() -> void:
	var cam_yaw := player.camera_rig.yaw
	var cam_forward := -Basis(Vector3.UP, cam_yaw).z
	var best: Node3D = null
	var best_score := INF
	for n in get_tree().get_nodes_in_group(&"hurtable"):
		var t := n as Node3D
		if t == null or not t.can_be_struck():
			continue
		var to := t.global_position - player.global_position
		to.y = 0.0
		var d := to.length()
		if d > assist_range or d < 0.05:
			continue
		var along := cam_forward.dot(to / d)
		if along < cos(deg_to_rad(assist_angle_degrees)) and d > 1.2:
			continue
		var score := d - along * 2.0
		if score < best_score:
			best_score = score
			best = t
	if best != null:
		player.face_toward(best.global_position)
	else:
		player.set_facing(cam_yaw)


## The moment of the strike: find what the claws reach and hurt it.
func _resolve() -> void:
	var forward := facing()
	var origin := player.global_position
	var airborne := not player.is_on_floor()
	var r := reach + (lunge_reach_bonus if kind == &"lunge" else 0.0)
	var space := player.get_world_3d().direct_space_state
	var chest := origin + Vector3(0, 1.1, 0)
	var best: Node3D = null
	var best_d := INF
	for n in get_tree().get_nodes_in_group(&"hurtable"):
		var t := n as Node3D
		if t == null or not t.can_be_struck():
			continue
		var p: Vector3 = t.strike_point()
		if absf(p.y - chest.y) > (3.4 if airborne else 1.7):
			continue
		if not CombatRules.in_cone(origin, forward, t.global_position, r + 0.45, half_angle_degrees, 1.1):
			continue
		var q := PhysicsRayQueryParameters3D.create(chest, p, Greybox.WORLD)
		if not space.intersect_ray(q).is_empty():
			continue
		var d := origin.distance_to(t.global_position)
		if d < best_d:
			best_d = d
			best = t
	if best == null:
		whiffed.emit()
		return
	var unaware: bool = best.is_unaware()
	var info := HitInfo.new()
	info.kind = kind
	info.source = player
	info.origin = origin
	info.ambush = unaware
	info.strong = unaware or kind != &"rend"
	info.knockback = 6.5 if info.strong else 3.5
	info.stagger = 0.0
	var bonus := player.surge.strike_bonus * player.surge.power * player.surge.intensity() if player.surge.active else 0.0
	info.amount = CombatRules.strike_damage(player.form.current.strike_damage, kind, unaware,
		CombatRules.hunger_factor(player.blood.is_hungry(), player.blood.is_starving()), bonus)
	hits += 1
	last_info = info
	best.receive_strike(info)
	player.blood.add(blood_taste)
	_land_feedback(best, info)
	struck.emit(best, info)


func _land_feedback(target: Node3D, info: HitInfo) -> void:
	var hard := info.ambush or info.kind == &"plunge"
	var point: Vector3 = target.strike_point()
	Sfx.play(&"rend_hit", -2.0 if hard else -5.0, 0.85 if hard else randf_range(0.95, 1.1))
	if info.kind == &"plunge":
		Sfx.play(&"land", -3.0, 0.6)
	Haptics.pulse(0.5, 0.95 if hard else 0.7, 0.14)
	player.camera_rig.kick_fov(6.0 if hard else 3.2, 9.0)
	player.camera_rig.add_shake(0.06 if hard else 0.035)
	Fx.burst(player, point, Color(0.75, 0.03, 0.06, 0.95), 26 if hard else 16, 3.2 if hard else 2.4, 0.09, 0.6, -6.0)
	_slash_mark(point)
	if hard:
		var fx := get_tree().get_first_node_in_group(&"screen_fx") as ScreenFX
		if fx:
			fx.flash(Color(0.75, 0.03, 0.06), 0.3, 5.0)
	_freeze = 0.05
	_alarm_people(player.global_position)


## Three claw marks, there and gone: a read on where the blow went.
func _slash_mark(point: Vector3) -> void:
	if _slash == null:
		_slash = MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.9, 0.035, 0.02)
		_slash.mesh = mesh
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = Color(1.0, 0.1, 0.12, 0.9)
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.no_depth_test = true
		_slash.material_override = mat
		_slash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_slash.top_level = true
		_slash.visible = false
		player.add_child(_slash)
	_slash.global_position = point
	_slash.global_rotation = Vector3(0.0, player.visual.rotation.y, deg_to_rad(-28.0))
	_slash.scale = Vector3(0.4, 1.0, 1.0)
	_slash.visible = true
	var mat := _slash.material_override as StandardMaterial3D
	mat.albedo_color.a = 0.95
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_slash, "scale", Vector3(1.25, 1.0, 1.0), 0.14)
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.2)
	tw.chain().tween_callback(func(): _slash.visible = false)


## A fight is loud: awake people within hearing grow uneasy, sleepers stir, and anyone who can see it runs.
func _alarm_people(origin: Vector3) -> void:
	if _noise_cooldown > 0.0:
		return
	_noise_cooldown = 0.6
	for n in get_tree().get_nodes_in_group(&"npcs"):
		var npc := n as HumanNpc
		if npc == null:
			continue
		npc.perceive_vampiric_act(origin, 0.5, 15.0, false)
		npc.perceive_vampiric_act(origin, 1.0, 10.0, true)


## The arm's work: draw back through the wind-up, whip across at the strike, settle through the recovery.
func _pose() -> void:
	var coil := 0.0
	var slash := 0.0
	match phase:
		Phase.WINDUP:
			coil = clampf(_t / windup, 0.0, 1.0)
		Phase.STRIKE:
			coil = 1.0
			slash = clampf(_t / strike_time, 0.0, 1.0)
		Phase.RECOVER:
			coil = 0.0
			slash = clampf(1.0 - _t / recover, 0.0, 1.0)
	player.visual.strike_pose(coil, slash)


# ---------------------------------------------------------------- being hit

## Take a blow. Returns true if it landed (false while you are in grace, or a mist, or not in the world).
func take_hit(info: HitInfo) -> bool:
	if invulnerable_left > 0.0 or player.state.is_dead():
		return false
	var mode := player.state.mode
	if mode == PlayerState.Mode.TRAVERSING or mode == PlayerState.Mode.RESTING or mode == PlayerState.Mode.MEMORY:
		return false
	invulnerable_left = grace_seconds
	if player.feeding.is_feeding():
		player.feeding.break_off()
	if phase != Phase.IDLE:
		phase = Phase.IDLE
		_t = 0.0
		_elapsed = 0.0
		player.speed_modifiers.erase(&"strike")
	player.health.damage(info.amount, &"hunter")
	last_info = info
	var away := player.global_position - info.origin
	away.y = 0.0
	away = away.normalized() if away.length() > 0.05 else Vector3.BACK
	Sfx.play(&"hit_taken", -1.0, randf_range(0.95, 1.05))
	Haptics.pulse(0.8, 1.0, 0.25)
	Fx.burst(player, player.global_position + Vector3(0, 1.2, 0), Color(0.7, 0.03, 0.06, 0.9), 14, 2.0, 0.08, 0.5, -5.0)
	player.camera_rig.add_shake(0.08)
	player.camera_rig.kick_fov(-3.0, 7.0)
	player.camera_rig.kick_roll(deg_to_rad(3.0) * (1.0 if randf() > 0.5 else -1.0), 6.0)
	if player.state.is_dead():
		hurt.emit(info, info.amount)
		return true
	player.push(away * info.knockback)
	if info.stagger > 0.0 and player.state.mode == PlayerState.Mode.NORMAL:
		_stagger_left = info.stagger
		player.state.set_mode(PlayerState.Mode.STAGGERED)
	_alarm_people(player.global_position)
	hurt.emit(info, info.amount)
	return true
