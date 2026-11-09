class_name DebugOverlay
extends CanvasLayer
## Developer readout, toggled with F3 or a three-finger tap.

const CANVAS_LAYER := 100
const FONT_SIZE := 20
const TOGGLE_FINGERS := 3
const MARGIN := Vector2(16.0, 16.0)

var watched_player: Player
var level_id: String = "-"

var _label: Label
var _active_touches: Dictionary = {}


func _ready() -> void:
	layer = CANVAS_LAYER
	visible = false
	_label = Label.new()
	_label.position = MARGIN
	_label.add_theme_font_size_override("font_size", FONT_SIZE)
	add_child(_label)


func _input(event: InputEvent) -> void:
	if event is InputEventKey:
		var key := event as InputEventKey
		if key.pressed and not key.echo and key.physical_keycode == KEY_F3:
			visible = not visible
	elif event is InputEventScreenTouch:
		_track_touch(event as InputEventScreenTouch)


func _process(_delta: float) -> void:
	if visible:
		_label.text = "\n".join(_build_lines())


func _track_touch(touch: InputEventScreenTouch) -> void:
	if touch.pressed:
		_active_touches[touch.index] = true
		if _active_touches.size() == TOGGLE_FINGERS:
			visible = not visible
	else:
		_active_touches.erase(touch.index)


func _build_lines() -> PackedStringArray:
	var lines := PackedStringArray([
		"FPS %d" % Engine.get_frames_per_second(),
		"Ping -",
		"Peer %d" % multiplayer.get_unique_id(),
		"Authority %s" % str(multiplayer.is_server()),
		"Level %s" % level_id,
	])
	if watched_player != null:
		lines.append("Velocity %.0f, %.0f" % [watched_player.velocity.x, watched_player.velocity.y])
		lines.append("Fuel %.1f" % watched_player.fuel.amount)
		lines.append("Floor %s  Crouch %s" % [
			str(watched_player.is_on_floor()), str(watched_player.is_crouching),
		])
	return lines
