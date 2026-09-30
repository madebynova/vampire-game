class_name CameraRig
extends Node3D
## Third-person orbit camera with collision (SpringArm3D), FOV control, shake and a
## "focus" mode used by feeding.

@export var mouse_sensitivity := 0.0024
@export var stick_speed := 2.8
@export var follow_speed := 18.0
@export var height := 1.6
@export var default_distance := 3.9
@export var min_pitch := deg_to_rad(-62.0)
@export var max_pitch := deg_to_rad(60.0)

@onready var spring: SpringArm3D = $SpringArm3D
@onready var camera: Camera3D = $SpringArm3D/Camera3D

var yaw := 0.0
var pitch := deg_to_rad(-12.0)
var base_fov := 68.0
var fov_boost := 0.0
var input_enabled := true

var _target: Node3D
var _shake := 0.0
var _focus := false
var _focus_point := Vector3.ZERO
var _focus_distance := 2.3
var _focus_fov := 56.0


func attach(target: Node3D) -> void:
	_target = target
	top_level = true
	spring.add_excluded_object(target.get_rid())
	spring.collision_mask = 1
	snap()


func snap() -> void:
	if _target:
		global_position = _target.global_position + Vector3(0, height, 0)
	rotation = Vector3(pitch, yaw, 0.0)
	spring.spring_length = default_distance


func set_focus(point: Vector3, distance: float, fov: float) -> void:
	_focus = true
	_focus_point = point
	_focus_distance = distance
	_focus_fov = fov


func clear_focus() -> void:
	_focus = false


func add_shake(amount: float) -> void:
	_shake = maxf(_shake, amount)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and input_enabled and not _focus \
			and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		yaw -= event.relative.x * mouse_sensitivity
		pitch = clampf(pitch - event.relative.y * mouse_sensitivity, min_pitch, max_pitch)


func _process(delta: float) -> void:
	if _target == null:
		return
	var goal := _target.global_position + Vector3(0, height, 0)
	global_position = global_position.lerp(goal, 1.0 - exp(-follow_speed * delta))

	if _focus:
		var to := _focus_point - global_position
		var want_yaw := atan2(-to.x, -to.z) + 0.45
		yaw = lerp_angle(yaw, want_yaw, 1.0 - exp(-5.0 * delta))
		pitch = lerpf(pitch, -0.16, 1.0 - exp(-5.0 * delta))
	elif input_enabled:
		var look := Input.get_vector(&"look_left", &"look_right", &"look_up", &"look_down")
		yaw -= look.x * stick_speed * delta
		pitch = clampf(pitch - look.y * stick_speed * delta, min_pitch, max_pitch)
	rotation = Vector3(pitch, yaw, 0.0)

	var dist := _focus_distance if _focus else default_distance
	spring.spring_length = lerpf(spring.spring_length, dist, 1.0 - exp(-5.0 * delta))
	var fov_goal := _focus_fov if _focus else base_fov + fov_boost
	camera.fov = lerpf(camera.fov, fov_goal, 1.0 - exp(-6.0 * delta))

	if _shake > 0.0005:
		camera.h_offset = randf_range(-1.0, 1.0) * _shake
		camera.v_offset = randf_range(-1.0, 1.0) * _shake
		_shake = maxf(_shake - delta * 0.35, 0.0)
	else:
		camera.h_offset = 0.0
		camera.v_offset = 0.0
