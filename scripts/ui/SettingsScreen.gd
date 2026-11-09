class_name SettingsScreen
extends MenuScreen
## Edits Settings. Changes apply at once so they can be heard; Save keeps them
## and leaving without saving puts the old values back.

const LABEL_FONT_SIZE := 24
const SLIDER_SIZE := Vector2(400.0, 72.0)
const FIELD_WIDTH := 400.0
const COLUMN_GAP := 56
const SKY_ACE := "sky_ace"

var music_slider: HSlider
var sfx_slider: HSlider
var stick_slider: HSlider
var aim_assist_button: Button
var name_field: LineEdit
var skin_button: Button


func _build() -> void:
	back_target = GameState.MAIN_MENU
	add_back_button()
	var page: VBoxContainer = make_centred_column()
	add_heading(page, "Settings")
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", COLUMN_GAP)
	page.add_child(columns)
	var left := VBoxContainer.new()
	var right := VBoxContainer.new()
	columns.add_child(left)
	columns.add_child(right)
	music_slider = _add_slider(left, "Music", 0.0, 1.0, 0.05, Settings.music, _on_music_changed)
	sfx_slider = _add_slider(left, "Sound effects", 0.0, 1.0, 0.05, Settings.sfx, _on_sfx_changed)
	stick_slider = _add_slider(left, "Stick size", 0.6, 1.4, 0.1, Settings.stick_size, _on_stick_changed)
	_build_right_column(right)
	add_button(page, "Save", save_and_leave)


func go_back() -> void:
	Settings.load_from_save()
	super()


func save_and_leave() -> void:
	Settings.save()
	GameState.go_to(back_target)


func _build_right_column(column: VBoxContainer) -> void:
	add_label(column, "Player name", LABEL_FONT_SIZE, "muted")
	name_field = LineEdit.new()
	name_field.text = Settings.player_name
	name_field.max_length = Settings.MAX_NAME_LENGTH
	name_field.custom_minimum_size.x = FIELD_WIDTH
	name_field.text_changed.connect(_on_name_changed)
	column.add_child(name_field)
	aim_assist_button = add_button(column, "Aim assist", _on_aim_assist_toggled)
	_refresh_aim_assist_caption()
	skin_button = add_button(column, "Skin", _on_skin_toggled)
	skin_button.visible = ProgressService.is_skin_unlocked(SKY_ACE)
	_refresh_skin_caption()


func _add_slider(parent: Control, caption: String, low: float, high: float, step: float,
		value: float, on_change: Callable) -> HSlider:
	add_label(parent, caption, LABEL_FONT_SIZE, "muted")
	var slider: HSlider = make_slider(low, high, step, value)
	slider.custom_minimum_size = SLIDER_SIZE
	slider.value_changed.connect(on_change)
	parent.add_child(slider)
	return slider


func _on_music_changed(value: float) -> void:
	Settings.music = value
	Settings.apply_audio()


func _on_sfx_changed(value: float) -> void:
	Settings.sfx = value
	Settings.apply_audio()
	AudioManager.play("pickup")


func _on_stick_changed(value: float) -> void:
	Settings.stick_size = value


func _on_name_changed(new_name: String) -> void:
	Settings.player_name = new_name.strip_edges()


func _on_aim_assist_toggled() -> void:
	Settings.aim_assist = not Settings.aim_assist
	_refresh_aim_assist_caption()


func _on_skin_toggled() -> void:
	Settings.selected_skin = "" if Settings.selected_skin == SKY_ACE else SKY_ACE
	_refresh_skin_caption()


func _refresh_aim_assist_caption() -> void:
	aim_assist_button.text = "Aim assist: %s" % ("On" if Settings.aim_assist else "Off")


func _refresh_skin_caption() -> void:
	skin_button.text = "Sky Ace skin: %s" % ("On" if Settings.selected_skin == SKY_ACE else "Off")
