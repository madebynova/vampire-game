extends Node
## Dev tool: captures hand-placed views of the estate to judge layout, lamps and trees.
##   godot --path . res://tests/world_probe.tscn -- <dir> [set]
## sets: "title", "day" (overview + ground views by day), "night" (same at night, vampire vision),
##       "routes" (window / roof traversal views with Sense on)

var main: Main
var player: Player
var out_dir := ""
var cam: Camera3D


func _ready() -> void:
	GameSettings.persist = false
	var args := OS.get_cmdline_user_args()
	out_dir = args[0]
	var which := args[1] if args.size() > 1 else "day"
	if which == "title":
		var title: Control = load("res://scenes/title.tscn").instantiate()
		add_child(title)
		await _wait(1.6)
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("%s/title.png" % out_dir)
		get_tree().quit()
		return
	HumanNpc.schedules_enabled = true
	main = load("res://scenes/main.tscn").instantiate()
	main.capture_mouse = false
	add_child(main)
	player = main.player
	await _wait(2.8)
	main.hud.set_dimmed(true)
	cam = Camera3D.new()
	add_child(cam)
	cam.make_current()
	main.tod.paused = true
	match which:
		"day":
			await _prepare(12.0, &"human")
			await _views("d")
		"night":
			await _prepare(23.0, &"vampire")
			await _views("n")
		"dusk":
			await _prepare(19.4, &"human")
			await _views("u")
		"routes":
			await _routes()
	get_tree().quit()


func _prepare(hour: float, form: StringName) -> void:
	main.tod.set_hour(hour)
	get_tree().call_group(&"npcs", &"new_day")
	player.form.set_form_immediate(form)
	player.place_at(Vector3(-6.5, 0, -15), 0)   # tucked away in the crypt
	await _wait(1.0)


func _view(n: String, pos: Vector3, look: Vector3, fov := 60.0) -> void:
	cam.global_position = pos
	cam.look_at(look, Vector3.UP)
	cam.fov = fov
	await _wait(0.35)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out_dir, n])


func _views(prefix: String) -> void:
	await _view(prefix + "01_overview", Vector3(0, 62, 34), Vector3(0, 0, 4), 62.0)
	await _view(prefix + "02_from_gate", Vector3(3, 2.2, 27.5), Vector3(3, 2.0, 0), 66.0)
	await _view(prefix + "03_road_to_manor", Vector3(9, 3.0, 14), Vector3(2, 1.5, -6), 62.0)
	await _view(prefix + "04_hut", Vector3(2.0, 2.0, 20.5), Vector3(11, 1.0, 26), 60.0)
	await _view(prefix + "05_cottage_well", Vector3(6, 2.6, 6), Vector3(17, 1.5, 15), 62.0)
	await _view(prefix + "06_gatehouse", Vector3(-10, 2.2, 10), Vector3(-23, 1.5, 4), 60.0)
	await _view(prefix + "07_graves", Vector3(12, 2.4, 6), Vector3(22, 1.2, -1), 60.0)
	await _view(prefix + "08_manor_front", Vector3(-4, 2.0, 6), Vector3(3, 2.0, -8), 64.0)


func _routes() -> void:
	await _prepare(23.0, &"vampire")
	var sense: VampiricSense = player.abilities.get_ability(&"vampiric_sense")
	player.blood.value = 100.0
	# Stand near each route with Sense on, looking at it.
	var stands := [
		["r1_manor_window", Vector3(6.2, 0, -3.3), Vector3(6.2, 1.6, -7)],
		["r2_roof_climb", Vector3(-5, 0, -2.8), Vector3(-5, 3.0, -6.5)],
		["r3_ruined_wall", Vector3(18, 0, 14.0), Vector3(18, 1.8, 11)],
		["r4_cottage_window", Vector3(22.1, 0, 12.4), Vector3(22.1, 1.6, 15)],
		["r5_gatehouse_window", Vector3(-23.35, 0, -0.6), Vector3(-23.35, 1.6, 2)],
	]
	for st in stands:
		player.place_at(st[1], 0)
		var d: Vector3 = st[2] - st[1]
		player.camera_rig.yaw = atan2(-d.x, -d.z)
		player.camera_rig.pitch = -0.1
		if not sense.active:
			sense.activate()
		await _wait(2.0)
		cam.current = false
		player.camera_rig.camera.make_current()
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out_dir, st[0]])
		print("[PROBE] %s prompt: %s" % [st[0], player.interactor.focused.get_prompt(player) if player.interactor.focused else "none"])


func _wait(s: float) -> void:
	await get_tree().create_timer(s).timeout
