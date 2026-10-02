extends Node
## Used ONLY by tools/test_exported_build.ps1. Exported Godot binaries refuse a scene path on the command line,
## so to run a test suite *inside an exported build* the script exports a temporary copy of the project whose
## main scene is this one, and picks the suite with the VG_SELFTEST_SUITE environment variable
## (e.g. "unit_tests", "smoke_test"). Everything after `--` is still passed to the suite as usual.
## This is never the main scene of the real project and nothing in the game refers to it.


func _ready() -> void:
	var suite := OS.get_environment("VG_SELFTEST_SUITE")
	if suite.is_empty():
		push_error("VG_SELFTEST_SUITE is not set")
		get_tree().quit(2)
		return
	var path := "res://tests/%s.tscn" % suite
	print("[SELFTEST] %s | editor=%s template=%s debug=%s | user dir: %s" % [
		path, OS.has_feature("editor"), OS.has_feature("template"), OS.is_debug_build(), OS.get_user_data_dir()])
	if not ResourceLoader.exists(path):
		push_error("suite scene not found in the exported build: %s" % path)
		get_tree().quit(2)
		return
	get_tree().change_scene_to_file.call_deferred(path)
