class_name LevelResults
extends MenuScreen
## Shows how a level went and offers the next step.

const RESULT_FONT_SIZE := 64
const INFO_FONT_SIZE := 30
const BANNER_FONT_SIZE := 34
const SPACING := 18
const BUTTON_SPACING := 20
const LARGE_STAR_SIZE := 72.0

var next_button: Button
var retry_button: Button
var select_button: Button

var _heading: Label
var _stars: StarRow
var _time: Label
var _banner: Label
var _reward: Label


func show_result(result: Dictionary) -> void:
	if result.is_empty():
		return
	var level_id: int = result["level_id"]
	var cleared: bool = result["cleared"]
	var is_last_level: bool = level_id >= LevelManager.level_count()
	_heading.text = "Level %d Clear!" % level_id if cleared else "Level %d Failed" % level_id
	_stars.stars = result["stars"]
	_stars.visible = cleared
	var whole_seconds: int = roundi(float(result["time"]))
	_time.text = "Time %d:%02d    Deaths %d" % [floori(whole_seconds / 60.0), whole_seconds % 60, result["deaths"]]
	_banner.text = _banner_text(result, is_last_level)
	var reward: String = result.get("reward_text", "")
	_reward.text = "Unlocked: %s" % reward if not reward.is_empty() else ""
	next_button.visible = cleared and not is_last_level
	next_button.pressed.connect(GameState.start_level.bind(level_id + 1), CONNECT_ONE_SHOT)
	retry_button.pressed.connect(GameState.start_level.bind(level_id), CONNECT_ONE_SHOT)


func heading_text() -> String:
	return _heading.text


func banner_text() -> String:
	return _banner.text


func _banner_text(result: Dictionary, is_last_level: bool) -> String:
	if not result["cleared"]:
		return ""
	if is_last_level:
		return "Campaign complete!"
	if result.get("new_level_unlocked", false):
		return "Level %d unlocked!" % (int(result["level_id"]) + 1)
	return ""


func _build() -> void:
	back_target = GameState.LEVEL_SELECT
	var column: VBoxContainer = make_centred_column()
	_heading = add_label(column, "", RESULT_FONT_SIZE, "text")
	_stars = StarRow.new()
	_stars.star_size = LARGE_STAR_SIZE
	column.add_child(_stars)
	_time = add_label(column, "", INFO_FONT_SIZE, "text")
	_banner = add_label(column, "", BANNER_FONT_SIZE, "amber")
	_reward = add_label(column, "", INFO_FONT_SIZE, "teal")
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", BUTTON_SPACING)
	column.add_child(buttons)
	next_button = add_button(buttons, "Next", func() -> void: pass)
	retry_button = add_button(buttons, "Retry", func() -> void: pass)
	select_button = add_button(buttons, "Level Select", goes_to(GameState.LEVEL_SELECT))
	show_result(GameState.last_result)
