extends GutTest

const STEP := 1.0 / 60.0

var tank: FuelTank


func before_each() -> void:
	tank = FuelTank.new({
		"capacity": 100.0,
		"drain_per_second": 35.0,
		"refill_per_second": 50.0,
		"refill_delay": 0.5,
	})


func _run(seconds: float, wants_thrust: bool, on_floor: bool) -> void:
	for i: int in range(roundi(seconds / STEP)):
		tank.update(STEP, wants_thrust, on_floor)


func test_starts_full() -> void:
	assert_eq(tank.amount, 100.0)


func test_thrust_drains_35_per_second() -> void:
	_run(1.0, true, false)
	assert_almost_eq(tank.amount, 65.0, 0.01)


func test_reports_thrust_while_fuel_remains() -> void:
	assert_true(tank.update(STEP, true, false))


func test_empties_after_expected_time_and_stops_thrust() -> void:
	_run(100.0 / 35.0 + STEP, true, false)
	assert_eq(tank.amount, 0.0)
	assert_false(tank.update(STEP, true, false))


func test_no_refill_in_the_air() -> void:
	_run(1.0, true, false)
	_run(2.0, false, false)
	assert_almost_eq(tank.amount, 65.0, 0.01)


func test_no_refill_during_delay() -> void:
	_run(1.0, true, false)
	_run(0.4, false, true)
	assert_almost_eq(tank.amount, 65.0, 0.01)


func test_refills_50_per_second_after_delay() -> void:
	_run(2.0, true, false)
	var before: float = tank.amount
	_run(0.5, false, true)
	_run(0.5, false, true)
	assert_almost_eq(tank.amount, before + 25.0, 1.0)


func test_refill_stops_at_capacity() -> void:
	_run(0.5, true, false)
	_run(5.0, false, true)
	assert_eq(tank.amount, 100.0)


func test_leaving_the_ground_restarts_delay() -> void:
	_run(1.0, true, false)
	_run(0.4, false, true)
	_run(0.1, false, false)
	_run(0.4, false, true)
	assert_almost_eq(tank.amount, 65.0, 0.01)


func test_holding_jet_on_empty_tank_does_not_refill() -> void:
	_run(100.0 / 35.0 + STEP, true, false)
	_run(2.0, true, true)
	assert_eq(tank.amount, 0.0)
