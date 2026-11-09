class_name SnapshotBuffer
extends RefCounted
## Recent positions from the host. Sampling slightly in the past lets a client
## glide between 20 Hz updates instead of jumping at each one.

const CAPACITY := 12

var _times: Array[float] = []
var _positions: Array[Vector2] = []


func push(time: float, position: Vector2) -> void:
	_times.append(time)
	_positions.append(position)
	if _times.size() > CAPACITY:
		_times.pop_front()
		_positions.pop_front()


func clear() -> void:
	_times.clear()
	_positions.clear()


func is_empty() -> bool:
	return _times.is_empty()


func sample(time: float) -> Vector2:
	if time <= _times[0]:
		return _positions[0]
	for i: int in range(1, _times.size()):
		if time <= _times[i]:
			var span: float = _times[i] - _times[i - 1]
			var blend: float = (time - _times[i - 1]) / span if span > 0.0 else 1.0
			return _positions[i - 1].lerp(_positions[i], blend)
	return _positions[_positions.size() - 1]
