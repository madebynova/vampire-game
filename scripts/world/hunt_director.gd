class_name HuntDirector
extends Node
## The hunt, as little machinery as will do. There is no quest log and no stored progress: the objective is read
## off the world. Which state it is in is worked out from the hunter (away, on his round, hunting you, searching,
## down, dead) and from whether you have ever laid eyes on him; what you are told is one line under the clock
## (HuntDefinition), plus the latest thing you have learned about him. The clues are not steps - they are
## facts that were already in the world (a clue read, a thing a villager said), and the hunt just notices.
##
## It also gives the night one more voice: when the hunter is near, the crickets go quiet.

enum Stage { RUMOR, SIGHTED, ENGAGED, WARY, DOWN, DONE, WITHDRAWN }

signal stage_changed(new_stage: Stage, old_stage: Stage)
signal clue_learned(clue: HuntClue)
signal objective_changed(title: String, text: String, clue: String)

var definition: HuntDefinition
var hunter: Hunter
var stage: Stage = Stage.RUMOR
## The player has laid eyes on the quarry (seen him, or sensed him), this game.
var sighted := false

var _player: Player
var _world: WorldBuilder
var _hud: Hud
var _timer := 0.0
var _clue_order: Array[StringName] = []
var _last_text := ""
var _last_clue := ""
var _was_up := false


func setup(player: Player, world: WorldBuilder, hud: Hud) -> void:
	_player = player
	_world = world
	_hud = hud
	add_to_group(&"hunt")
	definition = _pick_definition()
	if definition == null:
		return
	for h in world.hunters:
		if h.profile.id == definition.hunter_id:
			hunter = h
	if hunter != null:
		hunter.state_changed.connect(_on_hunter_state)
	_refresh(true)


func _pick_definition() -> HuntDefinition:
	for d in ContentRegistry.list(&"HuntDefinition"):
		for h in _world.hunters:
			if h.profile.id == d.hunter_id:
				return d
	return null


func active() -> bool:
	return definition != null and hunter != null


# ---------------------------------------------------------------- reading the world

## Where the hunt stands, from the hunter alone (plus whether you have seen him).
func compute_stage() -> Stage:
	if hunter == null:
		return Stage.RUMOR
	match hunter.state:
		Hunter.State.DEAD:
			return Stage.DONE
		Hunter.State.DOWNED, Hunter.State.FEEDING:
			return Stage.DOWN
		Hunter.State.HUNTING:
			return Stage.ENGAGED
		Hunter.State.SEARCHING, Hunter.State.SUSPICIOUS:
			return Stage.WARY
		Hunter.State.AWAY:
			return Stage.WITHDRAWN if sighted else Stage.RUMOR
	return Stage.SIGHTED if sighted else Stage.RUMOR


func clue_known(c: HuntClue) -> bool:
	match c.kind:
		HuntClue.Kind.INSPECT:
			return Inspectable.read_ids.has(c.ref)
		HuntClue.Kind.TIDING:
			for npc_id in HumanNpc.heard:
				if HumanNpc.heard[npc_id].has(c.ref):
					return true
	return false


func clues_known() -> int:
	var n := 0
	if definition != null:
		for c in definition.clues:
			if clue_known(c):
				n += 1
	return n


func clue_count() -> int:
	return definition.clues.size() if definition != null else 0


## The most recently learned clue's text ("" if none).
func latest_clue() -> String:
	if definition == null:
		return ""
	for i in range(_clue_order.size() - 1, -1, -1):
		for c in definition.clues:
			if c.id == _clue_order[i]:
				return c.text
	return ""


func objective_title() -> String:
	return definition.title if definition != null else ""


func objective_text() -> String:
	if definition == null:
		return ""
	match stage:
		Stage.SIGHTED:
			return definition.text_sighted
		Stage.ENGAGED:
			return definition.text_engaged
		Stage.WARY:
			return definition.text_wary
		Stage.DOWN:
			return definition.text_down
		Stage.DONE:
			return definition.text_done
		Stage.WITHDRAWN:
			return definition.text_withdrawn
	return definition.text_rumor


# ---------------------------------------------------------------- upkeep

