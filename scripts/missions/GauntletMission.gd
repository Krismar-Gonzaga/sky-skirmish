class_name GauntletMission
extends Mission
## Clear by defeating one wave on each map in turn.

var waves_cleared: int = 0


func on_wave_cleared() -> void:
	if status != Status.RUNNING:
		return
	waves_cleared += 1
	if waves_cleared >= _target:
		status = Status.CLEARED


func objective_text() -> String:
	return "Wave %d / %d" % [mini(waves_cleared + 1, _target), _target]
