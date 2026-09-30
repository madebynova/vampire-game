extends Node
## Dev tool: boots the main scene for a few seconds and quits. Any script error in the project shows
## up in the log; exit code 0 means the game at least starts and runs.
##   godot --headless --path . res://tests/boot_probe.tscn

func _ready() -> void:
	GameSettings.persist = false
	var main: Main = load("res://scenes/main.tscn").instantiate()
	main.capture_mouse = false
	add_child(main)
	await get_tree().create_timer(3.5).timeout
	print("[BOOT] form=%s blood=%.1f mode=%s" % [main.player.form.current.id, main.player.blood.value, PlayerState.Mode.keys()[main.player.state.mode]])
	print("[BOOT] OK")
	get_tree().quit(0)
