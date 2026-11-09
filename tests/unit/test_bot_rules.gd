extends GutTest
## Difficulty numbers, state transitions, navigation and path steering.

const S := BotDecision.State
const STEP_RETREAT := 0.3
const STEP_RECOVER := 0.6

var graph: JetNavGraph
var follower: PathFollower


func before_each() -> void:
	graph = JetNavGraph.new()
	follower = PathFollower.new(Tuning.section("bot_navigation"))


func _next(current: BotDecision.State, ratio: float, has_target: bool, can_shoot: bool) -> BotDecision.State:
	return BotDecision.next_state(current, ratio, has_target, can_shoot, STEP_RETREAT, STEP_RECOVER)


## A 20x20 box with a floor at row 16 (feet stand in row 15).
func _box_cells() -> Dictionary:
	var solid: Dictionary = {}
	for x: int in range(20):
		solid[Vector2i(x, 16)] = true
	return solid


func _feet(x: int, y: int) -> Vector2:
	return Vector2((x + 0.5) * 32.0, (y + 1.0) * 32.0)


func test_difficulty_numbers_match_design() -> void:
	var expected: Dictionary = {
		"easy": [60.0, 15.0, 0.8],
		"normal": [80.0, 10.0, 0.5],
		"hard": [100.0, 6.0, 0.35],
		"expert": [100.0, 3.0, 0.25],
	}
	for difficulty_id: String in expected:
		var row: Array = expected[difficulty_id]
		var stats: Dictionary = Difficulty.stats(difficulty_id)
		assert_eq(float(stats["hp"]), float(row[0]), difficulty_id)
		assert_eq(float(stats["aim_error_degrees"]), float(row[1]), difficulty_id)
		assert_eq(float(stats["reaction_time"]), float(row[2]), difficulty_id)


func test_retreat_threshold_matches_design() -> void:
	assert_eq(float(Tuning.section("bot")["retreat_below"]), 0.3)


func test_no_target_patrols() -> void:
	assert_eq(_next(S.PATROL, 1.0, false, false), S.PATROL)


func test_known_target_out_of_reach_is_chased() -> void:
	assert_eq(_next(S.PATROL, 1.0, true, false), S.CHASE)


func test_target_in_reach_is_attacked() -> void:
	assert_eq(_next(S.CHASE, 1.0, true, true), S.ATTACK)


func test_low_health_retreats_from_any_state() -> void:
	for state: BotDecision.State in [S.PATROL, S.CHASE, S.ATTACK]:
		assert_eq(_next(state, 0.2, true, true), S.RETREAT)


func test_retreat_lasts_until_recovered() -> void:
	assert_eq(_next(S.RETREAT, 0.45, true, true), S.RETREAT)
	assert_eq(_next(S.RETREAT, 0.65, true, true), S.ATTACK)


func test_path_crosses_open_ground() -> void:
	graph.build(Vector2i(20, 20), _box_cells(), {}, 32)
	var path: PackedVector2Array = graph.find_path(_feet(2, 15), _feet(15, 15))
	assert_gt(path.size(), 1)
	assert_eq(path[path.size() - 1], _feet(15, 15))


func test_path_goes_around_a_wall() -> void:
	var solid: Dictionary = _box_cells()
	for y: int in range(8, 16):
		solid[Vector2i(10, y)] = true
	graph.build(Vector2i(20, 20), solid, {}, 32)
	var path: PackedVector2Array = graph.find_path(_feet(5, 15), _feet(15, 15))
	var highest: float = INF
	for point: Vector2 in path:
		highest = minf(highest, point.y)
	assert_gt(path.size(), 1)
	assert_lte(highest, 8.0 * 32.0, "must rise over the wall")


func test_low_gap_is_not_routed_through() -> void:
	var solid: Dictionary = _box_cells()
	for y: int in range(0, 14):
		solid[Vector2i(10, y)] = true
	graph.build(Vector2i(20, 20), solid, {}, 32)
	var path: PackedVector2Array = graph.find_path(_feet(5, 15), _feet(15, 15))
	assert_eq(path.size(), 0, "a two-tile gap cannot fit a standing fighter")


