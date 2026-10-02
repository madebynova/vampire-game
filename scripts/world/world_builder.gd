class_name WorldBuilder
extends Node3D
## Builds the small greybox test arena from code and places coffin / NPCs / secret.
## All layout numbers live here so tuning is one file. Sun travels roughly toward +Z (south),
## so shade falls south of tall things; the house door faces south into a sunlit yard.
##
##  north (-Z)   (pine line behind the manor)
##   +----------------------- house (x -8..8, z -16..-6) ----------------------+
##   | crypt + coffin (x -8..-2) | hall (x -2..8), broken roof + north windows |
##   +--------------------------------- door (x 2..4) ------------------------+
##      shaded strip      ROAD (x 1.5..4.5) south to the gate        graveyard (NE)
##   gatehouse (Elise)    paths to the well, the cottage (Tomas), the watch hut (Corvin)
##  south (+Z)   iron gate in the south wall, z = 30
##
## Everything here earns its place: buildings are where people live, paths connect them, lamps
## stand where people walk, trees frame the estate and give shade at the edges rather than
## crowding the middle, and each window / ledge that matters is a designated traversal route.

const COFFIN_SCENE := preload("res://scenes/props/coffin.tscn")
const STASH_SCENE := preload("res://scenes/props/secret_stash.tscn")
const HATCH_SCENE := preload("res://scenes/props/cellar_hatch.tscn")
const NPC_SCENE := preload("res://scenes/npc/human_npc.tscn")
@export var location_id: StringName = &"blackthorn"

const GRASS := Color(0.17, 0.23, 0.12)
const DIRT := Color(0.34, 0.27, 0.19)
const STONE := Color(0.48, 0.47, 0.45)
const DARK_STONE := Color(0.3, 0.3, 0.33)
const WOOD := Color(0.32, 0.21, 0.13)
const DARK_WOOD := Color(0.2, 0.13, 0.09)
const ROOF := Color(0.22, 0.17, 0.16)
const FLOOR := Color(0.27, 0.19, 0.14)
const BARK := Color(0.24, 0.16, 0.1)
const LEAF := Color(0.09, 0.22, 0.11)
const WALL_H := 3.6
const WALL_T := 0.4

var coffin: Coffin
var traversal_links: Array[TraversalLink] = []
var tree_positions: Array[Vector3] = []
## Roads and footpaths as XZ rectangles: where people walk (lamps belong beside them, trees do not stand on them).
var walkways: Array[Rect2] = []
var location: LocationData
var npcs: Dictionary = {}     ## id -> HumanNpc
var animals: Array[Animal] = []   ## the wild creatures (foxes), in placement order
var inspectables: Array[Inspectable] = []   ## small things to read
var hunters: Array[Hunter] = []   ## the vampire hunters (away until their hours)
var nav: HuntNav                  ## the waypoint graph hunters walk
var camp_clues: Array[Inspectable] = []   ## what a hunter leaves in his camp
var secrets: Dictionary = {}  ## id -> SecretStash
var tomas: HumanNpc
var elise: HumanNpc
var corvin: HumanNpc
var stash: SecretStash        ## the well key (kept for tests/tools)


func _ready() -> void:
	build()


func build() -> void:
	location = ContentRegistry.get_def(&"LocationData", location_id) as LocationData
	assert(location != null, "WorldBuilder: unknown location %s" % location_id)
	_ground()
	_house()
	_gatehouse()
	_cottage()
	_hut()
	_gate()
	_yard_props()
	_trees()
	_graveyard()
	_boundary()
	_lamps()
	_actors()
	_animals()
	_inspectables()
	_traversals()
	_hunters()


# ---------------------------------------------------------------- terrain

func _ground() -> void:
	Greybox.box(self, Vector3(0, -0.5, 3), Vector3(76, 1, 62), GRASS, Greybox.WORLD, "Ground")
	# The road runs from the manor door to the estate gate; footpaths branch off it to every place
	# somebody lives or visits: the gatehouse, the well, the cottage, the graves, the watch hut.
	_walkway(Vector3(3, 0.03, 11.5), Vector2(3.0, 35), DIRT)
	_walkway(Vector3(3, 0.035, 3), Vector2(7, 6), DIRT.darkened(0.1))
	_walkway(Vector3(-8, 0.03, 5), Vector2(22, 1.6), DIRT)
	_walkway(Vector3(7.0, 0.03, 10.4), Vector2(5, 1.2), DIRT)
	_walkway(Vector3(10.0, 0.03, 18.4), Vector2(11, 1.3), DIRT)
	_walkway(Vector3(11.0, 0.03, 0.2), Vector2(13, 1.2), DIRT)
	_walkway(Vector3(6.3, 0.03, 25.7), Vector2(3.6, 1.4), DIRT)


