class_name FeedSource
extends CharacterBody3D
## Anything the vampire can drink from. FeedingController talks to this interface and nothing else, so a
## new kind of blood (a person, a fox, one day a bat colony or a cellar of casks) is one small class that
## answers these questions - the grab, the camera, the bloodrush, the memory and the HUD all follow.
##
## Humans (HumanNpc) and wild animals (Animal) are the two sources so far. What differs is data:
## FeedStyle (how the feed plays), BloodDefinition (what the blood is like), and the source's own result.

## Can this be fed on right now?
func can_be_fed() -> bool:
	return false


## The vampire has seized it.
func begin_feed(_feeder: Node3D) -> void:
	pass


## Called every frame of the feed with progress 0..1.
func feed_tick(_progress: float) -> void:
	pass


## The feed completed. Returns the result dictionary (see get_feed_result).
func finish_feed() -> Dictionary:
	return {}


## The vampire let go early.
func interrupt_feed() -> void:
	pass


## How this feed plays: sounds, shake, noise, witnesses, the rush and the memory's look.
func feed_style() -> FeedStyle:
	return null


## What the feed gives: name, blood_type, blood_note, yield, surge_name / surge_power / surge_seconds,
## style, and - when there is one to tell - title / memory / facts / reveals / first_time. An empty
## "memory" means there is nothing to experience: the feed is a meal, not a memory.
func get_feed_result() -> Dictionary:
	return {}


## Is it lying down (asleep, drained)? Humans are knelt beside when they lie.
func is_lying() -> bool:
	return false


## Seconds a full feed takes (0 = the controller's default).
func feed_seconds() -> float:
	return 0.0


## Where the feed camera looks (metres above the source's feet), how far it stands back, and how far the
## vampire stands from it.
func feed_focus_height() -> float:
	return 0.9 if is_lying() else 1.45


func feed_camera_distance() -> float:
	return 2.6 if is_lying() else 2.3


func feed_stand_distance() -> float:
	return 1.15 if is_lying() else 0.85


## How far to one side the vampire kneels (metres): beside a creature on the ground rather than over it, so
## the camera can see what is being drunk from.
func feed_stand_side() -> float:
	return 0.0


## How far the feed camera looks down (radians, negative = down): steeper for something on the ground.
func feed_camera_pitch() -> float:
	return -0.16


## How far round to the side of the line to the source the feed camera swings (radians): more shows what the
## vampire's own back would otherwise hide.
func feed_camera_yaw() -> float:
	return 0.45


## 0..1: how far the vampire bends to reach it (a fox on the ground needs more than a person).
func feed_crouch() -> float:
	return 0.0
