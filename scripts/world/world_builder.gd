class_name WorldBuilder
extends Node3D
## Builds the small greybox test arena from code and places coffin / NPCs / secret.
## All layout numbers live here so tuning is one file. Sun travels roughly toward +Z (south),
## so shade falls south of tall things; the house door faces south into a sunlit yard.
##
##  north (-Z)
##   +----------------------- house (x -8..8, z -16..-6) ----------------------+
##   | crypt + coffin (x -8..-2) | hall (x -2..8), broken roof + north windows |
##   +--------------------------------- door (x 2..4) ------------------------+
##      shaded strip           road            sunlit yard, well, Tomas
##   gatehouse (Elise) far west                trees / graves / ruined wall
##  south (+Z)

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
var location: LocationData
var npcs: Dictionary = {}     ## id -> HumanNpc
var secrets: Dictionary = {}  ## id -> SecretStash
var tomas: HumanNpc
var elise: HumanNpc
var stash: SecretStash        ## the well key (kept for tests/tools)


func _ready() -> void:
	build()


func build() -> void:
	location = ContentRegistry.get_def(&"LocationData", location_id) as LocationData
	assert(location != null, "WorldBuilder: unknown location %s" % location_id)
	_ground()
	_house()
	_gatehouse()
	_yard_props()
	_trees()
	_graveyard()
	_boundary()
	_lamps()
	_actors()


# ---------------------------------------------------------------- terrain

func _ground() -> void:
	Greybox.box(self, Vector3(0, -0.5, 4), Vector3(76, 1, 68), GRASS, Greybox.WORLD, "Ground")
	# Road from the front door south, and a footpath west to the gatehouse.
	Greybox.decal(self, Vector3(3, 0.03, 12), Vector3(3.0, 0.05, 36), DIRT)
	Greybox.decal(self, Vector3(-8, 0.03, 5), Vector3(22, 0.05, 1.6), DIRT)
	Greybox.decal(self, Vector3(3, 0.035, 3), Vector3(7, 0.05, 6), DIRT.darkened(0.1))


func _boundary() -> void:
	var h := 3.2
	Greybox.wall(self, Vector2(-34, -22), Vector2(34, -22), h, 1.0, DARK_STONE)
	Greybox.wall(self, Vector2(-34, 34), Vector2(34, 34), h, 1.0, DARK_STONE)
	Greybox.wall(self, Vector2(-34, -22), Vector2(-34, 34), h, 1.0, DARK_STONE)
	Greybox.wall(self, Vector2(34, -22), Vector2(34, 34), h, 1.0, DARK_STONE)


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
	# Roof with a collapsed section over the hall.
	Greybox.slab_with_hole(self, Rect2(x0 - 0.4, z0 - 0.4, 16.8, 10.8), WALL_H + 0.15, 0.3,
		Rect2(5.5, -15.0, 2.1, 2.2), ROOF)

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


func _omni(pos: Vector3, color: Color, energy: float, rng: float) -> void:
	var l := OmniLight3D.new()
	l.position = pos
	l.light_color = color
	l.light_energy = energy
	l.omni_range = rng
	add_child(l)


# ---------------------------------------------------------------- gatehouse (Elise)

func _gatehouse() -> void:
	var x0 := -27.0
	var x1 := -19.0
	var z0 := 2.0
	var z1 := 9.0
	Greybox.decal(self, Vector3((x0 + x1) * 0.5, 0.04, (z0 + z1) * 0.5), Vector3(8, 0.06, 7), FLOOR)
	var h := 3.0
	Greybox.wall(self, Vector2(x0, z0), Vector2(x1, z0), h, WALL_T, STONE.darkened(0.1))
	Greybox.wall(self, Vector2(x0, z1), Vector2(x1, z1), h, WALL_T, STONE.darkened(0.1))
	Greybox.wall(self, Vector2(x0, z0), Vector2(x0, z1), h, WALL_T, STONE.darkened(0.1))
	Greybox.wall(self, Vector2(x1, z0), Vector2(x1, z1), h, WALL_T, STONE.darkened(0.1), [
		{"at": 2.5, "w": 2.0, "y0": 0.0, "y1": 2.5},
	])
	Greybox.box(self, Vector3((x0 + x1) * 0.5, h + 0.15, (z0 + z1) * 0.5), Vector3(8.8, 0.3, 7.8), ROOF, Greybox.WORLD, "Roof")
	Greybox.box(self, Vector3(-25.2, 0.4, 3.2), Vector3(1.6, 0.8, 0.9), WOOD, Greybox.WORLD, "Bench")
	Greybox.box(self, Vector3(-22.0, 0.35, 8.0), Vector3(0.8, 0.7, 0.8), WOOD, Greybox.WORLD, "Crate")
	_omni(Vector3(-23.5, 2.2, 5.5), Color(1.0, 0.65, 0.35), 0.55, 6.5)


