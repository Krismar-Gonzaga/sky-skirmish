extends GutTest
## Runs a real Player through real physics on the test map.

const ScriptedInputProvider := preload("res://tests/helpers/ScriptedInputProvider.gd")
const MapScene := preload("res://scenes/maps/TestMap.tscn")
const PlayerScene := preload("res://scenes/game/Player.tscn")

const TILE := 32.0
const FLOOR_Y := 36.0 * TILE

var map: GameMap
var player: Player
var script_input: ScriptedInputProvider


func before_each() -> void:
	map = MapScene.instantiate() as GameMap
	add_child_autofree(map)
	script_input = ScriptedInputProvider.new()
	add_child_autofree(script_input)
	player = PlayerScene.instantiate() as Player
	add_child_autofree(player)
	player.input_provider = script_input
	player.global_position = map.spawn_points[0]


func _place_at_tile_column(column: float) -> void:
	player.global_position = Vector2((column + 0.5) * TILE, FLOOR_Y)


func test_only_exposed_solid_tiles_use_surface_art() -> void:
	var solid: TileMapLayer = map.get_node("Solid") as TileMapLayer
	assert_eq(solid.get_cell_source_id(Vector2i(10, 36)), GameMap.SURFACE_SOURCE)
	assert_eq(solid.get_cell_source_id(Vector2i(10, 37)), GameMap.FILL_SOURCE)


func test_bounds_include_the_border() -> void:
	assert_eq(map.get_bounds().position, Vector2(-12.0, -12.0) * TILE)
	assert_eq(map.get_bounds().size, Vector2(104.0, 64.0) * TILE)


func test_lands_on_solid_ground() -> void:
	player.global_position.y -= 100.0
	await wait_physics_frames(60)
	assert_true(player.is_on_floor())
	assert_almost_eq(player.global_position.y, FLOOR_Y, 2.0)


func test_walks_at_design_speed() -> void:
	await wait_physics_frames(5)
	script_input.input.move.x = 1.0
	await wait_physics_frames(30)
	assert_almost_eq(player.velocity.x, 220.0, 1.0)


func test_jet_climbs_at_capped_speed_and_burns_fuel() -> void:
	await wait_physics_frames(5)
	script_input.input.jet = true
	await wait_physics_frames(70)
	assert_false(player.is_on_floor())
	assert_almost_eq(player.velocity.y, -360.0, 1.0)
	assert_almost_eq(player.fuel.amount, 100.0 - 35.0 * 70.0 / 60.0, 2.0)


func test_rises_through_one_way_platform_and_stands_on_it() -> void:
	_place_at_tile_column(12.0)
	await wait_physics_frames(5)
	script_input.input.jet = true
	await wait_physics_frames(80)
	script_input.input.jet = false
	await wait_physics_frames(90)
	assert_true(player.is_on_floor())
	assert_almost_eq(player.global_position.y, 30.0 * TILE, 2.0)


func test_stays_crouched_under_a_low_ceiling() -> void:
	_place_at_tile_column(28.0)
	await wait_physics_frames(5)
	script_input.input.crouch = true
	script_input.input.move.x = 1.0
	await wait_physics_frames(85)
	assert_gt(player.global_position.x, 31.0 * TILE, "should be inside the tunnel")
	script_input.input.crouch = false
	script_input.input.move.x = 0.0
	await wait_physics_frames(10)
	assert_true(player.is_crouching)


func test_stands_up_in_the_open() -> void:
	await wait_physics_frames(5)
	script_input.input.crouch = true
	await wait_physics_frames(5)
	assert_true(player.is_crouching)
	script_input.input.crouch = false
	await wait_physics_frames(5)
	assert_false(player.is_crouching)


func test_landing_refills_fuel_after_delay() -> void:
	await wait_physics_frames(5)
	script_input.input.jet = true
	await wait_physics_frames(30)
	script_input.input.jet = false
	await wait_physics_frames(60)
	var landed: float = player.fuel.amount
	await wait_physics_frames(60)
	assert_gt(player.fuel.amount, landed)
