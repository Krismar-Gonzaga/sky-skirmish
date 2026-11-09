class_name Player
extends CharacterBody2D
## One fighter. Reads only a PlayerInput, so it does not care whether a thumb,
## a bot or the network is driving it. The origin is at the feet.
## Combat results leave as signals; Arena decides what they do to the world.

signal fired(shooter: Player, weapon: Weapon, origin: Vector2, directions: Array[Vector2])
signal grenade_thrown(thrower: Player, origin: Vector2, direction: Vector2)
signal melee_swung(attacker: Player, origin: Vector2, direction: Vector2)
signal died(victim: Player, killer: Player)
signal respawned(fighter: Player)
signal health_changed(current: float, maximum: float)
signal fuel_changed(current: float, capacity: float)
signal weapon_status_changed(status: String)
signal grenades_changed(count: int)

## Fighters on the same team cannot hurt each other.
var team: int = 0
## False for target dummies and gauntlet waves, which stay dead.
var respawns: bool = true
## Null means the fighter stands idle.
var input_provider: InputProvider
var fuel: FuelTank
var health: Health
var loadout: Loadout
var grenades: int = 0
var aim_direction: Vector2 = Vector2.RIGHT
var is_aiming: bool = false
var is_crouching: bool = false
var is_thrusting: bool = false
var is_dead: bool = false

var _motor: PlayerMotor
var _capsule: CapsuleShape2D
var _stand_height: float
var _crouch_height: float
var _aim_origin_ratio: float
var _crouch_spread_factor: float
var _grenade_capacity: int
var _grenade_cooldown_time: float
var _melee_cooldown_time: float
var _grenade_cooldown: float = 0.0
var _melee_cooldown: float = 0.0
var _rng := RandomNumberGenerator.new()
var _was_swap: bool = false
var _was_grenade: bool = false
var _was_melee: bool = false
var _reported_fuel: float = -1.0
var _reported_status: String = ""
var _collision_layer: int = 0

@onready var _body_shape: CollisionShape2D = $BodyShape
@onready var _visual: PlayerVisual = $Visual


func _ready() -> void:
	var config: Dictionary = Tuning.section("player")
	_motor = PlayerMotor.new(config)
	fuel = FuelTank.new(Tuning.section("fuel"))
	health = Health.new(Tuning.section("health"))
	loadout = Loadout.new()
	_stand_height = config["stand_height"]
	_crouch_height = config["crouch_height"]
	_aim_origin_ratio = config["aim_origin_height_ratio"]
	_crouch_spread_factor = WeaponCatalog.aim()["crouch_spread_factor"]
	_grenade_capacity = int(WeaponCatalog.grenade()["count_per_life"])
	_grenade_cooldown_time = WeaponCatalog.grenade()["cooldown"]
	_melee_cooldown_time = WeaponCatalog.melee()["cooldown"]
	grenades = _grenade_capacity
	_collision_layer = collision_layer
	_capsule = CapsuleShape2D.new()
	_capsule.radius = config["body_radius"]
	_body_shape.shape = _capsule
	_set_body_height(_stand_height)


func _physics_process(delta: float) -> void:
	var input: PlayerInput = PlayerInput.new()
	if input_provider != null:
		input = input_provider.poll(get_aim_origin())
	_update_crouch(input.crouch)
	is_thrusting = fuel.update(delta, input.jet, is_on_floor())
	velocity = _motor.step(velocity, input.move.x, is_on_floor(), is_thrusting, is_crouching, delta)
	move_and_slide()
	is_aiming = input.aim != Vector2.ZERO
	if is_aiming:
		aim_direction = input.aim.normalized()
	_update_combat(input, delta)
	_visual.update_pose(aim_direction, _capsule.height / _stand_height, is_thrusting)
	_visual.show_weapon(loadout.active().id)
	report_status()


func get_aim_origin() -> Vector2:
	return global_position + Vector2.UP * _capsule.height * _aim_origin_ratio


func get_center() -> Vector2:
	return global_position + Vector2.UP * _capsule.height / 2.0


## Distance from a point to the surface of the body, zero if inside it.
func distance_from(point: Vector2) -> float:
	var reach: float = maxf(_capsule.height / 2.0 - _capsule.radius, 0.0)
	var axis_point: Vector2 = Geometry2D.get_closest_point_to_segment(
			point, get_center() + Vector2.UP * reach, get_center() + Vector2.DOWN * reach)
	return maxf(point.distance_to(axis_point) - _capsule.radius, 0.0)


