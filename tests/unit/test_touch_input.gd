extends GutTest
## Multi-touch behaviour of the sticks, buttons and the touch provider.

var provider: TouchInputProvider
var controls: TouchControls


func before_each() -> void:
	provider = TouchInputProvider.new()
	add_child_autofree(provider)
	controls = provider.controls


func _touch(index: int, position: Vector2, pressed: bool) -> InputEventScreenTouch:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = position
	event.pressed = pressed
	return event


func _drag(index: int, position: Vector2) -> InputEventScreenDrag:
	var event := InputEventScreenDrag.new()
	event.index = index
	event.position = position
	return event


func _send(event: InputEvent) -> void:
	for node: Node in controls.get_children():
		if node is VirtualStick:
			(node as VirtualStick).handle_event(event)
		elif node is TouchActionButton:
			(node as TouchActionButton).handle_event(event)


func _at(stick: VirtualStick, deflection: Vector2) -> Vector2:
	return stick.global_position + deflection * stick.radius


func test_two_thumbs_drive_their_own_sticks() -> void:
	var left: VirtualStick = controls.move_stick
	var right: VirtualStick = controls.aim_stick
	_send(_touch(0, _at(left, Vector2.ZERO), true))
	_send(_touch(1, _at(right, Vector2.ZERO), true))
	_send(_drag(0, _at(left, Vector2(-0.5, 0.0))))
	_send(_drag(1, _at(right, Vector2(0.0, -0.5))))
	assert_almost_eq(left.output.x, -0.5, 0.001)
	assert_almost_eq(right.output.y, -0.5, 0.001)
	assert_almost_eq(left.output.y, 0.0, 0.001)
	assert_almost_eq(right.output.x, 0.0, 0.001)


func test_lifting_one_thumb_leaves_the_other_stick_active() -> void:
	var left: VirtualStick = controls.move_stick
	var right: VirtualStick = controls.aim_stick
	_send(_touch(0, _at(left, Vector2(0.5, 0.0)), true))
	_send(_touch(1, _at(right, Vector2(0.5, 0.0)), true))
	_send(_touch(1, _at(right, Vector2(0.5, 0.0)), false))
	assert_almost_eq(left.output.x, 0.5, 0.001)
	assert_eq(right.output, Vector2.ZERO)


func test_second_finger_cannot_steal_a_held_stick() -> void:
	var left: VirtualStick = controls.move_stick
	_send(_touch(0, _at(left, Vector2(0.5, 0.0)), true))
	_send(_touch(1, _at(left, Vector2(-0.5, 0.0)), true))
	_send(_drag(1, _at(left, Vector2(-1.0, 0.0))))
	assert_almost_eq(left.output.x, 0.5, 0.001)


func test_output_is_limited_to_unit_length() -> void:
	var left: VirtualStick = controls.move_stick
	_send(_touch(0, _at(left, Vector2.ZERO), true))
	_send(_drag(0, _at(left, Vector2(5.0, 5.0))))
	assert_almost_eq(left.output.length(), 1.0, 0.001)


func test_touch_away_from_controls_is_ignored() -> void:
	_send(_touch(0, Vector2(640.0, 100.0), true))
	assert_eq(controls.move_stick.output, Vector2.ZERO)
	assert_eq(controls.aim_stick.output, Vector2.ZERO)


func test_stick_up_jets_and_down_crouches() -> void:
	var left: VirtualStick = controls.move_stick
	_send(_touch(0, _at(left, Vector2(0.0, -0.8)), true))
	var up: PlayerInput = provider.poll(Vector2.ZERO)
	assert_true(up.jet)
	assert_false(up.crouch)
	_send(_drag(0, _at(left, Vector2(0.0, 0.8))))
	var down: PlayerInput = provider.poll(Vector2.ZERO)
	assert_false(down.jet)
	assert_true(down.crouch)


func test_diagonal_stick_still_walks_at_full_speed() -> void:
	var left: VirtualStick = controls.move_stick
	_send(_touch(0, _at(left, Vector2(0.75, -0.6)), true))
	assert_eq(provider.poll(Vector2.ZERO).move.x, 1.0)


func test_dead_zone_stops_drift() -> void:
	var left: VirtualStick = controls.move_stick
	_send(_touch(0, _at(left, Vector2(0.1, 0.0)), true))
	assert_eq(provider.poll(Vector2.ZERO).move.x, 0.0)


func test_aim_below_70_percent_does_not_fire() -> void:
	var right: VirtualStick = controls.aim_stick
	_send(_touch(0, _at(right, Vector2(0.5, 0.0)), true))
	var input: PlayerInput = provider.poll(Vector2.ZERO)
	assert_eq(input.aim, Vector2.RIGHT)
	assert_false(input.fire)


func test_aim_past_70_percent_auto_fires_while_held() -> void:
	var right: VirtualStick = controls.aim_stick
	_send(_touch(0, _at(right, Vector2(0.9, 0.0)), true))
	assert_true(provider.poll(Vector2.ZERO).fire)
	assert_true(provider.poll(Vector2.ZERO).fire)


func test_flick_faster_than_a_frame_fires_exactly_once() -> void:
	var right: VirtualStick = controls.aim_stick
	_send(_touch(0, _at(right, Vector2(0.0, 0.9)), true))
	_send(_touch(0, _at(right, Vector2(0.0, 0.9)), false))
	var shot: PlayerInput = provider.poll(Vector2.ZERO)
	assert_true(shot.fire)
	assert_eq(shot.aim, Vector2.DOWN)
	assert_false(provider.poll(Vector2.ZERO).fire)


func test_release_below_threshold_does_not_fire() -> void:
	var right: VirtualStick = controls.aim_stick
	_send(_touch(0, _at(right, Vector2(0.4, 0.0)), true))
	_send(_touch(0, _at(right, Vector2(0.4, 0.0)), false))
	assert_false(provider.poll(Vector2.ZERO).fire)


func test_button_works_while_both_sticks_are_held() -> void:
	_send(_touch(0, _at(controls.move_stick, Vector2.ZERO), true))
	_send(_touch(1, _at(controls.aim_stick, Vector2.ZERO), true))
	_send(_touch(2, controls.grenade_button.global_position, true))
	assert_true(provider.poll(Vector2.ZERO).grenade)


func test_very_short_button_tap_is_not_lost() -> void:
	var button: TouchActionButton = controls.swap_button
	_send(_touch(0, button.global_position, true))
	_send(_touch(0, button.global_position, false))
	assert_true(provider.poll(Vector2.ZERO).swap)
	assert_false(provider.poll(Vector2.ZERO).swap)


func test_buttons_stay_outside_stick_capture_at_every_size() -> void:
	for scale_factor: float in [0.6, 1.0, 1.4]:
		controls.set_stick_scale(scale_factor)
		var stick: VirtualStick = controls.aim_stick
		for button: TouchActionButton in [
			controls.melee_button, controls.grenade_button, controls.swap_button,
		]:
			var gap: float = button.global_position.distance_to(stick.global_position)
			assert_gt(gap, stick.capture_radius + button.radius)


func test_buttons_meet_touch_target() -> void:
	assert_gte(controls.melee_button.radius * 2.0, 96.0)
