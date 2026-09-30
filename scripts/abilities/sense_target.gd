class_name SenseTarget
extends Node3D
## Attach to anything Vampiric Sense can reveal (child of the thing being revealed).
## The parent may implement:
##   is_sense_visible() -> bool   (default true)
##   get_sense_data(dist) -> Dictionary
##       {label, color, bpm}                         the original, still honoured
##       {title, detail, blood, hint, known, state}  optional: the elegant split presentation
##
## What the player perceives:
##  - the silhouette burns at the target's real heart rate, in the colour of their blood; a stranger
##    is pale, hollow and flickering, someone you know is steady and warm
##  - each scan wave that passes over them makes them flare
##  - the one you are attending to (nearest, most in front of you) is bright and gets the full
##    readout; everyone else is dimmer and quieter
##  - heartbeats are heard in 3D with their own character (calm, asleep, afraid); a very close heart
##    throbs through the chest and the pad

const OVERLAY_SHADER := preload("res://shaders/sense_overlay.gdshader")

@export var kind: StringName = &"living"
@export var sense_color := Color(0.9, 0.05, 0.1)
@export var max_range := 40.0
@export var label_range := 22.0
@export var label_offset := Vector3(0, 0.9, 0)
@export var heartbeat_audio := false

var revealed := false
## 0..1: how strongly this is the focus of attention right now (set by VampiricSense).
var priority := 1.0

var _mat: ShaderMaterial
var _meshes: Array[MeshInstance3D] = []
var _title: Label3D
var _detail: Label3D
var _blood: Label3D
var _hint: Label3D
var _last_text := ""
var _beat_prev := 0.0
var _phase := randf()
var _flash := 0.0


func _ready() -> void:
	add_to_group(&"sense_targets")
	_mat = ShaderMaterial.new()
	_mat.shader = OVERLAY_SHADER
	_mat.set_shader_parameter(&"phase", _phase)
	_title = _make_label(34, 0.0)
	_detail = _make_label(24, 38.0)
	_blood = _make_label(21, 68.0)
	_hint = _make_label(22, 98.0)
	_hint.modulate = Color(1.0, 0.82, 0.4)


func _make_label(size: int, y_offset: float) -> Label3D:
	var l := Label3D.new()
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.fixed_size = true
	l.pixel_size = 0.0011
	l.font_size = size
	l.outline_size = 9
	l.render_priority = 20
	l.outline_render_priority = 19
	l.position = label_offset
	l.offset = Vector2(0, y_offset)
	l.visible = false
	add_child(l)
	return l


func is_senseable() -> bool:
	var p := get_parent()
	if p and p.has_method(&"is_sense_visible"):
		return p.is_sense_visible()
	return true


func get_data(dist := 0.0) -> Dictionary:
	var p := get_parent()
	if p and p.has_method(&"get_sense_data"):
		return p.get_sense_data(dist)
	return {}


## The scan wave has just passed over this target.
func pulse() -> void:
	_flash = 1.0


func apply(shown: bool, strength: float, listener_pos: Vector3 = Vector3.ZERO, attention := 1.0) -> void:
	if shown != revealed:
		revealed = shown
		_set_overlay(shown)
	priority = attention
	if not shown:
		_hide_labels()
		return
	var dist := global_position.distance_to(listener_pos)
	var data := get_data(dist)
	var col: Color = data.get("color", sense_color)
	var bpm: float = data.get("bpm", 0.0)
	var hz := bpm / 60.0 if bpm > 0.0 else 0.8
	var known: bool = data.get("known", true)
	var near := clampf(1.0 - dist / 5.0, 0.0, 1.0) if bpm > 0.0 else 0.0
	_flash = maxf(_flash - get_process_delta_time() * 2.2, 0.0)
	_mat.set_shader_parameter(&"color", col)
	_mat.set_shader_parameter(&"intensity", 0.4 + 0.6 * strength)
	_mat.set_shader_parameter(&"beat_hz", hz)
	_mat.set_shader_parameter(&"unknown", 0.0 if known else 1.0)
	_mat.set_shader_parameter(&"flash", _flash)
	_mat.set_shader_parameter(&"focus", lerpf(0.55, 1.0, attention))
	_mat.set_shader_parameter(&"near", near)

	_show_text(data, col, dist, attention)

	if heartbeat_audio and bpm > 0.0 and dist < 20.0:
		var t := Time.get_ticks_msec() / 1000.0 * hz + _phase
		var frac := fposmod(t, 1.0)
		if _beat_prev < 0.25 and frac >= 0.25:
			_beat(data, dist, hz, attention, near)
		_beat_prev = frac


