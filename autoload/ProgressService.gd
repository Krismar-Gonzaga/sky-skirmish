extends Node
## Reads and writes user://save.json and answers what the player has unlocked.
## A missing, damaged or hand-edited save must never crash the game: it falls
## back to a fresh save and reset_reason tells the UI to warn the player.

signal progress_changed

const CURRENT_VERSION := 1
const DEFAULT_DIRECTORY := "user://"
const SAVE_FILE := "save.json"
const TEMP_FILE := "save.tmp"
const SALT := "sky-skirmish:itsd85:f3a91c"
const HASH_KEY := "hash"
const DEFAULT_WEAPON := "pistol"
const DEFAULT_MAP := "outpost"
## best_time is rounded so a save hashes the same after a JSON round trip.
const TIME_PRECISION := 0.001

var data: Dictionary = {}
## Why the last load discarded the save, or empty if it did not.
var reset_reason: String = ""

var _directory: String = DEFAULT_DIRECTORY
var _unlock_all_this_session: bool = false


func _ready() -> void:
	load_save()


## Points the service at another folder, so tests never touch a real save.
func use_directory(directory: String) -> void:
	_directory = directory
	_unlock_all_this_session = false
	DirAccess.make_dir_recursive_absolute(directory)


func load_save() -> void:
	reset_reason = ""
	if not FileAccess.file_exists(_save_path()):
		data = _fresh_save()
		return
	# A power cut can leave a file full of zeros, and decoding those logs errors.
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(_save_path())
	if bytes.has(0):
		_discard("The save file was damaged.")
		return
	# JSON.new().parse reports problems quietly; parse_string would log an error.
	var json := JSON.new()
	if json.parse(bytes.get_string_from_utf8()) != OK:
		_discard("The save file was damaged.")
		return
	var loaded: Variant = json.data
	if not _has_valid_shape(loaded):
		_discard("The save file was damaged.")
		return
	if str(loaded.get(HASH_KEY, "")) != _compute_hash(loaded):
		_discard("The save file was changed outside the game.")
		return
	data = _upgraded(loaded)


func save() -> bool:
	data[HASH_KEY] = _compute_hash(data)
	var temp_path: String = _directory.path_join(TEMP_FILE)
	var file: FileAccess = FileAccess.open(temp_path, FileAccess.WRITE)
	if file == null:
		push_warning("Could not write the save: %s" % error_string(FileAccess.get_open_error()))
		return false
	file.store_string(JSON.stringify(data, "\t", true))
	file.close()
	# Writing beside the save and renaming means a crash leaves the old save intact.
	return DirAccess.rename_absolute(temp_path, _save_path()) == OK


func unlocked_level() -> int:
	return LevelManager.level_count() if _unlock_all_this_session else int(data["unlocked_level"])


func is_unlocked(level_id: int) -> bool:
	return level_id <= unlocked_level()


func stars_for(level_id: int) -> int:
	return int(data["levels"].get(str(level_id), {}).get("stars", 0))


func best_time_for(level_id: int) -> float:
	return float(data["levels"].get(str(level_id), {}).get("best_time", 0.0))


## Weapons random crates may contain in the campaign.
func crate_pool() -> Array[String]:
	var pool: Array[String] = []
	for weapon_id: String in data["unlocked_weapons"]:
		if weapon_id != DEFAULT_WEAPON:
			pool.append(weapon_id)
	return pool


func is_map_unlocked(map_id: String) -> bool:
	return map_id in data["unlocked_maps"]


func is_skin_unlocked(skin_id: String) -> bool:
	return skin_id in data["unlocked_skins"]


