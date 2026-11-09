class_name TouchActionButton
extends Control
## Round on-screen button that tracks its own touch index, so it works while
## both thumbs are busy on sticks. The position is the button centre.

const IDLE_ALPHA := 0.3
const HELD_ALPHA := 0.7
const FONT_SIZE := 22

var radius: float = 52.0
var caption: String = ""

var _touch_index: int = -1
var _tapped: bool = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _input(event: InputEvent) -> void:
	handle_event(event)


func handle_event(event: InputEvent) -> void:
	if not event is InputEventScreenTouch:
		return
	var touch := event as InputEventScreenTouch
	if touch.pressed:
		if _touch_index < 0 and touch.position.distance_to(global_position) <= radius:
			_touch_index = touch.index
			_tapped = true
			queue_redraw()
	elif touch.index == _touch_index:
		_touch_index = -1
		queue_redraw()


func reset_touch() -> void:
	_touch_index = -1
	_tapped = false
	queue_redraw()


## True while held, and once after a tap too short to span a physics frame.
func poll() -> bool:
	var active: bool = _touch_index >= 0 or _tapped
	_tapped = false
	return active


func _draw() -> void:
	var alpha: float = HELD_ALPHA if _touch_index >= 0 else IDLE_ALPHA
	draw_circle(Vector2.ZERO, radius, Color(AssetMap.color("amber"), alpha))
	var font: Font = get_theme_default_font()
	var width: float = radius * 2.0
	var baseline := Vector2(-radius, FONT_SIZE * 0.35)
	draw_string(font, baseline, caption, HORIZONTAL_ALIGNMENT_CENTER, width, FONT_SIZE,
			AssetMap.color("text"))
