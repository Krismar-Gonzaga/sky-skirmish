class_name LevelSelect
extends MenuScreen
## The campaign map: one card per level, locked until the previous one is clear.

const COLUMNS := 5
const CARD_SIZE := Vector2(224.0, 216.0)
const CARD_SPACING := 14
const TITLE_FONT_SIZE := 44
const CARD_NUMBER_FONT_SIZE := 30
const CARD_TITLE_FONT_SIZE := 20
const MESSAGE_FONT_SIZE := 26
const LOCKED_TINT := Color(0.55, 0.55, 0.62)

var _cards: Dictionary = {}
var _message: Label


## Returns true if the level starts. A locked level only shows a message.
func select_level(level_id: int) -> bool:
	if not ProgressService.is_unlocked(level_id):
		_message.text = "Clear Level %d first." % (level_id - 1)
		return false
	GameState.start_level(level_id)
	return true


func card(level_id: int) -> Button:
	return _cards[level_id]


func message_text() -> String:
	return _message.text


func _build() -> void:
	back_target = GameState.MAIN_MENU
	var centre := CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(centre)
	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", CARD_SPACING)
	centre.add_child(column)
	var title := Label.new()
	title.text = "Campaign"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", TITLE_FONT_SIZE)
	column.add_child(title)
	var grid := GridContainer.new()
	grid.columns = COLUMNS
	grid.add_theme_constant_override("h_separation", CARD_SPACING)
	grid.add_theme_constant_override("v_separation", CARD_SPACING)
	column.add_child(grid)
	for level_id: int in range(1, LevelManager.level_count() + 1):
		grid.add_child(_build_card(level_id))
	_message = Label.new()
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message.custom_minimum_size.y = MESSAGE_FONT_SIZE * 1.5
	_message.add_theme_font_size_override("font_size", MESSAGE_FONT_SIZE)
	_message.add_theme_color_override("font_color", AssetMap.color("amber"))
	column.add_child(_message)
	add_back_button()


func _build_card(level_id: int) -> Button:
	var button := Button.new()
	button.custom_minimum_size = CARD_SIZE
	button.pressed.connect(select_level.bind(level_id))
	var unlocked: bool = ProgressService.is_unlocked(level_id)
	if not unlocked:
		button.modulate = LOCKED_TINT
	var content := VBoxContainer.new()
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.set_anchors_preset(Control.PRESET_FULL_RECT)
	button.add_child(content)
	content.add_child(_card_label("Level %d" % level_id, CARD_NUMBER_FONT_SIZE))
	content.add_child(_card_label(str(LevelManager.level(level_id)["title"]), CARD_TITLE_FONT_SIZE))
	if unlocked:
		var row := StarRow.new()
		row.stars = ProgressService.stars_for(level_id)
		content.add_child(row)
	else:
		var lock := LockIcon.new()
		lock.name = "Lock"
		content.add_child(lock)
	_cards[level_id] = button
	return button


func _card_label(text: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	return label
