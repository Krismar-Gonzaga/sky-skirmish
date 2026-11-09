class_name PlayerMotor
extends RefCounted
## Velocity rules for a fighter, separate from the node so they can be tested
## without running physics.

var _gravity: float
var _walk_speed: float
var _ground_accel: float
var _air_accel: float
var _jet_accel: float
var _jet_max_up_speed: float
var _max_fall_speed: float
var _crouch_speed_factor: float


func _init(config: Dictionary) -> void:
	_gravity = config["gravity"]
	_walk_speed = config["walk_speed"]
	_ground_accel = config["ground_accel"]
	_air_accel = config["air_accel"]
	_jet_accel = config["jet_accel"]
	_jet_max_up_speed = config["jet_max_up_speed"]
	_max_fall_speed = config["max_fall_speed"]
	_crouch_speed_factor = config["crouch_speed_factor"]


func step(
		velocity: Vector2,
		move_x: float,
		on_floor: bool,
		thrusting: bool,
		crouching: bool,
		delta: float
) -> Vector2:
	var top_speed: float = _walk_speed * (_crouch_speed_factor if crouching else 1.0)
	var accel: float = _ground_accel if on_floor else _air_accel
	velocity.x = move_toward(velocity.x, clampf(move_x, -1.0, 1.0) * top_speed, accel * delta)
	velocity.y += _gravity * delta
	# The cap applies only under thrust so a blast can still launch a fighter faster.
	if thrusting:
		velocity.y = maxf(velocity.y - _jet_accel * delta, -_jet_max_up_speed)
	velocity.y = minf(velocity.y, _max_fall_speed)
	return velocity
