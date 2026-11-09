class_name PathFollower
extends RefCounted
## Turns a route into stick and jet input. Thrust is a simple feedback rule:
## fire the jet whenever the fighter is rising slower than the route wants.

## How many routes reached their end; a bot looping in place never raises this.
var routes_finished: int = 0

var _path: PackedVector2Array = PackedVector2Array()
var _index: int = 0
var _resting: bool = false

var _arrival_radius: float
var _climb_margin: float
var _vertical_gain: float
var _max_climb_speed: float
var _max_descent_speed: float
var _horizontal_span: float
var _low_fuel: float
var _resume_fuel: float


func _init(config: Dictionary) -> void:
	_arrival_radius = config["arrival_radius"]
	_climb_margin = config["climb_margin"]
	_vertical_gain = config["vertical_gain"]
	_max_climb_speed = config["max_climb_speed"]
	_max_descent_speed = config["max_descent_speed"]
	_horizontal_span = config["horizontal_span"]
	_low_fuel = config["low_fuel"]
	_resume_fuel = config["resume_fuel"]


func set_path(path: PackedVector2Array) -> void:
	_path = path
	_index = 0


func clear() -> void:
	set_path(PackedVector2Array())


func is_finished() -> bool:
	return _path.is_empty() or _index >= _path.size()


## True while the fighter is out of fuel and waiting on the ground to refill.
func is_resting() -> bool:
	return _resting


func steer(feet: Vector2, velocity: Vector2, on_floor: bool, fuel_ratio: float, input: PlayerInput) -> void:
	_advance(feet)
	_update_rest(on_floor, fuel_ratio)
	if is_finished():
		return
	var to_waypoint: Vector2 = _path[_index] - feet
	input.move.x = clampf(to_waypoint.x / _horizontal_span, -1.0, 1.0)
	var wanted_rise: float = clampf(to_waypoint.y * _vertical_gain, -_max_climb_speed, _max_descent_speed)
	var must_climb: bool = to_waypoint.y < -_climb_margin
	# Hovering matters only in the air; on the ground a level route just walks.
	var may_hover: bool = not on_floor and to_waypoint.y <= _climb_margin
	input.jet = not _resting and velocity.y > wanted_rise and (must_climb or may_hover)


func _advance(feet: Vector2) -> void:
	var was_finished: bool = is_finished()
	while _index < _path.size() and feet.distance_to(_path[_index]) < _arrival_radius:
		_index += 1
	if is_finished() and not was_finished:
		routes_finished += 1


func _update_rest(on_floor: bool, fuel_ratio: float) -> void:
	if fuel_ratio <= _low_fuel:
		_resting = true
	elif _resting and on_floor and fuel_ratio >= _resume_fuel:
		_resting = false