## Returns the damage actually applied.
func take_damage(amount: float, attacker: Player) -> float:
	if is_dead:
		return 0.0
	var dealt: float = health.take_damage(amount)
	_visual.flash_hit()
	health_changed.emit(health.current, health.maximum)
	if health.is_dead():
		_die(attacker)
	return dealt


func heal(amount: float) -> void:
	health.heal(amount)
	health_changed.emit(health.current, health.maximum)


func give_weapon(weapon_id: String) -> void:
	loadout.pickup(weapon_id)


func set_visual_scale(factor: float) -> void:
	_visual.scale = Vector2(factor, factor)


func apply_knockback(impulse: Vector2) -> void:
	velocity += impulse


func respawn(at: Vector2) -> void:
	global_position = at
	velocity = Vector2.ZERO
	health.restore()
	fuel.refill()
	loadout.reset()
	grenades = _grenade_capacity
	is_dead = false
	collision_layer = _collision_layer
	_body_shape.set_deferred("disabled", false)
	set_physics_process(true)
	_visual.fade_in()
	report_all_status()
	respawned.emit(self)


## Sends every status signal, so a freshly bound HUD starts correct.
func report_all_status() -> void:
	_reported_fuel = -1.0
	_reported_status = ""
	health_changed.emit(health.current, health.maximum)
	grenades_changed.emit(grenades)
	report_status()


func report_status() -> void:
	if fuel.amount != _reported_fuel:
		_reported_fuel = fuel.amount
		fuel_changed.emit(fuel.amount, fuel.capacity)
	var status: String = _weapon_status()
	if status != _reported_status:
		_reported_status = status
		weapon_status_changed.emit(status)


func _update_combat(input: PlayerInput, delta: float) -> void:
	var was_full: bool = health.is_full()
	health.update(delta)
	if not was_full:
		health_changed.emit(health.current, health.maximum)
	_grenade_cooldown = maxf(_grenade_cooldown - delta, 0.0)
	_melee_cooldown = maxf(_melee_cooldown - delta, 0.0)
	var was_reloading: bool = loadout.active().is_reloading()
	loadout.update(delta)
	if loadout.active().is_reloading() and not was_reloading:
		AudioManager.play("reload")
	if input.swap and not _was_swap and loadout.swap():
		AudioManager.play("swap")
	if input.grenade and not _was_grenade:
		_throw_grenade()
	if input.melee and not _was_melee:
		_swing_melee()
	if input.fire:
		_fire_weapon()
	_was_swap = input.swap
	_was_grenade = input.grenade
	_was_melee = input.melee


func _fire_weapon() -> void:
	var weapon: Weapon = loadout.active()
	var factor: float = _crouch_spread_factor if is_crouching else 1.0
	var directions: Array[Vector2] = weapon.try_fire(aim_direction, _rng, factor)
	if not directions.is_empty():
		fired.emit(self, weapon, get_aim_origin(), directions)


func _throw_grenade() -> void:
	if grenades <= 0 or _grenade_cooldown > 0.0:
		return
	grenades -= 1
	_grenade_cooldown = _grenade_cooldown_time
	grenades_changed.emit(grenades)
	grenade_thrown.emit(self, get_aim_origin(), aim_direction)


func _swing_melee() -> void:
	if _melee_cooldown > 0.0:
		return
	_melee_cooldown = _melee_cooldown_time
	_visual.swing_arm()
	melee_swung.emit(self, get_aim_origin(), aim_direction)


func _die(killer: Player) -> void:
	is_dead = true
	is_thrusting = false
	collision_layer = 0
	_body_shape.set_deferred("disabled", true)
	set_physics_process(false)
	_visual.hide_body()
	died.emit(self, killer)


func _weapon_status() -> String:
	var weapon: Weapon = loadout.active()
	var spare: String = "∞" if weapon.reserve == Weapon.INFINITE_RESERVE else str(weapon.reserve)
	var state: String = "  Reloading" if weapon.is_reloading() else ""
	return "%s  %d / %s%s" % [weapon.display_name, weapon.ammo, spare, state]


func _update_crouch(wants_crouch: bool) -> void:
	var should_crouch: bool = wants_crouch and is_on_floor()
	if should_crouch and not is_crouching:
		is_crouching = true
		_set_body_height(_crouch_height)
	elif is_crouching and not should_crouch and _has_headroom():
		is_crouching = false
		_set_body_height(_stand_height)


func _has_headroom() -> bool:
	var rise := Vector2.UP * (_stand_height - _crouch_height)
	return not test_move(global_transform, rise)


func _set_body_height(height: float) -> void:
	_capsule.height = height
	_body_shape.position.y = -height / 2.0
