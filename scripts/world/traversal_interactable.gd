class_name TraversalInteractable
extends Interactable
## One end of a TraversalLink. Available only to forms allowed to use that kind of route (a Human
## never sees the prompt: the route does not exist for them).

var link: TraversalLink
var end := 0


func is_available(actor: Player) -> bool:
	return link != null and actor.traversal.can_use(link)


func get_prompt(_actor: Player) -> String:
	var p := link.placement
	return p.prompt_a if end == 0 else p.prompt_b


func interact(actor: Player) -> void:
	actor.traversal.start(link, end)
	super.interact(actor)