func _process(delta: float) -> void:
	if not active():
		return
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = 0.25
	_refresh(false)


func _refresh(first: bool) -> void:
	# New leads.
	for c in definition.clues:
		if not _clue_order.has(c.id) and clue_known(c):
			_clue_order.append(c.id)
			if not first:
				clue_learned.emit(c)
				Sfx.play(&"secret", -10.0)
			if c.id == &"journal" and hunter != null:
				hunter.known = true
	_check_sighted()
	var s := compute_stage()
	if s != stage:
		var old := stage
		stage = s
		_announce(old, s)
		stage_changed.emit(s, old)
	var text := objective_text()
	var clue := ""
	if stage == Stage.RUMOR or stage == Stage.WITHDRAWN:
		clue = latest_clue()
	if text != _last_text or clue != _last_clue:
		_last_text = text
		_last_clue = clue
		objective_changed.emit(objective_title(), text, clue)
		if _hud != null:
			_hud.set_objective(objective_title(), text, clue, clues_known(), clue_count())


## Has the player laid eyes on him? In plain view and lit enough to see, or felt through Sense.
func _check_sighted() -> void:
	if sighted or hunter == null or _player == null or not hunter.is_up():
		return
	var d := hunter.global_position.distance_to(_player.global_position)
	var sense := _player.abilities.get_ability(&"vampiric_sense") as VampiricSense
	if sense != null and sense.active and d <= minf(sense.sense_range, hunter.profile.sense_range) - 2.0:
		_sight()
		return
	if d <= 20.0 and _player.camera_rig.camera.is_position_in_frustum(hunter.global_position + Vector3(0, 1.2, 0)):
		var q := PhysicsRayQueryParameters3D.create(_player.camera_rig.camera.global_position, hunter.global_position + Vector3(0, 1.4, 0), Greybox.WORLD)
		if _player.get_world_3d().direct_space_state.intersect_ray(q).is_empty():
			_sight()


func _sight() -> void:
	sighted = true
	if _hud != null:
		_hud.toast("A hunter. A silver blade at his hip, a lantern in his hand.", UiStyle.GOLD, 4.5)
	Sfx.play(&"secret", -8.0, 0.7)


## Words for the moments that matter, in the voice of the rest of the game's toasts.
func _announce(old: Stage, now: Stage) -> void:
	if _hud == null:
		return
	match now:
		Stage.ENGAGED:
			_hud.toast("He has seen you.", Color(1.0, 0.4, 0.35), 3.0)
		Stage.WARY:
			if old == Stage.ENGAGED:
				_hud.toast("You lose him. He is searching.", Color(1.0, 0.75, 0.45), 3.5)
		Stage.SIGHTED:
			if old == Stage.WARY or old == Stage.ENGAGED:
				_hud.toast("He gives up the search and goes back to his round.", Color(0.85, 0.85, 0.7), 3.5)
		Stage.DOWN:
			_hud.toast("The hunter is down.", UiStyle.GOLD, 4.0)
		Stage.DONE:
			_hud.toast("The lantern goes out. The hunt is over.", UiStyle.GOLD, 6.0)
		Stage.WITHDRAWN:
			if old != Stage.DONE:
				_hud.toast("The hunter withdraws with the dawn. He will be back at dusk.", Color(1.0, 0.8, 0.55), 4.5)


func _on_hunter_state(s: Hunter.State) -> void:
	# Each time he comes out for the night, say where.
	if s == Hunter.State.PATROL and not _was_up and _hud != null and stage != Stage.DONE:
		_hud.toast("A lantern kindles in the pines behind the manor.", Color(1.0, 0.82, 0.55), 5.0)
	_was_up = hunter != null and hunter.is_up()
	_timer = 0.0


# ---------------------------------------------------------------- the night's voice

## 1 when the night is as usual, down toward 0.2 when the hunter is close: the crickets hold their breath.
func night_hush() -> float:
	if hunter == null or _player == null or not hunter.is_up():
		return 1.0
	var d := hunter.global_position.distance_to(_player.global_position)
	return 1.0 - 0.8 * clampf(1.0 - d / 22.0, 0.0, 1.0)
