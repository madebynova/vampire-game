extends Node
## Dev tool: screenshots the yard at several hours, as Human and as Vampire.
##   godot --path . res://tests/time_probe.tscn -- <dir> [hours,comma,separated]

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var out_dir: String = args[0]
	var hours := [6.0, 9.0, 12.0, 16.0, 18.0, 19.0, 21.0, 0.0, 4.5, 5.75]
	if args.size() > 1:
		hours = []
		for h in args[1].split(","):
			hours.append(float(h))
	var main: Main = load("res://scenes/main.tscn").instantiate()
	main.capture_mouse = false
	add_child(main)
	await get_tree().create_timer(2.5).timeout
	main.hud._help.visible = false
	var player: Player = main.player
	var tod: TimeOfDay = main.tod
	tod.paused = true
	player.place_at(Vector3(3.0, 0, -2.0), 0.0)
	player.camera_rig.yaw = PI * 0.85
	player.camera_rig.pitch = -0.02
	player.sunlight.set_process(false)
	player.health.set_process(false)
	var shots: Array[Image] = []
	for h in hours:
		tod.set_hour(h)
		for form in [&"human", &"vampire"]:
			player.form.set_form_immediate(form)
			await get_tree().create_timer(0.9).timeout
			await RenderingServer.frame_post_draw
			var img := get_viewport().get_texture().get_image()
			shots.append(img)
	# Contact sheets: 5 hours per sheet, Human | Vampire per row.
	var cw := 480
	var ch := 270
	var per_sheet := 5
	for sheet_i in range(0, hours.size(), per_sheet):
		var count := mini(per_sheet, hours.size() - sheet_i)
		var sheet := Image.create(cw * 2, ch * count, false, Image.FORMAT_RGB8)
		for r in count:
			for c in 2:
				var im := shots[(sheet_i + r) * 2 + c].duplicate() as Image
				im.resize(cw, ch, Image.INTERPOLATE_BILINEAR)
				im.convert(Image.FORMAT_RGB8)
				sheet.blit_rect(im, Rect2i(0, 0, cw, ch), Vector2i(c * cw, r * ch))
		sheet.save_png("%s/sheet_%d.png" % [out_dir, sheet_i / per_sheet])
	get_tree().quit()