## A strip of trodden earth, remembered as a walkway.
func _walkway(center: Vector3, size: Vector2, color: Color) -> void:
	Greybox.decal(self, center, Vector3(size.x, 0.05, size.y), color)
	walkways.append(Rect2(center.x - size.x * 0.5, center.z - size.y * 0.5, size.x, size.y))


func _boundary() -> void:
	var h := 3.2
	Greybox.wall(self, Vector2(-34, -22), Vector2(34, -22), h, 1.0, DARK_STONE)
	# South wall, broken by the gate (see _gate).
	Greybox.wall(self, Vector2(-34, 30), Vector2(0.5, 30), h, 1.0, DARK_STONE)
	Greybox.wall(self, Vector2(5.5, 30), Vector2(34, 30), h, 1.0, DARK_STONE)
	Greybox.wall(self, Vector2(-34, -22), Vector2(-34, 30), h, 1.0, DARK_STONE)
	Greybox.wall(self, Vector2(34, -22), Vector2(34, 30), h, 1.0, DARK_STONE)


# ---------------------------------------------------------------- gate

## The estate's iron gate at the end of the road: closed. Pillars, a hung lantern, a name.
func _gate() -> void:
	var z := 30.0
	for sx in [1.0, 5.0]:
		Greybox.box(self, Vector3(sx, 1.8, z), Vector3(1.0, 3.6, 1.0), DARK_STONE, Greybox.WORLD, "GatePillar")
		Greybox.box(self, Vector3(sx, 3.75, z), Vector3(1.35, 0.3, 1.35), STONE, Greybox.WORLD, "GateCap")
	var iron := Color(0.1, 0.1, 0.12)
	Greybox.box(self, Vector3(3, 1.3, z), Vector3(3.0, 2.6, 0.12), iron, Greybox.WORLD, "Gate")
	for i in 5:
		Greybox.box(self, Vector3(1.75 + i * 0.625, 2.75, z - 0.05), Vector3(0.08, 0.5, 0.08), iron, Greybox.SUN_ONLY, "GateSpike")
	var sign_label := Label3D.new()
	sign_label.text = "BLACKTHORN"
	sign_label.font_size = 64
	sign_label.pixel_size = 0.008
	sign_label.outline_size = 10
	sign_label.modulate = Color(0.82, 0.76, 0.62)
	sign_label.outline_modulate = Color(0, 0, 0, 0.9)
	sign_label.position = Vector3(3, 4.5, z - 0.55)
	sign_label.rotation.y = PI   # read from inside the estate, looking out
	add_child(sign_label)
	var lantern := NightLight.new()
	lantern.position = Vector3(3.0, 3.1, z - 0.9)
	lantern.night_energy = 1.3
	lantern.omni_range = 8.0
	lantern.light_color = Color(1.0, 0.72, 0.4)
	lantern.shadow_enabled = false
	add_child(lantern)
	var head := Greybox.box(self, lantern.position, Vector3(0.26, 0.3, 0.26), Color(1.0, 0.75, 0.4), Greybox.SUN_ONLY, "LampHead")
	head.get_child(0).material_override = Greybox.material(Color(1.0, 0.75, 0.4), 1.4)


# ---------------------------------------------------------------- house

