extends Node
## Autoload: sparing gamepad vibration. Every pulse goes through GameSettings.vibration, so it
## can be switched off in Options. Used at: transformation, feeding heartbeat, Sense pulse,
## strong sunlight damage, low blood. Never continuous.

## Bookkeeping so tests (which run without a pad) can check that a moment asked for feedback.
var pulse_count := 0
var last_weak := 0.0
var last_strong := 0.0
var last_duration := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


## weak = high-frequency motor, strong = low-frequency rumble; both 0..1.
func pulse(weak: float, strong: float, duration := 0.2) -> void:
	if not GameSettings.vibration:
		return
	pulse_count += 1
	last_weak = clampf(weak, 0.0, 1.0)
	last_strong = clampf(strong, 0.0, 1.0)
	last_duration = duration
	for device in Input.get_connected_joypads():
		Input.start_joy_vibration(device, last_weak, last_strong, duration)


## A lub-dub felt in the hands.
func heartbeat(strength := 0.5) -> void:
	pulse(0.0, strength, 0.09)
	get_tree().create_timer(0.17, true, false, true).timeout.connect(func(): pulse(0.0, strength * 0.65, 0.07))


func stop() -> void:
	for device in Input.get_connected_joypads():
		Input.stop_joy_vibration(device)
