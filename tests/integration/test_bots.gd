extends GutTest
## Real bots on the test map.

const MapScene := preload("res://scenes/maps/TestMap.tscn")
const PlayerScene := preload("res://scenes/game/Player.tscn")
const BotScene := preload("res://scenes/game/Bot.tscn")

const TILE := 32.0
const FRAMES_PER_SECOND := 60.0
const ARRIVED := 64.0

var map: GameMap
var arena: Arena
var context: BotContext
var shot_errors: Array[float] = []
var first_shot_frame: int = -1


func before_each() -> void:
	map = MapScene.instantiate() as GameMap
	add_child_autofree(map)
	arena = Arena.new()
	add_child_autofree(arena)
	arena._spawn_points = map.spawn_points
	arena.respawn_enabled = false
	context = BotContext.new(map, arena)
	shot_errors = []
	first_shot_frame = -1


func _floor_at(column: float) -> Vector2:
	return Vector2((column + 0.5) * TILE, 36.0 * TILE)


func _add_bot(team: int, at: Vector2, difficulty: String) -> Bot:
	var bot: Bot = BotScene.instantiate() as Bot
	bot.team = team
	arena.add_child(bot)
	bot.global_position = at
	arena.register_fighter(bot)
	bot.setup(context, difficulty)
	return bot


func _add_dummy(team: int, at: Vector2) -> Player:
	var dummy: Player = PlayerScene.instantiate() as Player
	dummy.team = team
	arena.add_child(dummy)
	dummy.global_position = at
	arena.register_fighter(dummy)
	return dummy


func _record_shot(target: Player, origin: Vector2, directions: Array[Vector2]) -> void:
	if first_shot_frame < 0:
		first_shot_frame = Engine.get_physics_frames()
	var true_direction: Vector2 = (target.get_center() - origin).normalized()
	shot_errors.append(absf(true_direction.angle_to(directions[0])))


## Average absolute aim error in radians over a few seconds of shooting.
func _measure_aim(difficulty: String, column: float) -> float:
	var target: Player = _add_dummy(1, _floor_at(column + 5.0))
	target.health.set_maximum(1000000.0)
	var bot: Bot = _add_bot(0, _floor_at(column), difficulty)
	bot.fired.connect(func(_s: Player, _w: Weapon, origin: Vector2, directions: Array[Vector2]) -> void:
		_record_shot(target, origin, directions))
	shot_errors = []
	await wait_physics_frames(int(10.0 * FRAMES_PER_SECOND), "")
	var total: float = 0.0
	for error: float in shot_errors:
		total += error
	assert_gt(shot_errors.size(), 10, "%s should have fired repeatedly" % difficulty)
	arena.unregister_fighter(bot)
	arena.unregister_fighter(target)
	bot.queue_free()
	target.queue_free()
	return total / maxf(shot_errors.size(), 1)


func _seconds_until_first_shot(difficulty: String) -> float:
	var target: Player = _add_dummy(1, _floor_at(11.0))
	target.health.set_maximum(1000000.0)
	var bot: Bot = _add_bot(0, _floor_at(6.0), difficulty)
	bot.fired.connect(func(_s: Player, _w: Weapon, origin: Vector2, directions: Array[Vector2]) -> void:
		_record_shot(target, origin, directions))
	var start_frame: int = Engine.get_physics_frames()
	await wait_physics_frames(180, "")
	return (first_shot_frame - start_frame) / FRAMES_PER_SECOND


func test_hp_comes_from_difficulty() -> void:
	await wait_physics_frames(1, "")
	assert_eq(_add_bot(0, _floor_at(4.0), "easy").health.maximum, 60.0)
	assert_eq(_add_bot(0, _floor_at(5.0), "normal").health.maximum, 80.0)
	assert_eq(_add_bot(0, _floor_at(6.0), "expert").health.maximum, 100.0)


func test_hp_override_makes_a_leader() -> void:
	await wait_physics_frames(1, "")
	var leader: Bot = _add_bot(0, _floor_at(4.0), "hard")
	leader.setup(context, "hard", 300.0)
	assert_eq(leader.health.current, 300.0)


func test_easy_reacts_slower_than_expert() -> void:
	var easy_time: float = await _seconds_until_first_shot("easy")
	assert_gte(easy_time, 0.75, "easy reaction is 0.8 s")
	for child: Node in arena.get_children():
		if child is Player:
			arena.unregister_fighter(child as Player)
			child.queue_free()
	await wait_physics_frames(2, "")
	first_shot_frame = -1
	var expert_time: float = await _seconds_until_first_shot("expert")
	assert_gte(expert_time, 0.2, "expert reaction is 0.25 s")
	assert_lte(expert_time, 0.6)
	assert_gt(easy_time, expert_time + 0.3)