## Records a clear and returns true if it opened a new level.
func complete_level(level_id: int, stars: int, time: float) -> bool:
	var key: String = str(level_id)
	var previous: Dictionary = data["levels"].get(key, {})
	var best_time: float = time
	if previous.has("best_time"):
		best_time = minf(time, float(previous["best_time"]))
	data["levels"][key] = {
		"stars": maxi(stars, int(previous.get("stars", 0))),
		"best_time": snappedf(best_time, TIME_PRECISION),
	}
	var before: int = int(data["unlocked_level"])
	var after: int = maxi(before, mini(level_id + 1, LevelManager.level_count()))
	data["unlocked_level"] = after
	_apply_reward(LevelManager.level(level_id).get("reward"))
	save()
	progress_changed.emit()
	return after > before


func add_kills(count: int) -> void:
	if count <= 0:
		return
	data["stats"]["total_kills"] = int(data["stats"]["total_kills"]) + count
	save()


## For the --unlock-all developer flag. Never written to the save file.
func unlock_all_for_session() -> void:
	_unlock_all_this_session = true


func _save_path() -> String:
	return _directory.path_join(SAVE_FILE)


func _discard(reason: String) -> void:
	reset_reason = reason
	data = _fresh_save()
	save()


func _apply_reward(reward: Variant) -> void:
	if not reward is Dictionary:
		return
	var list_key: String = {
		"weapon": "unlocked_weapons", "map": "unlocked_maps", "skin": "unlocked_skins",
	}[reward["type"]]
	var unlocked: Array = data[list_key]
	if not reward["id"] in unlocked:
		unlocked.append(reward["id"])


func _fresh_save() -> Dictionary:
	return {
		"version": CURRENT_VERSION,
		"player_name": "Pilot",
		"unlocked_level": 1,
		"levels": {},
		"unlocked_weapons": [DEFAULT_WEAPON],
		"unlocked_maps": [DEFAULT_MAP],
		"unlocked_skins": [],
		"selected_skin": "",
		"stats": {"mp_wins": 0, "mp_losses": 0, "total_kills": 0},
		"settings": {"music": 0.7, "sfx": 0.9, "aim_assist": true, "stick_size": 1.0},
	}


func _has_valid_shape(loaded: Variant) -> bool:
	if not loaded is Dictionary:
		return false
	var expected: Dictionary = {
		"version": TYPE_FLOAT, "unlocked_level": TYPE_FLOAT, "levels": TYPE_DICTIONARY,
		"unlocked_weapons": TYPE_ARRAY, "unlocked_maps": TYPE_ARRAY,
		"stats": TYPE_DICTIONARY, "settings": TYPE_DICTIONARY, HASH_KEY: TYPE_STRING,
	}
	for key: String in expected:
		if typeof(loaded.get(key)) != expected[key]:
			return false
	return int(loaded["version"]) <= CURRENT_VERSION


## Brings an older save up to the current format, keeping all of its progress.
## Fields added in later versions take their default values.
func _upgraded(loaded: Dictionary) -> Dictionary:
	var result: Dictionary = _fresh_save()
	result.merge(loaded, true)
	result["version"] = CURRENT_VERSION
	result["unlocked_level"] = clampi(int(loaded["unlocked_level"]), 1, LevelManager.level_count())
	return result


## Salted SHA-256 of every field except the hash itself.
func _compute_hash(source: Dictionary) -> String:
	var without_hash: Dictionary = source.duplicate(true)
	without_hash.erase(HASH_KEY)
	return (JSON.stringify(_canonical(without_hash), "", true) + SALT).sha256_text()


## JSON reads every number back as a float, so 3 and 3.0 must hash the same.
func _canonical(value: Variant) -> Variant:
	match typeof(value):
		TYPE_DICTIONARY:
			var dictionary: Dictionary = {}
			for key: Variant in value:
				dictionary[key] = _canonical(value[key])
			return dictionary
		TYPE_ARRAY:
			var array: Array = []
			for item: Variant in value:
				array.append(_canonical(item))
			return array
		TYPE_FLOAT:
			var snapped_value: float = snappedf(value, TIME_PRECISION)
			if is_equal_approx(snapped_value, floorf(snapped_value)):
				return int(snapped_value)
			return snapped_value
	return value
