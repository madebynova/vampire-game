class_name HunterInteractable
extends Interactable
## The interaction point on a hunter: only a Vampire can do anything with him, and only once he is down -
## drink. (Before that he is something to fight, stalk or flee, not something to talk to.)

var hunter: Hunter


func is_available(actor: Player) -> bool:
	return hunter != null and actor.form.current.can_feed and hunter.can_be_fed()


func get_prompt(_actor: Player) -> String:
	return "Drink from the %s" % hunter.profile.title.to_lower()


func get_action(_actor: Player) -> StringName:
	return &"feed"


func get_hold_time(_actor: Player) -> float:
	return 0.5


func interact(actor: Player) -> void:
	actor.feeding.start(hunter)
	super.interact(actor)
