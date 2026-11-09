extends GutTest
## Real fighters, projectiles and physics on the test map.

const ScriptedInputProvider := preload("res://tests/helpers/ScriptedInputProvider.gd")
const MapScene := preload("res://scenes/maps/TestMap.tscn")
const PlayerScene := preload("res://scenes/game/Player.tscn")

const TILE := 32.0
const FLOOR_Y := 36.0 * TILE
const SHOOTER_COLUMN := 6.0
const TIMEOUT_FRAMES := 480

var map: GameMap
var arena: Arena
var shooter: Player
var target: Player
var controls: ScriptedInputProvider


func before_each() -> void:
	map = MapScene.instantiate() as GameMap
	add_child_autofree(map)
	arena = Arena.new()
	add_child_autofree(arena)
	arena.respawn_delay = 0.2
	# Not setup(): the map's crates would interfere with loadout assertions.
	arena._spawn_points = map.spawn_points
	shooter = _add_fighter(0, SHOOTER_COLUMN)
	target = _add_fighter(1, 11.0)
	controls = ScriptedInputProvider.new()
	add_child_autofree(controls)
	shooter.input_provider = controls
	controls.input.aim = Vector2.RIGHT


func _add_fighter(team: int, column: float) -> Player:
	var fighter: Player = PlayerScene.instantiate() as Player
	fighter.team = team
	arena.add_child(fighter)
	fighter.global_position = Vector2((column + 0.5) * TILE, FLOOR_Y)
	arena.register_fighter(fighter)
	return fighter


## Holds an input until the target dies. Returns false on timeout.
func _wait_for_target_death() -> bool:
	for i: int in range(TIMEOUT_FRAMES):
		if target.is_dead:
			return true
		await wait_physics_frames(1, "")
	return false


func _fire_until_target_dies(weapon_id: String) -> void:
	await wait_physics_frames(3, "")
	shooter.give_weapon(weapon_id)
	assert_eq(shooter.loadout.active().id, weapon_id)
	controls.input.fire = true
	assert_true(await _wait_for_target_death(), "%s should kill the target" % weapon_id)


func test_pistol_kills() -> void:
	await wait_physics_frames(3, "")
	controls.input.fire = true
	assert_true(await _wait_for_target_death(), "pistol should kill the target")


func test_rifle_kills() -> void:
	await _fire_until_target_dies("rifle")


func test_shotgun_kills() -> void:
	await _fire_until_target_dies("shotgun")


func test_sniper_kills() -> void:
	await _fire_until_target_dies("sniper")


func test_rocket_kills() -> void:
	await _fire_until_target_dies("rocket")


func test_grenades_kill() -> void:
	await wait_physics_frames(3, "")
	# Frozen so knockback from the first blast cannot carry it out of range.
	target.set_physics_process(false)
	target.global_position = shooter.global_position + Vector2(40.0, 0.0)
	controls.input.aim = Vector2(0.1, 1.0).normalized()
	for i: int in range(3):
		controls.input.grenade = true
		await wait_physics_frames(2, "")
		controls.input.grenade = false
		await wait_physics_frames(40, "")
	assert_eq(shooter.grenades, 0)
	# Out of the blast, so the shooter's own grenades do not end the test early.
	shooter.global_position.x += 10.0 * TILE
	assert_true(await _wait_for_target_death(), "grenades should kill the target")


func test_melee_does_25_and_kills() -> void:
	await wait_physics_frames(3, "")
	target.global_position = shooter.global_position + Vector2(50.0, 0.0)
	controls.input.melee = true
	await wait_physics_frames(2, "")
	assert_eq(target.health.current, 75.0)
	for i: int in range(3):
		controls.input.melee = false
		await wait_physics_frames(30, "")
		controls.input.melee = true
		await wait_physics_frames(2, "")
	assert_true(target.is_dead)


func test_melee_needs_range() -> void:
	await wait_physics_frames(3, "")
	controls.input.melee = true
	await wait_physics_frames(2, "")
	assert_eq(target.health.current, 100.0)


func test_bullet_damage_matches_the_weapon() -> void:
	await wait_physics_frames(3, "")
	controls.input.fire = true
	await wait_physics_frames(1, "")
	controls.input.fire = false
	await wait_physics_frames(30, "")
	assert_eq(target.health.current, 85.0)


func test_walls_block_bullets() -> void:
	await wait_physics_frames(3, "")
	shooter.global_position = Vector2(12.5 * TILE, FLOOR_Y)
	target.global_position = Vector2(21.5 * TILE, FLOOR_Y)
	shooter.give_weapon("rifle")
	controls.input.fire = true
	await wait_physics_frames(45, "")
	assert_eq(target.health.current, 100.0)


func test_bullets_pass_through_one_way_platforms() -> void:
	await wait_physics_frames(3, "")
	shooter.global_position = Vector2(12.5 * TILE, FLOOR_Y)
	target.global_position = Vector2(12.5 * TILE, 30.0 * TILE)
	controls.input.aim = Vector2.UP
	controls.input.fire = true
	await wait_physics_frames(60, "")
	assert_lt(target.health.current, 100.0)


func test_teammates_cannot_be_shot() -> void:
	await wait_physics_frames(3, "")
	target.team = shooter.team
	controls.input.fire = true
	await wait_physics_frames(60, "")
	assert_eq(target.health.current, 100.0)


