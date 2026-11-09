extends GutTest

const STEP := 1.0 / 60.0

var motor: PlayerMotor
var config: Dictionary


func before_each() -> void:
	config = Tuning.section("player")
	motor = PlayerMotor.new(config)


func test_gravity_accelerates_a_fall() -> void:
	var result: Vector2 = motor.step(Vector2.ZERO, 0.0, false, false, false, 0.1)
	assert_almost_eq(result.y, float(config["gravity"]) * 0.1, 0.01)


func test_fall_speed_is_capped() -> void:
	var fast := Vector2(0.0, 5000.0)
	var result: Vector2 = motor.step(fast, 0.0, false, false, false, STEP)
	assert_eq(result.y, float(config["max_fall_speed"]))


func test_walk_reaches_exactly_walk_speed() -> void:
	var velocity := Vector2.ZERO
	for i: int in range(120):
		velocity = motor.step(velocity, 1.0, true, false, false, STEP)
	assert_almost_eq(velocity.x, 220.0, 0.01)


func test_partial_stick_walks_proportionally() -> void:
	var velocity := Vector2.ZERO
	for i: int in range(120):
		velocity = motor.step(velocity, 0.5, true, false, false, STEP)
	assert_almost_eq(velocity.x, 110.0, 0.01)


func test_crouch_slows_walking() -> void:
	var velocity := Vector2.ZERO
	for i: int in range(120):
		velocity = motor.step(velocity, 1.0, true, false, true, STEP)
	assert_almost_eq(velocity.x, 220.0 * float(config["crouch_speed_factor"]), 0.01)


func test_jet_adds_force_on_top_of_gravity() -> void:
	var result: Vector2 = motor.step(Vector2.ZERO, 0.0, false, true, false, STEP)
	assert_almost_eq(result.y, (980.0 - 1400.0) * STEP, 0.001)


func test_jet_caps_at_360_upward() -> void:
	var velocity := Vector2.ZERO
	for i: int in range(240):
		velocity = motor.step(velocity, 0.0, false, true, false, STEP)
	assert_almost_eq(velocity.y, -360.0, 0.01)


func test_jet_does_not_clamp_when_not_thrusting() -> void:
	var launched := Vector2(0.0, -800.0)
	var result: Vector2 = motor.step(launched, 0.0, false, false, false, STEP)
	assert_lt(result.y, -360.0)
