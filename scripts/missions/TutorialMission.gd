class_name TutorialMission
extends EliminateMission
## Teaches the controls by hint, then asks for the target dummies.

var _has_walked: bool = false
var _has_flown: bool = false


func note_player_activity(walked: bool, flew: bool) -> void:
	_has_walked = _has_walked or walked
	_has_flown = _has_flown or flew


func objective_text() -> String:
	if not _has_walked:
		return "Walk: left stick left or right"
	if not _has_flown:
		return "Fly: push the left stick up"
	return "Shoot the dummies %d / %d" % [kills, _target]
