class_name VirtualStick
extends Control
## On-screen thumb stick. The position is the stick centre.
## Each stick follows one touch index, so two thumbs never interfere.

const KNOB_RATIO := 0.42
const BASE_ALPHA := 0.22
const KNOB_ALPHA := 0.55

## Stick deflection, from zero to length 1.
var output: Vector2 = Vector2.ZERO
var radius: float = 110.0
var capture_radius: float = 176.0
## A touch lifted at or past this deflection counts as a flick.
var release_threshold: float = 0.7

var _touch_index: int = -1
var _released_vector: Vector2 = Vector2.ZERO


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _input(event: InputEvent) -> void:
	handle_event(event)


func handle_event(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		_handle_touch(event as InputEventScreenTouch)
	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if drag.index == _touch_index:
			_follow(drag.position)


## Returns the deflection of a flick since the last call, or zero.
## Reading clears it, so one flick fires one shot.
func consume_release() -> Vector2:
	var released: Vector2 = _released_vector
	_released_vector = Vector2.ZERO
	return released


func reset_touch() -> void:
	_touch_index = -1
	_released_vector = Vector2.ZERO
	output = Vector2.ZERO
	queue_redraw()


func _handle_touch(touch: InputEventScreenTouch) -> void:
	if touch.pressed:
		var is_free: bool = _touch_index < 0
		if is_free and touch.position.distance_to(global_position) <= capture_radius:
			_touch_index = touch.index
			_follow(touch.position)
	elif touch.index == _touch_index:
		if not touch.canceled and output.length() >= release_threshold:
			_released_vector = output
		_touch_index = -1
		output = Vector2.ZERO
		queue_redraw()


func _follow(touch_position: Vector2) -> void:
	output = ((touch_position - global_position) / radius).limit_length(1.0)
	queue_redraw()


func _draw() -> void:
	var tint: Color = AssetMap.color("text")
	draw_circle(Vector2.ZERO, radius, Color(tint, BASE_ALPHA))
	draw_circle(output * radius, radius * KNOB_RATIO, Color(tint, KNOB_ALPHA))
