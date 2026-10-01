class_name TraversalController
extends PlayerComponent
## Moves the player along a designated TraversalLink (a window to slip through, a wall or roof to
## climb). It is deliberately NOT physics: the body follows a short authored path, which is what
## makes it reliable (no catching on sills) and supernatural (a vampire dissolves to mist to slip
## through a window; scales stone as if it were a stair).
##
## A traversal is only ever started on purpose. `problem()` is the one place that decides: the form
## may use this kind of route, the player is on the start end's level, close to it, on its own side of
## the wall, in line with it and facing the way it goes, and the landing spot is free and has floor
## under it. If any of that is false the route is not offered and `start()` refuses - standing near a
## route is never permission. (Press "in" from the outside and you can only ever go in.)
##
## Safety: the exit is also checked on arrival and nudged if needed; if nothing fits the player is
## returned to where they started. A traversal can never leave the body inside geometry.

signal started(link: TraversalLink, to_end: int)
signal finished(link: TraversalLink)
signal blocked(link: TraversalLink)

const WINDOW_TIME := 0.8
const WINDOW_ARC := 0.55
## The first part of a route eases the body from where it stood onto the route's line (no snap).
const SETTLE := 0.28

var active := false
var link: TraversalLink
var traversals_done := 0

var _from_end := 0
var _t := 0.0
var _dur := 1.0
var _cooldown := 0.0
var _trail: CPUParticles3D
var _hidden := false
var _settle := Vector3.ZERO
var _climb_phase := 0.0
var _dust_timer := 0.0


func _on_setup() -> void:
	_trail = Fx.emitter(player, Vector3(0, 1.0, 0), Color(0.05, 0.04, 0.08, 0.9), 40, 1.3, 0.34, 0.7, 0.4)
	player.health.died.connect(func(_c): _abort())


# ---------------------------------------------------------------- rules

## May this player use routes of this kind at all, right now? (Form and state - not where they stand.)
func can_use(l: TraversalLink) -> bool:
	if active or _cooldown > 0.0 or l == null or l.placement == null:
		return false
	if not player.state.can_act():
		return false
	return player.form.current.traversal.has(String(l.placement.type_name()))


## Why `l` cannot be started from `from_end` right now: a reason code ("" = it can). Cheap checks come
## first; the physics queries for the landing spot run last (this is asked about every nearby route
## while the player is looking around, so it must stay light).
func problem(l: TraversalLink, from_end: int) -> StringName:
	if not can_use(l):
		return &"not_allowed"
	var why := l.placement.entry_problem(from_end, player.global_position, [forward_of_camera(), forward_of_body()])
	if why != &"":
		return why
	var dest := l.placement.end_position(1 - from_end)
	if find_exit(dest, l.placement.end_position(from_end)) == null:
		return &"blocked"
	return &""


func can_start(l: TraversalLink, from_end: int) -> bool:
	return problem(l, from_end) == &""


## Flat world direction the camera is looking.
func forward_of_camera() -> Vector3:
	return -Basis(Vector3.UP, player.camera_rig.yaw).z


## Flat world direction the body faces.
func forward_of_body() -> Vector3:
	return -Basis(Vector3.UP, player.visual.rotation.y).z


func start(l: TraversalLink, from_end: int) -> bool:
	if not can_start(l, from_end):
		return false
	link = l
	_from_end = from_end
	_dur = route_duration(l.placement)
	_t = 0.0
	active = true
	_hidden = false
	_climb_phase = 0.0
	_dust_timer = 0.0
	var s := l.placement.end_position(from_end)
	var e := l.placement.end_position(1 - from_end)
	_settle = player.global_position - s
	var d := e - s
	if Vector2(d.x, d.z).length() > 0.05:
		player.set_facing(atan2(-d.x, -d.z))
	player.state.set_mode(PlayerState.Mode.TRAVERSING)
	player.velocity = Vector3.ZERO
	var window := l.placement.type == TraversalPlacement.Type.WINDOW
	Sfx.play(&"traverse_window" if window else &"traverse_climb", -4.0)
	Haptics.pulse(0.25, 0.3, 0.18)
	player.camera_rig.kick_fov(5.0, 4.0)
	if window:
		Fx.burst(player, player.global_position + Vector3(0, 1.0, 0), Color(0.04, 0.03, 0.06, 0.95), 30, 2.4, 0.3, 1.0, 0.6)
	# Anyone who SEES a person turn to mist or scale a wall is frightened.
	for n in get_tree().get_nodes_in_group(&"npcs"):
		(n as HumanNpc).perceive_vampiric_act(s, 1.0, 12.0, true)
	started.emit(l, 1 - from_end)
	return true