func _house() -> void:
	var x0 := -8.0
	var x1 := 8.0
	var z0 := -16.0
	var z1 := -6.0
	Greybox.decal(self, Vector3(0, 0.04, (z0 + z1) * 0.5), Vector3(16, 0.06, 10), FLOOR)
	# North wall: two broken windows in the hall let shafts of sun in.
	Greybox.wall(self, Vector2(x0, z0), Vector2(x1, z0), WALL_H, WALL_T, STONE, [
		{"at": 8.0, "w": 2.0, "y0": 1.0, "y1": 2.6},
		{"at": 13.0, "w": 1.6, "y0": 1.0, "y1": 2.6},
	])
	# South wall: front door (x 2..4) and one window.
	Greybox.wall(self, Vector2(x0, z1), Vector2(x1, z1), WALL_H, WALL_T, STONE, [
		{"at": 10.0, "w": 2.0, "y0": 0.0, "y1": 2.7},
		{"at": 13.6, "w": 1.2, "y0": 1.0, "y1": 2.4},
	])
	Greybox.wall(self, Vector2(x0, z0), Vector2(x0, z1), WALL_H, WALL_T, STONE)
	Greybox.wall(self, Vector2(x1, z0), Vector2(x1, z1), WALL_H, WALL_T, STONE)
	# Partition between crypt and hall, with a doorway.
	Greybox.wall(self, Vector2(-2, z0), Vector2(-2, z1), WALL_H, WALL_T, STONE, [
		{"at": 5.0, "w": 2.0, "y0": 0.0, "y1": 2.6},
	])
	# Roof with a collapsed section over the hall. A low rim of broken stone runs round the hole so nobody
	# walks (or runs, or is carried) off the roof into the room below by accident: it can be jumped over
	# on purpose, or used through the "broken roof" route. The rim stops bodies only; sun rays pass it.
	var hole := Rect2(5.5, -15.0, 2.1, 2.2)
	Greybox.slab_with_hole(self, Rect2(x0 - 0.4, z0 - 0.4, 16.8, 10.8), WALL_H + 0.15, 0.3, hole, ROOF)
	_roof_hole_rim(hole, WALL_H + 0.3)

	# Hall furniture.
	Greybox.box(self, Vector3(2.0, 0.42, -10.6), Vector3(3.6, 0.1, 1.1), DARK_WOOD, Greybox.WORLD, "Table")
	Greybox.box(self, Vector3(0.5, 0.2, -10.6), Vector3(0.12, 0.4, 0.9), DARK_WOOD, Greybox.WORLD, "TableLeg")
	Greybox.box(self, Vector3(3.5, 0.2, -10.6), Vector3(0.12, 0.4, 0.9), DARK_WOOD, Greybox.WORLD, "TableLeg")
	Greybox.box(self, Vector3(6.9, 0.4, -9.2), Vector3(0.9, 0.8, 0.9), WOOD, Greybox.WORLD, "Crate")
	Greybox.box(self, Vector3(6.9, 1.05, -9.2), Vector3(0.6, 0.5, 0.6), WOOD.lightened(0.1), Greybox.WORLD, "Crate")
	Greybox.box(self, Vector3(-0.2, 1.8, -8.0), Vector3(0.5, 3.6, 0.5), STONE.darkened(0.15), Greybox.WORLD, "Pillar")
	Greybox.box(self, Vector3(4.0, 0.9, -15.4), Vector3(2.4, 1.8, 0.5), DARK_WOOD, Greybox.WORLD, "Shelf")
	# Crypt dressing.
	Greybox.box(self, Vector3(-7.4, 0.5, -8.0), Vector3(1.0, 1.0, 1.0), STONE.darkened(0.2), Greybox.WORLD, "Plinth")
	Greybox.box(self, Vector3(-3.0, 0.5, -14.6), Vector3(0.9, 1.0, 0.9), STONE.darkened(0.2), Greybox.WORLD, "Plinth")

	var hatch := HATCH_SCENE.instantiate() as Node3D
	hatch.position = Vector3(5.2, 0.0, -11.3)
	add_child(hatch)

	# Interior lights so humans can still see (a little): a hall lantern, a crypt glow.
	_omni(Vector3(3.0, 2.6, -10.5), Color(1.0, 0.7, 0.4), 0.7, 8.0)
	_omni(Vector3(-5.0, 2.4, -10.0), Color(0.6, 0.25, 0.4), 0.35, 7.0)

	coffin = COFFIN_SCENE.instantiate() as Coffin
	coffin.position = location.coffin_position
	add_child(coffin)


