class_name EliminateMission
extends Mission
## Clear by reaching a number of kills.

var kills: int = 0


func on_enemy_killed(_was_leader: bool) -> void:
	if status != Status.RUNNING:
		return
	kills += 1
	if kills >= _target:
		status = Status.CLEARED


func objective_text() -> String:
	return "Eliminate %d / %d" % [kills, _target]
