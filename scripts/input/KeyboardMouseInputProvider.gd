class_name KeyboardMouseInputProvider
extends InputProvider
## Desktop controls for development: A/D walk, W or Space jet, S crouch,
## mouse aims, left click fires, G grenade, Q swap, F melee.


func poll(aim_origin: Vector2) -> PlayerInput:
	var input := PlayerInput.new()
	input.move.x = _axis(KEY_A, KEY_D)
	input.jet = _held(KEY_W) or _held(KEY_SPACE)
	input.crouch = _held(KEY_S)
	input.move.y = _axis(KEY_W, KEY_S)
	input.aim = (_mouse_world_position() - aim_origin).normalized()
	input.fire = Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	input.grenade = _held(KEY_G)
	input.swap = _held(KEY_Q)
	input.melee = _held(KEY_F)
	return input


func _held(key: Key) -> bool:
	return Input.is_physical_key_pressed(key)


func _axis(negative: Key, positive: Key) -> float:
	return float(_held(positive)) - float(_held(negative))


func _mouse_world_position() -> Vector2:
	var viewport: Viewport = get_viewport()
	return viewport.get_canvas_transform().affine_inverse() * viewport.get_mouse_position()
