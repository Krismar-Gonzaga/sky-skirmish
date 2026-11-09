class_name CaptureMission
extends Mission
## Clear by holding the zone for a total time.

var progress: float = 0.0


## Progress is kept when the player leaves, and pauses while an enemy contests.
func update_zone(delta: float, player_inside: bool, enemy_inside: bool) -> void:
	if status != Status.RUNNING or not player_inside or enemy_inside:
		return
	progress += delta
	if progress >= _target:
		status = Status.CLEARED


func objective_text() -> String:
	return "Hold the zone %d / %d s" % [floori(progress), _target]