# ---------------------------------------------------------------- yard

func _yard_props() -> void:
	# Well with a little roof (its shade falls south of it).
	var well := Vector3(11.0, 0, 12.0)
	Greybox.cylinder(self, well + Vector3(0, 0.45, 0), 1.0, 0.9, STONE)
	for sx in [-1.0, 1.0]:
		Greybox.box(self, well + Vector3(1.05 * sx, 1.5, 0), Vector3(0.18, 3.0, 0.18), DARK_WOOD, Greybox.WORLD, "WellPost")
	Greybox.box(self, well + Vector3(0, 3.1, 0), Vector3(3.0, 0.25, 2.6), ROOF, Greybox.WORLD, "WellRoof")

	# Tomas' handcart.
	Greybox.box(self, Vector3(4.6, 0.7, 9.6), Vector3(2.0, 0.6, 1.1), WOOD, Greybox.WORLD, "Cart")
	Greybox.cylinder(self, Vector3(4.6, 0.4, 10.2), 0.4, 0.1, DARK_WOOD, Greybox.WORLD).rotation.z = PI * 0.5
	Greybox.cylinder(self, Vector3(4.6, 0.4, 9.0), 0.4, 0.1, DARK_WOOD, Greybox.WORLD).rotation.z = PI * 0.5

	# Ruined wall east of the well: a shade pocket to escape into.
	Greybox.wall(self, Vector2(14, 11), Vector2(22, 11), 2.6, 0.6, DARK_STONE)
	Greybox.wall(self, Vector2(14, 11), Vector2(14, 8.5), 2.0, 0.6, DARK_STONE)

	# Low garden wall south.
	Greybox.wall(self, Vector2(-8, 21), Vector2(4, 21), 1.2, 0.5, STONE)
	# A couple of boulders to break up the yard.
	Greybox.box(self, Vector3(-4.5, 0.6, 12.5), Vector3(1.6, 1.2, 1.4), DARK_STONE, Greybox.WORLD, "Boulder")
	Greybox.box(self, Vector3(16.5, 0.7, 20.0), Vector3(2.2, 1.4, 1.8), DARK_STONE, Greybox.WORLD, "Boulder")


func _trees() -> void:
	var pines := [
		Vector3(3.0, 0, 5.0), Vector3(-13.0, 0, 8.0), Vector3(-16.0, 0, 13.0), Vector3(-9.0, 0, 15.0),
		Vector3(-6.0, 0, 3.0), Vector3(24.0, 0, 4.0), Vector3(26.0, 0, 10.0), Vector3(22.0, 0, 17.0),
		Vector3(29.0, 0, -3.0), Vector3(-26.0, 0, 18.0), Vector3(-20.0, 0, 24.0), Vector3(12.0, 0, 26.0),
		Vector3(0.0, 0, 27.0), Vector3(-30.0, 0, 8.0), Vector3(30.0, 0, 22.0), Vector3(-2.0, 0, 30.0),
	]
	var heights := [6.5, 7.0, 6.0, 6.5, 5.5, 7.0, 6.5, 6.0, 7.5, 6.5, 7.0, 6.5, 6.0, 7.0, 6.5, 6.0]
	for i in pines.size():
		_pine(pines[i], heights[i])


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
	for sp in location.secrets:
		var st := STASH_SCENE.instantiate() as SecretStash
		st.placement = sp
		st.position = sp.position
		add_child(st)
		secrets[sp.secret_id] = st
	stash = secrets.get(&"well_key")


func _spawn_npc(profile: NpcProfile, pos: Vector3, yaw_degrees: float) -> HumanNpc:
	var npc := NPC_SCENE.instantiate() as HumanNpc
	npc.profile = profile
	npc.position = pos
	npc.rotation.y = deg_to_rad(yaw_degrees)
	add_child(npc)
	return npc
