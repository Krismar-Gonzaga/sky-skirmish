class_name Difficulty
extends RefCounted
## Access to data/difficulty.json.

const PATH := "res://data/difficulty.json"

static var _data: Dictionary = {}


static func stats(difficulty_id: String) -> Dictionary:
	if _data.is_empty():
		_data = DataFile.load_dictionary(PATH)
	return _data[difficulty_id]
