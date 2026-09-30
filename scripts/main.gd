class_name Main
extends Node3D
## Scene glue. Owns no gameplay rules: it wires player events to presentation
## (screen effects, vision, HUD) and handles death -> coffin.

@export var capture_mouse := true

@onready var player: Player = $Player
@onready var world: WorldBuilder = $World
@onready var hud: Hud = $HUD
@onready var screen_fx: ScreenFX = $ScreenFX
@onready var atmosphere: WorldAtmosphere = $WorldEnvironment
@onready var sun: DirectionalLight3D = $Sun
@onready var moon: DirectionalLight3D = $Moon
@onready var tod: TimeOfDay = $TimeOfDay


func _ready() -> void:
	atmosphere.setup(tod, sun, moon)
	atmosphere.set_vision(player.form.current, 0.0)
	hud.bind(player)
	_bind_presentation()
	Sfx.start_loop(&"wind_loop", -24.0)
	Sfx.start_loop(&"crickets_loop", -80.0)
	Sfx.start_loop(&"birds_loop", -80.0)
	screen_fx.set_fade(1.0)
	if capture_mouse:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	world.coffin.wake(player, &"start")


func _bind_presentation() -> void:
	player.form.form_changed.connect(func(_old: FormData, f: FormData): atmosphere.set_vision(f))
	player.form.transform_started.connect(func(to: FormData):
		screen_fx.flash(Color(0.35, 0.0, 0.05) if to.can_feed else Color(0.95, 0.88, 0.8), 0.9, 2.0))
	var sense := player.abilities.get_ability(&"vampiric_sense")
	if sense:
		sense.activated.connect(func(): screen_fx.sense_target = 1.0)
		sense.deactivated.connect(func(): screen_fx.sense_target = 0.0)
	player.feeding.feed_started.connect(func(_n): screen_fx.feed_target = 1.0)
	player.feeding.feed_completed.connect(func(_n, _r):
		screen_fx.feed_target = 0.0
		screen_fx.memory_target = 1.0
		screen_fx.flash(Color(0.6, 0.0, 0.05), 0.7, 1.4))
	hud.memory_closed.connect(func(): screen_fx.memory_target = 0.0)
	player.feeding.feed_interrupted.connect(func(_n, _p): screen_fx.feed_target = 0.0)
	player.health.damaged.connect(func(amount: float, _s): screen_fx.hurt_pulse(clampf(0.1 + amount * 0.05, 0.1, 0.5)))
	player.health.died.connect(_on_player_died)
	tod.phase_changed.connect(_on_phase_changed)
	tod.hour_changed.connect(_on_hour_changed)


func _on_phase_changed(new_phase: StringName, _old: StringName) -> void:
	match new_phase:
		TimeOfDay.DUSK:
			hud.toast("The sun sinks. Dusk.", Color(1.0, 0.7, 0.5), 4.0)
			Sfx.play(&"bell", -6.0)
		TimeOfDay.NIGHT:
			hud.toast("Night falls. The world is yours - and theirs.", Color(0.7, 0.75, 1.0), 4.5)
		TimeOfDay.DAWN:
			hud.toast("The sky pales. Dawn is here.", Color(1.0, 0.75, 0.55), 4.0)
		TimeOfDay.DAY:
			hud.toast("The sun is up.", Color(1.0, 0.9, 0.7), 3.0)


func _on_hour_changed(h: int) -> void:
	if h == 5 and player.form.current.sun_vulnerable:
		hud.toast("Less than an hour until sunrise. Find shelter.", Color(1.0, 0.6, 0.4), 5.0)
		Sfx.play(&"bell", -4.0, 0.8)


func _on_player_died(_cause: StringName) -> void:
	screen_fx.feed_target = 0.0
	screen_fx.sense_target = 0.0
	screen_fx.flash(Color(1.0, 0.9, 0.7), 1.0, 1.2)
	await get_tree().create_timer(2.4).timeout
	world.coffin.wake(player, &"death")


func _process(_delta: float) -> void:
	# Ambience follows the time of day: crickets at night, birds in daylight.
	var night := tod.darkness()
	var day := clampf(tod.sun_strength() * 1.4, 0.0, 1.0)
	Sfx.set_loop_volume(&"crickets_loop", linear_to_db(maxf(night * 0.5, 0.0001)))
	Sfx.set_loop_volume(&"birds_loop", linear_to_db(maxf(day * 0.35, 0.0001)))
	if not hud._memory_panel.visible:
		screen_fx.memory_target = 0.0
	var s := player.sunlight
	var glare := s.burn_ratio() * 0.9
	if s.stage > 0 and s.strength > 0.03:
		glare += 0.08
	screen_fx.sun_target = clampf(glare, 0.0, 1.0)


func _physics_process(_delta: float) -> void:
	# Safety net: fell out of the arena.
	if player.global_position.y < -15.0 and not player.state.is_dead():
		world.coffin.wake(player, &"rest")


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED and capture_mouse:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event.is_action_pressed(&"ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
