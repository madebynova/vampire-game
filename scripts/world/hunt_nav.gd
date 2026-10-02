class_name HuntNav
extends RefCounted
## How a hunter finds his way. The world has no navmesh, so a location lists a handful of waypoints (on the
## ground, in doorways, inside rooms) and this links every pair that can walk to one another in a straight
## line - tested against the real geometry with a few rays a body's width apart - then finds routes over the
## result with A*. A route to anywhere is: straight there if the way is clear, otherwise to the nearest
## waypoint you can see, along the graph, and from the waypoint nearest the goal.
##
## Windows are not doors: a ray at knee height hits the wall below the sill, so a hunter has to go round
## through a doorway. That is what makes slipping out of a window a real escape.

## Waypoints further apart than this are not linked directly (the graph stays sparse and the tests quick).
const LINK_RANGE := 14.0
## Half the width of the body that must fit along a link.
const CLEAR_RADIUS := 0.38
## Heights above the waypoint (knee and chest) the rays are cast at.
const HEIGHTS: Array[float] = [0.45, 1.2]
## A route never goes to somewhere this much higher or lower than where it starts (a roof is not on the way).
const MAX_RISE := 1.6

var points: PackedVector3Array
var links := 0

var _astar := AStar3D.new()
var _built := false


func _init(waypoints: PackedVector3Array = PackedVector3Array()) -> void:
	points = waypoints


func is_built() -> bool:
	return _built


## Link the waypoints. Needs the physics space with the world in it (so after the first physics frame).
func build(space: PhysicsDirectSpaceState3D) -> void:
	_astar.clear()
	links = 0
	for i in points.size():
		_astar.add_point(i, points[i])
	for i in points.size():
		for j in range(i + 1, points.size()):
			if points[i].distance_to(points[j]) <= LINK_RANGE and line_clear(space, points[i], points[j]):
				_astar.connect_points(i, j)
				links += 1
	_built = true


## Could a body walk straight from `a` to `b`? Three parallel rays (centre and either shoulder) at knee and
## chest height; any hit on the world blocks it.
static func line_clear(space: PhysicsDirectSpaceState3D, a: Vector3, b: Vector3, radius := CLEAR_RADIUS) -> bool:
	var dir := b - a
	dir.y = 0.0
	var side := Vector3(-dir.z, 0.0, dir.x).normalized() * radius if dir.length() > 0.01 else Vector3.ZERO
	for h in HEIGHTS:
		for s in [-1.0, 0.0, 1.0]:
			var off: Vector3 = side * s
			var q := PhysicsRayQueryParameters3D.create(a + off + Vector3(0, h, 0), b + off + Vector3(0, h, 0), Greybox.WORLD)
			if not space.intersect_ray(q).is_empty():
				return false
	return true


## The waypoint nearest `pos` that can be walked to in a straight line (-1 if none within `max_dist`).
func nearest_visible(space: PhysicsDirectSpaceState3D, pos: Vector3, max_dist := 40.0) -> int:
	var order: Array[int] = []
	for i in points.size():
		if absf(points[i].y - pos.y) <= MAX_RISE and _flat(points[i], pos) <= max_dist:
			order.append(i)
	order.sort_custom(func(x: int, y: int): return _flat(points[x], pos) < _flat(points[y], pos))
	var tried := 0
	for i in order:
		if line_clear(space, pos, points[i]):
			return i
		tried += 1
		if tried >= 10:
			break
	return -1


## Index of the waypoint nearest `pos` on the ground plane, whether or not it can be seen (-1 if there are none).
func nearest_point(pos: Vector3) -> int:
	var best := -1
	var best_d := INF
	for i in points.size():
		var d := _flat(points[i], pos)
		if d < best_d:
			best_d = d
			best = i
	return best


## The places to walk through to get from `from` to `to`, not including `from` and ending at `to`. Empty means
## there is no way on foot.
func path(space: PhysicsDirectSpaceState3D, from: Vector3, to: Vector3) -> PackedVector3Array:
	if absf(to.y - from.y) > MAX_RISE:
		return PackedVector3Array()
	if line_clear(space, from, to):
		return PackedVector3Array([to])
	if not _built:
		return PackedVector3Array()
	var s := nearest_visible(space, from)
	var e := nearest_visible(space, to)
	if s < 0 or e < 0:
		return PackedVector3Array()
	var ids := _astar.get_id_path(s, e)
	if ids.is_empty():
		return PackedVector3Array()
	var out := PackedVector3Array()
	for id in ids:
		out.append(points[id])
	out.append(to)
	# Cut the corner if the second stop is already in plain view.
	while out.size() > 2 and line_clear(space, from, out[1]):
		out.remove_at(0)
	return out


## Total length of a route (for tests and for choosing between two).
static func length_of(from: Vector3, route: PackedVector3Array) -> float:
	var total := 0.0
	var prev := from
	for p in route:
		total += prev.distance_to(p)
		prev = p
	return total


static func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()