## Four low stone lips standing on the roof around `hole` (XZ), `top` being the roof surface height.
func _roof_hole_rim(hole: Rect2, top: float) -> void:
	var h := 0.45
	var t := 0.18
	var y := top + h * 0.5
	var cx := hole.position.x + hole.size.x * 0.5
	var cz := hole.position.y + hole.size.y * 0.5
	var w := hole.size.x + t * 2.0
	for sz in [-1.0, 1.0]:
		Greybox.box(self, Vector3(cx, y, cz + sz * (hole.size.y * 0.5 + t * 0.5)), Vector3(w, h, t), DARK_STONE, Greybox.PLAYER_ONLY, "RoofRim")
	for sx in [-1.0, 1.0]:
		Greybox.box(self, Vector3(cx + sx * (hole.size.x * 0.5 + t * 0.5), y, cz), Vector3(t, h, hole.size.y), DARK_STONE, Greybox.PLAYER_ONLY, "RoofRim")


func _omni(pos: Vector3, color: Color, energy: float, rng: float) -> void:
	var l := OmniLight3D.new()
	l.position = pos
	l.light_color = color
	l.light_energy = energy
	l.omni_range = rng
	add_child(l)
	WorldLight.register(l)   # a lit room is a lit room to anyone looking in


# ---------------------------------------------------------------- gatehouse (Elise)

func _gatehouse() -> void:
	var x0 := -27.0
	var x1 := -19.0
	var z0 := 2.0
	var z1 := 9.0
	Greybox.decal(self, Vector3((x0 + x1) * 0.5, 0.04, (z0 + z1) * 0.5), Vector3(8, 0.06, 7), FLOOR)
	var h := 3.0
	# A back window above the bench lets a vampire reach a sleeper unseen.
	Greybox.wall(self, Vector2(x0, z0), Vector2(x1, z0), h, WALL_T, STONE.darkened(0.1), [{"at": 3.0, "w": 1.3, "y0": 1.0, "y1": 2.2}])
	Greybox.wall(self, Vector2(x0, z1), Vector2(x1, z1), h, WALL_T, STONE.darkened(0.1))
	Greybox.wall(self, Vector2(x0, z0), Vector2(x0, z1), h, WALL_T, STONE.darkened(0.1))
	Greybox.wall(self, Vector2(x1, z0), Vector2(x1, z1), h, WALL_T, STONE.darkened(0.1), [
		{"at": 2.5, "w": 2.0, "y0": 0.0, "y1": 2.5},
	])
	Greybox.box(self, Vector3((x0 + x1) * 0.5, h + 0.15, (z0 + z1) * 0.5), Vector3(8.8, 0.3, 7.8), ROOF, Greybox.WORLD, "Roof")
	Greybox.box(self, Vector3(-25.2, 0.4, 3.2), Vector3(1.6, 0.8, 0.9), WOOD, Greybox.WORLD, "Bench")
	Greybox.box(self, Vector3(-22.0, 0.35, 8.0), Vector3(0.8, 0.7, 0.8), WOOD, Greybox.WORLD, "Crate")
	_omni(Vector3(-23.5, 2.2, 5.5), Color(1.0, 0.65, 0.35), 0.55, 6.5)


# ---------------------------------------------------------------- cottage (Tomas)

func _cottage() -> void:
	var x0 := 16.0
	var x1 := 24.0
	var z0 := 15.0
	var z1 := 21.0
	var h := 2.8
	var stone := STONE.darkened(0.05)
	Greybox.decal(self, Vector3((x0 + x1) * 0.5, 0.04, (z0 + z1) * 0.5), Vector3(8, 0.06, 6), FLOOR)
	Greybox.wall(self, Vector2(x0, z0), Vector2(x1, z0), h, WALL_T, stone, [{"at": 5.5, "w": 1.2, "y0": 1.0, "y1": 2.0}])
	Greybox.wall(self, Vector2(x0, z1), Vector2(x1, z1), h, WALL_T, stone)
	Greybox.wall(self, Vector2(x1, z0), Vector2(x1, z1), h, WALL_T, stone)
	# Door in the west wall (z 17.4 .. 19.4).
	Greybox.wall(self, Vector2(x0, z0), Vector2(x0, z1), h, WALL_T, stone, [{"at": 2.4, "w": 2.0, "y0": 0.0, "y1": 2.4}])
	Greybox.box(self, Vector3((x0 + x1) * 0.5, h + 0.15, (z0 + z1) * 0.5), Vector3(8.8, 0.3, 6.8), ROOF, Greybox.WORLD, "Roof")
	Greybox.box(self, Vector3(21.8, 0.225, 18.6), Vector3(2.0, 0.45, 0.95), WOOD, Greybox.WORLD, "Bed")
	Greybox.decal(self, Vector3(21.5, 0.5, 18.6), Vector3(1.4, 0.06, 0.85), Color(0.55, 0.2, 0.2))
	Greybox.box(self, Vector3(23.3, 0.4, 16.2), Vector3(1.0, 0.8, 0.7), DARK_WOOD, Greybox.WORLD, "Chest")
	Greybox.box(self, Vector3(19.2, 0.4, 20.2), Vector3(1.4, 0.8, 0.7), WOOD, Greybox.WORLD, "Table")
	var lamp := NightLight.new()
	lamp.position = Vector3(20.0, 2.0, 18.4)
	lamp.day_energy = 0.4
	lamp.night_energy = 1.0
	lamp.omni_range = 6.5
	lamp.light_color = Color(1.0, 0.7, 0.4)
	add_child(lamp)


