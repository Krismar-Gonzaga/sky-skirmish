class_name AimCamera
extends Camera2D
## Follows a fighter and leads toward where they aim, so a phone screen shows
## more of what the player is shooting at. Also owns screen shake.

var target: Player

var _aim_lead: float
var _follow_rate: float
var _zoom_rate: float
var _shake_max_offset: float
var _shake_decay: float
var _trauma: float = 0.0


func _ready() -> void:
	var config: Dictionary = Tuning.section("camera")
	_aim_lead = config["aim_lead"]
	_follow_rate = config["follow_rate"]
	_zoom_rate = config["zoom_rate"]
	_shake_max_offset = config["shake_max_offset"]
	_shake_decay = config["shake_decay"]
	process_callback = Camera2D.CAMERA2D_PROCESS_PHYSICS
	process_physics_priority = 10


func _physics_process(delta: float) -> void:
	if target == null:
		return
	var blend: float = 1.0 - exp(-_follow_rate * delta)
	global_position = global_position.lerp(_desired_position(), blend)
	var zoom_blend: float = 1.0 - exp(-_zoom_rate * delta)
	zoom = zoom.lerp(Vector2.ONE * _desired_zoom(), zoom_blend)
	_update_shake(delta)


## Trauma is squared when applied, so small hits barely shake and big ones do.
func add_trauma(amount: float) -> void:
	_trauma = minf(_trauma + amount, 1.0)


func set_bounds(bounds: Rect2) -> void:
	limit_left = int(bounds.position.x)
	limit_top = int(bounds.position.y)
	limit_right = int(bounds.end.x)
	limit_bottom = int(bounds.end.y)


func snap_to_target() -> void:
	global_position = _desired_position()
	reset_smoothing()


func _update_shake(delta: float) -> void:
	_trauma = maxf(_trauma - _shake_decay * delta, 0.0)
	var strength: float = _trauma * _trauma * _shake_max_offset
	offset = Vector2(randf_range(-strength, strength), randf_range(-strength, strength))


func _desired_position() -> Vector2:
	var lead: float = _aim_lead
	if target.is_aiming:
		lead *= target.loadout.active().aim_lead_factor
	return target.get_aim_origin() + target.aim_direction * lead


func _desired_zoom() -> float:
	return target.loadout.active().view_zoom if target.is_aiming else 1.0
