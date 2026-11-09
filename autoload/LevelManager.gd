extends Node
## Loads data/levels.json and builds the mission for a level.

const PATH := "res://data/levels.json"
const MAP_SCENE_PATTERN := "res://scenes/maps/%s.tscn"

var _levels: Dictionary = {}


func _ready() -> void:
	_ensure_loaded()


func level_count() -> int:
	_ensure_loaded()
	return _levels.size()


func level(level_id: int) -> Dictionary:
	_ensure_loaded()
	return _levels.get(level_id, {})


func map_scene_path(map_id: String) -> String:
	return MAP_SCENE_PATTERN % map_id.capitalize()


func create_mission(level_id: int) -> Mission:
	var data: Dictionary = level(level_id)
	var lives: int = int(Tuning.section("campaign")["lives"])
	match data["mission_type"]:
		"tutorial":
			return TutorialMission.new(data, lives)
		"eliminate":
			return EliminateMission.new(data, lives)
		"survive":
			return SurviveMission.new(data, lives)
		"capture":
			return CaptureMission.new(data, lives)
		"boss":
			return BossMission.new(data, lives)
		"gauntlet":
			return GauntletMission.new(data, lives)
	push_error("Unknown mission type in level %d" % level_id)
	return EliminateMission.new(data, lives)


## The player-facing name of a level's reward, or empty if it has none.
func reward_text(level_id: int) -> String:
	var reward: Variant = level(level_id).get("reward")
	if not reward is Dictionary:
		return ""
	var reward_id: String = reward["id"]
	match reward["type"]:
		"weapon":
			return str(WeaponCatalog.stats(reward_id)["display_name"])
		"map":
			return "%s map in multiplayer" % reward_id.capitalize()
		"skin":
			return "\"Sky Ace\" skin"
	return ""


func _ensure_loaded() -> void:
	if not _levels.is_empty():
		return
	var raw: Dictionary = DataFile.load_dictionary(PATH)
	for entry: Dictionary in raw.get("levels", []):
		_levels[int(entry["id"])] = entry
