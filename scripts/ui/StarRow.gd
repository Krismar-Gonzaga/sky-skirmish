class_name StarRow
extends Control
## Three stars drawn as shapes, so no font has to include a star glyph.

const MAX_STARS := 3
const POINTS := 5
const INNER_RATIO := 0.45

var stars: int = 0:
	set(value):
		stars = value
		queue_redraw()
var star_size: float = 40.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(star_size * MAX_STARS, star_size)


func _draw() -> void:
	var start_x: float = (size.x - star_size * MAX_STARS) / 2.0
	for i: int in range(MAX_STARS):
		var centre := Vector2(start_x + star_size * (i + 0.5), size.y / 2.0)
		var color: Color = AssetMap.color("amber" if i < stars else "slate")
		draw_colored_polygon(_star_points(centre), color)


func _star_points(centre: Vector2) -> PackedVector2Array:
	var outer: float = star_size * 0.46
	var points := PackedVector2Array()
	for i: int in range(POINTS * 2):
		var radius: float = outer if i % 2 == 0 else outer * INNER_RATIO
		points.append(centre + Vector2.UP.rotated(TAU * i / (POINTS * 2)) * radius)
	return points