func test_expert_aims_far_better_than_easy() -> void:
	var easy_error: float = await _measure_aim("easy", 6.0)
	var expert_error: float = await _measure_aim("expert", 6.0)
	assert_gt(easy_error, expert_error * 2.0)


func test_expert_beats_easy_in_a_duel() -> void:
	var expert: Bot = _add_bot(0, _floor_at(5.0), "expert")
	var easy: Bot = _add_bot(1, _floor_at(12.0), "easy")
	for i: int in range(int(30.0 * FRAMES_PER_SECOND)):
		if easy.is_dead or expert.is_dead:
			break
		await wait_physics_frames(1, "")
	assert_true(easy.is_dead, "easy should lose")
	assert_false(expert.is_dead, "expert should survive")


func test_chases_a_target_it_cannot_see() -> void:
	var target: Player = _add_dummy(1, _floor_at(24.0))
	target.health.set_maximum(1000000.0)
	var bot: Bot = _add_bot(0, _floor_at(6.0), "normal")
	bot.brain._target = target
	await wait_physics_frames(int(12.0 * FRAMES_PER_SECOND), "")
	# It stops at firing range, so it never needs to reach the target itself.
	assert_gt(bot.global_position.x, 12.0 * TILE, "should have travelled toward the target")


func test_low_health_makes_a_bot_retreat() -> void:
	var target: Player = _add_dummy(1, _floor_at(11.0))
	target.health.set_maximum(1000000.0)
	var bot: Bot = _add_bot(0, _floor_at(6.0), "normal")
	await wait_physics_frames(30, "")
	bot.take_damage(bot.health.maximum * 0.8, target)
	await wait_physics_frames(15, "")
	assert_eq(bot.brain.state, BotDecision.State.RETREAT)
	bot.heal(bot.health.maximum)
	await wait_physics_frames(15, "")
	assert_ne(bot.brain.state, BotDecision.State.RETREAT)


func _assert_reaches(start: Vector2, destination: Vector2, seconds: float) -> void:
	var bot: Bot = _add_bot(0, start, "normal")
	var only_destination: Array[Vector2] = [destination]
	context.patrol_points = only_destination
	var reached: bool = false
	for i: int in range(int(seconds * FRAMES_PER_SECOND)):
		if bot.global_position.distance_to(destination) < ARRIVED:
			reached = true
			break
		await wait_physics_frames(1, "")
	assert_true(reached, "from %s to %s, ended at %s" % [start, destination, bot.global_position])
	arena.unregister_fighter(bot)
	bot.queue_free()


func test_reaches_the_far_side_of_the_map() -> void:
	await _assert_reaches(map.spawn_points[0], map.spawn_points[1], 30.0)


func test_reaches_a_high_platform() -> void:
	await _assert_reaches(map.spawn_points[0], map.spawn_points[3], 25.0)


func test_comes_down_from_a_high_platform() -> void:
	await _assert_reaches(map.spawn_points[3], map.spawn_points[0], 25.0)


func test_crosses_over_the_tunnel_block() -> void:
	await _assert_reaches(_floor_at(26.0), _floor_at(46.0), 25.0)


func test_bots_never_get_permanently_stuck() -> void:
	# One team, so nothing interrupts travel and any stillness means stuck.
	var bots: Array[Bot] = []
	var last_positions: Array[Vector2] = []
	var travelled: Array[float] = []
	var columns: Array[float] = [4.0, 12.0, 24.0, 46.0, 58.0, 72.0]
	for column: float in columns:
		var bot: Bot = _add_bot(0, _floor_at(column), "normal")
		bots.append(bot)
		last_positions.append(bot.global_position)
		travelled.append(0.0)
	var measure := func() -> void:
		for i: int in range(bots.size()):
			if not is_instance_valid(bots[i]):
				return
			travelled[i] += bots[i].global_position.distance_to(last_positions[i])
			last_positions[i] = bots[i].global_position
	get_tree().physics_frame.connect(measure)
	var window_seconds: float = 16.0
	for window: int in range(4):
		await wait_physics_frames(int(window_seconds * FRAMES_PER_SECOND), "")
		for i: int in range(bots.size()):
			assert_gt(travelled[i], 400.0, "bot %d window %d at %s" % [i, window, bots[i].global_position])
			travelled[i] = 0.0
	get_tree().physics_frame.disconnect(measure)
	# A bot circling in place still travels, but it never completes a route.
	for i: int in range(bots.size()):
		assert_gte(bots[i].brain.routes_finished(), 3, "bot %d at %s" % [i, bots[i].global_position])
