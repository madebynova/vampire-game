class_name Main
extends Node3D
## Scene glue. Owns no gameplay rules: it wires player events to presentation
## (screen effects, vision, HUD) and handles death -> coffin.

@export var sun_rotation_degrees := Vector3(-24.0, 160.0, 0.0)
@export var capture_mouse := true

@onready var player: Player = $Player
@onready var world: WorldBuilder = $World
@onready var hud: Hud = $HUD
@onready var screen_fx: ScreenFX = $ScreenFX
@onready var atmosphere: WorldAtmosphere = $WorldEnvironment
@onready var sun: DirectionalLight3D = $Sun


func _ready() -> void:
	sun.rotation_degrees = sun_rotation_degrees
	hud.bind(player)
	_bind_presentation()
	Sfx.start_loop(&"wind_loop", -22.0)
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
		screen_fx.flash(Color(0.6, 0.0, 0.05), 0.7, 1.4))
	player.feeding.feed_interrupted.connect(func(_n, _p): screen_fx.feed_target = 0.0)
	player.health.damaged.connect(func(amount: float, _s): screen_fx.hurt_pulse(clampf(0.1 + amount * 0.05, 0.1, 0.5)))
	player.health.died.connect(_on_player_died)


func _on_player_died(_cause: StringName) -> void:
	screen_fx.feed_target = 0.0
	screen_fx.sense_target = 0.0
	screen_fx.flash(Color(1.0, 0.9, 0.7), 1.0, 1.2)
	await get_tree().create_timer(2.4).timeout
	world.coffin.wake(player, &"death")


func _process(_delta: float) -> void:
	var s := player.sunlight
	var glare := s.burn_ratio() * 0.9
	if s.stage != SunlightExposure.Stage.SAFE and s.exposure > 0.05:
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
