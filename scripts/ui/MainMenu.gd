class_name MainMenu
extends MenuScreen
## Title screen and the hub for everything else.

const TITLE_FONT_SIZE := 84
const NAME_FONT_SIZE := 28


func _build() -> void:
	add_backdrop()
	var column: VBoxContainer = make_centred_column()
	add_label(column, "Sky Skirmish", TITLE_FONT_SIZE, "amber")
	add_label(column, Settings.player_name, NAME_FONT_SIZE, "teal")
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", COLUMN_SPACING)
	column.add_child(row)
	add_button(row, "Campaign", goes_to(GameState.LEVEL_SELECT))
	add_button(row, "Multiplayer", goes_to(GameState.MULTIPLAYER_MENU))
	add_button(row, "Settings", goes_to(GameState.SETTINGS_SCREEN))
	add_button(row, "Credits", goes_to(GameState.CREDITS))


## There is nothing to go back to, so Android's back gesture leaves the app.
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST and is_inside_tree():
		get_tree().quit()
