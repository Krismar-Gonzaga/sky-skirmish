class_name Tuning
extends RefCounted
## Access to data/tuning.json, so playtest changes never touch code.

const PATH := "res://data/tuning.json"

static var _sections: Dictionary = {}


static func section(section_name: String) -> Dictionary:
	if _sections.is_empty():
		_sections = DataFile.load_dictionary(PATH)
	return _sections.get(section_name, {})
