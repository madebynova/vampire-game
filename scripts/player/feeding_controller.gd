class_name FeedingController
extends PlayerComponent
## The feeding action: seize -> hold -> drink -> memory. Player must keep holding interact.
## Letting go early wrenches the victim free (terrified, no memory). Finishing leaves them
## unconscious (alive) and hands the player what the blood remembers.

signal feed_started(npc: HumanNpc)
signal feed_progress(progress: float)
signal feed_completed(npc: HumanNpc, result: Dictionary)
signal feed_interrupted(npc: HumanNpc, progress: float)

@export var duration := 3.6
@export var min_hold := 0.35

var target: HumanNpc
var progress := 0.0
var _elapsed := 0.0
var _yield_per_sec := 0.0


func _on_setup() -> void:
	player.health.died.connect(func(_c): _abort())


func is_feeding() -> bool:
	return target != null


func can_feed(npc: HumanNpc) -> bool:
	return target == null and player.form.current.can_feed and npc.can_be_fed() and player.state.can_act()


func start(npc: HumanNpc) -> void:
	if not can_feed(npc):
		return
	target = npc
	progress = 0.0
	_elapsed = 0.0
	player.state.set_mode(PlayerState.Mode.FEEDING)
	npc.begin_feed(player)
	_yield_per_sec = npc.get_feed_result()["yield"] / duration

	var away := player.global_position - npc.global_position
	away.y = 0.0
	away = away.normalized() if away.length() > 0.05 else Vector3.BACK
	var stand := npc.global_position + away * 0.85
	create_tween().tween_property(player, "global_position", Vector3(stand.x, player.global_position.y, stand.z), 0.2)
	player.face_toward(npc.global_position)
	player.camera_rig.set_focus(npc.global_position + Vector3(0, 1.45, 0), 2.3, 56.0)
	player.camera_rig.add_shake(0.05)
	Sfx.play(&"bite")
	Sfx.start_loop(&"feed_loop", -6.0)
	feed_started.emit(npc)


func _process(delta: float) -> void:
	if target == null:
		return
	_elapsed += delta
	if _elapsed > min_hold and not Input.is_action_pressed(&"interact"):
		_interrupt()
		return
	progress = minf(progress + delta / duration, 1.0)
	player.blood.add(_yield_per_sec * delta)
	target.feed_tick(progress)
	if target.was_afraid_when_grabbed:
		player.camera_rig.add_shake(0.012)
	feed_progress.emit(progress)
	if progress >= 1.0:
		_complete()


func _complete() -> void:
	var npc := target
	var result := npc.finish_feed()
	_end()
	Sfx.play(&"feed_end", -2.0)
	player.state.set_mode(PlayerState.Mode.NORMAL)
	if npc.profile.reveals_secret != &"":
		get_tree().call_group(&"secrets", &"reveal", npc.profile.reveals_secret)
	feed_completed.emit(npc, result)


func _interrupt() -> void:
	var npc := target
	var p := progress
	npc.interrupt_feed()
	_end()
	player.state.set_mode(PlayerState.Mode.NORMAL)
	feed_interrupted.emit(npc, p)


## Player died mid-feed: clean up without touching state (it is already DEAD).
func _abort() -> void:
	if target == null:
		return
	target.interrupt_feed()
	_end()


func _end() -> void:
	target = null
	Sfx.stop_loop(&"feed_loop")
	player.camera_rig.clear_focus()
