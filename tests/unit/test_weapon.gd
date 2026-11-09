extends GutTest
## Ammo, fire rate and reload rules.

const STEP := 1.0 / 60.0

var rng := RandomNumberGenerator.new()


func _advance(weapon: Weapon, seconds: float) -> void:
	for i: int in range(roundi(seconds / STEP)):
		weapon.update(STEP)


func _shots_over(weapon: Weapon, seconds: float) -> int:
	var shots: int = 0
	for i: int in range(roundi(seconds / STEP)):
		weapon.update(STEP)
		if not weapon.try_fire(Vector2.RIGHT, rng).is_empty():
			shots += 1
	return shots


func test_each_id_builds_its_own_class() -> void:
	assert_true(WeaponCatalog.create("pistol") is Pistol)
	assert_true(WeaponCatalog.create("rifle") is Rifle)
	assert_true(WeaponCatalog.create("shotgun") is Shotgun)
	assert_true(WeaponCatalog.create("sniper") is Sniper)
	assert_true(WeaponCatalog.create("rocket") is RocketLauncher)


func test_firing_uses_one_round() -> void:
	var rifle: Weapon = WeaponCatalog.create("rifle")
	rifle.try_fire(Vector2.RIGHT, rng)
	assert_eq(rifle.ammo, 29)


func test_shotgun_uses_one_round_for_six_pellets() -> void:
	var shotgun: Weapon = WeaponCatalog.create("shotgun")
	assert_eq(shotgun.try_fire(Vector2.RIGHT, rng).size(), 6)
	assert_eq(shotgun.ammo, 5)


func test_fire_rate_limits_shots() -> void:
	assert_eq(_shots_over(WeaponCatalog.create("pistol"), 1.0), 4)
	assert_eq(_shots_over(WeaponCatalog.create("rifle"), 1.0), 10)


func test_cannot_fire_during_cooldown() -> void:
	var sniper: Weapon = WeaponCatalog.create("sniper")
	assert_false(sniper.try_fire(Vector2.RIGHT, rng).is_empty())
	assert_true(sniper.try_fire(Vector2.RIGHT, rng).is_empty())


func test_empty_magazine_reloads_automatically() -> void:
	var rocket: Weapon = WeaponCatalog.create("rocket")
	rocket.ammo = 1
	_advance(rocket, 2.0)
	rocket.try_fire(Vector2.RIGHT, rng)
	assert_eq(rocket.ammo, 0)
	assert_true(rocket.is_reloading())


func test_cannot_fire_while_reloading() -> void:
	var pistol: Weapon = WeaponCatalog.create("pistol")
	pistol.ammo = 1
	pistol.try_fire(Vector2.RIGHT, rng)
	_advance(pistol, 0.5)
	assert_true(pistol.try_fire(Vector2.RIGHT, rng).is_empty())


func test_reload_takes_reload_time_and_moves_ammo_from_reserve() -> void:
	var rocket: Weapon = WeaponCatalog.create("rocket")
	rocket.ammo = 0
	rocket.update(STEP)
	_advance(rocket, rocket.reload_time - 0.1)
	assert_eq(rocket.ammo, 0)
	_advance(rocket, 0.2)
	assert_eq(rocket.ammo, 2)
	assert_eq(rocket.reserve, 4)


func test_pistol_reserve_never_runs_out() -> void:
	var pistol: Weapon = WeaponCatalog.create("pistol")
	pistol.ammo = 0
	pistol.update(STEP)
	_advance(pistol, pistol.reload_time + 0.1)
	assert_eq(pistol.ammo, 12)
	assert_eq(pistol.reserve, Weapon.INFINITE_RESERVE)


func test_partial_reserve_partly_fills_the_magazine() -> void:
	var rifle: Weapon = WeaponCatalog.create("rifle")
	rifle.ammo = 0
	rifle.reserve = 7
	rifle.update(STEP)
	_advance(rifle, rifle.reload_time + 0.1)
	assert_eq(rifle.ammo, 7)
	assert_eq(rifle.reserve, 0)


func test_depleted_only_with_nothing_left() -> void:
	var rocket: Weapon = WeaponCatalog.create("rocket")
	assert_false(rocket.is_depleted())
	rocket.ammo = 0
	rocket.reserve = 0
	assert_true(rocket.is_depleted())


func test_spread_stays_inside_the_half_angle() -> void:
	var rifle: Weapon = WeaponCatalog.create("rifle")
	for i: int in range(200):
		rifle.ammo = rifle.magazine_size
		rifle.update(1.0)
		var direction: Vector2 = rifle.try_fire(Vector2.RIGHT, rng)[0]
		assert_lte(absf(direction.angle()), rifle.spread + 0.0001)


func test_spread_factor_tightens_the_shot() -> void:
	var rifle: Weapon = WeaponCatalog.create("rifle")
	for i: int in range(200):
		rifle.ammo = rifle.magazine_size
		rifle.update(1.0)
		var direction: Vector2 = rifle.try_fire(Vector2.RIGHT, rng, 0.5)[0]
		assert_lte(absf(direction.angle()), rifle.spread * 0.5 + 0.0001)
