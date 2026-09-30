class_name PlayerFeedback
extends PlayerComponent
## Everything the player *sees, hears and feels* about their own body: form look, aura, the
## persistent vampire rim, sunlight smoke/sizzle, hunger and the heartbeat, the Bloodrush, feeding
## and death effects. Purely presentational; gameplay never reads from here.
## (The transformation itself lives in TransformPresentation.)

var _aura: OmniLight3D
var _smoke: CPUParticles3D
var _embers: CPUParticles3D
var _fx: ScreenFX
var _aura_base := 0.0
var _heartbeat_timer := 0.0
var _hunger_timer := 4.0
var _was_surging := false
## Observable by tests: how loud the body currently is about its own heart (0..1).
var heart_visibility := 0.0


func _on_setup() -> void:
	_aura = OmniLight3D.new()
	_aura.position = Vector3(0, 1.1, 0)
	_aura.omni_range = 5.0
	_aura.shadow_enabled = false
	player.add_child(_aura)
	_smoke = Fx.emitter(player, Vector3(0, 1.2, 0), Color(0.18, 0.16, 0.16, 0.7), 26, 1.8, 0.45, 1.3, 1.5)
	_embers = Fx.emitter(player, Vector3(0, 1.0, 0), Color(1.0, 0.55, 0.15, 1.0), 20, 2.6, 0.08, 0.8, 2.5)

	player.form.form_changed.connect(_on_form_changed)
	player.sunlight.stage_changed.connect(_on_stage_changed)
	player.health.died.connect(_on_died)
	player.feeding.feed_started.connect(_on_feed_started)
	player.feeding.feed_completed.connect(_on_feed_done)
	player.feeding.feed_interrupted.connect(func(_n, _p):
		Sfx.play(&"gasp", -4.0)
		Haptics.pulse(0.6, 0.2, 0.2))
	player.surge.started.connect(_on_surge_started)
	player.surge.ended.connect(func(): _burst_soft(Color(0.5, 0.05, 0.08, 0.5)))
	if player.form.current:
		_on_form_changed(null, player.form.current)


func _process(delta: float) -> void:
	var sun := player.sunlight
	var lit := sun.strength > 0.03
	var frac := sun.stage_fraction()
	_smoke.emitting = sun.stage > 0 and frac >= 0.5 and lit
	_embers.emitting = frac >= 0.75 and lit
	_smoke.amount = 26 if frac < 0.75 else 40
	if lit and frac >= 0.5:
		var vol := lerpf(-16.0, -3.0, frac)
		Sfx.start_loop(&"sizzle_loop", vol)
		Sfx.set_loop_volume(&"sizzle_loop", vol)
	else:
		Sfx.stop_loop(&"sizzle_loop")
	# Critical: your own heartbeat, quickening.
	if lit and frac >= 0.99:
		_heartbeat_timer -= delta
		if _heartbeat_timer <= 0.0:
			_heartbeat_timer = 0.55
			Sfx.play(&"heartbeat", -4.0, 1.3)
			Haptics.heartbeat(0.45)
	player.camera_rig.fov_boost = 6.0 if Input.is_action_pressed(&"sprint") and player.velocity.length() > 3.0 else 0.0
	_presence(delta)


## The persistent "something inside me is alive" layer: the vampire rim, hunger, the Bloodrush,
## and the heart that shows itself at the edges of the screen when it has reason to.
func _presence(delta: float) -> void:
	if _fx == null:
		_fx = get_tree().get_first_node_in_group(&"screen_fx") as ScreenFX
	var f := player.form.current
	var blood := player.blood
	var vampire := f.can_feed
	var surge := player.surge.intensity()
	var hunger := 0.0
	if blood.is_hungry():
		hunger = clampf((blood.hungry_threshold - blood.value) / blood.hungry_threshold, 0.0, 1.0) * 0.6 + 0.4
	# How visible the heartbeat is: hunger and a Bloodrush show it; a calm full vampire does not.
	heart_visibility = clampf(maxf(hunger, surge * 0.45), 0.0, 1.0)
	if player.feeding.is_feeding():
		heart_visibility = maxf(heart_visibility, 0.6)
	if _fx:
		_fx.vamp_target = 1.0 if vampire else 0.0
		_fx.hunger_target = hunger
		_fx.surge_target = surge
		_fx.pulse_strength_target = heart_visibility
	# Aura and eyes swell with the Bloodrush (the transformation animates them itself).
	if vampire and player.state.mode != PlayerState.Mode.TRANSFORMING:
		_aura.light_energy = _aura_base * (1.0 + 1.2 * surge)
		player.visual.set_eye_energy(f.eye_glow * (1.0 + 0.6 * surge))
	# The heart: only audible when it has something to say.
	var audible := vampire and (blood.is_hungry() or surge > 0.3) and not player.feeding.is_feeding() 		and player.state.mode == PlayerState.Mode.NORMAL
	_beat_clock(delta, audible)
	# Hunger pangs: a low call from the body, rarely, never a chore.
	if vampire and blood.is_hungry() and player.state.mode == PlayerState.Mode.NORMAL:
		_hunger_timer -= delta
		if _hunger_timer <= 0.0:
			_hunger_timer = 6.0 if blood.is_starving() else 11.0
			Sfx.play(&"hunger_pang", -9.0)
			Haptics.pulse(0.0, 0.3, 0.25)
	else:
		_hunger_timer = maxf(_hunger_timer, 3.0)


