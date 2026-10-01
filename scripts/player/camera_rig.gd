class_name CameraRig
extends Node3D
## Third-person orbit camera with collision (SpringArm3D), FOV control, shake and a
## "focus" mode used by feeding. Presentation code (transformation, Sense, feeding, traversal)
## drives it only through the offsets below - never by touching the camera node directly.

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
## Additive presentation offsets. Tween them (or call the kick_* helpers); they are added after all
## smoothing, so a punch feels instant while the base FOV still eases.
var fov_offset := 0.0
var roll_offset := 0.0           ## radians
var distance_offset := 0.0       ## metres; negative = closer

var _target: Node3D
var _shake := 0.0
var _focus := false
var _focus_point := Vector3.ZERO
var _focus_distance := 2.3
var _focus_fov := 56.0
var _focus_pitch := -0.16
var _focus_yaw_offset := 0.45
var _fov_kick := 0.0
var _fov_kick_decay := 6.0
var _roll_kick := 0.0
var _roll_kick_decay := 4.0
var _fov_smooth := -1.0


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


func set_focus(point: Vector3, distance: float, fov: float, look_pitch := -0.16, yaw_offset := 0.45) -> void:
	_focus = true
	_focus_point = point
	_focus_distance = distance
	_focus_fov = fov
	_focus_pitch = look_pitch
	_focus_yaw_offset = yaw_offset


func clear_focus() -> void:
	_focus = false


func add_shake(amount: float) -> void:
	_shake = maxf(_shake, amount)


## An instant FOV jump that eases back to normal ("camera punch").
func kick_fov(degrees: float, decay := 6.0) -> void:
	_fov_kick = degrees
	_fov_kick_decay = decay


func kick_roll(radians: float, decay := 4.0) -> void:
	_roll_kick = radians
	_roll_kick_decay = decay


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and input_enabled and not _focus \
			and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var k := mouse_sensitivity * GameSettings.mouse_sensitivity
		yaw -= event.relative.x * k
		pitch = clampf(pitch - event.relative.y * k, min_pitch, max_pitch)


func _process(delta: float) -> void:
	if _target == null:
		return
	var goal := _target.global_position + Vector3(0, height, 0)
	global_position = global_position.lerp(goal, 1.0 - exp(-follow_speed * delta))

	if _focus:
		var to := _focus_point - global_position
		var want_yaw := atan2(-to.x, -to.z) + _focus_yaw_offset
		yaw = lerp_angle(yaw, want_yaw, 1.0 - exp(-5.0 * delta))
		pitch = lerpf(pitch, _focus_pitch, 1.0 - exp(-5.0 * delta))
	elif input_enabled:
		var look := Input.get_vector(&"look_left", &"look_right", &"look_up", &"look_down")
		# A gentle response curve: fine aim near the centre, full speed at the edge.
		look = look.normalized() * pow(look.length(), 1.6)
		var k := stick_speed * GameSettings.stick_sensitivity * delta
		yaw -= look.x * k
		pitch = clampf(pitch - look.y * k, min_pitch, max_pitch)
	_fov_kick = lerpf(_fov_kick, 0.0, 1.0 - exp(-_fov_kick_decay * delta))
	_roll_kick = lerpf(_roll_kick, 0.0, 1.0 - exp(-_roll_kick_decay * delta))
	rotation = Vector3(pitch, yaw, roll_offset + _roll_kick)

	var dist := (_focus_distance if _focus else default_distance) + distance_offset
	spring.spring_length = lerpf(spring.spring_length, dist, 1.0 - exp(-5.0 * delta))
	var fov_goal := (_focus_fov if _focus else base_fov + fov_boost) + fov_offset
	if _fov_smooth < 0.0:
		_fov_smooth = camera.fov
	_fov_smooth = lerpf(_fov_smooth, fov_goal, 1.0 - exp(-6.0 * delta))
	camera.fov = clampf(_fov_smooth + _fov_kick, 10.0, 140.0)

	if _shake > 0.0005:
		camera.h_offset = randf_range(-1.0, 1.0) * _shake
		camera.v_offset = randf_range(-1.0, 1.0) * _shake
		_shake = maxf(_shake - delta * 0.35, 0.0)
	else:
		camera.h_offset = 0.0
		camera.v_offset = 0.0