# ---------------------------------------------------------------- watch hut (Corvin)

## A one-room hut by the gate where the night watchman sleeps through the day.
func _hut() -> void:
	var x0 := 8.0
	var x1 := 14.0
	var z0 := 23.0
	var z1 := 28.0
	var h := 2.6
	var stone := STONE.darkened(0.08)
	Greybox.decal(self, Vector3((x0 + x1) * 0.5, 0.04, (z0 + z1) * 0.5), Vector3(6, 0.06, 5), FLOOR)
	Greybox.wall(self, Vector2(x0, z0), Vector2(x1, z0), h, WALL_T, stone)
	Greybox.wall(self, Vector2(x0, z1), Vector2(x1, z1), h, WALL_T, stone)
	Greybox.wall(self, Vector2(x1, z0), Vector2(x1, z1), h, WALL_T, stone)
	# Door in the west wall, facing the road (z 24.7 .. 26.7).
	Greybox.wall(self, Vector2(x0, z0), Vector2(x0, z1), h, WALL_T, stone, [{"at": 1.7, "w": 2.0, "y0": 0.0, "y1": 2.3}])
	Greybox.box(self, Vector3((x0 + x1) * 0.5, h + 0.15, (z0 + z1) * 0.5), Vector3(6.8, 0.3, 5.8), ROOF, Greybox.WORLD, "Roof")
	Greybox.box(self, Vector3(11.8, 0.225, 26.0), Vector3(2.0, 0.45, 0.95), WOOD, Greybox.WORLD, "Bed")
	Greybox.decal(self, Vector3(11.5, 0.5, 26.0), Vector3(1.4, 0.06, 0.85), Color(0.2, 0.25, 0.42))
	Greybox.box(self, Vector3(9.6, 0.4, 23.9), Vector3(1.2, 0.8, 0.7), DARK_WOOD, Greybox.WORLD, "Table")
	var lamp := NightLight.new()
	lamp.position = Vector3(11.0, 2.0, 25.2)
	lamp.day_energy = 0.3
	lamp.night_energy = 0.9
	lamp.omni_range = 6.0
	lamp.light_color = Color(1.0, 0.7, 0.4)
	add_child(lamp)
	# A bracket lantern beside the door, for the watch.
	var bracket := NightLight.new()
	bracket.position = Vector3(7.5, 2.2, 27.2)
	bracket.night_energy = 1.2
	bracket.omni_range = 7.0
	bracket.light_color = Color(1.0, 0.72, 0.4)
	bracket.shadow_enabled = false
	add_child(bracket)


# ---------------------------------------------------------------- yard

