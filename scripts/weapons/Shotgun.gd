class_name Shotgun
extends Weapon
## Short-range burst of pellets.


func _init(stats: Dictionary) -> void:
	super("shotgun", stats)


## An even fan instead of pure randomness, so a close shot reliably lands.
func _shot_directions(aim: Vector2, rng: RandomNumberGenerator, half_angle: float) -> Array[Vector2]:
	var directions: Array[Vector2] = []
	var gap: float = (half_angle * 2.0) / maxf(pellets - 1, 1)
	for i: int in range(pellets):
		var jitter: float = rng.randf_range(-gap, gap) * 0.25
		directions.append(aim.rotated(-half_angle + gap * i + jitter))
	return directions
