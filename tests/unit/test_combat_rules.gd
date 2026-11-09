extends GutTest
## Splash falloff, health, spawn choice and design values in the data files.

const STEP := 1.0 / 60.0

var health: Health


func before_each() -> void:
	health = Health.new({"max_hp": 100.0, "regen_per_second": 5.0, "regen_delay": 5.0})


func _run_health(seconds: float) -> void:
	for i: int in range(roundi(seconds / STEP)):
		health.update(STEP)


func test_splash_is_full_at_the_centre() -> void:
	assert_eq(Splash.damage_at(0.0, 96.0, 60.0), 60.0)


func test_splash_falls_off_linearly() -> void:
	assert_almost_eq(Splash.damage_at(48.0, 96.0, 60.0), 30.0, 0.001)
	assert_almost_eq(Splash.damage_at(72.0, 96.0, 60.0), 15.0, 0.001)


func test_splash_is_zero_at_and_beyond_the_radius() -> void:
	assert_eq(Splash.damage_at(96.0, 96.0, 60.0), 0.0)
	assert_eq(Splash.damage_at(500.0, 96.0, 60.0), 0.0)


func test_no_radius_means_no_splash() -> void:
	assert_eq(Splash.damage_at(0.0, 0.0, 60.0), 0.0)


func test_damage_reduces_health() -> void:
	health.take_damage(30.0)
	assert_eq(health.current, 70.0)


func test_damage_is_capped_at_remaining_health() -> void:
	health.current = 10.0
	assert_eq(health.take_damage(50.0), 10.0)
	assert_true(health.is_dead())


func test_no_regen_before_five_seconds() -> void:
	health.take_damage(30.0)
	_run_health(4.9)
	assert_eq(health.current, 70.0)


func test_regen_at_five_per_second_after_delay() -> void:
	health.take_damage(30.0)
	_run_health(5.0)
	_run_health(2.0)
	assert_almost_eq(health.current, 80.0, 0.5)


func test_new_damage_restarts_the_regen_delay() -> void:
	health.take_damage(30.0)
	_run_health(4.0)
	health.take_damage(1.0)
	_run_health(4.0)
	assert_eq(health.current, 69.0)


func test_regen_stops_at_maximum() -> void:
	health.take_damage(5.0)
	_run_health(20.0)
	assert_eq(health.current, 100.0)


func test_dead_fighter_does_not_regen() -> void:
	health.take_damage(100.0)
	_run_health(20.0)
	assert_eq(health.current, 0.0)


func test_spawn_is_farthest_from_the_threat() -> void:
	var spawns: Array[Vector2] = [Vector2(0.0, 0.0), Vector2(100.0, 0.0), Vector2(1000.0, 0.0)]
	var threats: Array[Vector2] = [Vector2(50.0, 0.0)]
	assert_eq(SpawnPicker.farthest_from(spawns, threats), Vector2(1000.0, 0.0))


func test_spawn_considers_the_nearest_of_several_threats() -> void:
	var spawns: Array[Vector2] = [Vector2(0.0, 0.0), Vector2(1000.0, 0.0)]
	var threats: Array[Vector2] = [Vector2(100.0, 0.0), Vector2(950.0, 0.0)]
	assert_eq(SpawnPicker.farthest_from(spawns, threats), Vector2(0.0, 0.0))


func test_weapon_numbers_match_design() -> void:
	var expected: Dictionary = {
		"pistol": [15.0, 1, 4.0, 12],
		"rifle": [12.0, 1, 10.0, 30],
		"shotgun": [8.0, 6, 1.2, 6],
		"sniper": [70.0, 1, 0.8, 5],
		"rocket": [60.0, 1, 0.6, 2],
	}
	for weapon_id: String in expected:
		var stats: Dictionary = WeaponCatalog.stats(weapon_id)
		var row: Array = expected[weapon_id]
		assert_eq(float(stats["damage"]), float(row[0]), weapon_id)
		assert_eq(int(stats["pellets"]), int(row[1]), weapon_id)
		assert_eq(float(stats["fire_rate"]), float(row[2]), weapon_id)
		assert_eq(int(stats["magazine"]), int(row[3]), weapon_id)
	assert_eq(float(WeaponCatalog.stats("rocket")["splash_radius"]), 96.0)
	assert_eq(int(WeaponCatalog.stats("pistol")["reserve"]), Weapon.INFINITE_RESERVE)


func test_grenade_melee_and_pickup_numbers_match_design() -> void:
	assert_eq(float(WeaponCatalog.grenade()["damage"]), 80.0)
	assert_eq(float(WeaponCatalog.grenade()["fuse"]), 2.5)
	assert_eq(int(WeaponCatalog.grenade()["count_per_life"]), 3)
	assert_eq(float(WeaponCatalog.melee()["damage"]), 25.0)
	assert_eq(float(Tuning.section("pickups")["respawn_time"]), 20.0)
	assert_eq(float(Tuning.section("pickups")["health_pack"]), 50.0)
	assert_eq(float(Tuning.section("health")["max_hp"]), 100.0)
	assert_eq(float(Tuning.section("health")["regen_per_second"]), 5.0)
	assert_eq(float(Tuning.section("health")["regen_delay"]), 5.0)
	assert_eq(float(Tuning.section("health")["respawn_delay"]), 3.0)
