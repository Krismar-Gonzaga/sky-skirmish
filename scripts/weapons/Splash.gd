class_name Splash
extends RefCounted
## Splash damage falloff.


## Full damage at the centre, falling linearly to zero at the radius.
static func damage_at(distance: float, radius: float, max_damage: float) -> float:
	if radius <= 0.0 or distance >= radius:
		return 0.0
	return max_damage * (1.0 - maxf(distance, 0.0) / radius)
