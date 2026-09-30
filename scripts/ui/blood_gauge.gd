class_name BloodGauge
extends Control
## Blood as something alive, not a mana bar: a vessel of liquid blood with a living surface, a pulse
## that follows your real heart rate (slow and heavy as a vampire, faster when hungry, feeding or
## burning), a ring for vitality, droplets that fall while Sense is spending it, a golden arc while
## a Bloodrush lasts. No number. Hunger is a dashed ring (a shape, not only a colour).
## Drawn entirely in `_draw()`; it reads the player, never drives it.

const R := 52.0

var player: Player

var _t := 0.0
var _blood := 0.5          ## smoothed 0..1
var _health := 1.0
var _vamp := 0.0           ## 0 human .. 1 vampire (smoothed)
var _surge := 0.0
var _surge_frac := 0.0
var _flash := 0.0          ## a gain (feeding) lights the vessel
var _beat_phase := 0.0
var _hungry := false
var _starving := false
var _draining := false
var _drops: Array[Dictionary] = []
var _drop_timer := 0.0


func _init() -> void:
	custom_minimum_size = Vector2(190, 190)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func bind(p: Player) -> void:
	player = p
	_blood = p.blood.fraction()
	_vamp = 1.0 if p.form.current.can_feed else 0.0
	p.blood.gained.connect(func(amount: float): _flash = minf(_flash + amount * 0.02, 1.0))


## Smoothed values the HUD reads to decide what else to say (and tests to check).
func vampire_blend() -> float:
	return _vamp


func displayed_blood() -> float:
	return _blood


func _process(delta: float) -> void:
	if player == null:
		return
	_t += delta
	var b := player.blood
	_blood = lerpf(_blood, b.fraction(), 1.0 - exp(-5.0 * delta))
	_health = lerpf(_health, player.health.value / player.health.max_health, 1.0 - exp(-6.0 * delta))
	_vamp = lerpf(_vamp, 1.0 if player.form.current.can_feed else 0.0, 1.0 - exp(-4.0 * delta))
	_surge = lerpf(_surge, player.surge.intensity(), 1.0 - exp(-5.0 * delta))
	_surge_frac = player.surge.seconds_left / maxf(player.surge.total_seconds, 1.0) if player.surge.active else 0.0
	_flash = maxf(_flash - delta * 1.4, 0.0)
	_hungry = b.is_hungry()
	_starving = b.is_starving()
	_beat_phase += delta * b.pulse_rate() / 60.0
	# Spending (Sense) sheds drops from the vessel.
	_draining = b.spend_rate > 0.3
	if _draining:
		_drop_timer -= delta
		if _drop_timer <= 0.0:
			_drop_timer = 0.55 / clampf(b.spend_rate, 0.3, 3.0)
			_drops.append({"x": randf_range(-14.0, 14.0), "y": R * 0.85, "v": randf_range(30.0, 55.0), "life": 1.0})
	for d in _drops:
		d["y"] += d["v"] * delta
		d["v"] += 140.0 * delta
		d["life"] -= delta * 1.3
	_drops = _drops.filter(func(d): return d["life"] > 0.0)
	queue_redraw()


