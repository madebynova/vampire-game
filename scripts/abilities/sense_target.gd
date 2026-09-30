class_name SenseTarget
extends Node3D
## Attach to anything Vampiric Sense can reveal (child of the thing being revealed).
## The parent may implement:
##   is_sense_visible() -> bool   (default true)
##   get_sense_data() -> Dictionary {label: String, color: Color, bpm: float}

const OVERLAY_SHADER := preload("res://shaders/sense_overlay.gdshader")

@export var kind: StringName = &"living"
@export var sense_color := Color(0.9, 0.05, 0.1)
@export var max_range := 40.0
@export var label_range := 22.0
@export var label_offset := Vector3(0, 0.9, 0)
@export var heartbeat_audio := false

var revealed := false
var _mat: ShaderMaterial
var _meshes: Array[MeshInstance3D] = []
var _label: Label3D
var _last_label := ""
var _beat_prev := 0.0
var _phase := randf()


func _ready() -> void:
	add_to_group(&"sense_targets")
	_mat = ShaderMaterial.new()
	_mat.shader = OVERLAY_SHADER
	_mat.set_shader_parameter(&"phase", _phase)
	_label = Label3D.new()
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.no_depth_test = true
	_label.fixed_size = true
	_label.pixel_size = 0.0011
	_label.font_size = 26
	_label.outline_size = 8
	_label.render_priority = 20
	_label.outline_render_priority = 19
	_label.position = label_offset
	_label.visible = false
	add_child(_label)


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


func apply(shown: bool, strength: float, listener_pos: Vector3 = Vector3.ZERO) -> void:
	if shown != revealed:
		revealed = shown
		_set_overlay(shown)
	if not shown:
		_label.visible = false
		return
	var dist := global_position.distance_to(listener_pos)
	var data := get_data(dist)
	var col: Color = data.get("color", sense_color)
	var bpm: float = data.get("bpm", 0.0)
	var hz := bpm / 60.0 if bpm > 0.0 else 0.8
	_mat.set_shader_parameter(&"color", col)
	_mat.set_shader_parameter(&"intensity", 0.4 + 0.6 * strength)
	_mat.set_shader_parameter(&"beat_hz", hz)

	_label.position = data.get("label_offset", label_offset)
	var text: String = data.get("label", "")
	_label.visible = text != "" and dist <= label_range
	if _label.visible and text != _last_label:
		_label.text = text
		_last_label = text
	_label.modulate = col.lightened(0.35)

	if heartbeat_audio and bpm > 0.0 and dist < 20.0:
		var t := Time.get_ticks_msec() / 1000.0 * hz + _phase
		var frac := fposmod(t, 1.0)
		if _beat_prev < 0.25 and frac >= 0.25:
			Sfx.play_at(&"heartbeat", global_position, -12.0 - dist * 0.5, clampf(hz / 1.1, 0.7, 1.6))
		_beat_prev = frac


func _set_overlay(on: bool) -> void:
	if _meshes.is_empty():
		var root := get_parent()
		if root:
			for n in root.find_children("*", "MeshInstance3D", true, false):
				_meshes.append(n)
	for m in _meshes:
		if is_instance_valid(m):
			m.material_overlay = _mat if on else null