# ---------------------------------------------------------------- the path (pure, testable)

static func route_duration(p: TraversalPlacement) -> float:
	if p.duration > 0.0:
		return p.duration
	if p.type == TraversalPlacement.Type.WINDOW:
		return WINDOW_TIME
	var rise := absf(p.a.y - p.b.y)
	return clampf(0.5 + rise * 0.22, 0.9, 1.8)


## For a climb: the share of the route spent going straight up (or down) the face; the rest is the lip.
static func climb_fraction(p: TraversalPlacement) -> float:
	var rise := absf(p.a.y - p.b.y)
	var run := Vector2(p.b.x - p.a.x, p.b.z - p.a.z).length()
	return clampf(rise / maxf(rise + run, 0.01), 0.4, 0.85)


## Feet position at progress `t` (0..1) when travelling from end `from_end` to the other.
static func sample(p: TraversalPlacement, from_end: int, t: float) -> Vector3:
	var s := p.end_position(from_end)
	var e := p.end_position(1 - from_end)
	t = clampf(t, 0.0, 1.0)
	if p.type == TraversalPlacement.Type.WINDOW:
		return s.lerp(e, smoothstep(0.0, 1.0, t)) + Vector3(0, WINDOW_ARC * sin(PI * t), 0)
	# CLIMB: straight up the face, then over the lip (up), or out over the lip then down (drop).
	var ascending := e.y > s.y
	var low := s if ascending else e
	var high := e if ascending else s
	var corner := Vector3(low.x, high.y, low.z)
	var fv := climb_fraction(p)
	if ascending:
		if t < fv:
			var u := t / fv
			return low.lerp(corner, 1.0 - pow(1.0 - u, 2.0))
		var u2 := (t - fv) / maxf(1.0 - fv, 0.001)
		return corner.lerp(high, smoothstep(0.0, 1.0, u2)) + Vector3(0, p.lip_height * sin(PI * u2), 0)
	var fh := 1.0 - fv
	if t < fh:
		var u3 := t / maxf(fh, 0.001)
		return high.lerp(corner, smoothstep(0.0, 1.0, u3)) + Vector3(0, p.lip_height * 0.68 * sin(PI * u3), 0)
	var u4 := (t - fh) / maxf(fv, 0.001)
	return corner.lerp(low, u4 * u4)


## True if a standing body fits at `feet` (nothing solid overlapping it).
func is_clear(feet: Vector3) -> bool:
	var shape_node := player.get_node("CollisionShape3D") as CollisionShape3D
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = shape_node.shape
	q.transform = Transform3D(Basis(), feet + Vector3(0, 0.9 + 0.03, 0))
	q.collision_mask = 1
	q.margin = -0.03
	q.exclude = [player.get_rid()]
	return player.get_world_3d().direct_space_state.intersect_shape(q, 1).is_empty()


## Is there something to stand on at `feet` (floor, roof) rather than empty air?
func has_footing(feet: Vector3) -> bool:
	var q := PhysicsRayQueryParameters3D.create(feet + Vector3(0, 0.6, 0), feet + Vector3(0, -0.5, 0), 1, [player.get_rid()])
	return not player.get_world_3d().direct_space_state.intersect_ray(q).is_empty()


## Where the body would actually end up for a route that lands at `dest`: the spot itself, or the first
## nearby spot that is clear and has footing. `null` if there is none (blocked).
func find_exit(dest: Vector3, start_pos: Vector3) -> Variant:
	var dir := dest - start_pos
	dir.y = 0.0
	dir = dir.normalized() if dir.length() > 0.01 else Vector3.BACK
	var tries: Array[Vector3] = [
		Vector3.ZERO, Vector3(0, 0.15, 0), Vector3(0, 0.4, 0), dir * 0.3, dir * 0.6, dir * 0.6 + Vector3(0, 0.3, 0),
		-dir * 0.4, dir * 1.0 + Vector3(0, 0.4, 0),
	]
	for off in tries:
		if is_clear(dest + off) and has_footing(dest + off):
			return dest + off
	return null


