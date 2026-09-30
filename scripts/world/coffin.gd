class_name Coffin
extends Node3D
## The vampire's resting place: recognisable, the spawn point, the reset point after death,
## and the place to "end the night" (world resets: NPCs return, wounds close, hunger floor).
## Foundation for the future vampire home system - intentionally tiny.

const WOOD := Color(0.3, 0.13, 0.09)
const TRIM := Color(0.85, 0.62, 0.2)
const CLOTH := Color(0.55, 0.05, 0.1)

@export var spawn_yaw_degrees := -90.0
@export var min_blood_after_rest := 40.0

@onready var spawn: Marker3D = $SpawnPoint
@onready var interactable: Interactable = $Interactable

var _busy := false
var _candle_lights: Array[OmniLight3D] = []


func _ready() -> void:
	add_to_group(&"coffins")
	interactable.prompt_text = "Rest in your coffin (end the night)"
	interactable.interacted.connect(func(actor: Player): wake(actor, &"rest"))
	_build_visuals()


func _process(_delta: float) -> void:
	var t := Time.get_ticks_msec() / 1000.0
	for i in _candle_lights.size():
		_candle_lights[i].light_energy = 0.9 + sin(t * 9.0 + i * 2.0) * 0.12 + sin(t * 23.0 + i) * 0.06


func spawn_yaw() -> float:
	return rotation.y + deg_to_rad(spawn_yaw_degrees)


func _build_visuals() -> void:
	Greybox.decal(self, Vector3(0, 0.03, 0.1), Vector3(3.2, 0.05, 3.8), CLOTH)
	# Tapered hexagonal-ish coffin: head, shoulders, body, feet.
	var sections := [
		[Vector3(0.5, 0.55, 0.5), Vector3(0, 0.32, -0.8)],
		[Vector3(0.88, 0.55, 0.5), Vector3(0, 0.32, -0.3)],
		[Vector3(0.66, 0.55, 0.7), Vector3(0, 0.32, 0.3)],
		[Vector3(0.46, 0.55, 0.4), Vector3(0, 0.32, 0.85)],
	]
	for s in sections:
		Greybox.box(self, s[1], s[0], WOOD, Greybox.WORLD, "CoffinBase")
	# Lid, left slightly ajar so the silhouette reads as "coffin", not "crate".
	var lid := Node3D.new()
	lid.name = "Lid"
	lid.position = Vector3(0.0, 0.64, 0.0)
	lid.rotation.y = deg_to_rad(11.0)
	add_child(lid)
	for s in sections:
		var size: Vector3 = s[0]
		var pos: Vector3 = s[1]
		Greybox.decal(lid, Vector3(pos.x, 0.0, pos.z), Vector3(size.x + 0.08, 0.1, size.z + 0.02), WOOD.lightened(0.08))
	Greybox.decal(lid, Vector3(0, 0.07, -0.3), Vector3(0.07, 0.04, 0.75), TRIM)
	Greybox.decal(lid, Vector3(0, 0.07, -0.42), Vector3(0.36, 0.04, 0.07), TRIM)
	# Candles at the head.
	for side in [-1.0, 1.0]:
		var candle := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.045
		cm.bottom_radius = 0.05
		cm.height = 0.45
		candle.mesh = cm
		candle.material_override = Greybox.material(Color(0.9, 0.85, 0.7))
		candle.position = Vector3(0.75 * side, 0.22, -1.05)
		add_child(candle)
		var flame := MeshInstance3D.new()
		var fm := SphereMesh.new()
		fm.radius = 0.03
		fm.height = 0.08
		flame.mesh = fm
		flame.material_override = Greybox.material(Color(1.0, 0.6, 0.2), 6.0)
		flame.position = Vector3(0.75 * side, 0.5, -1.05)
		flame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(flame)
		var light := OmniLight3D.new()
		light.light_color = Color(1.0, 0.55, 0.25)
		light.omni_range = 8.0
		light.position = Vector3(0.75 * side, 0.7, -1.05)
		add_child(light)
		_candle_lights.append(light)


## Reset everything a night resets and put the player at the coffin.
## kind: &"start" (game launch), &"rest" (player chose to sleep), &"death".
func wake(player: Player, kind: StringName) -> void:
	if _busy:
		return
	_busy = true
	var fx := get_tree().get_first_node_in_group(&"screen_fx") as ScreenFX
	var hud := get_tree().get_first_node_in_group(&"hud") as Hud
	if kind != &"start":
		player.state.set_mode(PlayerState.Mode.RESTING)
		if fx:
			await fx.fade_to(1.0, 0.7 if kind == &"rest" else 1.0)
		Sfx.play(&"coffin", -2.0)
		await get_tree().create_timer(1.3).timeout

	player.abilities.deactivate_all()
	player.form.set_form_immediate(&"human")
	player.health.revive(0.55 if kind == &"death" else 1.0)
	player.sunlight.reset()
	player.blood.set_floor(min_blood_after_rest)
	player.state.set_mode(PlayerState.Mode.RESTING)
	get_tree().call_group(&"npcs", &"new_day")
	get_tree().call_group(&"secrets", &"new_day")
	player.place_at(spawn.global_position, spawn_yaw())
	if fx and kind == &"start":
		fx.set_fade(1.0)
	if fx:
		await fx.fade_to(0.0, 1.6)
	player.state.set_mode(PlayerState.Mode.NORMAL)
	if hud:
		match kind:
			&"start":
				hud.toast("You wake in your coffin. Press H for controls.", Color(0.9, 0.8, 0.8), 6.0)
			&"rest":
				hud.toast("A night passes. The living have forgotten you.", Color(0.8, 0.8, 0.95), 4.5)
			&"death":
				hud.toast("You wake in your coffin, weaker than before.", Color(0.95, 0.5, 0.5), 5.0)
	_busy = false


# Vampiric Sense hooks: home calls to you.
func get_sense_data(_dist := 0.0) -> Dictionary:
	var p := get_tree().get_first_node_in_group(&"player") as Player
	var d := 0.0 if p == null else p.global_position.distance_to(global_position)
	return {"label": "Your coffin  (%d m)" % roundi(d), "color": Color(0.55, 0.3, 1.0), "bpm": 0.0}
