extends Node3D
## Dev tool: poses the vampire model (idle, walk, run, jump, transformation, climb) and photographs it from the
## side and from behind, so the cape and the climb can be LOOKED at rather than only measured.
##   godot --path . res://tests/model_probe.tscn -- <dir>

var out_dir := ""
var model: HumanoidModel
var cam: Camera3D


func _ready() -> void:
	out_dir = OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else ""
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.35, 0.4, 0.5)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.8, 0.8, 0.9)
	env.environment.ambient_light_energy = 0.7
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45, 30, 0)
	add_child(sun)
	var floor_mesh := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(12, 12)
	floor_mesh.mesh = pm
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color(0.25, 0.3, 0.2)
	floor_mesh.material_override = fm
	add_child(floor_mesh)
	model = HumanoidModel.new()
	add_child(model)
	model.apply_look(Color(0.66, 0.68, 0.8), Color(0.35, 0.05, 0.1), Color(0.1, 0.08, 0.12), Color(0.05, 0.03, 0.04), Color(1, 0.1, 0.05), 6.0, true, true)
	cam = Camera3D.new()
	cam.fov = 40
	add_child(cam)
	cam.make_current()
	await _wait(0.5)

	await _pose("idle", 0.0, true, 0.0, 0.0)
	await _pose("walk", 4.2, true, 0.0, 0.0)
	await _pose("run", 9.0, true, 0.0, 0.0)
	await _pose("jump", 8.0, false, 0.0, 0.0)
	await _pose("transform", 0.0, true, 1.0, 0.0)
	await _pose("climb", 0.0, true, 0.0, 1.0)
	await _pose("feed", 0.0, true, 0.0, 2.0)
	get_tree().quit()


func _wait(s: float) -> void:
	await get_tree().create_timer(s).timeout


## `mode`: 0 = locomotion, 1 = climb pose, 2 = feeding pose (arms forward, leaning in).
func _pose(pose_name: String, speed: float, on_floor: bool, pose_amount: float, mode: float) -> void:
	model.pose_amount = pose_amount
	model.body.rotation.x = 0.0
	var dt := 1.0 / 60.0
	for i in 180:
		if mode == 1.0:
			model.climb_pose(i * dt * 11.0, dt)
			model.body.rotation.x = -0.12
		else:
			model.animate(speed, on_floor, dt)
			if mode == 2.0:
				model.set_arms_forward(1.0)
				model.body.rotation.x = -0.3
		await get_tree().process_frame
	print("[PROBE] %s  cape clearance %.3f  tip %s" % [pose_name, model.cape_clearance(), str(model.cape_tip())])
	# Side view (the model faces -Z, so look along -X from +X), then behind and above.
	cam.global_position = Vector3(4.5, 1.1, 0.0)
	cam.look_at(Vector3(0, 0.95, 0.0), Vector3.UP)
	await _shot("%s_side" % pose_name)
	cam.global_position = Vector3(2.4, 1.5, 3.6)
	cam.look_at(Vector3(0, 0.9, 0.2), Vector3.UP)
	await _shot("%s_back" % pose_name)


func _shot(shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	if out_dir != "":
		get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out_dir, shot_name])
