class_name TransformPresentation
extends PlayerComponent
## Everything the player sees, hears and feels while changing form. Presentation only: the
## sequence itself (when the form swaps, when control returns) belongs to FormController.
##
## Human -> Vampire is the dark one: a held breath (FOV tightens, the world narrows to a red-black
## tunnel, the body rises and leans back) - then the swap: an impact (FOV slams open, time stutters,
## a shockwave ring, chromatic tear, leather wings, the night suddenly opens around you).
## Vampire -> Human is the quiet one: the blood retreats, a long exhale, warmth, the cloak
## dissolving into ash. They share machinery, not a recipe.
##
## Restraint: about 1.2 seconds, control returns at the normal time, nothing is a cutscene.

const RING_SHADER_CODE := """
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;
uniform vec4 color : source_color = vec4(1.0, 0.1, 0.12, 1.0);
uniform float radius = 0.0;
uniform float fade = 1.0;
void fragment() {
	float d = length(UV - vec2(0.5)) * 2.0;
	float ring = smoothstep(0.16, 0.0, abs(d - radius));
	ALBEDO = color.rgb * ring * 2.2;
	ALPHA = ring * fade;
}
"""

var _tween: Tween
var _tween_aux: Tween
var _transforming := false
var _to_vampire := false
var _flash_light: OmniLight3D
var _ring: MeshInstance3D
var _ring_mat: ShaderMaterial
## Observable by tests/tools: what the last transformation did.
var last_direction: StringName = &""
var swaps := 0


func _on_setup() -> void:
	_flash_light = OmniLight3D.new()
	_flash_light.position = Vector3(0, 1.1, 0)
	_flash_light.omni_range = 9.0
	_flash_light.light_energy = 0.0
	_flash_light.visible = false
	_flash_light.shadow_enabled = false
	player.add_child(_flash_light)
	var shader := Shader.new()
	shader.code = RING_SHADER_CODE
	_ring_mat = ShaderMaterial.new()
	_ring_mat.shader = shader
	_ring = MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(9, 9)
	quad.orientation = PlaneMesh.FACE_Y
	_ring.mesh = quad
	_ring.material_override = _ring_mat
	_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_ring.visible = false
	_ring.top_level = true
	player.add_child(_ring)
	player.form.transform_started.connect(_on_started)
	player.form.form_changed.connect(_on_form_changed)
	player.form.transform_finished.connect(func(_f): _transforming = false)
	player.health.died.connect(func(_c): reset())


func _fx() -> ScreenFX:
	return get_tree().get_first_node_in_group(&"screen_fx") as ScreenFX


# ---------------------------------------------------------------- stage 1: wind-up

func _on_started(to_form: FormData) -> void:
	reset()
	_transforming = true
	_to_vampire = to_form.can_feed
	last_direction = &"to_vampire" if _to_vampire else &"to_human"
	var windup := player.form.transform_time * player.form.swap_fraction
	var cam := player.camera_rig
	var fx := _fx()
	_tween = create_tween().set_parallel(true)
	if _to_vampire:
		Sfx.play(&"transform_vampire", -2.0)
		Haptics.pulse(0.0, 0.25, windup)
		AudioBuses.set_muffle(AudioBuses.AMBIENCE, 0.0)
		_tween.tween_method(_set_muffle, 0.0, 0.85, windup * 0.9)
		_tween.tween_property(cam, "fov_offset", -16.0, windup).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		_tween.tween_property(cam, "distance_offset", -0.9, windup).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		_tween.tween_property(player.visual, "pose_amount", 1.0, windup).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		_tween.tween_property(player.visual, "position:y", 0.22, windup).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		if fx:
			fx.morph_color = Color(0.22, 0.0, 0.04)
			_tween.tween_property(fx, "morph", 0.75, windup).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			_tween.tween_property(fx, "chroma", 0.45, windup).set_ease(Tween.EASE_IN)
		cam.add_shake(0.02)
		Fx.burst(player, player.global_position + Vector3(0, 0.25, 0), Color(0.04, 0.03, 0.06, 0.9), 26, 2.2, 0.3, 1.3, 1.2)
	else:
		Sfx.play(&"transform_human", -3.0)
		Haptics.pulse(0.1, 0.15, windup)
		AudioBuses.set_muffle(AudioBuses.AMBIENCE, 0.0)
		_tween.tween_method(_set_muffle, 0.0, 0.5, windup * 0.9)
		_tween.tween_property(cam, "fov_offset", 5.0, windup).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		_tween.tween_property(cam, "distance_offset", 0.35, windup).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		_tween.tween_method(_flicker_eyes, 0.0, 1.0, windup)
		if fx:
			fx.morph_color = Color(0.86, 0.74, 0.62)
			_tween.tween_property(fx, "morph", 0.4, windup).set_ease(Tween.EASE_OUT)
	get_tree().call_group(&"npcs", &"feel_transformation", player.global_position, _to_vampire)


