class_name InputGlyph
extends Control
## A small drawn button prompt: a keycap for the keyboard, a coloured round button for an
## Xbox-style pad (A/B/X/Y), a symbol button for a PlayStation pad (cross/circle/square/triangle),
## pills for bumpers and triggers, a ring for stick clicks. It asks InputSetup what the action is
## bound to, and redraws itself when the player switches between keyboard and pad.
##
## `kind` forces a device family (the Controls screen shows both side by side); leave it empty to
## follow whatever the player touched last.

var action: StringName = &""
var kind: StringName = &""
var binding_index := 0

var _info: Dictionary = {}
var _literal: Dictionary = {}
var _font: Font = ThemeDB.fallback_font


func _init(a: StringName = &"", forced_kind: StringName = &"") -> void:
	action = a
	kind = forced_kind
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	InputSetup.device_changed.connect(_on_device_changed)
	refresh()


func _on_device_changed(_k: StringName) -> void:
	if kind == &"":
		refresh()


func set_action(a: StringName) -> void:
	action = a
	refresh()


## A fixed, non-rebindable glyph (a key like "W", or an axis like "Left stick") that is not an action.
static func literal(text: String, shape: StringName, forced_kind: StringName = &"") -> InputGlyph:
	var g := InputGlyph.new(&"", forced_kind)
	g._literal = {"text": text, "shape": shape, "color": Color(0.85, 0.85, 0.88) if shape == &"key" else Color(0.8, 0.8, 0.85)}
	return g


func refresh() -> void:
	var k := kind if kind != &"" else InputSetup.device_kind
	if not _literal.is_empty():
		_info = _literal
		custom_minimum_size = _measure(k)
		queue_redraw()
		return
	var b := InputSetup.bindings_for(action, k)
	_info = b[mini(binding_index, b.size() - 1)] if not b.is_empty() else {}
	custom_minimum_size = _measure(k)
	queue_redraw()


func text_now() -> String:
	return _info.get("text", "")


func _measure(k: StringName) -> Vector2:
	if _info.is_empty():
		return Vector2(0, 30)
	var t: String = _info["text"]
	match _info["shape"]:
		&"key", &"mouse":
			return Vector2(maxf(32.0, _font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, 17).x + 20.0), 32)
		&"face", &"stick", &"dpad":
			return Vector2(32, 32)
		&"pill", &"trigger":
			return Vector2(maxf(46.0, _font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x + 18.0), 26)
	return Vector2(32, 32)


func _draw() -> void:
	if _info.is_empty():
		return
	var size_v := size if size.x > 0 else custom_minimum_size
	var t: String = _info["text"]
	var col: Color = _info["color"]
	var k := kind if kind != &"" else InputSetup.device_kind
	var c := Vector2(size_v.x * 0.5, size_v.y * 0.5)
	match _info["shape"]:
		&"key", &"mouse":
			var r := Rect2(Vector2(1, 1), size_v - Vector2(2, 4))
			draw_rect(Rect2(r.position + Vector2(0, 3), r.size), Color(0, 0, 0, 0.6), true)
			draw_rect(r, Color(0.16, 0.14, 0.15, 0.95), true)
			draw_rect(r, Color(0.75, 0.72, 0.7, 0.9), false, 1.5)
			_centered_text(t, c - Vector2(0, 2), 17, UiStyle.BONE)
		&"face":
			draw_circle(c, 15.0, Color(0.06, 0.05, 0.06, 0.9))
			draw_arc(c, 15.0, 0.0, TAU, 28, col, 2.5, true)
			if k == InputSetup.PLAYSTATION:
				_ps_symbol(t, c, col)
			else:
				_centered_text(t, c, 18, col)
		&"stick":
			draw_circle(c, 15.0, Color(0.06, 0.05, 0.06, 0.9))
			draw_arc(c, 15.0, 0.0, TAU, 28, col, 2.0, true)
			_centered_text(t, c, 13, col)
		&"pill", &"trigger":
			var r2 := Rect2(Vector2(1, 1), size_v - Vector2(2, 2))
			draw_rect(r2, Color(0.06, 0.05, 0.06, 0.9), true)
			draw_rect(r2, col, false, 2.0)
			_centered_text(t, c, 15, col)
		&"dpad":
			draw_circle(c, 15.0, Color(0.06, 0.05, 0.06, 0.9))
			draw_rect(Rect2(c - Vector2(3, 10), Vector2(6, 20)), col, true)
			draw_rect(Rect2(c - Vector2(10, 3), Vector2(20, 6)), col, true)


func _centered_text(t: String, center: Vector2, font_size: int, col: Color) -> void:
	var ts := _font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var asc := _font.get_ascent(font_size)
	draw_string(_font, Vector2(center.x - ts.x * 0.5, center.y + asc * 0.5 - 1.0), t, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, col)


## PlayStation face buttons are symbols, not letters.
func _ps_symbol(name_text: String, c: Vector2, col: Color) -> void:
	match name_text:
		"Cross":
			draw_line(c + Vector2(-6, -6), c + Vector2(6, 6), col, 2.5, true)
			draw_line(c + Vector2(-6, 6), c + Vector2(6, -6), col, 2.5, true)
		"Circle":
			draw_arc(c, 6.5, 0.0, TAU, 20, col, 2.5, true)
		"Square":
			draw_rect(Rect2(c - Vector2(6, 6), Vector2(12, 12)), col, false, 2.5)
		"Triangle":
			draw_polyline(PackedVector2Array([c + Vector2(0, -7), c + Vector2(7, 5), c + Vector2(-7, 5), c + Vector2(0, -7)]), col, 2.5, true)
		_:
			_centered_text(name_text, c, 12, col)
