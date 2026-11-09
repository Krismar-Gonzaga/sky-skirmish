class_name SurviveMission
extends Mission
## Clear by still being alive when the clock runs out.


func objective_text() -> String:
	return "Survive"


func _on_time_up() -> void:
	status = Status.CLEARED


func _time_counts_for_stars() -> bool:
	return false
