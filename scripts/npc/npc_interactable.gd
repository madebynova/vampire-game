class_name NpcInteractable
extends Interactable
## One interaction point, two meanings: Human form talks, Vampire form feeds.

@onready var npc: HumanNpc = get_parent() as HumanNpc


func is_available(actor: Player) -> bool:
	var can_feed := actor.form.current.can_feed
	match npc.mode:
		HumanNpc.Mode.DRAINED, HumanNpc.Mode.ENTRANCED:
			return false
		HumanNpc.Mode.FLEEING, HumanNpc.Mode.SLEEPING, HumanNpc.Mode.STUNNED:
			return can_feed  # nobody chats with a runner, a sleeper or someone in shock
	return true


func get_prompt(actor: Player) -> String:
	var who := npc.profile.display_name if npc.known else "the stranger"
	if actor.form.current.can_feed:
		match npc.mode:
			HumanNpc.Mode.FLEEING:
				return "Seize %s" % who
			HumanNpc.Mode.SLEEPING:
				return "Feed on %s (asleep)" % who
		return "Feed on %s" % who
	if npc.mode == HumanNpc.Mode.FOLLOWING:
		return "Talk to %s (send them back to work)" % who
	return "Talk to %s" % who


func get_action(actor: Player) -> StringName:
	return &"feed" if actor.form.current.can_feed else &"interact"


func get_hold_time(actor: Player) -> float:
	if not actor.form.current.can_feed:
		return 0.0
	match npc.mode:
		HumanNpc.Mode.FLEEING:
			return 0.25  # tackling a runner is a quick lunge
		HumanNpc.Mode.STUNNED:
			return 0.3
		HumanNpc.Mode.SLEEPING:
			return 0.6   # slow and careful
	return 0.45


func interact(actor: Player) -> void:
	if actor.form.current.can_feed:
		actor.feeding.start(npc)
	else:
		npc.talk(actor)
	super.interact(actor)
