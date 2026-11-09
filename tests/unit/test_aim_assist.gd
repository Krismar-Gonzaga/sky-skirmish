extends GutTest

const MAX_ANGLE := 0.2
const MAX_RANGE := 900.0


func _adjust(aim: Vector2, targets: Array[Vector2], strength: float = 1.0) -> Vector2:
	return AimAssist.adjust(aim, Vector2.ZERO, targets, MAX_ANGLE, MAX_RANGE, strength)


func test_no_targets_leaves_aim_alone() -> void:
	var none: Array[Vector2] = []
	assert_eq(_adjust(Vector2.RIGHT, none), Vector2.RIGHT)


func test_snaps_to_a_target_inside_the_cone() -> void:
	var target := Vector2(500.0, 50.0)
	var targets: Array[Vector2] = [target]
	assert_almost_eq(_adjust(Vector2.RIGHT, targets).angle(), target.angle(), 0.0001)


func test_strength_blends_toward_the_target() -> void:
	var target := Vector2(500.0, 50.0)
	var targets: Array[Vector2] = [target]
	assert_almost_eq(_adjust(Vector2.RIGHT, targets, 0.5).angle(), target.angle() * 0.5, 0.0001)


func test_ignores_a_target_outside_the_cone() -> void:
	var targets: Array[Vector2] = [Vector2(0.0, 500.0)]
	assert_eq(_adjust(Vector2.RIGHT, targets), Vector2.RIGHT)


func test_ignores_a_target_out_of_range() -> void:
	var targets: Array[Vector2] = [Vector2(5000.0, 0.0)]
	var aim: Vector2 = Vector2.RIGHT.rotated(0.1)
	assert_eq(_adjust(aim, targets), aim)


func test_chooses_the_target_closest_to_the_aim() -> void:
	var near := Vector2(500.0, 20.0)
	var targets: Array[Vector2] = [Vector2(500.0, 90.0), near]
	assert_almost_eq(_adjust(Vector2.RIGHT, targets).angle(), near.angle(), 0.0001)


func test_touch_reset_forgets_held_controls() -> void:
	var provider := TouchInputProvider.new()
	add_child_autofree(provider)
	var touch := InputEventScreenTouch.new()
	touch.pressed = true
	touch.position = provider.controls.aim_stick.global_position + Vector2(100.0, 0.0)
	provider.controls.aim_stick.handle_event(touch)
	assert_true(provider.poll(Vector2.ZERO).fire)
	provider.reset()
	assert_false(provider.poll(Vector2.ZERO).fire)
