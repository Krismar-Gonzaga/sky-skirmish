class_name GameMap
extends Node2D
## Fills the TileMapLayer children from a JSON layout, so maps are editable data
## and tiles stay swappable through AssetMap.

enum Collision { NONE, SOLID, ONE_WAY }

const FILL_SOURCE := 0
const SURFACE_SOURCE := 1
const NO_TILE := -1
## Crates and packs float this far above the surface they sit on.
const PICKUP_HEIGHT := 22.0

@export_file("*.json") var layout_path: String = ""

var spawn_points: Array[Vector2] = []
## Each entry: {"position": Vector2, "weapon": String}. Empty weapon means random.
var crates: Array[Dictionary] = []
var health_packs: Array[Vector2] = []

var _tile_size: int = 0
var _size_in_tiles: Vector2i = Vector2i.ZERO
var _border_tiles: int = 0

@onready var _decor: TileMapLayer = $Decor
@onready var _solid: TileMapLayer = $Solid
@onready var _one_way: TileMapLayer = $OneWay


func _ready() -> void:
	var layout: Dictionary = DataFile.load_dictionary(layout_path)
	if layout.is_empty():
		return
	_tile_size = int(layout["tile_size"])
	_size_in_tiles = Vector2i(int(layout["size"][0]), int(layout["size"][1]))
	_border_tiles = int(layout.get("border", 0))
	_decor.tile_set = _make_tile_set(["decor"], Collision.NONE)
	_solid.tile_set = _make_tile_set(["solid", "solid_top"], Collision.SOLID)
	_one_way.tile_set = _make_tile_set(["oneway"], Collision.ONE_WAY)
	var layers: Dictionary = {"decor": _decor, "solid": _solid, "oneway": _one_way}
	for rect: Dictionary in layout["rects"]:
		_fill(layers[rect["layer"]], rect)
	_fill_border()
	_apply_surface_tiles()
	_read_points(layout)
	# Collision would otherwise appear a frame late and let the first fall pass through.
	for layer: TileMapLayer in [_decor, _solid, _one_way]:
		layer.update_internals()


## The camera's limits. Includes the border, so a fighter at the map edge stays
## away from the screen corners where the thumb sticks sit.
func get_bounds() -> Rect2:
	var border := Vector2i(_border_tiles, _border_tiles)
	return Rect2(Vector2(-border * _tile_size), Vector2((_size_in_tiles + border * 2) * _tile_size))


func _read_points(layout: Dictionary) -> void:
	for spawn: Array in layout["spawns"]:
		spawn_points.append(_feet_position(_cell(spawn)))
	for crate: Dictionary in layout.get("crates", []):
		crates.append({
			"position": _pickup_position(_cell(crate["cell"])),
			"weapon": crate.get("weapon", ""),
		})
	for pack: Array in layout.get("health_packs", []):
		health_packs.append(_pickup_position(_cell(pack)))


func _cell(pair: Array) -> Vector2i:
	return Vector2i(int(pair[0]), int(pair[1]))


func _fill(layer: TileMapLayer, rect: Dictionary) -> void:
	var left: int = int(rect["x"])
	var top: int = int(rect["y"])
	for x: int in range(left, left + int(rect["w"])):
		for y: int in range(top, top + int(rect["h"])):
			layer.set_cell(Vector2i(x, y), FILL_SOURCE, Vector2i.ZERO)


func _fill_border() -> void:
	var inside := Rect2i(Vector2i.ZERO, _size_in_tiles)
	for x: int in range(-_border_tiles, _size_in_tiles.x + _border_tiles):
		for y: int in range(-_border_tiles, _size_in_tiles.y + _border_tiles):
			if not inside.has_point(Vector2i(x, y)):
				_solid.set_cell(Vector2i(x, y), FILL_SOURCE, Vector2i.ZERO)


func _apply_surface_tiles() -> void:
	for cell: Vector2i in _solid.get_used_cells():
		if _solid.get_cell_source_id(cell + Vector2i.UP) == NO_TILE:
			_solid.set_cell(cell, SURFACE_SOURCE, Vector2i.ZERO)


## A fighter's origin is at the feet, so a spawn stands on the bottom of its cell.
func _feet_position(cell: Vector2i) -> Vector2:
	return Vector2((cell.x + 0.5) * _tile_size, (cell.y + 1.0) * _tile_size)


func _pickup_position(cell: Vector2i) -> Vector2:
	return _feet_position(cell) + Vector2.UP * PICKUP_HEIGHT


## Each key becomes one tile source; the source id is its index in tile_keys.
func _make_tile_set(tile_keys: Array[String], collision: Collision) -> TileSet:
	var tile_set := TileSet.new()
	tile_set.tile_size = Vector2i(_tile_size, _tile_size)
	if collision != Collision.NONE:
		var layer_bit: int = PhysicsLayers.PLATFORMS if collision == Collision.ONE_WAY else PhysicsLayers.WORLD
		tile_set.add_physics_layer()
		tile_set.set_physics_layer_collision_layer(0, layer_bit)
		tile_set.set_physics_layer_collision_mask(0, 0)
	for source_id: int in tile_keys.size():
		var source := TileSetAtlasSource.new()
		source.texture = AssetMap.tile_texture(tile_keys[source_id], _tile_size)
		source.texture_region_size = tile_set.tile_size
		tile_set.add_source(source, source_id)
		source.create_tile(Vector2i.ZERO)
		if collision != Collision.NONE:
			var tile: TileData = source.get_tile_data(Vector2i.ZERO, 0)
			tile.add_collision_polygon(0)
			tile.set_collision_polygon_points(0, 0, _collision_points(collision))
			tile.set_collision_polygon_one_way(0, 0, collision == Collision.ONE_WAY)
	return tile_set


func _collision_points(collision: Collision) -> PackedVector2Array:
	var half: float = _tile_size / 2.0
	var bottom: float = half
	if collision == Collision.ONE_WAY:
		bottom = -half + float(Tuning.section("map")["one_way_thickness"])
	return PackedVector2Array([
		Vector2(-half, -half), Vector2(half, -half),
		Vector2(half, bottom), Vector2(-half, bottom),
	])
