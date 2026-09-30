class_name Player
extends CharacterBody3D
## Third-person controller: movement, jumping, facing. Everything vampire-related lives in
## the components under $Components; this script only owns locomotion and wiring.

@export var gravity := 22.0
@export var turn_speed := 14.0
@export var coyote_time := 0.12
@export var jump_buffer_time := 0.12

@onready var visual: HumanoidModel = $Visual
@onready var camera_rig: CameraRig = $CameraRig
@onready var state: PlayerState = $Components/State
@onready var form: FormController = $Components/Form
@onready var blood: BloodPool = $Components/Blood
@onready var health: Health = $Components/Health
@onready var sunlight: SunlightExposure = $Components/Sunlight
@onready var abilities: AbilityManager = $Components/Abilities
@onready var interactor: Interactor = $Components/Interactor
@onready var feeding: FeedingController = $Components/Feeding
@onready var feedback: PlayerFeedback = $Components/Feedback

## Multipliers on movement speed keyed by source (sunlight, hunger, ...).
var speed_modifiers: Dictionary = {}

var _coyote := 0.0
var _jump_buffer := 0.0
var _facing_yaw := 0.0


func _ready() -> void:
	add_to_group(&"player")
	collision_layer = 2
	collision_mask = 1 | 4
	camera_rig.attach(self)
	_setup_components($Components)


func _setup_components(node: Node) -> void:
	for child in node.get_children():
		if child is PlayerComponent:
			child.setup(self)
		_setup_components(child)


func get_speed_multiplier() -> float:
	var m := 1.0
	for v in speed_modifiers.values():
		m *= v
	return m


func face_toward(world_pos: Vector3) -> void:
	var d := world_pos - global_position
	if Vector2(d.x, d.z).length() > 0.01:
		_facing_yaw = atan2(-d.x, -d.z)
		visual.rotation.y = _facing_yaw


## Hard-place the player (spawn, respawn). `yaw` = facing/camera direction.
func place_at(pos: Vector3, yaw: float) -> void:
	global_position = pos
	velocity = Vector3.ZERO
	_facing_yaw = yaw
	visual.rotation.y = yaw
	visual.visible = true
	camera_rig.yaw = yaw
	camera_rig.pitch = deg_to_rad(-10.0)
	camera_rig.snap()


func _physics_process(delta: float) -> void:
	var can_move := state.can_control_movement()
	var f := form.current
	var input := Vector2.ZERO
	if can_move:
		input = Input.get_vector(&"move_left", &"move_right", &"move_forward", &"move_back")
	var running := can_move and Input.is_action_pressed(&"sprint") and input.length() > 0.1
	var speed := (f.run_speed if running else f.walk_speed) * get_speed_multiplier()
	var dir := Basis(Vector3.UP, camera_rig.yaw) * Vector3(input.x, 0.0, input.y)
	if dir.length() > 1.0:
		dir = dir.normalized()

	var accel := f.acceleration if is_on_floor() else f.acceleration * 0.4
	var hv := Vector3(velocity.x, 0.0, velocity.z).move_toward(dir * speed, accel * delta)
	velocity.x = hv.x
	velocity.z = hv.z
	if not is_on_floor():
		velocity.y -= gravity * delta

	_coyote = coyote_time if is_on_floor() else maxf(_coyote - delta, 0.0)
	if can_move and Input.is_action_just_pressed(&"jump"):
		_jump_buffer = jump_buffer_time
	else:
		_jump_buffer = maxf(_jump_buffer - delta, 0.0)
	if _jump_buffer > 0.0 and _coyote > 0.0:
		velocity.y = f.jump_velocity
		_jump_buffer = 0.0
		_coyote = 0.0

	move_and_slide()

	if can_move and dir.length() > 0.1:
		_facing_yaw = lerp_angle(_facing_yaw, atan2(-dir.x, -dir.z), minf(1.0, turn_speed * delta))
	visual.rotation.y = _facing_yaw
	visual.animate(hv.length(), is_on_floor(), delta)
	var grabbing := state.mode == PlayerState.Mode.FEEDING
	visual.body.rotation.x = lerpf(visual.body.rotation.x, -0.3 if grabbing else 0.0, minf(1.0, 8.0 * delta))
	if grabbing:
		visual.set_arms_forward(1.0)
