class_name MapChooser
extends HBoxContainer
## The host's row of map buttons. Maps not yet earned in the campaign are locked.

const MAP_IDS: Array[String] = ["outpost", "canyon", "skyforge"]
const SPACING := 12

var chosen_map: String = "outpost"

var _buttons: Dictionary = {}


func _ready() -> void:
	alignment = BoxContainer.ALIGNMENT_CENTER
	add_theme_constant_override("separation", SPACING)
	for map_id: String in MAP_IDS:
		var map_button := Button.new()
		map_button.text = map_id.capitalize()
		map_button.disabled = not ProgressService.is_map_unlocked(map_id)
		map_button.pressed.connect(_choose.bind(map_id))
		add_child(map_button)
		_buttons[map_id] = map_button
	_choose(chosen_map)


func button(map_id: String) -> Button:
	return _buttons[map_id]


func _choose(map_id: String) -> void:
	chosen_map = map_id
	for each: String in _buttons:
		var map_button: Button = _buttons[each]
		map_button.modulate = AssetMap.color("amber") if each == map_id else Color.WHITE
