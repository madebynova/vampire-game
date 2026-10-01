class_name AnimalInteractable
extends Interactable
## The interaction point on a wild animal: only a Vampire can do anything with it - feed.

var animal: Animal


func is_available(actor: Player) -> bool:
	return animal != null and actor.form.current.can_feed and animal.can_be_fed()


func get_prompt(_actor: Player) -> String:
	var kind := animal.profile.species
	match animal.mode:
		Animal.Mode.FLEE, Animal.Mode.ALERT:
			return "Seize the %s" % kind
		Animal.Mode.SLEEPING:
			return "Feed on the sleeping %s" % kind
	return "Feed on the %s" % kind


func get_action(_actor: Player) -> StringName:
	return &"feed"


func get_hold_time(_actor: Player) -> float:
	match animal.mode:
		Animal.Mode.FLEE, Animal.Mode.ALERT:
			return 0.25   # a lunge
		Animal.Mode.SLEEPING:
			return 0.5
	return 0.4


func interact(actor: Player) -> void:
	actor.feeding.start(animal)
	super.interact(actor)
