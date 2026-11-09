class_name PauseMenu
extends CanvasLayer
## Overlay shown while a campaign level is paused. Keeps running while the rest
## of the game is frozen.

signal resume_requested
signal retry_requested
signal quit_requested

const CANVAS_LAYER := 50
const DIM_ALPHA := 0.7
const HEADING_FONT_SIZE := 52
const SPACING := 18


func _ready() -> void:
	layer = CANVAS_LAYER
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	var dim := ColorRect.new()
	dim.color = Color(AssetMap.color("ink"), DIM_ALPHA)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var centre := CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(centre)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", SPACING)
	centre.add_child(column)
	var heading := Label.new()
	heading.text = "Paused"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", HEADING_FONT_SIZE)
	column.add_child(heading)
	_add_button(column, "Resume", resume_requested)
	_add_button(column, "Retry", retry_requested)
	_add_button(column, "Level Select", quit_requested)


func _add_button(parent: Control, caption: String, event: Signal) -> void:
	var button := Button.new()
	button.name = caption
	button.text = caption
	button.pressed.connect(func() -> void: event.emit())
	parent.add_child(button)