# ---------------------------------------------------------------- stage 2: the swap

func _on_form_changed(_old: FormData, f: FormData) -> void:
	# Persistent look of the body is PlayerFeedback's job; hearing belongs to the form.
	AudioBuses.set_vampire_hearing(f.can_feed)
	if not _transforming:
		return
	swaps += 1
	if _tween:
		_tween.kill()
	var release := maxf(player.form.transform_time * (1.0 - player.form.swap_fraction), 0.3)
	var cam := player.camera_rig
	var fx := _fx()
	_tween = create_tween().set_parallel(true)
	if _to_vampire:
		Sfx.play(&"heartbeat_deep", -2.0)
		Haptics.pulse(0.7, 1.0, 0.32)
		cam.kick_fov(20.0, 4.5)
		cam.kick_roll(deg_to_rad(3.5) * (1.0 if randf() > 0.5 else -1.0), 5.0)
		cam.add_shake(0.07)
		cam.fov_offset = 0.0
		_tween.tween_property(cam, "distance_offset", 0.0, release).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).from(0.6)
		_tween.tween_property(player.visual, "position:y", 0.0, 0.14).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
		_tween.tween_property(player.visual, "pose_amount", 0.0, 0.4).set_delay(0.1)
		_tween.tween_method(_set_muffle, 0.85, 0.0, release * 1.1)
		_tween.tween_method(_set_eye_energy, 26.0, f.eye_glow, release)
		if fx:
			fx.flash(Color(0.85, 0.05, 0.08), 0.85, 3.0)
			_tween.tween_property(fx, "morph", 0.0, release * 0.85).set_ease(Tween.EASE_OUT)
			_tween.tween_property(fx, "chroma", 0.0, release).set_ease(Tween.EASE_OUT)
			_tween.tween_property(fx, "morph_ring", 1.6, 0.8).from(0.0)
			_tween.tween_property(fx, "morph_ring_strength", 0.0, 0.8).from(1.0)
		_shockwave(Color(1.0, 0.08, 0.12))
		_light_flash(Color(1.0, 0.1, 0.12), 7.0, 0.7)
		Fx.burst(player, player.global_position + Vector3(0, 1.0, 0), Color(0.6, 0.02, 0.05, 0.95), 70, 5.0, 0.4, 1.1, 0.3)
		Fx.burst(player, player.global_position + Vector3(0, 0.3, 0), Color(0.04, 0.03, 0.06, 0.95), 34, 3.4, 0.28, 1.5, 1.0)
		_hit_stop(0.3, 0.13)
	else:
		Sfx.play(&"heartbeat", -4.0, 0.85)
		Haptics.pulse(0.3, 0.3, 0.2)
		cam.kick_fov(-5.0, 3.0)
		cam.add_shake(0.02)
		cam.fov_offset = 0.0
		_tween.tween_property(cam, "distance_offset", 0.0, release).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_tween.tween_method(_set_muffle, 0.5, 0.0, release)
		if fx:
			fx.flash(Color(0.95, 0.86, 0.75), 0.5, 2.4)
			_tween.tween_property(fx, "morph", 0.0, release).set_ease(Tween.EASE_OUT)
			_tween.tween_property(fx, "chroma", 0.0, release)
		_light_flash(Color(1.0, 0.85, 0.6), 2.5, 0.8)
		Fx.burst(player, player.global_position + Vector3(0, 1.3, 0), Color(0.12, 0.1, 0.12, 0.9), 46, 1.4, 0.16, 1.9, 0.9)
		Fx.burst(player, player.global_position + Vector3(0, 1.0, 0), Color(0.95, 0.82, 0.68, 0.5), 18, 1.2, 0.2, 1.2, 0.4)


