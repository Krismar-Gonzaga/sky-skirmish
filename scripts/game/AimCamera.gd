class_name AimCamera
extends Camera2D
## Follows a fighter and leads toward where they aim, so a phone screen shows
## more of what the player is shooting at.

var target: Player

var _aim_lead: float
var _follow_rate: float


func _ready() -> void:
	var config: Dictionary = Tuning.section("camera")
	_aim_lead = config["aim_lead"]
	_follow_rate = config["follow_rate"]
	process_callback = Camera2D.CAMERA2D_PROCESS_PHYSICS
	process_physics_priority = 10


func _physics_process(delta: float) -> void:
	if target == null:
		return
	var blend: float = 1.0 - exp(-_follow_rate * delta)
	global_position = global_position.lerp(_desired_position(), blend)


func set_bounds(bounds: Rect2) -> void:
	limit_left = int(bounds.position.x)
	limit_top = int(bounds.position.y)
	limit_right = int(bounds.end.x)
	limit_bottom = int(bounds.end.y)


func snap_to_target() -> void:
	global_position = _desired_position()
	reset_smoothing()


func _desired_position() -> Vector2:
	return target.get_aim_origin() + target.aim_direction * _aim_lead
