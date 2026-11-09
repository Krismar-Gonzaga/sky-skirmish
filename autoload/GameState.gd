extends Node
## Tracks which level is being played and routes its outcome to the save and
## the right screen. Developer flags go after --, for example:
## godot --path . -- --level=3 --unlock-all

const MATCH_SCENE := "res://scenes/game/Match.tscn"
const LEVEL_SELECT_SCENE := "res://scenes/ui/LevelSelect.tscn"
const LEVEL_RESULTS_SCENE := "res://scenes/ui/LevelResults.tscn"
const LEVEL_FLAG := "--level="
const UNLOCK_ALL_FLAG := "--unlock-all"

## Level the next Match should start, or 0.
var pending_level: int = 0
## Set by the --level flag and cleared once used.
var requested_level: int = 0
var last_result: Dictionary = {}


func _ready() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with(LEVEL_FLAG):
			requested_level = argument.trim_prefix(LEVEL_FLAG).to_int()
		elif argument == UNLOCK_ALL_FLAG:
			ProgressService.unlock_all_for_session()


func start_level(level_id: int) -> void:
	pending_level = level_id
	get_tree().change_scene_to_file(MATCH_SCENE)


func go_to_level_select() -> void:
	get_tree().change_scene_to_file(LEVEL_SELECT_SCENE)


## Saves the outcome of a level. A failed level changes nothing but kill stats.
func record_level_result(result: Dictionary) -> void:
	var level_id: int = result["level_id"]
	var opened_new_level: bool = false
	if result["cleared"]:
		opened_new_level = ProgressService.complete_level(level_id, result["stars"], result["time"])
	ProgressService.add_kills(result["kills"])
	last_result = result.duplicate()
	last_result["new_level_unlocked"] = opened_new_level
	last_result["reward_text"] = LevelManager.reward_text(level_id) if result["cleared"] else ""


func finish_level(result: Dictionary) -> void:
	record_level_result(result)
	get_tree().change_scene_to_file(LEVEL_RESULTS_SCENE)
