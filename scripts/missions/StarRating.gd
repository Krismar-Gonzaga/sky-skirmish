class_name StarRating
extends RefCounted
## How many stars a cleared level earns.


## time_counts is false where the clock cannot reflect skill: survive levels
## always end at zero, and some levels have no limit.
static func calculate(deaths: int, time_left: float, time_limit: float, time_counts: bool) -> int:
	if deaths > 1:
		return 1
	if deaths == 1:
		return 2
	if not time_counts:
		return 3
	var required: float = time_limit * float(Tuning.section("campaign")["three_star_time_ratio"])
	return 3 if time_left > required else 2
