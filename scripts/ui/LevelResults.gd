class_name LevelResults
extends Control
## Shows how a level went and offers the next step.

const HEADING_FONT_SIZE := 64
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


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build()
	show_result(GameState.last_result)


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
	var centre := CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(centre)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", SPACING)
	centre.add_child(column)
	_heading = _add_label(column, HEADING_FONT_SIZE, "text")
	_stars = StarRow.new()
	_stars.star_size = LARGE_STAR_SIZE
	column.add_child(_stars)
	_time = _add_label(column, INFO_FONT_SIZE, "text")
	_banner = _add_label(column, BANNER_FONT_SIZE, "amber")
	_reward = _add_label(column, INFO_FONT_SIZE, "teal")
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", BUTTON_SPACING)
	column.add_child(buttons)
	next_button = _add_button(buttons, "Next")
	retry_button = _add_button(buttons, "Retry")
	select_button = _add_button(buttons, "Level Select")
	select_button.pressed.connect(GameState.go_to_level_select)


func _add_label(parent: Control, font_size: int, color_name: String) -> Label:
	var label := Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", AssetMap.color(color_name))
	parent.add_child(label)
	return label


func _add_button(parent: Control, caption: String) -> Button:
	var button := Button.new()
	button.text = caption
	parent.add_child(button)
	return button
