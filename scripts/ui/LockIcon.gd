class_name LockIcon
extends Control
## A padlock drawn as shapes.

const ICON_SIZE := Vector2(40.0, 44.0)
const BODY := Rect2(4.0, 20.0, 32.0, 24.0)
const SHACKLE_CENTRE := Vector2(20.0, 20.0)
const SHACKLE_RADIUS := 11.0
const SHACKLE_WIDTH := 5.0
const ARC_POINTS := 16


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = ICON_SIZE


func _draw() -> void:
	var offset: Vector2 = (size - ICON_SIZE) / 2.0
	var color: Color = AssetMap.color("muted")
	draw_arc(SHACKLE_CENTRE + offset, SHACKLE_RADIUS, PI, TAU, ARC_POINTS, color, SHACKLE_WIDTH)
	draw_rect(Rect2(BODY.position + offset, BODY.size), color)
