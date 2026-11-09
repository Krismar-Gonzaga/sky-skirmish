class_name Weapon
extends RefCounted
## Fire rate, ammo and reload rules. Holds no nodes, so the rules can be unit
## tested; Arena turns the shots it returns into projectiles.

const INFINITE_RESERVE := -1
## Fire periods are whole physics ticks; this absorbs float rounding so a
## 10 shots/s weapon really fires every 6th tick.
const COOLDOWN_EPSILON := 0.0001

var id: String
var display_name: String
var damage: float
var pellets: int
var fire_rate: float
var magazine_size: int
var reload_time: float
var spread: float
var projectile_speed: float
var max_range: float
var splash_radius: float
var self_damage_factor: float
var view_zoom: float
var aim_lead_factor: float
var projectile_kind: String

var ammo: int
var reserve: int

var _cooldown: float = 0.0
var _reload_left: float = 0.0


func _init(weapon_id: String, stats: Dictionary) -> void:
	id = weapon_id
	display_name = stats["display_name"]
	damage = stats["damage"]
	pellets = int(stats["pellets"])
	fire_rate = stats["fire_rate"]
	magazine_size = int(stats["magazine"])
	reload_time = stats["reload_time"]
	spread = deg_to_rad(float(stats["spread_degrees"]))
	projectile_speed = stats["projectile_speed"]
	max_range = stats["range"]
	splash_radius = stats["splash_radius"]
	self_damage_factor = stats["self_damage_factor"]
	view_zoom = stats["view_zoom"]
	aim_lead_factor = stats["aim_lead_factor"]
	projectile_kind = stats["projectile"]
	ammo = magazine_size
	reserve = int(stats["reserve"])


func update(delta: float) -> void:
	_cooldown = maxf(_cooldown - delta, 0.0)
	if is_reloading():
		_reload_left -= delta
		if _reload_left <= 0.0:
			_finish_reload()
	elif ammo == 0:
		start_reload()


func can_fire() -> bool:
	return ammo > 0 and not is_reloading() and _cooldown <= COOLDOWN_EPSILON


## Returns one direction per pellet, or an empty array if the weapon cannot fire.
func try_fire(aim: Vector2, rng: RandomNumberGenerator, spread_factor: float = 1.0) -> Array[Vector2]:
	if not can_fire():
		return []
	ammo -= 1
	_cooldown = 1.0 / fire_rate
	if ammo == 0:
		start_reload()
	return _shot_directions(aim, rng, spread * spread_factor)


func is_reloading() -> bool:
	return _reload_left > 0.0


func start_reload() -> void:
	if is_reloading() or ammo == magazine_size or reserve == 0:
		return
	_reload_left = reload_time


func cancel_reload() -> void:
	_reload_left = 0.0


## True when nothing is left to fire or reload.
func is_depleted() -> bool:
	return ammo == 0 and reserve == 0 and not is_reloading()


func add_magazine() -> void:
	if reserve != INFINITE_RESERVE:
		reserve += magazine_size


func _shot_directions(aim: Vector2, rng: RandomNumberGenerator, half_angle: float) -> Array[Vector2]:
	var directions: Array[Vector2] = []
	for i: int in range(pellets):
		directions.append(aim.rotated(rng.randf_range(-half_angle, half_angle)))
	return directions


func _finish_reload() -> void:
	_reload_left = 0.0
	var needed: int = magazine_size - ammo
	var taken: int = needed if reserve == INFINITE_RESERVE else mini(needed, reserve)
	ammo += taken
	if reserve != INFINITE_RESERVE:
		reserve -= taken
