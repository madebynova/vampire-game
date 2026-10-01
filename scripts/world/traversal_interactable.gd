class_name TraversalInteractable
extends Interactable
## One end of a TraversalLink. Offered only when the route can really be taken FROM THIS END right now
## (TraversalController.problem): a Human never sees it (the route does not exist for them), and a
## vampire sees it only on the right level, on the right side of the wall, facing it - so "in" is never
## confused with "out", and a roof never offers the room below.

var link: TraversalLink
var end := 0


func is_available(actor: Player) -> bool:
	return link != null and actor.traversal.can_start(link, end)


func get_prompt(_actor: Player) -> String:
	var p := link.placement
	return p.prompt_a if end == 0 else p.prompt_b


func interact(actor: Player) -> void:
	actor.traversal.start(link, end)
	super.interact(actor)
