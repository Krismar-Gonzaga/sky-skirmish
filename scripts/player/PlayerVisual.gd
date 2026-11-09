class_name PlayerVisual
extends Node2D
## Draws a fighter from AssetMap parts. Purely cosmetic: it reads the pose and
## never changes gameplay state.

const SHOULDER := Vector2(0.0, -44.0)
const NOZZLE := Vector2(-18.0, -24.0)

var _body: Node2D
var _arm: Node2D
var _flame: CPUParticles2D


func _ready() -> void:
	_body = Node2D.new()
	add_child(_body)
	for part: String in ["player.jetpack", "player.legs", "player.torso", "player.head"]:
		_body.add_child(AssetMap.create_visual(part))
	_arm = AssetMap.create_visual("player.arm")
	_arm.position = SHOULDER
	_body.add_child(_arm)
	_flame = _create_flame()
	_body.add_child(_flame)


## height_ratio is the current body height over the standing height.
func update_pose(aim: Vector2, height_ratio: float, thrusting: bool) -> void:
	var facing: float = -1.0 if aim.x < 0.0 else 1.0
	_body.scale = Vector2(facing, height_ratio)
	_arm.rotation = Vector2(aim.x * facing, aim.y).angle()
	_flame.emitting = thrusting


func _create_flame() -> CPUParticles2D:
	var flame := CPUParticles2D.new()
	flame.position = NOZZLE
	flame.emitting = false
	flame.local_coords = false
	flame.amount = 28
	flame.lifetime = 0.28
	flame.direction = Vector2.DOWN
	flame.spread = 14.0
	flame.gravity = Vector2.ZERO
	flame.initial_velocity_min = 170.0
	flame.initial_velocity_max = 260.0
	flame.scale_amount_min = 4.0
	flame.scale_amount_max = 8.0
	var ramp := Gradient.new()
	ramp.set_color(0, AssetMap.color("amber"))
	ramp.set_color(1, Color(AssetMap.color("flame"), 0.0))
	flame.color_ramp = ramp
	return flame
