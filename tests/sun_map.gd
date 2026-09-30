extends Node
## Dev tool: prints an ASCII map of sunlight (using the same rays as SunlightExposure).
##   '#' solid   '.' full sun   ':' partial   ' ' shade   'C' coffin  'T' Tomas  'E' Elise  'W' well
## Run: godot --headless --path . res://tests/sun_map.tscn -- <hour, default 16>

func _ready() -> void:
	var main: Node3D = load("res://scenes/main.tscn").instantiate()
	main.capture_mouse = false
	add_child(main)
	var hour := 16.0
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		hour = float(args[0])
	main.tod.paused = true
	main.tod.set_hour(hour)
	for i in 4:
		await get_tree().physics_frame
	var space := main.get_world_3d().direct_space_state
	var to_sun: Vector3 = main.tod.sun_direction()
	print("hour %.1f  elevation %.1f deg" % [hour, main.tod.sun_elevation_degrees()])
	print("to_sun = ", to_sun)
	var world: WorldBuilder = main.get_node("World")
	var marks := {
		Vector2i(roundi(world.coffin.global_position.x), roundi(world.coffin.global_position.z)): "C",
		Vector2i(roundi(world.tomas.global_position.x), roundi(world.tomas.global_position.z)): "T",
		Vector2i(roundi(world.elise.global_position.x), roundi(world.elise.global_position.z)): "E",
		Vector2i(11, 12): "W",
	}
	var lines: PackedStringArray = []
	for z in range(-22, 35):
		var row := ""
		for x in range(-34, 35):
			var ch := ""
			if marks.has(Vector2i(x, z)):
				ch = marks[Vector2i(x, z)]
			else:
				var down := PhysicsRayQueryParameters3D.create(Vector3(x, 3.0, z), Vector3(x, 0.2, z), 1)
				if not space.intersect_ray(down).is_empty():
					ch = "#"
				else:
					var lit := 0
					for h in [0.15, 0.9, 1.7]:
						var from := Vector3(x, h, z)
						var q := PhysicsRayQueryParameters3D.create(from, from + to_sun * 80.0, 1 | 16)
						if space.intersect_ray(q).is_empty():
							lit += 1
					ch = "." if lit == 3 else (":" if lit > 0 else " ")
			row += ch
		lines.append("%3d %s" % [z, row])
	print("x from -34 to 34, rows are z")
	print("\n".join(lines))
	get_tree().quit()
