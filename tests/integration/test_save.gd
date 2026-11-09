extends GutTest
## Saving, restarting, corruption and tamper recovery, on the real autoload.

const DIRECTORY := "user://test_saves/save_service"
const SAVE_PATH := DIRECTORY + "/save.json"
const TEMP_PATH := DIRECTORY + "/save.tmp"


func before_each() -> void:
	ProgressService.use_directory(DIRECTORY)
	_delete(SAVE_PATH)
	_delete(TEMP_PATH)
	ProgressService.load_save()


func after_all() -> void:
	ProgressService.use_directory(ProgressService.DEFAULT_DIRECTORY)
	ProgressService.load_save()


func _delete(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)


func _write(path: String, text: String) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()


## A fresh instance reading the same file is what an app restart does.
func _restarted_service() -> Node:
	var service: Node = (load("res://autoload/ProgressService.gd") as GDScript).new()
	service.use_directory(DIRECTORY)
	service.load_save()
	autofree(service)
	return service


func test_missing_save_is_a_fresh_start() -> void:
	assert_eq(ProgressService.unlocked_level(), 1)
	assert_eq(ProgressService.reset_reason, "")


func test_save_survives_a_restart() -> void:
	ProgressService.complete_level(1, 3, 41.2)
	ProgressService.complete_level(2, 2, 132.5)
	var restarted: Node = _restarted_service()
	assert_eq(restarted.reset_reason, "")
	assert_eq(restarted.unlocked_level(), 3)
	assert_eq(restarted.stars_for(1), 3)
	assert_eq(restarted.stars_for(2), 2)
	assert_almost_eq(restarted.best_time_for(2), 132.5, 0.001)


func test_a_save_loaded_and_saved_again_stays_valid() -> void:
	ProgressService.complete_level(1, 3, 41.237)
	var first: Node = _restarted_service()
	first.save()
	var second: Node = _restarted_service()
	assert_eq(second.reset_reason, "")
	assert_eq(second.stars_for(1), 3)


func test_atomic_write_leaves_no_temp_file() -> void:
	ProgressService.save()
	assert_true(FileAccess.file_exists(SAVE_PATH))
	assert_false(FileAccess.file_exists(TEMP_PATH))


func test_saving_twice_replaces_the_file() -> void:
	ProgressService.complete_level(1, 1, 50.0)
	ProgressService.complete_level(1, 3, 40.0)
	assert_eq(_restarted_service().stars_for(1), 3)


func test_interrupted_write_keeps_the_old_save() -> void:
	ProgressService.complete_level(1, 2, 50.0)
	_write(TEMP_PATH, "{ half written")
	var restarted: Node = _restarted_service()
	assert_eq(restarted.reset_reason, "")
	assert_eq(restarted.stars_for(1), 2)


func test_garbage_save_recovers() -> void:
	_write(SAVE_PATH, "not json at all{{{")
	var restarted: Node = _restarted_service()
	assert_ne(restarted.reset_reason, "")
	assert_eq(restarted.unlocked_level(), 1)


func test_zero_filled_save_recovers() -> void:
	var zeros := PackedByteArray()
	zeros.resize(4096)
	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	file.store_buffer(zeros)
	file.close()
	var restarted: Node = _restarted_service()
	assert_ne(restarted.reset_reason, "")
	assert_eq(restarted.unlocked_level(), 1)


func test_truncated_save_recovers() -> void:
	ProgressService.complete_level(1, 3, 41.2)
	var text: String = FileAccess.get_file_as_string(SAVE_PATH)
	_write(SAVE_PATH, text.left(floori(text.length() * 0.5)))
	assert_eq(_restarted_service().unlocked_level(), 1)


func test_empty_save_recovers() -> void:
	_write(SAVE_PATH, "")
	var restarted: Node = _restarted_service()
	assert_ne(restarted.reset_reason, "")
	assert_eq(restarted.unlocked_level(), 1)


func test_wrong_shape_save_recovers() -> void:
	_write(SAVE_PATH, "[1, 2, 3]")
	assert_ne(_restarted_service().reset_reason, "")


func test_hand_edited_save_resets_to_level_one() -> void:
	ProgressService.complete_level(1, 3, 41.2)
	var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	saved["unlocked_level"] = 10
	_write(SAVE_PATH, JSON.stringify(saved))
	var restarted: Node = _restarted_service()
	assert_string_contains(restarted.reset_reason, "changed outside")
	assert_eq(restarted.unlocked_level(), 1)


func test_warning_appears_only_once() -> void:
	_write(SAVE_PATH, "garbage")
	assert_ne(_restarted_service().reset_reason, "")
	assert_eq(_restarted_service().reset_reason, "")


func test_older_save_gains_new_fields_and_keeps_progress() -> void:
	ProgressService.complete_level(1, 3, 41.2)
	var older: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	older.erase("selected_skin")
	older.erase("unlocked_skins")
	older["version"] = 0
	older["hash"] = ProgressService._compute_hash(older)
	_write(SAVE_PATH, JSON.stringify(older))
	var restarted: Node = _restarted_service()
	assert_eq(restarted.reset_reason, "")
	assert_eq(restarted.stars_for(1), 3)
	assert_eq(int(restarted.data["version"]), ProgressService.CURRENT_VERSION)
	assert_eq(restarted.data["unlocked_skins"], [])


func test_save_from_a_newer_app_is_not_trusted() -> void:
	var newer: Dictionary = ProgressService._fresh_save()
	newer["version"] = ProgressService.CURRENT_VERSION + 1
	newer["hash"] = ProgressService._compute_hash(newer)
	_write(SAVE_PATH, JSON.stringify(newer))
	assert_ne(_restarted_service().reset_reason, "")


func test_replay_keeps_best_stars_and_best_time() -> void:
	ProgressService.complete_level(1, 3, 40.0)
	ProgressService.complete_level(1, 1, 60.0)
	assert_eq(ProgressService.stars_for(1), 3)
	assert_eq(ProgressService.best_time_for(1), 40.0)
	ProgressService.complete_level(1, 2, 30.0)
	assert_eq(ProgressService.stars_for(1), 3)
	assert_eq(ProgressService.best_time_for(1), 30.0)


func test_clearing_the_last_level_stays_in_range() -> void:
	ProgressService.complete_level(10, 3, 100.0)
	assert_eq(ProgressService.unlocked_level(), 10)
	ProgressService.load_save()
	assert_eq(ProgressService.reset_reason, "")


func test_rewards_are_granted_once() -> void:
	ProgressService.complete_level(2, 1, 100.0)
	ProgressService.complete_level(2, 1, 100.0)
	assert_eq(ProgressService.data["unlocked_weapons"], ["pistol", "rifle"])
	ProgressService.complete_level(5, 1, 100.0)
	assert_true(ProgressService.is_map_unlocked("canyon"))
	assert_false(ProgressService.is_map_unlocked("skyforge"))
	ProgressService.complete_level(10, 1, 100.0)
	assert_true(ProgressService.is_skin_unlocked("sky_ace"))


func test_crate_pool_excludes_the_pistol() -> void:
	assert_eq(ProgressService.crate_pool().size(), 0)
	ProgressService.complete_level(2, 1, 100.0)
	assert_eq(ProgressService.crate_pool(), ["rifle"] as Array[String])


func test_unlock_all_is_never_saved() -> void:
	ProgressService.unlock_all_for_session()
	assert_true(ProgressService.is_unlocked(10))
	ProgressService.save()
	assert_eq(_restarted_service().unlocked_level(), 1)
