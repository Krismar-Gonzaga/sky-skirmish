class_name PlayerVisual
extends Node2D
## Draws a fighter from AssetMap parts. Purely cosmetic: it reads the pose and
## never changes gameplay state.

const HIT_FLASH_SHADER := preload("res://assets/shaders/hit_flash.gdshader")
const SHOULDER := Vector2(0.0, -44.0)
const NOZZLE := Vector2(-18.0, -24.0)
const FLASH_TIME := 0.14
const FADE_IN_TIME := 0.35
const SWING_ANGLE := 1.3
const SWING_TIME := 0.08

var _body: Node2D
var _torso: Node2D
var _head: Node2D
var _arm: Node2D
var _held_weapon: Node2D
var _held_weapon_id: String = ""
var _flame: CPUParticles2D
var _flash_material: ShaderMaterial
var _swing_offset: float = 0.0


func _ready() -> void:
	_flash_material = ShaderMaterial.new()
	_flash_material.shader = HIT_FLASH_SHADER
	_body = Node2D.new()
	_body.material = _flash_material
	add_child(_body)
	_body.add_child(_create_part("player.jetpack"))
	_body.add_child(_create_part("player.legs"))
	_torso = _create_part("player.torso")
	_body.add_child(_torso)
	_head = _create_part("player.head")
	_body.add_child(_head)
	_arm = _create_part("player.arm")
	_arm.position = SHOULDER
	_body.add_child(_arm)
	_flame = _create_flame()
	_body.add_child(_flame)


## height_ratio is the current body height over the standing height.
func update_pose(aim: Vector2, height_ratio: float, thrusting: bool) -> void:
	var facing: float = -1.0 if aim.x < 0.0 else 1.0
	_body.scale = Vector2(facing, height_ratio)
	_arm.rotation = Vector2(aim.x * facing, aim.y).angle() + _swing_offset
	_flame.emitting = thrusting


func show_weapon(weapon_id: String) -> void:
	if weapon_id == _held_weapon_id:
		return
	_held_weapon_id = weapon_id
	if _held_weapon != null:
		_held_weapon.queue_free()
	_held_weapon = _create_part("weapon.%s" % weapon_id)
	_arm.add_child(_held_weapon)


## Swaps the parts a skin recolours. An unknown skin leaves the default look.
func apply_skin(skin_id: String) -> void:
	_torso = _replace_part(_torso, "skin.%s.torso" % skin_id)
	_head = _replace_part(_head, "skin.%s.head" % skin_id)


func _replace_part(old_part: Node2D, key: String) -> Node2D:
	if not AssetMap.has_sprite(key):
		return old_part
	var new_part: Node2D = _create_part(key)
	_body.add_child(new_part)
	_body.move_child(new_part, old_part.get_index())
	old_part.queue_free()
	return new_part


func flash_hit() -> void:
	var tween: Tween = create_tween()
	_flash_material.set_shader_parameter("flash_amount", 1.0)
	tween.tween_method(_set_flash, 1.0, 0.0, FLASH_TIME)


func swing_arm() -> void:
	var tween: Tween = create_tween()
	tween.tween_method(_set_swing, -SWING_ANGLE, SWING_ANGLE, SWING_TIME)
	tween.tween_method(_set_swing, SWING_ANGLE, 0.0, SWING_TIME)


func hide_body() -> void:
	visible = false
	_flame.emitting = false


func fade_in() -> void:
	visible = true
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, FADE_IN_TIME)


func _set_flash(amount: float) -> void:
	_flash_material.set_shader_parameter("flash_amount", amount)


func _set_swing(angle: float) -> void:
	_swing_offset = angle


func _create_part(key: String) -> Node2D:
	var part: Node2D = AssetMap.create_visual(key)
	# Parts share the body's material so one flash covers the whole fighter.
	part.use_parent_material = true
	return part


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
