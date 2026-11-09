extends SceneTree
## Runs inside an exported game pack to prove it is complete: every data file,
## screen and level must load with no project folder present.
## Classes are reached through load(), because -s scripts compile before autoloads exist.

const DATA_FILES: Array[String] = [
	"res://data/tuning.json", "res://data/weapons.json", "res://data/levels.json",
	"res://data/difficulty.json", "res://data/credits.json", "res://data/maps/outpost.json",
	"res://data/maps/canyon.json", "res://data/maps/skyforge.json", "res://assets/asset_map.json",
]
const SCREENS: Array[String] = [
	"Splash", "MainMenu", "LevelSelect", "LevelResults", "MultiplayerMenu",
	"LanLobby", "OnlineLobby", "MatchResults", "Settings", "Credits",
]
const LEVEL_COUNT := 10
const FRAMES_PER_ITEM := 10

var _problems: PackedStringArray = PackedStringArray()


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	root.get_node("GameState").suppress_scene_changes = true
	root.get_node("ProgressService").use_directory("user://test_saves/export_check")
	root.get_node("ProgressService").load_save()
	for path: String in DATA_FILES:
		if not FileAccess.file_exists(path):
			_problems.append("missing " + path)
	for screen_name: String in SCREENS:
		await _try_scene("res://scenes/ui/%s.tscn" % screen_name)
	for level_id: int in range(1, LEVEL_COUNT + 1):
		await _try_level(level_id)
	root.get_node("ProgressService").use_directory("user://")
	if _problems.is_empty():
		print("EXPORT_CHECK PASS")
		quit(0)
	else:
		print("EXPORT_CHECK FAIL: ", ", ".join(_problems))
		quit(1)


func _try_scene(path: String) -> void:
	var packed: PackedScene = load(path) as PackedScene
	if packed == null:
		_problems.append("cannot load " + path)
		return
	var node: Node = packed.instantiate()
	root.add_child(node)
	for i: int in range(FRAMES_PER_ITEM):
		await process_frame
	node.queue_free()
	await process_frame


func _try_level(level_id: int) -> void:
	var game: Node = (load("res://scenes/game/Match.tscn") as PackedScene).instantiate()
	root.add_child(game)
	game.begin_campaign(level_id)
	for i: int in range(FRAMES_PER_ITEM):
		await process_frame
	if game.local_player == null or game.map == null:
		_problems.append("level %d did not start" % level_id)
	game.queue_free()
	await process_frame
