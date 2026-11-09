class_name DataFile
extends RefCounted
## Reads JSON data files. A bad file is reported, never fatal, so a tuning typo
## during playtests shows an error instead of crashing the phone.


static func load_dictionary(path: String) -> Dictionary:
	var text: String = FileAccess.get_file_as_string(path)
	if text.is_empty():
		push_error("Data file missing or empty: %s" % path)
		return {}
	var parsed: Variant = JSON.parse_string(text)
	if parsed is Dictionary:
		return parsed
	push_error("Data file is not a JSON object: %s" % path)
	return {}
