class_name TouchControls
extends CanvasLayer
## Lays out the two sticks and three action buttons in the bottom corners.

const CANVAS_LAYER := 10
## Buttons sit on an arc around the aim stick: left, up-left, up.
const FIRST_BUTTON_ANGLE := PI
const BUTTON_ANGLE_STEP := PI / 4.0

## Multiplier from the Settings stick-size slider. Set before adding to the tree.
var stick_scale: float = 1.0

var move_stick: VirtualStick
var aim_stick: VirtualStick
var melee_button: TouchActionButton
var grenade_button: TouchActionButton
var swap_button: TouchActionButton

var _config: Dictionary


func _ready() -> void:
	layer = CANVAS_LAYER
	_config = Tuning.section("touch")
	move_stick = _add_stick()
	aim_stick = _add_stick()
	melee_button = _add_button("Melee")
	grenade_button = _add_button("Nade")
	swap_button = _add_button("Swap")
	get_viewport().size_changed.connect(_layout)
	_layout()


func set_stick_scale(new_scale: float) -> void:
	stick_scale = new_scale
	_layout()


func _add_stick() -> VirtualStick:
	var stick := VirtualStick.new()
	stick.release_threshold = _config["fire_threshold"]
	add_child(stick)
	return stick


func _add_button(caption: String) -> TouchActionButton:
	var button := TouchActionButton.new()
	button.caption = caption
	button.radius = _config["button_radius"]
	add_child(button)
	return button


func _layout() -> void:
	var view: Vector2 = get_viewport().get_visible_rect().size
	var radius: float = float(_config["stick_radius"]) * stick_scale
	var capture: float = radius * float(_config["capture_factor"])
	var inset: float = radius + float(_config["stick_inset_margin"])
	for stick: VirtualStick in [move_stick, aim_stick]:
		stick.radius = radius
		stick.capture_radius = capture
		stick.queue_redraw()
	move_stick.position = Vector2(inset, view.y - inset)
	aim_stick.position = Vector2(view.x - inset, view.y - inset)
	# Ring distance grows with the stick so a button is never inside its capture zone.
	var button_radius: float = _config["button_radius"]
	var ring: float = capture + button_radius + float(_config["button_gap"])
	var angle: float = FIRST_BUTTON_ANGLE
	for button: TouchActionButton in [melee_button, grenade_button, swap_button]:
		button.position = aim_stick.position + Vector2.from_angle(angle) * ring
		angle += BUTTON_ANGLE_STEP
