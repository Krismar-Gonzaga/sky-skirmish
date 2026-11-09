class_name AimAssistProvider
extends InputProvider
## Wraps a human's input and applies aim assist when the Setting is on.

var _inner: InputProvider
var _player: Player
var _fighters: Array[Player] = []
var _max_angle: float
var _range: float
var _strength: float


## fighters is Arena's live list, so new enemies are covered automatically.
func _init(inner: InputProvider, player: Player, fighters: Array[Player]) -> void:
	_inner = inner
	_player = player
	_fighters = fighters
	var config: Dictionary = Tuning.section("aim_assist")
	_max_angle = deg_to_rad(float(config["max_angle_degrees"]))
	_range = config["range"]
	_strength = config["strength"]
	add_child(inner)


func poll(aim_origin: Vector2) -> PlayerInput:
	var input: PlayerInput = _inner.poll(aim_origin)
	if Settings.aim_assist and input.aim != Vector2.ZERO:
		input.aim = AimAssist.adjust(input.aim, aim_origin, _enemy_positions(),
				_max_angle, _range, _strength)
	return input


func reset() -> void:
	_inner.reset()


func _enemy_positions() -> Array[Vector2]:
	var positions: Array[Vector2] = []
	for fighter: Player in _fighters:
		if fighter.team != _player.team and not fighter.is_dead:
			positions.append(fighter.get_center())
	return positions