func _yard_props() -> void:
	# Well with a little roof (its shade falls south of it).
	var well := Vector3(11.0, 0, 12.0)
	Greybox.cylinder(self, well + Vector3(0, 0.45, 0), 1.0, 0.9, STONE)
	for sx in [-1.0, 1.0]:
		Greybox.box(self, well + Vector3(1.05 * sx, 1.5, 0), Vector3(0.18, 3.0, 0.18), DARK_WOOD, Greybox.WORLD, "WellPost")
	Greybox.box(self, well + Vector3(0, 3.1, 0), Vector3(3.0, 0.25, 2.6), ROOF, Greybox.WORLD, "WellRoof")

	# Tomas' handcart, parked off the road between the well and the yard.
	Greybox.box(self, Vector3(9.8, 0.7, 6.4), Vector3(2.0, 0.6, 1.1), WOOD, Greybox.WORLD, "Cart")
	Greybox.cylinder(self, Vector3(9.8, 0.4, 7.0), 0.4, 0.1, DARK_WOOD, Greybox.WORLD).rotation.z = PI * 0.5
	Greybox.cylinder(self, Vector3(9.8, 0.4, 5.8), 0.4, 0.1, DARK_WOOD, Greybox.WORLD).rotation.z = PI * 0.5
	# A bench by the well where people stop to talk, and a woodpile by the cottage door.
	Greybox.box(self, Vector3(13.3, 0.25, 13.4), Vector3(1.6, 0.5, 0.45), WOOD, Greybox.WORLD, "Bench")
	Greybox.box(self, Vector3(15.3, 0.28, 20.4), Vector3(0.8, 0.56, 1.5), DARK_WOOD, Greybox.WORLD, "Woodpile")
	Greybox.box(self, Vector3(15.3, 0.7, 20.4), Vector3(0.6, 0.28, 1.3), WOOD, Greybox.WORLD, "Woodpile")

	# Ruined wall east of the well: a shade pocket to escape into.
	Greybox.wall(self, Vector2(14, 11), Vector2(22, 11), 2.6, 0.6, DARK_STONE)
	Greybox.wall(self, Vector2(14, 11), Vector2(14, 8.5), 2.0, 0.6, DARK_STONE)



## Nine trees, each placed for a reason - none on a road or path, none against a building. A dark
## line behind the manor (the silhouette you see from the yard), a pair framing the graves, one behind
## the gatehouse, one beside the cottage, one framing the gate. The middle of the estate stays open.
func _trees() -> void:
	var trees := [
		[Vector3(-2.6, 0, 26.8), 6.5],     # frames the gate from the road
		[Vector3(-16.0, 0, -19.0), 7.0],   # the pine line behind the manor
		[Vector3(-22.0, 0, -15.5), 6.0],
		[Vector3(15.5, 0, -19.0), 6.5],
		[Vector3(25.5, 0, -14.5), 7.5],
		[Vector3(26.8, 0, -0.6), 6.5],     # the graves
		[Vector3(14.6, 0, -3.8), 6.0],
		[Vector3(-31.0, 0, 7.0), 7.0],     # behind the gatehouse
		[Vector3(27.0, 0, 23.0), 6.5],     # beside the cottage
	]
	for t in trees:
		tree_positions.append(t[0])
		_pine(t[0], t[1])


func _pine(base: Vector3, h: float) -> void:
	var trunk_h := h * 0.4
	Greybox.cylinder(self, base + Vector3(0, trunk_h * 0.5, 0), 0.28, trunk_h, BARK)
	Greybox.cone(self, base + Vector3(0, h * 0.2, 0), h * 0.42, h * 0.55, LEAF)
	Greybox.cone(self, base + Vector3(0, h * 0.5, 0), h * 0.3, h * 0.5, LEAF.lightened(0.05))


func _graveyard() -> void:
	var stones := [
		Vector2(17, -1), Vector2(19, -3.5), Vector2(21.5, -1), Vector2(23.5, -3), Vector2(17.5, 3),
		Vector2(19.5, 1.2), Vector2(21.5, 3.2), Vector2(24, 1),
	]
	for i in stones.size():
		var s: Vector2 = stones[i]
		var b := Greybox.box(self, Vector3(s.x, 0.55, s.y), Vector3(0.55, 1.1, 0.16), STONE.darkened(0.1), Greybox.WORLD, "Gravestone")
		b.rotation.y = 0.15 * ((i % 3) - 1)
	# A tall cross casts a long thin shadow.
	Greybox.box(self, Vector3(20.5, 1.4, 0.0), Vector3(0.3, 2.8, 0.3), STONE, Greybox.WORLD, "Cross")
	Greybox.box(self, Vector3(20.5, 2.1, 0.0), Vector3(1.3, 0.3, 0.3), STONE, Greybox.WORLD, "Cross")


# ---------------------------------------------------------------- lamps

