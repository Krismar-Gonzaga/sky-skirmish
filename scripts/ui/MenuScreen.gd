class_name MenuScreen
extends Control
## Base for full-screen menus: shared layout helpers and the back gesture.

const HEADING_FONT_SIZE := 52
const BODY_FONT_SIZE := 28
const COLUMN_SPACING := 16
const EDGE_MARGIN := 20.0
const GRABBER_DIAMETER := 40

## Scene the back button, Esc and Android back lead to. Empty means no way back.
var back_target: String = ""
var plays_menu_music: bool = true


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	if plays_menu_music:
		AudioManager.play_music("menu")
	_build()


## Subclasses create their contents here.
func _build() -> void:
	pass


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		go_back()


func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		go_back()


func go_back() -> void:
	if not back_target.is_empty():
		GameState.go_to(back_target)


func make_centred_column() -> VBoxContainer:
	var centre := CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(centre)
	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", COLUMN_SPACING)
	centre.add_child(column)
	return column


func add_backdrop() -> void:
	var backdrop := ParallaxBackdrop.new()
	add_child(backdrop)


func add_heading(parent: Control, text: String) -> Label:
	return add_label(parent, text, HEADING_FONT_SIZE, "text")


func add_label(parent: Control, text: String, font_size: int, color_name: String) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", AssetMap.color(color_name))
	parent.add_child(label)
	return label


func add_button(parent: Control, text: String, handler: Callable) -> Button:
	var button := Button.new()
	button.name = text
	button.text = text
	button.pressed.connect(handler)
	parent.add_child(button)
	return button


## Sends the player to a scene. Handy as a button handler.
func goes_to(scene_path: String) -> Callable:
	return GameState.go_to.bind(scene_path)


func add_back_button() -> Button:
	var button: Button = add_button(self, "Back", go_back)
	button.position = Vector2(EDGE_MARGIN, EDGE_MARGIN)
	return button


func make_slider(minimum: float, maximum: float, step: float, value: float) -> HSlider:
	var slider := HSlider.new()
	slider.min_value = minimum
	slider.max_value = maximum
	slider.step = step
	slider.value = value
	var grabber: ImageTexture = _grabber_texture()
	slider.add_theme_icon_override("grabber", grabber)
	slider.add_theme_icon_override("grabber_highlight", grabber)
	return slider


func _grabber_texture() -> ImageTexture:
	var image := Image.create_empty(GRABBER_DIAMETER, GRABBER_DIAMETER, false, Image.FORMAT_RGBA8)
	var radius: float = GRABBER_DIAMETER / 2.0
	var centre := Vector2(radius, radius)
	var color: Color = AssetMap.color("amber")
	for x: int in range(GRABBER_DIAMETER):
		for y: int in range(GRABBER_DIAMETER):
			if Vector2(x + 0.5, y + 0.5).distance_to(centre) <= radius:
				image.set_pixel(x, y, color)
	return ImageTexture.create_from_image(image)
