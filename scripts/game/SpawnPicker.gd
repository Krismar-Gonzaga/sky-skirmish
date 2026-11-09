class_name SpawnPicker
extends RefCounted
## Chooses where a fighter comes back into the fight.


## The spawn whose nearest threat is farthest away.
## With no threats, any spawn is as good as another, so the first is used.
static func farthest_from(spawns: Array[Vector2], threats: Array[Vector2]) -> Vector2:
	var best: Vector2 = spawns[0]
	var best_distance: float = -1.0
	for spawn: Vector2 in spawns:
		var nearest: float = INF
		for threat: Vector2 in threats:
			nearest = minf(nearest, spawn.distance_to(threat))
		if nearest > best_distance:
			best_distance = nearest
			best = spawn
	return best