func _draw() -> void:
	if player == null:
		return
	var p := fposmod(_beat_phase, 1.0)
	var env := exp(-p * 10.0) + (0.5 * exp(-(p - 0.27) * 14.0) if p > 0.27 else 0.0)
	var pulse_amount := lerpf(0.018, 0.04, _vamp) + (0.03 if _hungry else 0.0)
	var s := lerpf(0.8, 1.0, _vamp) * (1.0 + pulse_amount * env)
	draw_set_transform(size * 0.5, 0.0, Vector2(s, s))
	var liquid := Color(0.74, 0.17, 0.2).lerp(Color(0.6, 0.02, 0.07), _vamp).lerp(Color(1.0, 0.3, 0.3), _flash * 0.6)
	var ring_col := UiStyle.BONE.lerp(Color(0.8, 0.25, 0.3), _vamp * 0.6)

	# The vessel.
	draw_circle(Vector2.ZERO, R + 1.0, Color(0.03, 0.01, 0.02, 0.78))
	var level := clampf(_blood, 0.0, 1.0)
	if level > 0.012:
		var amp := 2.0 + 2.5 * _flash + (2.5 if player.feeding.is_feeding() else 0.0) + (1.5 if _hungry else 0.0)
		var top := _liquid(level, R - 4.0, amp)
		if top.size() >= 3:
			draw_colored_polygon(top, liquid)
		# A darker body underneath the surface for depth.
		var body := _liquid(level * 0.72, R - 4.0, amp * 0.6)
		if body.size() >= 3:
			draw_colored_polygon(body, liquid.darkened(0.25))
	# Glass.
	draw_arc(Vector2.ZERO, R - 7.0, deg_to_rad(205), deg_to_rad(262), 12, Color(1, 1, 1, 0.22), 3.0, true)
	draw_arc(Vector2.ZERO, R - 3.0, deg_to_rad(290), deg_to_rad(330), 8, Color(1, 1, 1, 0.1), 2.0, true)

	# Vitality ring: a full ring is quiet, a shrinking one is impossible to miss.
	var hurt := _health < 0.995
	draw_arc(Vector2.ZERO, R + 4.0, 0.0, TAU, 56, Color(0.14, 0.09, 0.1, 0.85), 4.0, true)
	if _health > 0.01:
		var hc := ring_col if not hurt else ring_col.lerp(Color(1.0, 0.25, 0.2), 1.0 - _health)
		hc.a = 0.35 if not hurt else 0.95
		draw_arc(Vector2.ZERO, R + 4.0, -PI * 0.5, -PI * 0.5 + TAU * _health, 56, hc, 4.0, true)

	# A heartbeat ripple leaves the vessel; a hungry or burning heart makes it strong.
	var vis := 0.22 + (0.5 if _hungry else 0.0) + 0.3 * _surge
	if p < 0.65:
		var k := p / 0.65
		draw_arc(Vector2.ZERO, R + 6.0 + k * 22.0, 0.0, TAU, 56, Color(liquid.r, liquid.g * 0.6, liquid.b * 0.6, (1.0 - k) * vis), 2.0, true)

	# Hunger: a dashed outer ring that flashes (shape, not only colour).
	if _hungry:
		var a := 0.45 + 0.55 * (0.5 + 0.5 * sin(_t * (9.0 if _starving else 5.0)))
		for i in 14:
			var a0 := i * TAU / 14.0
			draw_arc(Vector2.ZERO, R + 12.0, a0, a0 + TAU / 28.0, 4, Color(1.0, 0.35, 0.3, a), 3.0, true)

	# Bloodrush: a gold-crimson arc that unwinds as it fades.
	if _surge > 0.01:
		var sc := Color(1.0, 0.62, 0.25).lerp(Color(1.0, 0.2, 0.2), 0.3)
		sc.a = 0.9
		draw_arc(Vector2.ZERO, R + 12.0, -PI * 0.5, -PI * 0.5 + TAU * clampf(_surge_frac, 0.0, 1.0), 56, sc, 3.5, true)
		draw_arc(Vector2.ZERO, R + 8.0, 0.0, TAU, 56, Color(sc.r, sc.g, sc.b, 0.12 * _surge), 6.0, true)

	# Gains flash the rim.
	if _flash > 0.02:
		draw_arc(Vector2.ZERO, R + 2.0, 0.0, TAU, 56, Color(1.0, 0.6, 0.6, _flash * 0.6), 3.0, true)

	# The vampire's fangs bite the rim at the top.
	if _vamp > 0.02:
		var fa := Color(0.95, 0.92, 0.85, _vamp)
		draw_colored_polygon(PackedVector2Array([Vector2(-11, -R - 8), Vector2(-3, -R - 8), Vector2(-7, -R + 5)]), fa)
		draw_colored_polygon(PackedVector2Array([Vector2(3, -R - 8), Vector2(11, -R - 8), Vector2(7, -R + 5)]), fa)

	# Drops shed by Sense.
	for d in _drops:
		draw_circle(Vector2(d["x"], d["y"]), 2.6, Color(liquid.r, liquid.g, liquid.b, clampf(d["life"], 0.0, 1.0)))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Polygon of the liquid in a circle of `radius`, filled to `level`, with a living surface. The surface is
## kept strictly inside the glass (so the outline is always a simple polygon that triangulates), and the
## nearly empty / nearly full cases are simplified. Empty array = draw nothing.
func _liquid(level: float, radius: float, amp: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	if level < 0.03:
		return pts
	if level > 0.965:
		for i in 40:
			var a := TAU * i / 40.0
			pts.append(Vector2(cos(a), sin(a)) * radius)
		return pts
	var y_w := radius - 2.0 * radius * level
	var hw := sqrt(maxf(radius * radius - y_w * y_w, 0.0))
	var theta_r := asin(clampf(y_w / radius, -1.0, 1.0))
	var theta_l := PI - theta_r
	var n := 20
	for i in n + 1:
		var th := lerpf(theta_l, theta_r, float(i) / n)
		pts.append(Vector2(cos(th), sin(th)) * radius)
	var m := 14
	# The two ends of the surface are the arc's own end points: skip them (duplicate points break triangulation).
	for i in range(1, m):
		var x := lerpf(hw, -hw, float(i) / m)
		var fade := 1.0 - pow(absf(x) / maxf(hw, 1.0), 2.0)   # the surface meets the glass cleanly at both ends
		var y := y_w + sin(x * 0.13 + _t * 2.2) * amp * 0.6 * fade + sin(x * 0.29 - _t * 3.1) * amp * 0.4 * fade
		var reach := sqrt(maxf(radius * radius - x * x, 0.0)) - 0.75
		pts.append(Vector2(x, clampf(y, -reach, reach)))
	return pts