# ---------------------------------------------------------------- running it

func _physics_process(delta: float) -> void:
	if not active:
		_cooldown = maxf(_cooldown - delta, 0.0)
		_trail.emitting = false
		return
	_t += delta / _dur
	var p := link.placement
	var pos := sample(p, _from_end, _t)
	# Ease from wherever the player stood onto the route's line, so nothing snaps.
	pos += _settle * (1.0 - smoothstep(0.0, SETTLE, _t))
	player.global_position = pos
	player.velocity = Vector3.ZERO
	if p.type == TraversalPlacement.Type.WINDOW:
		# The body dissolves into mist at the sill and re-forms on the other side.
		var gone := _t > 0.14 and _t < 0.76
		if gone != _hidden:
			_hidden = gone
			player.visual.visible = not gone
			if not gone:
				Fx.burst(player, player.global_position + Vector3(0, 1.0, 0), Color(0.04, 0.03, 0.06, 0.95), 26, 2.0, 0.28, 0.9, 0.5)
		_trail.emitting = gone
	else:
		_climb(p, delta)
	if _t >= 1.0:
		_finish()


## The wall climb: hands and feet find the stone, the body stays on the face, dark mist trails off the
## cloak and stone dust falls - the same supernatural language as slipping through a window.
func _climb(p: TraversalPlacement, delta: float) -> void:
	var ascending := p.end_position(1 - _from_end).y > p.end_position(_from_end).y
	var rising := ascending and _t < climb_fraction(p) * 0.97
	_climb_phase += delta * 11.0
	if rising:
		player.visual.climb_pose(_climb_phase, delta)
		player.visual.body.rotation.x = lerpf(player.visual.body.rotation.x, -0.12, minf(1.0, 10.0 * delta))
		_dust_timer -= delta
		if _dust_timer <= 0.0:
			_dust_timer = 0.16
			var wall := player.global_position + Vector3(0, 1.5, 0) + player.visual.global_transform.basis * Vector3(0, 0, -0.35)
			Fx.burst(player, wall, Color(0.62, 0.6, 0.56, 0.8), 6, 0.9, 0.05, 0.6, -3.0)
		player.camera_rig.add_shake(0.004)
	else:
		# Over the lip (or off it): an easy, flowing motion rather than the hand-over-hand climb.
		player.visual.animate(3.0, true, delta)
		player.visual.body.rotation.x = lerpf(player.visual.body.rotation.x, -0.22, minf(1.0, 10.0 * delta))
	_trail.emitting = true


func _finish() -> void:
	var l := link
	var dest := l.destination_of(_from_end)
	active = false
	_trail.emitting = false
	player.visual.visible = true
	_hidden = false
	player.global_position = dest
	var ok := _resolve_exit(dest, l.placement.end_position(_from_end))
	player.velocity = Vector3.ZERO
	if player.state.mode == PlayerState.Mode.TRAVERSING:
		player.state.set_mode(PlayerState.Mode.NORMAL)
	_cooldown = 0.45
	player.camera_rig.add_shake(0.02)
	if ok:
		traversals_done += 1
		if l.placement.type == TraversalPlacement.Type.CLIMB:
			Sfx.play(&"land", -10.0)
		finished.emit(l)
	else:
		blocked.emit(l)


## Make sure the body is not inside anything; nudge if it is; return to the start as a last resort.
func _resolve_exit(dest: Vector3, start_pos: Vector3) -> bool:
	var spot: Variant = find_exit(dest, start_pos)
	if spot != null:
		player.global_position = spot
		return true
	player.global_position = start_pos
	return false


func _abort() -> void:
	if not active:
		return
	active = false
	_trail.emitting = false
	player.visual.visible = true


## Test/tool hook: is this route usable right now by the player?
func describe(l: TraversalLink) -> String:
	return "%s %s" % [l.placement.id, "usable" if can_use(l) else "unavailable"]