## Text: a name, a pulse and a mood, the blood, and - only when something is still unheard - a gold hint.
func _show_text(data: Dictionary, col: Color, dist: float, attention: float) -> void:
	var title: String = data.get("title", "")
	var detail: String = data.get("detail", "")
	var blood: String = data.get("blood", "")
	var hint: String = data.get("hint", "")
	if title == "" and detail == "" and data.get("label", "") != "":
		# Old-style data: a single block of text.
		title = str(data["label"])
	var in_range := dist <= label_range
	var a := lerpf(0.55, 1.0, attention)
	var big := attention > 0.9
	_title.text = title
	_title.visible = in_range and title != ""
	_title.modulate = Color(col.lightened(0.45), a)
	_title.font_size = 34 if big else 27
	_detail.text = detail
	_detail.visible = in_range and detail != ""
	_detail.modulate = Color(col.lightened(0.2), a * 0.9)
	# Finer print only for the one you are attending to: the world stays readable.
	_blood.text = blood
	_blood.visible = in_range and blood != "" and big
	_blood.modulate = Color(0.95, 0.85, 0.8, 0.85)
	_hint.text = hint
	_hint.visible = in_range and hint != "" and big
	var off: Vector3 = data.get("label_offset", label_offset)
	# Stack the visible lines upward from the anchor, bottom to top: hint, blood, detail, name.
	var y := 0.0
	for l in [_hint, _blood, _detail, _title]:
		l.position = off
		if l.visible:
			l.offset = Vector2(0, y)
			y += l.font_size * 1.25


func _hide_labels() -> void:
	_title.visible = false
	_detail.visible = false
	_blood.visible = false
	_hint.visible = false


## One heartbeat, heard in the world: its character follows the state of the heart.
func _beat(data: Dictionary, dist: float, hz: float, attention: float, near: float) -> void:
	var state: StringName = data.get("state", &"calm")
	var sound := &"heartbeat"
	var vol := -12.0 - dist * 0.5
	var pitch := clampf(hz / 1.1, 0.7, 1.6)
	match state:
		&"afraid":
			sound = &"heartbeat_sharp"
			vol += 3.0
		&"asleep":
			sound = &"heartbeat_deep"
			pitch = clampf(hz / 1.0, 0.6, 1.1)
		&"drained":
			vol -= 6.0
	if attention > 0.9:
		vol += 2.0
	Sfx.play_at(sound, global_position, vol, pitch)
	# Very close: the heart is in your chest.
	if near > 0.25 and attention > 0.9:
		Sfx.play(&"sense_throb", -14.0 + near * 6.0, clampf(hz, 0.8, 1.4))
		Haptics.pulse(0.0, near * 0.45, 0.08)
		var fx := get_tree().get_first_node_in_group(&"screen_fx") as ScreenFX
		if fx:
			fx.beat()


func _set_overlay(on: bool) -> void:
	if _meshes.is_empty():
		var root := get_parent()
		if root:
			for n in root.find_children("*", "MeshInstance3D", true, false):
				_meshes.append(n)
	for m in _meshes:
		if is_instance_valid(m):
			m.material_overlay = _mat if on else null