# ---------------------------------------------------------------- pieces

func _set_muffle(v: float) -> void:
	AudioBuses.set_muffle(AudioBuses.AMBIENCE, v)
	AudioBuses.set_muffle(AudioBuses.EFFECTS, v * 0.45)


func _set_eye_energy(v: float) -> void:
	if v > 0.0:
		player.visual.set_eye_energy(v)


## Vampire -> Human: the red eyes gutter before the change.
func _flicker_eyes(t: float) -> void:
	var f := player.form.current
	var flicker := 0.5 + 0.5 * sin(t * 40.0)
	player.visual.set_eye_energy(f.eye_glow * (1.0 - t) * (0.4 + 0.6 * flicker))


func _shockwave(color: Color) -> void:
	_ring.global_position = player.global_position + Vector3(0, 0.08, 0)
	_ring.visible = true
	_ring_mat.set_shader_parameter(&"color", color)
	_ring_mat.set_shader_parameter(&"radius", 0.05)
	_ring_mat.set_shader_parameter(&"fade", 1.0)
	if _tween_aux:
		_tween_aux.kill()
	_tween_aux = create_tween().set_parallel(true)
	_tween_aux.tween_method(func(v: float): _ring_mat.set_shader_parameter(&"radius", v), 0.05, 1.0, 0.8).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween_aux.tween_method(func(v: float): _ring_mat.set_shader_parameter(&"fade", v), 1.0, 0.0, 0.8)
	_tween_aux.chain().tween_callback(func(): _ring.visible = false)


func _light_flash(color: Color, energy: float, seconds: float) -> void:
	_flash_light.light_color = color
	_flash_light.light_energy = energy
	_flash_light.visible = true
	var tw := create_tween()
	tw.tween_property(_flash_light, "light_energy", 0.0, seconds).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func(): _flash_light.visible = false)


## A brief hit-stop: the world stutters for a fraction of a second at the moment of change.
func _hit_stop(scale: float, real_seconds: float) -> void:
	if PauseControl.is_paused():
		return
	var prev := Engine.time_scale
	Engine.time_scale = prev * scale
	get_tree().create_timer(real_seconds, true, false, true).timeout.connect(func():
		if not PauseControl.is_paused() and absf(Engine.time_scale - prev * scale) < 0.001:
			Engine.time_scale = prev)


## Undo every presentation offset (a new transformation, death, a menu).
func reset() -> void:
	if _tween:
		_tween.kill()
	if _tween_aux:
		_tween_aux.kill()
	var cam := player.camera_rig
	cam.fov_offset = 0.0
	cam.distance_offset = 0.0
	cam.roll_offset = 0.0
	player.visual.pose_amount = 0.0
	player.visual.position.y = 0.0
	AudioBuses.set_muffle(AudioBuses.AMBIENCE, 0.0)
	AudioBuses.set_muffle(AudioBuses.EFFECTS, 0.0)
	_ring.visible = false
	var fx := _fx()
	if fx:
		fx.morph = 0.0
		fx.chroma = 0.0
		fx.morph_ring_strength = 0.0