func _lamps() -> void:
	for pos in location.lamp_positions:
		Greybox.cylinder(self, pos + Vector3(0, 1.2, 0), 0.07, 2.4, DARK_WOOD)
		Greybox.box(self, pos + Vector3(0, 2.5, 0), Vector3(0.28, 0.32, 0.28), Color(1.0, 0.75, 0.4), Greybox.SUN_ONLY, "LampHead").get_child(0).material_override = Greybox.material(Color(1.0, 0.75, 0.4), 1.4)
		var light := NightLight.new()
		light.position = pos + Vector3(0, 2.4, 0)
		light.night_energy = 1.6
		light.omni_range = 9.0
		light.light_color = Color(1.0, 0.72, 0.4)
		light.shadow_enabled = false
		add_child(light)


# ---------------------------------------------------------------- traversal

func _traversals() -> void:
	for p in location.traversals:
		var link := TraversalLink.new()
		add_child(link)
		link.setup(p)
		traversal_links.append(link)


# ---------------------------------------------------------------- actors

func _actors() -> void:
	for p in location.npcs:
		var profile := ContentRegistry.npc(p.npc_id)
		if profile == null:
			push_warning("Location '%s' references unknown NPC '%s'" % [location.id, p.npc_id])
			continue
		npcs[p.npc_id] = _spawn_npc(profile, p.position, p.yaw_degrees)
	tomas = npcs.get(&"tomas")
	elise = npcs.get(&"elise")
	corvin = npcs.get(&"corvin")
	for sp in location.secrets:
		var st := STASH_SCENE.instantiate() as SecretStash
		st.placement = sp
		st.position = sp.position
		add_child(st)
		secrets[sp.secret_id] = st
	stash = secrets.get(&"well_key")


## The small things worth a look the location lists (see InspectPlacement).
func _inspectables() -> void:
	for p in location.inspectables:
		var it := Inspectable.new()
		it.placement = p
		it.position = p.position
		add_child(it)
		inspectables.append(it)


## The wild creatures the location lists, each at a den: a low mound of earth with a dark mouth, where the
## animal sleeps by day and goes to ground when it is frightened.
func _animals() -> void:
	var dens: Dictionary = {}
	for p in location.animals:
		var profile := ContentRegistry.get_def(&"AnimalProfile", p.animal_id) as AnimalProfile
		if profile == null:
			push_warning("Location '%s' references unknown animal '%s'" % [location.id, p.animal_id])
			continue
		var den: Vector3 = p.den_position if p.den_position != Vector3.ZERO else p.position
		var key := "%.1f/%.1f" % [den.x, den.z]
		if not dens.has(key):
			dens[key] = true
			_den(den)
		var a := Animal.new()
		a.profile = profile
		a.den = den
		a.position = p.position
		a.rotation.y = deg_to_rad(p.yaw_degrees)
		add_child(a)
		animals.append(a)


## A fox den: a half-buried mound and a dark opening (visual only: nothing to bump into).
func _den(pos: Vector3) -> void:
	var mound := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 1.0
	sm.height = 2.0
	mound.mesh = sm
	mound.material_override = Greybox.material(DIRT.darkened(0.25))
	mound.scale = Vector3(1.3, 0.28, 1.1)
	mound.position = pos + Vector3(0, 0.02, 0)
	mound.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mound)
	var mouth := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.5, 0.26, 0.05)
	mouth.mesh = bm
	mouth.material_override = Greybox.material(Color(0.03, 0.02, 0.02))
	mouth.position = pos + Vector3(0.0, 0.14, 0.78)
	mouth.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mouth)


# ---------------------------------------------------------------- hunters

## The vampire hunters the location lists. Each starts unseen at his camp and comes out in his hours.
func _hunters() -> void:
	nav = HuntNav.new(location.nav_points)
	for p in location.hunters:
		var profile := ContentRegistry.get_def(&"HunterProfile", p.hunter_id) as HunterProfile
		if profile == null:
			push_warning("Location '%s' references unknown hunter '%s'" % [location.id, p.hunter_id])
			continue
		var h := Hunter.new()
		h.profile = profile
		h.placement = p
		h.nav = nav
		h.position = p.camp
		add_child(h)
		hunters.append(h)
		if p.build_camp:
			_camp(p)


