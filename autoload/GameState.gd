extends Node
## Tracks which level is being played and moves between screens with a fade.
## Developer flags go after --, for example:
## godot --path . -- --level=3 --unlock-all

const SPLASH := "res://scenes/ui/Splash.tscn"
const MAIN_MENU := "res://scenes/ui/MainMenu.tscn"
const LEVEL_SELECT := "res://scenes/ui/LevelSelect.tscn"
const MATCH_SCENE := "res://scenes/game/Match.tscn"
const LEVEL_RESULTS := "res://scenes/ui/LevelResults.tscn"
const MULTIPLAYER_MENU := "res://scenes/ui/MultiplayerMenu.tscn"
const LAN_LOBBY := "res://scenes/ui/LanLobby.tscn"
const ONLINE_LOBBY := "res://scenes/ui/OnlineLobby.tscn"
const MATCH_RESULTS := "res://scenes/ui/MatchResults.tscn"
const SETTINGS_SCREEN := "res://scenes/ui/Settings.tscn"
const CREDITS := "res://scenes/ui/Credits.tscn"

const LEVEL_FLAG := "--level="
const UNLOCK_ALL_FLAG := "--unlock-all"
const FADE_LAYER := 200
const FADE_TIME := 0.18

## Level the next Match should start, or 0.
var pending_level: int = 0
## Set by the --level flag and cleared once used.
var requested_level: int = 0
var last_result: Dictionary = {}
## {"winner": String, "forfeit": bool, "players": [{"name", "kills", "deaths"}]}
var last_match_result: Dictionary = {}
## Tests turn this on to check where a button leads without leaving the scene.
var suppress_scene_changes: bool = false
var last_requested_scene: String = ""

var _fade: ColorRect
var _changing_scene: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_fade()
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with(LEVEL_FLAG):
			requested_level = argument.trim_prefix(LEVEL_FLAG).to_int()
		elif argument == UNLOCK_ALL_FLAG:
			ProgressService.unlock_all_for_session()


func go_to(scene_path: String) -> void:
	last_requested_scene = scene_path
	if suppress_scene_changes or _changing_scene:
		return
	_changing_scene = true
	_fade.mouse_filter = Control.MOUSE_FILTER_STOP
	await _tween_fade(1.0)
	# A pause menu may have sent us here; the next screen must not start frozen.
	get_tree().paused = false
	get_tree().change_scene_to_file(scene_path)
	await get_tree().process_frame
	await _tween_fade(0.0)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_changing_scene = false


func start_level(level_id: int) -> void:
	pending_level = level_id
	go_to(MATCH_SCENE)


func go_to_level_select() -> void:
	go_to(LEVEL_SELECT)


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
	go_to(LEVEL_RESULTS)


func _tween_fade(alpha: float) -> void:
	var tween: Tween = create_tween()
	tween.tween_property(_fade, "color:a", alpha, FADE_TIME)
	await tween.finished


func _build_fade() -> void:
	var layer := CanvasLayer.new()
	layer.layer = FADE_LAYER
	add_child(layer)
	_fade = ColorRect.new()
	_fade.color = Color(AssetMap.color("ink"), 0.0)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(_fade)
