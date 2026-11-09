extends GutTest
## Every campaign map must be playable by fighters and bots.

const PlayerScene := preload("res://scenes/game/Player.tscn")
const BotScene := preload("res://scenes/game/Bot.tscn")
const MAP_IDS: Array[String] = ["outpost", "canyon", "skyforge"]


func _load_map(map_id: String) -> GameMap:
	var map: GameMap = (load(LevelManager.map_scene_path(map_id)) as PackedScene).instantiate() as GameMap
	add_child_autofree(map)
	return map


func _graph_for(map: GameMap) -> JetNavGraph:
	var graph := JetNavGraph.new()
	graph.build(map.size_in_tiles(), map.solid_cells(), map.one_way_cells(), map.tile_size())
	return graph


## Maps share one physics world, so the last one must go before the next loads.
func _unload(map: GameMap) -> void:
	map.queue_free()
	await wait_physics_frames(3, "")


func test_every_map_has_the_content_a_match_needs() -> void:
	for map_id: String in MAP_IDS:
		var map: GameMap = _load_map(map_id)
		assert_gte(map.spawn_points.size(), 8, map_id)
		assert_gte(map.crates.size(), 4, map_id)
		assert_gte(map.health_packs.size(), 2, map_id)


func test_canyon_has_a_capture_zone_with_standing_room() -> void:
	var map: GameMap = _load_map("canyon")
	assert_gt(map.capture_zone.get_area(), 0.0)
	var solid: Dictionary = map.solid_cells()
	var below_zone := Vector2i(45, 28)
	assert_true(solid.has(below_zone), "the arch should be the zone's floor")


func test_fighters_stand_at_every_spawn_point() -> void:
	for map_id: String in MAP_IDS:
		var map: GameMap = _load_map(map_id)
		var fighters: Array[Player] = []
		for spawn: Vector2 in map.spawn_points:
			var fighter: Player = PlayerScene.instantiate() as Player
			add_child_autofree(fighter)
			fighter.global_position = spawn
			fighters.append(fighter)
		await wait_physics_frames(30, "")
		for i: int in range(fighters.size()):
			assert_almost_eq(fighters[i].global_position.y, map.spawn_points[i].y, 3.0,
					"%s spawn %d" % [map_id, i])
			assert_true(fighters[i].is_on_floor(), "%s spawn %d" % [map_id, i])
			fighters[i].queue_free()
		await _unload(map)


func test_every_point_can_be_reached_both_ways() -> void:
	for map_id: String in MAP_IDS:
		var map: GameMap = _load_map(map_id)
		var graph: JetNavGraph = _graph_for(map)
		var home: Vector2 = map.spawn_points[0]
		for point: Vector2 in map.patrol_points():
			assert_gt(graph.find_path(home, point).size(), 0, "%s to %s" % [map_id, point])
			assert_gt(graph.find_path(point, home).size(), 0, "%s from %s" % [map_id, point])


func test_bots_keep_completing_routes_on_every_map() -> void:
	for map_id: String in MAP_IDS:
		var map: GameMap = _load_map(map_id)
		var arena := Arena.new()
		add_child_autofree(arena)
		var context := BotContext.new(map, arena)
		var bots: Array[Bot] = []
		for i: int in range(4):
			var bot: Bot = BotScene.instantiate() as Bot
			arena.add_child(bot)
			bot.global_position = map.spawn_points[i]
			arena.register_fighter(bot)
			bot.setup(context, "normal")
			bots.append(bot)
		await wait_physics_frames(60 * 75, "")
		for i: int in range(bots.size()):
			assert_gte(bots[i].brain.routes_finished(), 2,
					"%s bot %d at %s" % [map_id, i, bots[i].global_position])
		arena.queue_free()
		await _unload(map)
