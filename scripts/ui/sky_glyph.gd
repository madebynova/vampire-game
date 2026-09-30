class_name SkyGlyph
extends Control
## A tiny drawn sun / half-sun / moon beside the clock (and a warning sun in the danger bar), so the
## time of day reads at a glance without words or colour alone.

enum Mode { AUTO, SUN }

var phase: StringName = TimeOfDay.DAY
var mode: Mode = Mode.AUTO
var tint := Color(1.0, 0.85, 0.45)
var pulse := 0.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var c := size * 0.5 if size.x > 0 else custom_minimum_size * 0.5
	var r := minf(c.x, c.y) * 0.5
	if mode == Mode.SUN:
		_sun(c, r, tint, 1.0 + 0.15 * sin(Time.get_ticks_msec() / 1000.0 * (4.0 + pulse * 10.0)) * pulse)
		return
	match phase:
		TimeOfDay.NIGHT:
			draw_arc(c, r * 0.95, deg_to_rad(35), deg_to_rad(325), 28, UiStyle.MOON, r * 0.75, true)
			draw_circle(c + Vector2(r * 1.15, -r * 0.6), r * 0.12, Color(UiStyle.MOON, 0.7))
		TimeOfDay.DAWN, TimeOfDay.DUSK:
			var col := Color(1.0, 0.6, 0.35)
			draw_arc(c + Vector2(0, r * 0.35), r * 0.95, PI, TAU, 20, col, 3.0, true)
			draw_line(c + Vector2(-r * 1.5, r * 0.35), c + Vector2(r * 1.5, r * 0.35), col, 2.0, true)
			for i in 3:
				var a := PI + (i + 1) * PI / 4.0
				draw_line(c + Vector2(0, r * 0.35) + Vector2(cos(a), sin(a)) * r * 1.2, c + Vector2(0, r * 0.35) + Vector2(cos(a), sin(a)) * r * 1.7, col, 2.0, true)
		_:
			_sun(c, r, UiStyle.SUN, 1.0)


func _sun(c: Vector2, r: float, col: Color, k: float) -> void:
	draw_circle(c, r * 0.8 * k, col)
	for i in 8:
		var a := i * TAU / 8.0
		draw_line(c + Vector2(cos(a), sin(a)) * r * 1.15 * k, c + Vector2(cos(a), sin(a)) * r * 1.7 * k, col, 2.2, true)
