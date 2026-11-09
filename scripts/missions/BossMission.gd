class_name BossMission
extends Mission
## Clear by killing the leader. Escorts do not count.


func on_enemy_killed(was_leader: bool) -> void:
	if status == Status.RUNNING and was_leader:
		status = Status.CLEARED


func objective_text() -> String:
	return "Eliminate the leader"
