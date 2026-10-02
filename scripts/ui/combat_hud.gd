class_name CombatHud
extends Control
## The few marks that make a fight legible without turning the screen into a combat interface. All of it sits
## on the centre dot you already have:
##   - a thin ring that fills while Rend is swinging and rests whole when it is ready (it flares as it returns),
##     shown only when there is something to fight or you have just struck;
##   - four ticks when a blow lands (gold for an ambush or a plunge);
##   - a red arc at the screen edge pointing at whoever just hit you;
##   - one quiet word under the dot when an unaware hunter is within reach, so the ambush is never a secret.
## It reads the player; it never drives anything.

const RING_R := 15.0

var player: Player

var _show := 0.0
var _near_t := 0.0
var _near := false
var _hint := ""
var _hint_t := 0.0
var _ready_flash := 0.0
var _hit := 0.0
var _hit_gold := false
var _hurts: Array[Dictionary] = []
var _recent := 0.0


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func bind(p: Player) -> void:
	player = p
	p.combat.ready_again.connect(func(): _ready_flash = 1.0)
	p.combat.struck.connect(func(_t, info: HitInfo):
		_hit = 1.0
		_hit_gold = info.ambush or info.kind == &"plunge"
		_recent = 4.0)
	p.combat.strike_started.connect(func(_k): _recent = 4.0)
	p.combat.hurt.connect(_on_hurt)


## Observable by tests: is the strike ring on screen, and what does the hint say.
func ring_visible() -> bool:
	return _show > 0.05


func hint_text() -> String:
	return _hint


func hurt_arcs() -> int:
	return _hurts.size()


func _on_hurt(info: HitInfo, _amount: float) -> void:
	if player == null:
		return
	var d := info.origin - player.global_position
	var yaw := player.camera_rig.yaw
	var fwd := Vector2(-sin(yaw), -cos(yaw))
	var right := Vector2(cos(yaw), -sin(yaw))
	var flat := Vector2(d.x, d.z)
	if flat.length() < 0.1:
		flat = fwd
	_hurts.append({"angle": atan2(flat.dot(right), flat.dot(fwd)), "t": 1.0})
	_recent = 4.0


func _process(delta: float) -> void:
	if player == null:
		return
	_near_t -= delta
	if _near_t <= 0.0:
		_near_t = 0.25
		_look_around()
	_recent = maxf(_recent - delta, 0.0)
	var want := 1.0 if (player.form.current.strike_damage > 0.0 and (_near or _recent > 0.0 or player.combat.is_attacking())) else 0.0
	_show = lerpf(_show, want, 1.0 - exp(-8.0 * delta))
	_ready_flash = maxf(_ready_flash - delta * 4.0, 0.0)
	_hit = maxf(_hit - delta * 6.0, 0.0)
	for h in _hurts:
		h["t"] -= delta * 1.15
	_hurts.assign(_hurts.filter(func(h): return h["t"] > 0.0))
	queue_redraw()


## Is there a hunter near enough to matter, and is one within reach of an ambush?
func _look_around() -> void:
	_near = false
	_hint = ""
	if player.form.current.strike_damage <= 0.0:
		return
	var best := INF
	for n in get_tree().get_nodes_in_group(&"hunters"):
		var h := n as Hunter
		if h == null or not h.is_up():
			continue
		var d := h.global_position.distance_to(player.global_position)
		if d < 30.0:
			_near = true
		if d < 7.0 and d < best and h.is_unaware():
			best = d
			_hint = "%s  Ambush" % InputSetup.prompt_text(&"attack")


func _draw() -> void:
	if player == null:
		return
	var c := size * 0.5
	if _show > 0.03:
		var a := _show
		var combat := player.combat
		draw_arc(c, RING_R, 0.0, TAU, 40, Color(0.04, 0.0, 0.0, 0.45 * a), 4.0, true)
		if combat.phase == PlayerCombat.Phase.IDLE:
			draw_arc(c, RING_R, 0.0, TAU, 40, Color(0.93, 0.88, 0.8, 0.6 * a), 1.8, true)
		else:
			var f := combat.progress()
			draw_arc(c, RING_R, -PI * 0.5, -PI * 0.5 + TAU * f, 40, Color(1.0, 0.3, 0.3, 0.95 * a), 2.4, true)
		if _ready_flash > 0.02:
			draw_arc(c, RING_R + 12.0 * (1.0 - _ready_flash), 0.0, TAU, 40, Color(1.0, 0.85, 0.7, _ready_flash * 0.8 * a), 2.0, true)
	if _hit > 0.02:
		var col := Color(1.0, 0.85, 0.4, _hit) if _hit_gold else Color(1.0, 1.0, 1.0, _hit)
		for i in 4:
			var dir := Vector2.from_angle(PI * 0.25 + i * PI * 0.5)
			var r0 := 20.0 + 6.0 * (1.0 - _hit)
			draw_line(c + dir * r0, c + dir * (r0 + 10.0), col, 2.5, true)
	for h in _hurts:
		var ang: float = h["angle"] - PI * 0.5
		var rad := minf(size.x, size.y) * 0.36
		draw_arc(c, rad, ang - 0.34, ang + 0.34, 14, Color(0.95, 0.05, 0.05, clampf(h["t"], 0.0, 1.0) * 0.85), 9.0, true)
	if _hint != "":
		var font := UiStyle.serif_bold()
		var w := font.get_string_size(_hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x
		var pos := c + Vector2(-w * 0.5, 44.0)
		draw_string_outline(font, pos, _hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, 6, Color(0, 0, 0, 0.9))
		draw_string(font, pos, _hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(1.0, 0.85, 0.5, 0.95))
