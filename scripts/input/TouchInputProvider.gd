class_name TouchInputProvider
extends InputProvider
## Turns the on-screen sticks and buttons into PlayerInput.

var controls: TouchControls

var _dead_zone: float
var _full_speed_at: float
var _jet_threshold: float
var _crouch_threshold: float
var _fire_threshold: float


func _ready() -> void:
	var config: Dictionary = Tuning.section("touch")
	_dead_zone = config["dead_zone"]
	_full_speed_at = config["full_speed_at"]
	_jet_threshold = config["jet_threshold"]
	_crouch_threshold = config["crouch_threshold"]
	_fire_threshold = config["fire_threshold"]
	controls = TouchControls.new()
	controls.stick_scale = Settings.stick_size
	add_child(controls)


func poll(_aim_origin: Vector2) -> PlayerInput:
	var input := PlayerInput.new()
	_read_move_stick(input)
	_read_aim_stick(input)
	input.grenade = controls.grenade_button.poll()
	input.swap = controls.swap_button.poll()
	input.melee = controls.melee_button.poll()
	return input


func _read_move_stick(input: PlayerInput) -> void:
	var stick: Vector2 = controls.move_stick.output
	input.move.y = stick.y
	# Full speed before the rim keeps walking fast when the stick is diagonal,
	# as it usually is while flying.
	if absf(stick.x) >= _dead_zone:
		input.move.x = clampf(stick.x / _full_speed_at, -1.0, 1.0)
	input.jet = stick.y <= -_jet_threshold
	input.crouch = stick.y >= _crouch_threshold


func _read_aim_stick(input: PlayerInput) -> void:
	var released: Vector2 = controls.aim_stick.consume_release()
	if released != Vector2.ZERO:
		input.aim = released.normalized()
		input.fire = true
		return
	var stick: Vector2 = controls.aim_stick.output
	if stick.length() >= _dead_zone:
		input.aim = stick.normalized()
		input.fire = stick.length() >= _fire_threshold
