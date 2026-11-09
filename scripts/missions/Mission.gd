class_name Mission
extends RefCounted
## The rules that decide whether a level is cleared or failed: timer, lives and
## objective. Holds no nodes, so every rule can be unit tested.

enum Status { RUNNING, CLEARED, FAILED }

const NO_LIMIT := 0.0

var status: Status = Status.RUNNING
var deaths: int = 0
var time_limit: float = NO_LIMIT
var time_left: float = NO_LIMIT
var elapsed: float = 0.0

var _target: int = 0
var _allowed_deaths: int = 0


func _init(level_data: Dictionary, lives: int) -> void:
	_target = int(level_data["target"])
	time_limit = level_data["time_limit"]
	time_left = time_limit
	_allowed_deaths = lives
	if level_data.has("max_deaths"):
		# "Max 2 deaths" means the third death ends the run.
		_allowed_deaths = mini(lives, int(level_data["max_deaths"]) + 1)


func update(delta: float) -> void:
	if status != Status.RUNNING:
		return
	elapsed += delta
	if time_limit > NO_LIMIT:
		time_left = maxf(time_left - delta, 0.0)
		if time_left <= 0.0:
			_on_time_up()


func on_player_died() -> void:
	if status != Status.RUNNING:
		return
	deaths += 1
	if deaths >= _allowed_deaths:
		status = Status.FAILED


func on_enemy_killed(_was_leader: bool) -> void:
	pass


func lives_left() -> int:
	return maxi(_allowed_deaths - deaths, 0)


func stars() -> int:
	return StarRating.calculate(deaths, time_left, time_limit, _time_counts_for_stars())


func objective_text() -> String:
	return ""


func _on_time_up() -> void:
	status = Status.FAILED


func _time_counts_for_stars() -> bool:
	return time_limit > NO_LIMIT
