extends Node
## Dev tool: captures hand-placed screenshots to eyeball look & layout.
##   godot --path . res://tests/visual_probe.tscn -- <dir>

var main: Main
var player: Player
var world: WorldBuilder
var out_dir := ""


func _ready() -> void:
	out_dir = OS.get_cmdline_user_args()[0]
	main = load("res://scenes/main.tscn").instantiate()
	main.capture_mouse = false
	add_child(main)
	player = main.player
	world = main.world
	await _wait(2.5)
	main.hud._help.visible = false

	# Overview from above.
	var cam := Camera3D.new()
	add_child(cam)
	cam.global_position = Vector3(0, 62, 26)
	cam.look_at(Vector3(0, 0, 4), Vector3.UP)
	cam.fov = 60
	cam.make_current()
	await _wait(0.5)
	await _shot("v01_overview")
	cam.global_position = Vector3(0, 30, 6)
	cam.look_at(Vector3(0, 0, -6), Vector3.UP)
	await _wait(0.3)
	await _shot("v02_house_from_above")
	cam.queue_free()
	player.camera_rig.camera.make_current()

	# Character from the front: human then vampire.
	player.place_at(Vector3(1.0, 0, 0.5), 0.0)
	player.camera_rig.yaw = PI
	player.camera_rig.pitch = -0.05
	player.camera_rig.default_distance = 3.0
	await _wait(1.0)
	await _shot("v03_human_front")
	player.form.set_form_immediate(&"vampire")
	await _wait(1.0)
	await _shot("v04_vampire_front")

	# Sense wave ring, a fraction of a second after activation, facing the yard.
	player.place_at(Vector3(3.0, 0, -3.0), 0.0)
	player.camera_rig.default_distance = 3.9
	player.camera_rig.yaw = PI
	player.camera_rig.pitch = -0.12
	await _wait(0.5)
	var sense: VampiricSense = player.abilities.get_ability(&"vampiric_sense")
	sense.activate()
	await _wait(0.45)
	await _shot("v05_sense_wave_early")
	await _wait(0.5)
	await _shot("v06_sense_wave_mid")
	await _wait(1.5)
	await _shot("v07_sense_settled")
	sense.deactivate()

	# Interior sun shafts (human form so the sun is harmless while we look).
	player.form.set_form_immediate(&"human")
	player.place_at(Vector3(1.0, 0, -12.5), 0.0)
	player.camera_rig.yaw = PI
	player.camera_rig.pitch = -0.1
	await _wait(0.8)
	await _shot("v08_hall_interior")
	player.place_at(Vector3(-4.0, 0, -8.6), 0.0)
	player.camera_rig.yaw = deg_to_rad(-20)
	await _wait(0.8)
	await _shot("v09_crypt")
	get_tree().quit()


func _wait(s: float) -> void:
	await get_tree().create_timer(s).timeout


func _shot(n: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out_dir, n])
