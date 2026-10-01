class_name FeedingController
extends PlayerComponent
## The feeding action: seize -> hold -> drink -> memory. The player must keep holding `feed`.
## Letting go early wrenches the victim free (terrified, no memory). Finishing leaves them
## unconscious (alive), hands the player what the blood remembers, and starts a Bloodrush.
##
## How it plays depends on the victim's state (FeedStyle data): a sleeper is quiet and slow and
## gives the richest dream; someone unaware is steady; a terrified victim fights, screams, carries
## further and pays more - and anyone who SEES it, panics.

signal feed_started(npc: FeedSource)
signal feed_progress(progress: float)
signal feed_completed(npc: FeedSource, result: Dictionary)
signal feed_interrupted(npc: FeedSource, progress: float)
## Someone saw (or heard) the feeding and was sent running.
signal witnessed(count: int)

@export var duration := 3.6
@export var min_hold := 0.35
## Kneeling motionless over a victim: skin flushed with blood, no cloak to hide in. Sunlight
## heat is multiplied by this while feeding.
@export var sun_heat_multiplier := 2.0

## How often bystanders are re-checked while feeding (seconds); heard noise accrues per second.
const WITNESS_INTERVAL := 0.6

var target: FeedSource
var progress := 0.0
var style: FeedStyle
## People sent running by this feed so far.
var witness_count := 0
var _elapsed := 0.0
var _duration := 3.6
var _yield_per_sec := 0.0
var _beat_timer := 0.0
var _witness_timer := 0.0


func _on_setup() -> void:
	player.health.died.connect(func(_c): _abort())


func is_feeding() -> bool:
	return target != null


## 0..1: how far the vampire bends over what they are drinking from (a fox on the ground, not a person).
func crouch_amount() -> float:
	return target.feed_crouch() if target != null else 0.0


func can_feed(npc: FeedSource) -> bool:
	return target == null and player.form.current.can_feed and npc.can_be_fed() and player.state.can_act()


func start(npc: FeedSource) -> void:
	if not can_feed(npc):
		return
	target = npc
	progress = 0.0
	_elapsed = 0.0
	_beat_timer = 0.2
	_witness_timer = WITNESS_INTERVAL
	witness_count = 0
	player.state.set_mode(PlayerState.Mode.FEEDING)
	npc.begin_feed(player)
	style = npc.feed_style()
	_duration = npc.feed_seconds() if npc.feed_seconds() > 0.0 else duration
	_yield_per_sec = npc.get_feed_result()["yield"] / _duration

	var away := player.global_position - npc.global_position
	away.y = 0.0
	away = away.normalized() if away.length() > 0.05 else Vector3.BACK
	var stand := npc.global_position + away * npc.feed_stand_distance() + Vector3(away.z, 0.0, -away.x) * npc.feed_stand_side()
	create_tween().tween_property(player, "global_position", Vector3(stand.x, player.global_position.y, stand.z), 0.2)
	player.face_toward(npc.global_position)
	player.camera_rig.set_focus(npc.global_position + Vector3(0, npc.feed_focus_height(), 0), npc.feed_camera_distance(), 56.0, npc.feed_camera_pitch(), npc.feed_camera_yaw())
	player.camera_rig.add_shake(0.05 + style.camera_shake * 3.0)
	player.sunlight.set_heat_modifier(&"feeding", sun_heat_multiplier)
	# The bite and the drinking: hushed over a sleeper, loud over a screamer.
	Sfx.play(&"bite", style.feed_volume_db - 4.0, style.feed_pitch)
	Sfx.start_loop(&"feed_loop", style.feed_volume_db - 6.0)
	Sfx.set_loop_pitch(&"feed_loop", style.feed_pitch)
	Haptics.pulse(0.3, 0.6 * (0.5 + style.haptic_strength), 0.15)
	if style.noise_radius > 0.0:
		# A terrified victim screams: awake people who cannot see it still hear it.
		Sfx.play_at(&"gasp", npc.global_position + Vector3(0, 1.5, 0), 2.0, 0.7)
	_alert_bystanders(1.0)   # the first shriek carries a full second's worth of alarm
	feed_started.emit(npc)


func _process(delta: float) -> void:
	if target == null:
		return
	_elapsed += delta
	if _elapsed > min_hold and not Input.is_action_pressed(&"feed"):
		_interrupt()
		return
	progress = minf(progress + delta / _duration, 1.0)
	player.blood.add(_yield_per_sec * delta)
	target.feed_tick(progress)
	if style.camera_shake > 0.0:
		player.camera_rig.add_shake(style.camera_shake)
	# The feed quickens as you drink: the loop rises in pitch, your heart answers.
	Sfx.set_loop_pitch(&"feed_loop", style.feed_pitch * (1.0 + 0.3 * progress))
	_beat_timer -= delta
	if _beat_timer <= 0.0:
		_beat_timer = 60.0 / maxf(player.blood.pulse_rate(), 40.0)
		_beat()
	_witness_timer -= delta
	if _witness_timer <= 0.0:
		_witness_timer = WITNESS_INTERVAL
		_alert_bystanders(WITNESS_INTERVAL)
	feed_progress.emit(progress)
	if progress >= 1.0:
		_complete()


## One heartbeat of the feed: felt in the audio, the hands, the camera and the edges of the screen.
func _beat() -> void:
	Sfx.play(&"heartbeat_deep", -5.0 + 4.0 * progress, 1.0 + 0.2 * progress)
	Haptics.heartbeat(style.haptic_strength * (0.6 + 0.6 * progress))
	player.camera_rig.kick_fov(1.6, 9.0)
	var fx := get_tree().get_first_node_in_group(&"screen_fx") as ScreenFX
	if fx:
		fx.beat()


## Anyone who could SEE this (within the style's witness radius) panics; anyone who could
## only HEAR it (terrified victims are loud) is alarmed. Runs at the start and every ~0.6 s, so
## someone strolling into view mid-feed still counts.
func _alert_bystanders(interval: float) -> void:
	if target == null or style == null:
		return
	var fled := 0
	for n in get_tree().get_nodes_in_group(&"npcs"):
		var other := n as HumanNpc
		if other == null or other == target:
			continue
		if style.witness_radius > 0.0 and other.perceive_vampiric_act(target.global_position, 1.0, style.witness_radius, true):
			fled += 1
		elif style.noise_radius > 0.0 and other.perceive_vampiric_act(target.global_position, style.noise_alarm * interval, style.noise_radius, false):
			fled += 1
	if fled > 0:
		witness_count += fled
		witnessed.emit(fled)


func _complete() -> void:
	var npc := target
	var result := npc.finish_feed()
	var st := style
	_end()
	Sfx.play(&"feed_rush", -2.0)
	Haptics.pulse(0.5, 0.9, 0.4)
	player.camera_rig.kick_fov(9.0, 3.5)
	player.state.set_mode(PlayerState.Mode.NORMAL)
	if result["reveals"] != &"":
		get_tree().call_group(&"secrets", &"reveal", result["reveals"])
	# The reward that is not a number: Bloodrush. Say what it does, so the screen is never a puzzle.
	result["surge_effect"] = player.surge.effect_text(float(result["surge_power"]))
	player.surge.start(float(result["surge_power"]), float(result["surge_seconds"]), String(result["surge_name"]))
	result["witnesses"] = witness_count
	result["style"] = st
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
	player.sunlight.clear_heat_modifier(&"feeding")
	Sfx.stop_loop(&"feed_loop")
	player.camera_rig.clear_focus()
