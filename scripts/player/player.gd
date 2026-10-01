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
@onready var surge: BloodSurge = $Components/Surge
@onready var traversal: TraversalController = $Components/Traversal
@onready var transform_fx: TransformPresentation = $Components/TransformFx

## Multipliers on movement speed keyed by source (sunlight, hunger, ...).
var speed_modifiers: Dictionary = {}
## Multiplier on the form's jump (Bloodrush).
var jump_multiplier := 1.0

var _coyote := 0.0
var _jump_buffer := 0.0
var _facing_yaw := 0.0
var _run_latched := false
var _latch_idle := 0.0
var _fall_speed := 0.0


func _ready() -> void:
	add_to_group(&"player")
	collision_layer = 2
	collision_mask = 1 | 4 | Greybox.PLAYER_ONLY
	camera_rig.attach(self)
	_setup_components($Components)


func _setup_components(node: Node) -> void:
	for child in node.get_children():
		if child is PlayerComponent:
			child.setup(self)
		_setup_components(child)


## One step of ground (or air) steering: `hv` is the current horizontal velocity, `target` the velocity the
## stick asks for. The speed along the wanted direction rises at `accel`; letting go, easing off or
## reversing sheds speed at the (much higher) `decel`; and any sideways drift left over from the old
## direction is cancelled at `grip`. Plain `move_toward` on the whole vector uses one rate for all of
## it, which is what made turning and stopping feel like skating on ice.
static func steer(hv: Vector3, target: Vector3, accel: float, decel: float, grip: float, delta: float) -> Vector3:
	if target.length() < 0.01:
		return hv.move_toward(Vector3.ZERO, decel * delta)
	var dir := target.normalized()
	var want := target.length()
	var along := hv.dot(dir)
	var lateral := hv - dir * along
	lateral = lateral.move_toward(Vector3.ZERO, grip * delta)
	var rate := decel if (along < 0.0 or along > want) else accel
	along = move_toward(along, want, rate * delta)
	return dir * along + lateral


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


func set_facing(yaw: float) -> void:
	_facing_yaw = yaw
	visual.rotation.y = yaw


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
	interactor.reset_focus()   # whatever was in reach where we were is not in reach here


func _physics_process(delta: float) -> void:
	var can_move := state.can_control_movement()
	var f := form.current
	var input := Vector2.ZERO
	if can_move:
		input = Input.get_vector(&"move_left", &"move_right", &"move_forward", &"move_back")
	var moving := input.length() > 0.1
	# Run: hold the sprint action, or (pad) click the left stick to latch it until you stop moving.
	if can_move and Input.is_action_just_pressed(&"sprint_toggle"):
		_run_latched = not _run_latched
	if _run_latched:
		_latch_idle = 0.0 if moving else _latch_idle + delta
		if _latch_idle > 0.25 or not can_move:
			_run_latched = false
	var running := can_move and moving and (Input.is_action_pressed(&"sprint") or _run_latched)
	if state.mode == PlayerState.Mode.TRAVERSING:
		# The traversal controller moves the body along its own path; nothing else may push it.
		velocity = Vector3.ZERO
		visual.rotation.y = _facing_yaw
		return
	var speed := (f.run_speed if running else f.walk_speed) * get_speed_multiplier()
	var dir := Basis(Vector3.UP, camera_rig.yaw) * Vector3(input.x, 0.0, input.y)
	if dir.length() > 1.0:
		dir = dir.normalized()

	var grounded := is_on_floor()
	var hv := steer(Vector3(velocity.x, 0.0, velocity.z), dir * speed,
		f.acceleration if grounded else f.acceleration * 0.4,
		f.deceleration if grounded else f.deceleration * 0.25,
		f.turn_grip if grounded else f.turn_grip * 0.2, delta)
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
		velocity.y = f.jump_velocity * jump_multiplier
		_jump_buffer = 0.0
		_coyote = 0.0

	_fall_speed = minf(velocity.y, 0.0)
	move_and_slide()
	if is_on_floor() and _fall_speed < -7.0:
		# Landing: a vampire lands like a cat, a human like a person.
		var soft := form.current.sun_vulnerable
		Sfx.play(&"land", -14.0 if soft else -7.0, 1.0 if soft else 0.85)
		_fall_speed = 0.0

	if can_move and dir.length() > 0.1:
		_facing_yaw = lerp_angle(_facing_yaw, atan2(-dir.x, -dir.z), minf(1.0, turn_speed * delta))
	visual.rotation.y = _facing_yaw
	visual.animate(hv.length(), is_on_floor(), delta)
	var grabbing := state.mode == PlayerState.Mode.FEEDING
	var lean := (-0.3 - 0.75 * feeding.crouch_amount()) if grabbing else 0.0
	lean -= 0.32 * visual.pose_amount   # transformation arches the back
	lean = lerpf(lean, PI * 0.5, visual.lying)
	visual.body.rotation.x = lerpf(visual.body.rotation.x, lean, minf(1.0, 8.0 * delta))
	if grabbing:
		visual.set_arms_forward(1.0)