func test_rocket_hurts_its_shooter_at_close_range() -> void:
	await wait_physics_frames(3, "")
	target.global_position = shooter.global_position + Vector2(44.0, 0.0)
	shooter.give_weapon("rocket")
	controls.input.fire = true
	await wait_physics_frames(1, "")
	controls.input.fire = false
	await wait_physics_frames(20, "")
	assert_lt(shooter.health.current, 100.0)
	assert_gt(shooter.health.current, target.health.current)


func test_solid_wall_shields_from_splash() -> void:
	await wait_physics_frames(3, "")
	shooter.global_position = Vector2(12.5 * TILE, FLOOR_Y)
	target.global_position = Vector2(20.5 * TILE, FLOOR_Y)
	shooter.give_weapon("rocket")
	controls.input.fire = true
	await wait_physics_frames(1, "")
	controls.input.fire = false
	await wait_physics_frames(60, "")
	assert_eq(target.health.current, 100.0)


func test_respawn_restores_the_fighter_at_a_spawn_point() -> void:
	await wait_physics_frames(3, "")
	target.give_weapon("sniper")
	target.grenades = 0
	target.take_damage(500.0, shooter)
	assert_true(target.is_dead)
	await wait_seconds(0.4, "")
	assert_false(target.is_dead)
	assert_eq(target.health.current, 100.0)
	assert_eq(target.grenades, 3)
	assert_eq(target.loadout.active().id, "pistol")
	assert_true(target.global_position in map.spawn_points)


func test_dead_fighter_is_not_hit() -> void:
	arena.respawn_enabled = false
	await wait_physics_frames(3, "")
	target.take_damage(500.0, shooter)
	assert_eq(target.take_damage(10.0, shooter), 0.0)


func test_kill_is_reported_with_the_killer() -> void:
	watch_signals(arena)
	await wait_physics_frames(3, "")
	shooter.give_weapon("sniper")
	controls.input.fire = true
	assert_true(await _wait_for_target_death())
	assert_signal_emitted_with_parameters(arena, "fighter_killed", [target, shooter])


func test_projectiles_are_reused() -> void:
	await wait_physics_frames(3, "")
	controls.input.fire = true
	await wait_physics_frames(90, "")
	controls.input.fire = false
	await wait_physics_frames(60, "")
	var count: int = 0
	for child: Node in arena.get_children():
		if child is Projectile:
			count += 1
	# Six shots with at most three in flight at once.
	assert_lt(count, 5)


func test_grenade_survives_its_thrower_leaving() -> void:
	await wait_physics_frames(3, "")
	target.global_position = shooter.global_position + Vector2(40.0, 0.0)
	controls.input.aim = Vector2(0.1, 1.0).normalized()
	controls.input.grenade = true
	await wait_physics_frames(2, "")
	arena.unregister_fighter(shooter)
	shooter.queue_free()
	await wait_physics_frames(170, "")
	assert_lt(target.health.current, 100.0)


func test_rocket_survives_its_shooter_leaving() -> void:
	await wait_physics_frames(3, "")
	shooter.give_weapon("rocket")
	controls.input.fire = true
	await wait_physics_frames(1, "")
	arena.unregister_fighter(shooter)
	shooter.queue_free()
	await wait_physics_frames(40, "")
	assert_lt(target.health.current, 100.0)


func test_sniper_zooms_out_only_while_aiming() -> void:
	var camera := AimCamera.new()
	add_child_autofree(camera)
	camera.target = shooter
	await wait_physics_frames(3, "")
	shooter.give_weapon("sniper")
	await wait_physics_frames(60, "")
	assert_lt(camera.zoom.x, 0.75)
	controls.input.aim = Vector2.ZERO
	await wait_physics_frames(90, "")
	assert_gt(camera.zoom.x, 0.95)


func test_explosion_trauma_shakes_then_settles() -> void:
	var camera := AimCamera.new()
	add_child_autofree(camera)
	camera.target = shooter
	await wait_physics_frames(3, "")
	camera.add_trauma(1.0)
	await wait_physics_frames(2, "")
	assert_ne(camera.offset, Vector2.ZERO)
	await wait_physics_frames(70, "")
	assert_eq(camera.offset, Vector2.ZERO)


func test_crate_gives_its_weapon_then_returns() -> void:
	var pickup: Pickup = (load("res://scenes/game/Pickup.tscn") as PackedScene).instantiate() as Pickup
	var pool: Array[String] = []
	arena.add_child(pickup)
	pickup.global_position = shooter.get_center()
	pickup.setup(Pickup.Kind.WEAPON, "shotgun", pool)
	pickup.touched.connect(arena._on_pickup_touched)
	pickup._respawn_time = 0.2
	await wait_physics_frames(5, "")
	assert_eq(shooter.loadout.active().id, "shotgun")
	assert_false(pickup.is_available())
	# Standing on it would collect it again the moment it returns.
	shooter.global_position.x += 5.0 * TILE
	await wait_physics_frames(20, "")
	assert_true(pickup.is_available())


func test_health_pack_heals_50_and_is_left_alone_at_full_health() -> void:
	var pickup: Pickup = (load("res://scenes/game/Pickup.tscn") as PackedScene).instantiate() as Pickup
	var pool: Array[String] = []
	arena.add_child(pickup)
	pickup.global_position = target.get_center()
	pickup.setup(Pickup.Kind.HEALTH, "", pool)
	pickup.touched.connect(arena._on_pickup_touched)
	await wait_physics_frames(5, "")
	assert_true(pickup.is_available(), "full health should not consume it")
	target.take_damage(70.0, shooter)
	await wait_physics_frames(5, "")
	assert_eq(target.health.current, 80.0)
	assert_false(pickup.is_available())