## A hunter's camp, empty by day: a bedroll, a crate with a journal on it, a cold fire ring, stakes, a lantern
## hung on a post (it burns at night). Two small things to read; they say what the people only hint at.
func _camp(p: HunterPlacement) -> void:
	var c := p.camp
	var canvas := Color(0.2, 0.24, 0.16)
	Greybox.decal(self, c + Vector3(-0.9, 0.06, -0.5), Vector3(1.9, 0.12, 0.75), canvas)
	Greybox.decal(self, c + Vector3(-1.7, 0.13, -0.5), Vector3(0.4, 0.1, 0.5), canvas.lightened(0.25))
	Greybox.box(self, c + Vector3(1.3, 0.35, -1.4), Vector3(0.7, 0.7, 0.7), WOOD, Greybox.WORLD, "CampCrate")
	Greybox.decal(self, c + Vector3(1.3, 0.72, -1.4), Vector3(0.4, 0.04, 0.3), Color(0.8, 0.74, 0.58))
	# A cold fire ring: dark ash inside a circle of stones.
	var ring := c + Vector3(0.4, 0.0, 1.5)
	Greybox.decal(self, ring + Vector3(0, 0.03, 0), Vector3(0.9, 0.05, 0.9), Color(0.07, 0.065, 0.06))
	for i in 7:
		var a := TAU * i / 7.0
		Greybox.decal(self, ring + Vector3(cos(a) * 0.55, 0.1, sin(a) * 0.55), Vector3(0.22, 0.2, 0.22), STONE.darkened(0.15))
	# Ash-wood stakes leaning on the crate.
	for i in 3:
		var stake := Greybox.decal(self, c + Vector3(1.0 + i * 0.12, 0.58, -0.95 - i * 0.05), Vector3(0.05, 1.15, 0.05), Color(0.62, 0.55, 0.4))
		stake.rotation = Vector3(deg_to_rad(-16.0), 0.0, deg_to_rad(8.0 - i * 7.0))
	# The lantern post.
	var post := c + Vector3(2.4, 0.0, 0.9)
	Greybox.cylinder(self, post + Vector3(0, 1.1, 0), 0.06, 2.2, DARK_WOOD)
	Greybox.box(self, post + Vector3(0, 2.3, 0), Vector3(0.26, 0.3, 0.26), Color(1.0, 0.75, 0.4), Greybox.SUN_ONLY, "LampHead").get_child(0).material_override = Greybox.material(Color(1.0, 0.75, 0.4), 1.2)
	var lamp := NightLight.new()
	lamp.position = post + Vector3(0, 2.3, 0)
	lamp.night_energy = 1.0
	lamp.omni_range = 7.0
	lamp.light_color = Color(1.0, 0.72, 0.4)
	lamp.shadow_enabled = false
	add_child(lamp)
	for def in [
		[&"hunter_bedroll", c + Vector3(-0.9, 0.25, -0.5), "Examine the bedroll",
			"A bedroll, warm from no one. Ash-wood stakes sharpened to needle points, a vial of lavender oil, a tin of salt and a single silver nail. The candle stub in the lantern matches the wax under the manor's north window."],
		[&"hunter_journal", c + Vector3(1.3, 0.85, -1.4), "Read the hunter's journal",
			"'Night three. The house breathes at dusk. The lamps along the road gutter one by one, and the watchman counts nine and swears he sees eight. The gate is sealed on the Order's word: nothing leaves Blackthorn. Lavender on my boots, so that it cannot smell me. If it sleeps by day, it sleeps in the house; if it sleeps in the house, it sleeps on the north side. - H.C.'"],
	]:
		var ip := InspectPlacement.new()
		ip.id = def[0]
		ip.position = def[1]
		ip.prompt = def[2]
		ip.text = def[3]
		var it := Inspectable.new()
		it.placement = ip
		it.position = ip.position
		add_child(it)
		camp_clues.append(it)


func _spawn_npc(profile: NpcProfile, pos: Vector3, yaw_degrees: float) -> HumanNpc:
	var npc := NPC_SCENE.instantiate() as HumanNpc
	npc.profile = profile
	npc.position = pos
	npc.rotation.y = deg_to_rad(yaw_degrees)
	add_child(npc)
	return npc