func test_can_fly_up_through_a_one_way_platform() -> void:
	var one_way: Dictionary = {}
	for x: int in range(0, 20):
		one_way[Vector2i(x, 10)] = true
	graph.build(Vector2i(20, 20), _box_cells(), one_way, 32)
	assert_gt(graph.find_path(_feet(5, 15), _feet(5, 9)).size(), 1)


func test_cannot_drop_down_through_a_one_way_platform() -> void:
	var one_way: Dictionary = {}
	for x: int in range(0, 20):
		one_way[Vector2i(x, 10)] = true
	graph.build(Vector2i(20, 20), _box_cells(), one_way, 32)
	assert_eq(graph.find_path(_feet(5, 9), _feet(5, 15)).size(), 0)


func test_must_walk_off_a_platform_edge_to_descend() -> void:
	var one_way: Dictionary = {}
	for x: int in range(3, 8):
		one_way[Vector2i(x, 10)] = true
	graph.build(Vector2i(20, 20), _box_cells(), one_way, 32)
	var path: PackedVector2Array = graph.find_path(_feet(5, 9), _feet(5, 15))
	assert_gt(path.size(), 1)
	var leaves_platform: bool = false
	for point: Vector2 in path:
		if point.x < 3.0 * 32.0 or point.x >= 8.0 * 32.0:
			leaves_platform = true
	assert_true(leaves_platform)


func test_steers_toward_the_waypoint() -> void:
	follower.set_path(PackedVector2Array([Vector2(500.0, 100.0)]))
	var input := PlayerInput.new()
	follower.steer(Vector2(100.0, 100.0), Vector2.ZERO, true, 1.0, input)
	assert_eq(input.move.x, 1.0)
	assert_false(input.jet, "a level route on the ground should walk")


func test_jets_when_the_waypoint_is_above() -> void:
	follower.set_path(PackedVector2Array([Vector2(100.0, 0.0)]))
	var input := PlayerInput.new()
	follower.steer(Vector2(100.0, 300.0), Vector2.ZERO, true, 1.0, input)
	assert_true(input.jet)


func test_stops_jetting_at_climb_speed() -> void:
	follower.set_path(PackedVector2Array([Vector2(100.0, 0.0)]))
	var input := PlayerInput.new()
	follower.steer(Vector2(100.0, 300.0), Vector2(0.0, -400.0), false, 1.0, input)
	assert_false(input.jet)


func test_rests_on_low_fuel_until_refilled_on_the_ground() -> void:
	follower.set_path(PackedVector2Array([Vector2(100.0, 0.0)]))
	var input := PlayerInput.new()
	follower.steer(Vector2(100.0, 300.0), Vector2.ZERO, false, 0.05, input)
	assert_true(follower.is_resting())
	assert_false(input.jet)
	input = PlayerInput.new()
	follower.steer(Vector2(100.0, 300.0), Vector2.ZERO, false, 1.0, input)
	assert_true(follower.is_resting(), "must land before jetting again")
	input = PlayerInput.new()
	follower.steer(Vector2(100.0, 300.0), Vector2.ZERO, true, 0.6, input)
	assert_true(follower.is_resting(), "a part-full tank cannot reach high platforms")
	input = PlayerInput.new()
	follower.steer(Vector2(100.0, 300.0), Vector2.ZERO, true, 1.0, input)
	assert_false(follower.is_resting())
	assert_true(input.jet)


func test_counts_finished_routes_once() -> void:
	follower.set_path(PackedVector2Array([Vector2(100.0, 100.0)]))
	follower.steer(Vector2(100.0, 100.0), Vector2.ZERO, true, 1.0, PlayerInput.new())
	follower.steer(Vector2(100.0, 100.0), Vector2.ZERO, true, 1.0, PlayerInput.new())
	assert_eq(follower.routes_finished, 1)
