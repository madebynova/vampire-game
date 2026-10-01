class_name AnimalPlacement
extends Resource
## Puts an AnimalProfile (by id) in a location: where it starts, and the den it keeps to.

@export var animal_id: StringName = &""
@export var position := Vector3.ZERO
@export var yaw_degrees := 0.0
## Where it sleeps by day and returns to. Zero = its starting spot.
@export var den_position := Vector3.ZERO
