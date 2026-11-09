class_name JetNavGraph
extends RefCounted
## Where a jetpack fighter can go. Every open tile is a node because a fighter
## can fly anywhere, unlike platformer AI that needs jump links.
## Edges are one-directional across one-way platforms: fly up through, never down.

const NEIGHBOURS: Array[Vector2i] = [
	Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
	Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1),
]
const GROUND_COST := 1.0

var _astar := AStar2D.new()
var _size: Vector2i = Vector2i.ZERO
var _tile_size: int = 0
var _body_rows: int = 0
var _solid: Dictionary = {}
var _one_way: Dictionary = {}


## solid and one_way use Vector2i tile coordinates as keys.
func build(size: Vector2i, solid: Dictionary, one_way: Dictionary, tile_size: int) -> void:
	_size = size
	_solid = solid
	_one_way = one_way
	_tile_size = tile_size
	_body_rows = ceili(float(Tuning.section("player")["stand_height"]) / tile_size)
	_astar.clear()
	_astar.reserve_space(size.x * size.y)
	var config: Dictionary = Tuning.section("bot_navigation")
	for y: int in range(size.y):
		for x: int in range(size.x):
			var cell := Vector2i(x, y)
			if _fits(cell):
				_astar.add_point(_id(cell), _feet_position(cell), _cost(cell, config))
	for point_id: int in _astar.get_point_ids():
		_connect_neighbours(point_id)


## World-space waypoints at feet height, or empty if there is no route.
func find_path(from_feet: Vector2, to_feet: Vector2) -> PackedVector2Array:
	var from_id: int = _nearest_id(from_feet)
	var to_id: int = _nearest_id(to_feet)
	if from_id < 0 or to_id < 0:
		return PackedVector2Array()
	return _astar.get_point_path(from_id, to_id)


func _nearest_id(feet: Vector2) -> int:
	# Feet rest exactly on a tile boundary; the nudge keeps them in the upper cell.
	var cell := Vector2i(floori(feet.x / _tile_size), floori((feet.y - 1.0) / _tile_size))
	var id: int = _id(cell)
	if _fits(cell) and _astar.has_point(id):
		return id
	return _astar.get_closest_point(feet)


func _id(cell: Vector2i) -> int:
	return cell.x + cell.y * _size.x


func _feet_position(cell: Vector2i) -> Vector2:
	return Vector2((cell.x + 0.5) * _tile_size, (cell.y + 1.0) * _tile_size)


## True if a fighter whose feet are in this cell has room for its whole body.
func _fits(cell: Vector2i) -> bool:
	if cell.x < 0 or cell.y < 0 or cell.x >= _size.x or cell.y >= _size.y:
		return false
	for row: int in range(_body_rows):
		if _solid.has(cell + Vector2i.UP * row):
			return false
	return true


func _cost(cell: Vector2i, config: Dictionary) -> float:
	for row: int in range(_body_rows):
		var body_cell: Vector2i = cell + Vector2i.UP * row
		if _solid.has(body_cell + Vector2i.LEFT) or _solid.has(body_cell + Vector2i.RIGHT):
			return config["wall_cost"]
	var below: Vector2i = cell + Vector2i.DOWN
	return GROUND_COST if _solid.has(below) or _one_way.has(below) else float(config["air_cost"])


func _connect_neighbours(point_id: int) -> void:
	var from_cell := Vector2i(point_id % _size.x, floori(float(point_id) / _size.x))
	for step: Vector2i in NEIGHBOURS:
		var to_cell: Vector2i = from_cell + step
		if _can_move(from_cell, step, to_cell):
			_astar.connect_points(point_id, _id(to_cell), false)


func _can_move(from_cell: Vector2i, step: Vector2i, to_cell: Vector2i) -> bool:
	if not _fits(to_cell):
		return false
	if step.y > 0 and _one_way.has(to_cell):
		return false
	if step.x != 0 and step.y != 0:
		# No squeezing diagonally past a corner.
		return _fits(from_cell + Vector2i(step.x, 0)) and _fits(from_cell + Vector2i(0, step.y))
	return true
