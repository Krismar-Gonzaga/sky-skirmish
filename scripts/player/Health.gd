class_name Health
extends RefCounted
## Hit point and regeneration rules, kept free of nodes for unit testing.

var maximum: float
var current: float

var _regen_per_second: float
var _regen_delay: float
var _time_since_damage: float = 0.0


func _init(config: Dictionary) -> void:
	maximum = config["max_hp"]
	_regen_per_second = config["regen_per_second"]
	_regen_delay = config["regen_delay"]
	current = maximum


func set_maximum(new_maximum: float) -> void:
	maximum = new_maximum
	restore()


func restore() -> void:
	current = maximum
	_time_since_damage = 0.0


func is_dead() -> bool:
	return current <= 0.0


func is_full() -> bool:
	return current >= maximum


## Returns the damage actually applied, which is capped at the remaining HP.
func take_damage(amount: float) -> float:
	var dealt: float = minf(amount, current)
	current -= dealt
	_time_since_damage = 0.0
	return dealt


func heal(amount: float) -> void:
	current = minf(current + amount, maximum)


func update(delta: float) -> void:
	if is_dead() or is_full():
		return
	_time_since_damage += delta
	if _time_since_damage >= _regen_delay:
		heal(_regen_per_second * delta)
