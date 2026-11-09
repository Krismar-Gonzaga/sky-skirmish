class_name FuelTank
extends RefCounted
## Jetpack fuel rules, kept free of nodes so they can be unit tested exactly.

var capacity: float
var amount: float

var _drain_per_second: float
var _refill_per_second: float
var _refill_delay: float
var _time_on_ground: float = 0.0


func _init(config: Dictionary) -> void:
	capacity = config["capacity"]
	_drain_per_second = config["drain_per_second"]
	_refill_per_second = config["refill_per_second"]
	_refill_delay = config["refill_delay"]
	amount = capacity


## Advances the tank by delta seconds and returns true if the jet fires.
func update(delta: float, wants_thrust: bool, on_floor: bool) -> bool:
	if wants_thrust and amount > 0.0:
		amount = maxf(amount - _drain_per_second * delta, 0.0)
		_time_on_ground = 0.0
		return true
	# Holding the jet on an empty tank must not refill, or the fighter would
	# stutter-hop on tiny sips of fuel.
	if on_floor and not wants_thrust:
		_time_on_ground += delta
		if _time_on_ground >= _refill_delay:
			amount = minf(amount + _refill_per_second * delta, capacity)
	else:
		_time_on_ground = 0.0
	return false
