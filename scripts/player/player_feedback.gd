class_name PlayerFeedback
extends PlayerComponent
## Everything the player *sees and hears* about their own state: form look, aura,
## transformation burst, sunlight smoke/sizzle, feeding and death effects.
## Purely presentational; gameplay never reads from here.

var _aura: OmniLight3D
var _smoke: CPUParticles3D
var _embers: CPUParticles3D


func _on_setup() -> void:
	_aura = OmniLight3D.new()
	_aura.position = Vector3(0, 1.1, 0)
	_aura.omni_range = 5.0
	_aura.shadow_enabled = false
	player.add_child(_aura)
	_smoke = Fx.emitter(player, Vector3(0, 1.2, 0), Color(0.18, 0.16, 0.16, 0.7), 26, 1.8, 0.45, 1.3, 1.5)
	_embers = Fx.emitter(player, Vector3(0, 1.0, 0), Color(1.0, 0.55, 0.15, 1.0), 20, 2.6, 0.08, 0.8, 2.5)

	player.form.form_changed.connect(_on_form_changed)
	player.form.transform_started.connect(_on_transform_started)
	player.sunlight.stage_changed.connect(_on_stage_changed)
	player.health.died.connect(_on_died)
	player.feeding.feed_started.connect(_on_feed_started)
	player.feeding.feed_completed.connect(_on_feed_done)
	player.feeding.feed_interrupted.connect(func(_n, _p): Sfx.play(&"gasp", -4.0))
	if player.form.current:
		_on_form_changed(null, player.form.current)


func _process(_delta: float) -> void:
	var stage := player.sunlight.stage
	_smoke.emitting = stage >= SunlightExposure.Stage.BURNING
	_embers.emitting = stage >= SunlightExposure.Stage.SEARING
	_smoke.amount = 26 if stage == SunlightExposure.Stage.BURNING else 40
	var burn := player.sunlight.burn_ratio()
	if stage >= SunlightExposure.Stage.BURNING and player.sunlight.exposure > 0.05:
		Sfx.start_loop(&"sizzle_loop", lerpf(-16.0, -2.0, burn))
		Sfx.set_loop_volume(&"sizzle_loop", lerpf(-16.0, -2.0, burn))
	else:
		Sfx.stop_loop(&"sizzle_loop")
	player.camera_rig.fov_boost = 6.0 if Input.is_action_pressed(&"sprint") and player.velocity.length() > 3.0 else 0.0


func _on_form_changed(_old: FormData, f: FormData) -> void:
	player.visual.apply_look(f.skin_color, f.cloth_color, f.pants_color, f.hair_color, f.eye_color, f.eye_glow, f.show_cloak, f.show_fangs)
	_aura.light_color = f.aura_color
	_aura.light_energy = f.aura_energy
	player.camera_rig.base_fov = f.fov


func _on_transform_started(to_form: FormData) -> void:
	var to_vampire := to_form.can_feed
	Sfx.play(&"transform_vampire" if to_vampire else &"transform_human", -2.0)
	player.camera_rig.add_shake(0.06 if to_vampire else 0.025)
	var col := Color(0.25, 0.02, 0.06, 0.9) if to_vampire else Color(0.9, 0.8, 0.7, 0.6)
	Fx.burst(player, player.global_position + Vector3(0, 1.0, 0), col, 60 if to_vampire else 30, 4.5, 0.4, 1.1, 0.5)
	if to_vampire:
		Fx.burst(player, player.global_position + Vector3(0, 0.3, 0), Color(0.05, 0.05, 0.07, 0.95), 24, 2.5, 0.25, 1.4, 1.5)


func _on_stage_changed(stage: SunlightExposure.Stage, old: SunlightExposure.Stage) -> void:
	if stage > old:
		Sfx.play(&"sun_warn", -4.0 + 3.0 * stage, 1.0 + 0.12 * stage)
		player.camera_rig.add_shake(0.012 * stage)


func _on_died(_cause: StringName) -> void:
	Sfx.stop_loop(&"sizzle_loop")
	Sfx.stop_loop(&"feed_loop")
	Sfx.play(&"death", 0.0)
	Fx.burst(player, player.global_position + Vector3(0, 1.0, 0), Color(0.2, 0.2, 0.2, 0.95), 80, 3.5, 0.3, 1.8, 0.8)
	Fx.burst(player, player.global_position + Vector3(0, 1.0, 0), Color(1.0, 0.5, 0.1, 1.0), 40, 5.0, 0.1, 1.0, 2.0)
	_smoke.emitting = false
	_embers.emitting = false
	player.visual.visible = false


func _on_feed_started(npc: HumanNpc) -> void:
	Fx.burst(player, npc.global_position + Vector3(0, 1.45, 0), Color(0.7, 0.02, 0.05, 1.0), 14, 1.6, 0.05, 0.7, -5.0)


func _on_feed_done(_npc: HumanNpc, _result: Dictionary) -> void:
	Fx.burst(player, player.global_position + Vector3(0, 1.0, 0), Color(0.8, 0.03, 0.06, 0.8), 30, 2.0, 0.2, 1.0, 0.3)
