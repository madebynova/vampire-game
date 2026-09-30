class_name VampiricSense
extends Ability
## THE prototype ability. Toggle it and the world splits in two:
##  - the living glow through walls, their heartbeat pulsing at their actual (fear-driven) rate
##    and audible as sound;
##  - their blood is described (temperament, scent);
##  - things the living have hidden - and that blood has told you about - reveal themselves;
##  - your resting place calls to you.
## Costs blood while active (a small up-front price and a steady trickle; free during a Bloodrush).
## Humans cannot use it at all.
##
## Feel: switching it on is a thump in the chest, a camera breath and a rumble; every scan wave that
## passes over someone makes them flare; the nearest living thing in front of you is the one you
## attend to (bright, full readout) while the rest recede.

@export var sense_range := 28.0
@export var wave_speed := 26.0
@export var ping_interval := 4.2
## In daylight, smouldering ground tiles show where the sun would burn you.
@export var embers_enabled := true

const WAVE_SHADER := preload("res://shaders/sense_wave.gdshader")

var _reach := 0.0            ## how far the first scan has travelled: nothing beyond is revealed yet
var _wave_radius := 0.0      ## the visible, repeating ring
var _ping_timer := 0.0
var _wave_strength := 0.0
var _wave_mat: ShaderMaterial
var _wave_quad: MeshInstance3D
var _embers: SenseEmbers
var _ember_timer := 0.0
var _last_wave := 0.0
## The living thing currently attended to (nearest, most in front of you). Observable by tests.
var focus_target: SenseTarget


func _on_setup() -> void:
	_build_wave_quad()
	_embers = SenseEmbers.new()
	add_child(_embers)


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
	_ember_timer = 0.0
	_last_wave = 0.0
	# The switch-on: felt before it is seen.
	player.camera_rig.kick_fov(4.5, 6.0)
	Haptics.pulse(0.25, 0.4, 0.16)
	var fx := get_tree().get_first_node_in_group(&"screen_fx") as ScreenFX
	if fx:
		fx.flash(Color(0.35, 0.02, 0.06), 0.35, 3.5)
		fx.beat()


func _on_deactivated() -> void:
	Sfx.play(&"sense_off", -4.0)
	Sfx.stop_loop(&"sense_loop")
	_wave_quad.visible = false
	_embers.hide_all()
	focus_target = null
	for target in get_tree().get_nodes_in_group(&"sense_targets"):
		target.apply(false, 0.0, Vector3.ZERO)


func _on_tick(delta: float) -> void:
	var origin := player.global_position + Vector3(0, 0.5, 0)
	_reach = minf(_reach + wave_speed * delta, sense_range + 5.0)
	_last_wave = _wave_radius
	_wave_radius += wave_speed * delta
	_ping_timer -= delta
	if _ping_timer <= 0.0:
		_ping_timer = ping_interval
		_wave_radius = 0.0
		_last_wave = 0.0
		_wave_strength = 0.75
		Sfx.play(&"sense_ping", -10.0)
		Haptics.pulse(0.0, 0.15, 0.07)
	var fade := clampf(1.0 - _wave_radius / (sense_range * 1.15), 0.0, 1.0)
	_wave_mat.set_shader_parameter(&"origin", origin)
	_wave_mat.set_shader_parameter(&"radius", _wave_radius)
	_wave_mat.set_shader_parameter(&"strength", _wave_strength * fade)

	if embers_enabled:
		_ember_timer -= delta
		if _ember_timer <= 0.0:
			_ember_timer = 0.6
			_embers.refresh(player.global_position, player.sunlight.to_sun(), player.sunlight.sun_intensity())
	var targets := get_tree().get_nodes_in_group(&"sense_targets")
	focus_target = _pick_focus(targets, origin)
	for target in targets:
		var d := origin.distance_to(target.global_position)
		var range_limit := minf(sense_range, target.max_range)
		var shown: bool = target.is_senseable() and d <= range_limit and d <= _reach
		var strength := 1.0 - smoothstep(range_limit * 0.55, range_limit, d)
		# The wave reaching someone makes them flare.
		if shown and d > _last_wave and d <= _wave_radius:
			target.pulse()
		var attention := 1.0 if (target == focus_target or target.kind != &"living") else 0.5
		target.apply(shown, strength, player.global_position, attention)


## The living thing you are attending to: near, and in front of where you are looking.
func _pick_focus(targets: Array, origin: Vector3) -> SenseTarget:
	var cam_forward := -Basis(Vector3.UP, player.camera_rig.yaw).z
	var best: SenseTarget = null
	var best_score := INF
	for t in targets:
		var target := t as SenseTarget
		if target == null or target.kind != &"living" or not target.is_senseable():
			continue
		var to: Vector3 = target.global_position - origin
		var d := to.length()
		if d > minf(sense_range, target.max_range) or d > _reach:
			continue
		var facing := clampf(cam_forward.dot(Vector3(to.x, 0.0, to.z).normalized()), 0.0, 1.0) if d > 0.1 else 1.0
		var score := d - facing * 6.0
		if score < best_score:
			best_score = score
			best = target
	return best
