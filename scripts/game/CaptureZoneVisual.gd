class_name CaptureZoneVisual
extends Node2D
## Outlines the capture area and shows who holds it.

const FILL_ALPHA := 0.18
const OUTLINE_WIDTH := 4.0

var _area: Rect2 = Rect2()
var _color_name: String = "muted"


func show_area(area: Rect2) -> void:
	_area = area
	queue_redraw()


func set_state(player_inside: bool, enemy_inside: bool) -> void:
	var next_color: String = "muted"
	if enemy_inside:
		next_color = "danger"
	elif player_inside:
		next_color = "moss"
	if next_color != _color_name:
		_color_name = next_color
		queue_redraw()


func _draw() -> void:
	var color: Color = AssetMap.color(_color_name)
	draw_rect(_area, Color(color, FILL_ALPHA))
	draw_rect(_area, color, false, OUTLINE_WIDTH)
