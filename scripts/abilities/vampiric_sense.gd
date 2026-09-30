class_name VampiricSense
extends Ability
## THE prototype ability. Toggle it and the world splits in two:
##  - the living glow through walls, their heartbeat pulsing at their actual (fear-driven) rate
##    and audible as sound;
##  - their blood is described (temperament, scent);
##  - things the living have hidden - and that blood has told you about - reveal themselves;
##  - your resting place calls to you.
## Costs blood while active. Humans cannot use it at all.

@export var sense_range := 28.0
@export var wave_speed := 26.0
@export var ping_interval := 4.2

const WAVE_SHADER := preload("res://shaders/sense_wave.gdshader")

var _reach := 0.0            ## how far the first scan has travelled: nothing beyond is revealed yet
var _wave_radius := 0.0      ## the visible, repeating ring
var _ping_timer := 0.0
var _wave_strength := 0.0
var _wave_mat: ShaderMaterial
var _wave_quad: MeshInstance3D


func _on_setup() -> void:
	_build_wave_quad()


func _build_wave_quad() -> void:
	_wave_mat = ShaderMaterial.new()
	_wave_mat.shader = WAVE_SHADER
	_wave_quad = MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(2, 2)
	_wave_quad.mesh = q
	_wave_quad.material_override = _wave_mat
	_wave_quad.extra_cull_margin = 16384.0
	_wave_quad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_wave_quad.visible = false
	player.camera_rig.camera.add_child(_wave_quad)


func _on_activated() -> void:
	Sfx.play(&"sense_on", -3.0)
	Sfx.start_loop(&"sense_loop", -14.0)
	_reach = 0.0
	_wave_radius = 0.0
	_ping_timer = ping_interval
	_wave_strength = 1.0
	_wave_quad.visible = true


func _on_deactivated() -> void:
	Sfx.play(&"sense_off", -4.0)
	Sfx.stop_loop(&"sense_loop")
	_wave_quad.visible = false
	for target in get_tree().get_nodes_in_group(&"sense_targets"):
		target.apply(false, 0.0, Vector3.ZERO)


func _on_tick(delta: float) -> void:
	var origin := player.global_position + Vector3(0, 0.5, 0)
	_reach = minf(_reach + wave_speed * delta, sense_range + 5.0)
	_wave_radius += wave_speed * delta
	_ping_timer -= delta
	if _ping_timer <= 0.0:
		_ping_timer = ping_interval
		_wave_radius = 0.0
		_wave_strength = 0.75
		Sfx.play(&"sense_ping", -10.0)
	var fade := clampf(1.0 - _wave_radius / (sense_range * 1.15), 0.0, 1.0)
	_wave_mat.set_shader_parameter(&"origin", origin)
	_wave_mat.set_shader_parameter(&"radius", _wave_radius)
	_wave_mat.set_shader_parameter(&"strength", _wave_strength * fade)

	for target in get_tree().get_nodes_in_group(&"sense_targets"):
		var d := origin.distance_to(target.global_position)
		var range_limit := minf(sense_range, target.max_range)
		var shown: bool = target.is_senseable() and d <= range_limit and d <= _reach
		var strength := 1.0 - smoothstep(range_limit * 0.55, range_limit, d)
		target.apply(shown, strength, player.global_position)
