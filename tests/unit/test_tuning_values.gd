extends GutTest
## Fails if tuning.json drifts from the numbers in docs/DESIGN.md section 3.
## Update both together when playtests change a value.


func test_player_movement_matches_design() -> void:
	var player: Dictionary = Tuning.section("player")
	assert_eq(float(player["gravity"]), 980.0)
	assert_eq(float(player["walk_speed"]), 220.0)
	assert_eq(float(player["jet_accel"]), 1400.0)
	assert_eq(float(player["jet_max_up_speed"]), 360.0)


func test_fuel_matches_design() -> void:
	var fuel: Dictionary = Tuning.section("fuel")
	assert_eq(float(fuel["capacity"]), 100.0)
	assert_eq(float(fuel["drain_per_second"]), 35.0)
	assert_eq(float(fuel["refill_per_second"]), 50.0)
	assert_eq(float(fuel["refill_delay"]), 0.5)


func test_fire_threshold_matches_design() -> void:
	assert_eq(float(Tuning.section("touch")["fire_threshold"]), 0.7)
