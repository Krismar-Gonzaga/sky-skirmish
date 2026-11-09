class_name Player
extends CharacterBody2D
## One fighter. Reads only a PlayerInput, so it does not care whether a thumb,
## a bot or the network is driving it. The origin is at the feet.

## Null means the fighter stands idle.
var input_provider: InputProvider
var fuel: FuelTank
var aim_direction: Vector2 = Vector2.RIGHT
var is_crouching: bool = false
var is_thrusting: bool = false

var _motor: PlayerMotor
var _capsule: CapsuleShape2D
var _stand_height: float
var _crouch_height: float
var _aim_origin_ratio: float

@onready var _body_shape: CollisionShape2D = $BodyShape
@onready var _visual: PlayerVisual = $Visual


func _ready() -> void:
	var config: Dictionary = Tuning.section("player")
	_motor = PlayerMotor.new(config)
	fuel = FuelTank.new(Tuning.section("fuel"))
	_stand_height = config["stand_height"]
	_crouch_height = config["crouch_height"]
	_aim_origin_ratio = config["aim_origin_height_ratio"]
	_capsule = CapsuleShape2D.new()
	_capsule.radius = config["body_radius"]
	_body_shape.shape = _capsule
	_set_body_height(_stand_height)


func _physics_process(delta: float) -> void:
	var input: PlayerInput = PlayerInput.new()
	if input_provider != null:
		input = input_provider.poll(get_aim_origin())
	_update_crouch(input.crouch)
	is_thrusting = fuel.update(delta, input.jet, is_on_floor())
	velocity = _motor.step(velocity, input.move.x, is_on_floor(), is_thrusting, is_crouching, delta)
	move_and_slide()
	if input.aim != Vector2.ZERO:
		aim_direction = input.aim.normalized()
	_visual.update_pose(aim_direction, _capsule.height / _stand_height, is_thrusting)


func get_aim_origin() -> Vector2:
	return global_position + Vector2.UP * _capsule.height * _aim_origin_ratio


func _update_crouch(wants_crouch: bool) -> void:
	var should_crouch: bool = wants_crouch and is_on_floor()
	if should_crouch and not is_crouching:
		is_crouching = true
		_set_body_height(_crouch_height)
	elif is_crouching and not should_crouch and _has_headroom():
		is_crouching = false
		_set_body_height(_stand_height)


func _has_headroom() -> bool:
	var rise := Vector2.UP * (_stand_height - _crouch_height)
	return not test_move(global_transform, rise)


func _set_body_height(height: float) -> void:
	_capsule.height = height
	_body_shape.position.y = -height / 2.0