var _beat_t := 0.0


func _beat_clock(delta: float, audible: bool) -> void:
	_beat_t -= delta
	if _beat_t > 0.0:
		return
	_beat_t = 60.0 / maxf(player.blood.pulse_rate(), 30.0)
	if player.feeding.is_feeding():
		return   # FeedingController keeps its own, louder beat
	if _fx and heart_visibility > 0.05:
		_fx.beat()
	if audible:
		Sfx.play(&"heartbeat_deep", -12.0 + 6.0 * heart_visibility)
		if player.blood.is_hungry():
			Haptics.heartbeat(0.22 * heart_visibility)


func _on_form_changed(_old: FormData, f: FormData) -> void:
	player.visual.apply_look(f.skin_color, f.cloth_color, f.pants_color, f.hair_color, f.eye_color, f.eye_glow, f.show_cloak, f.show_fangs)
	_aura.light_color = f.aura_color
	_aura_base = f.aura_energy
	_aura.light_energy = f.aura_energy
	player.camera_rig.base_fov = f.fov


func _on_stage_changed(stage: int, old: int) -> void:
	if stage > old:
		var f := player.sunlight.stage_fraction()
		Sfx.play(&"sun_warn", -8.0 + 8.0 * f, 0.9 + 0.35 * f)
		player.camera_rig.add_shake(0.01 + 0.03 * f)
		if f >= 0.5:
			Haptics.pulse(0.4 * f, 0.6 * f, 0.3)


func _on_died(_cause: StringName) -> void:
	Sfx.stop_loop(&"sizzle_loop")
	Sfx.stop_loop(&"feed_loop")
	Sfx.play(&"death", 0.0)
	Haptics.pulse(1.0, 1.0, 0.5)
	Fx.burst(player, player.global_position + Vector3(0, 1.0, 0), Color(0.2, 0.2, 0.2, 0.95), 80, 3.5, 0.3, 1.8, 0.8)
	Fx.burst(player, player.global_position + Vector3(0, 1.0, 0), Color(1.0, 0.5, 0.1, 1.0), 40, 5.0, 0.1, 1.0, 2.0)
	_smoke.emitting = false
	_embers.emitting = false
	player.visual.visible = false


func _on_feed_started(npc: HumanNpc) -> void:
	Fx.burst(player, npc.global_position + Vector3(0, 1.45, 0), Color(0.7, 0.02, 0.05, 1.0), 14, 1.6, 0.05, 0.7, -5.0)


func _on_feed_done(_npc: HumanNpc, _result: Dictionary) -> void:
	Fx.burst(player, player.global_position + Vector3(0, 1.0, 0), Color(0.8, 0.03, 0.06, 0.8), 30, 2.0, 0.2, 1.0, 0.3)
	Fx.burst(player, player.global_position + Vector3(0, 0.2, 0), Color(0.9, 0.08, 0.1, 0.9), 40, 3.2, 0.14, 1.4, 1.6)


func _on_surge_started(info: Dictionary) -> void:
	if info.get("fresh", true):
		_burst_soft(Color(1.0, 0.1, 0.12, 0.8))


func _burst_soft(color: Color) -> void:
	Fx.burst(player, player.global_position + Vector3(0, 1.1, 0), color, 26, 1.8, 0.12, 1.2, 0.8)
