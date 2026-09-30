class_name NpcInteractable
extends Interactable
## One interaction point, two meanings: Human form talks, Vampire form feeds.

@onready var npc: HumanNpc = get_parent() as HumanNpc


func is_available(actor: Player) -> bool:
	match npc.mode:
		HumanNpc.Mode.DRAINED, HumanNpc.Mode.ENTRANCED:
			return false
		HumanNpc.Mode.FLEEING:
			return actor.form.current.can_feed
	return true


func get_prompt(actor: Player) -> String:
	var who := npc.profile.display_name
	if actor.form.current.can_feed:
		return "Seize %s" % who if npc.mode == HumanNpc.Mode.FLEEING else "Feed on %s" % who
	return "Talk to %s" % who


func get_hold_time(actor: Player) -> float:
	if not actor.form.current.can_feed:
		return 0.0
	# Tackling someone who is already running is a quick lunge; a calm victim takes a moment.
	return 0.25 if npc.mode == HumanNpc.Mode.FLEEING else 0.45


func interact(actor: Player) -> void:
	if actor.form.current.can_feed:
		actor.feeding.start(npc)
	else:
		npc.talk(actor)
	super.interact(actor)
