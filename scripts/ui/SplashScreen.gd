class_name SplashScreen
extends MenuScreen
## Logo and loading bar. Autoloads have already read the save by now; this is
## where the player hears about it if the save had to be reset.

const LOGO_FONT_SIZE := 92
const BAR_SIZE := Vector2(480.0, 20.0)
const WARNING_FONT_SIZE := 28

## How long the logo stays up.
var hold_time: float = 0.9

var _bar: ProgressBar
var _warning: Label
var _ok_button: Button


func _init() -> void:
	plays_menu_music = false


func _build() -> void:
	add_backdrop()
	var column: VBoxContainer = make_centred_column()
	add_label(column, "Sky Skirmish", LOGO_FONT_SIZE, "amber")
	_bar = ProgressBar.new()
	_bar.custom_minimum_size = BAR_SIZE
	_bar.show_percentage = false
	column.add_child(_bar)
	_warning = add_label(column, "", WARNING_FONT_SIZE, "danger")
	_ok_button = add_button(column, "OK", _go_on)
	_ok_button.visible = false
	var tween: Tween = create_tween()
	tween.tween_property(_bar, "value", _bar.max_value, hold_time)
	tween.tween_callback(_finish_loading)


func warning_text() -> String:
	return _warning.text


func ok_button_visible() -> bool:
	return _ok_button.visible


func _finish_loading() -> void:
	var reason: String = ProgressService.reset_reason
	if reason.is_empty():
		_go_on()
		return
	_warning.text = "%s Progress was reset to Level 1." % reason
	_ok_button.visible = true


func _go_on() -> void:
	if GameState.requested_level > 0:
		var level_id: int = GameState.requested_level
		GameState.requested_level = 0
		GameState.start_level(level_id)
	else:
		GameState.go_to(GameState.MAIN_MENU)
