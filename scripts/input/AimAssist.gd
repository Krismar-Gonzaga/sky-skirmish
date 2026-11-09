class_name AimAssist
extends RefCounted
## Nudges a thumb's rough aim toward a nearby target.


## strength 0 leaves the aim alone; 1 points exactly at the target.
static func adjust(aim: Vector2, origin: Vector2, targets: Array[Vector2],
		max_angle: float, max_range: float, strength: float) -> Vector2:
	var best_difference: float = 0.0
	var found: bool = false
	var smallest: float = max_angle
	for target: Vector2 in targets:
		var offset: Vector2 = target - origin
		if offset.length() > max_range or offset == Vector2.ZERO:
			continue
		var difference: float = aim.angle_to(offset)
		if absf(difference) <= smallest:
			smallest = absf(difference)
			best_difference = difference
			found = true
	return aim.rotated(best_difference * strength) if found else aim
