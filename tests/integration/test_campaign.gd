extends GutTest
## T1 to T5 from section 9 of the design, plus every mission in a real Match.

const MatchScene := preload("res://scenes/game/Match.tscn")
const LevelSelectScene := preload("res://scenes/ui/LevelSelect.tscn")
const LevelResultsScene := preload("res://scenes/ui/LevelResults.tscn")
const DIRECTORY := "user://test_saves/campaign"
const SAVE_PATH := DIRECTORY + "/save.json"
## About three-quarters of the screen width.
const MIN_SPAWN_GAP := 900.0

var game: Match
var result: Dictionary = {}


func before_each() -> void:
	ProgressService.use_directory(DIRECTORY)
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)
	ProgressService.load_save()
	GameState.pending_level = 0
	GameState.last_result = {}
	result = {}


func after_all() -> void:
	ProgressService.use_directory(ProgressService.DEFAULT_DIRECTORY)
	ProgressService.load_save()


func _start(level_id: int) -> void:
	game = MatchScene.instantiate() as Match
	add_child_autofree(game)
	game.match_ended.connect(func(ended: Dictionary) -> void: result = ended)
	game.begin_campaign(level_id)
	game.rules.end_delay = 0.0
	await wait_physics_frames(3, "")


func _kill(fighter: Player) -> void:
	fighter.take_damage(100000.0, game.local_player)


func _kill_all_enemies() -> void:
	for enemy: Player in game.rules.enemies.duplicate():
		if not enemy.is_dead:
			_kill(enemy)


func _freeze_enemies() -> void:
	for enemy: Player in game.rules.enemies:
		enemy.set_physics_process(false)


func _select_screen() -> LevelSelect:
	var screen: LevelSelect = LevelSelectScene.instantiate() as LevelSelect
	screen.start_on_select = false
	add_child_autofree(screen)
	return screen


func _results_screen(shown: Dictionary) -> LevelResults:
	var screen: LevelResults = LevelResultsScene.instantiate() as LevelResults
	GameState.last_result = shown
	add_child_autofree(screen)
	return screen


func _clear_level_one() -> void:
	await _start(1)
	_kill_all_enemies()
	await wait_physics_frames(3, "")
	GameState.record_level_result(result)


func test_t1_fresh_install_only_level_one_is_unlocked() -> void:
	var screen: LevelSelect = _select_screen()
	assert_false(screen.card(1).find_child("Lock", true, false) != null)
	for level_id: int in range(2, 11):
		assert_not_null(screen.card(level_id).find_child("Lock", true, false), "level %d" % level_id)
		assert_false(ProgressService.is_unlocked(level_id), "level %d" % level_id)


func test_t2_clearing_level_one_unlocks_level_two_and_saves_stars() -> void:
	await _clear_level_one()
	assert_true(result["cleared"])
	assert_true(ProgressService.is_unlocked(2))
	assert_false(ProgressService.is_unlocked(3))
	assert_eq(ProgressService.stars_for(1), 3)
	ProgressService.load_save()
	assert_eq(ProgressService.stars_for(1), 3, "stars must be on disk")


func test_t3_time_running_out_fails_and_unlocks_nothing() -> void:
	ProgressService.complete_level(1, 3, 40.0)
	await _start(2)
	game.rules.mission.time_left = 0.05
	await wait_physics_frames(10, "")
	assert_false(result["cleared"])
	GameState.record_level_result(result)
	assert_false(ProgressService.is_unlocked(3))
	assert_eq(ProgressService.stars_for(2), 0)
	var screen: LevelResults = _results_screen(GameState.last_result)
	assert_true(screen.retry_button.visible, "retry must be offered")
	assert_false(screen.next_button.visible)


func test_t4_progress_is_kept_after_closing_the_app() -> void:
	ProgressService.complete_level(1, 3, 40.0)
	ProgressService.complete_level(2, 2, 120.0)
	ProgressService.complete_level(3, 1, 90.0)
	ProgressService.load_save()
	var screen: LevelSelect = _select_screen()
	for level_id: int in range(1, 5):
		assert_true(ProgressService.is_unlocked(level_id), "level %d" % level_id)
		assert_null(screen.card(level_id).find_child("Lock", true, false), "level %d" % level_id)
	assert_false(ProgressService.is_unlocked(5))
	assert_eq(ProgressService.stars_for(1), 3)
	assert_eq(ProgressService.stars_for(2), 2)
	assert_eq(ProgressService.stars_for(3), 1)


func test_t5_tapping_a_locked_level_shows_a_message_and_does_not_start() -> void:
	var screen: LevelSelect = _select_screen()
	assert_false(screen.select_level(5))
	assert_eq(screen.message_text(), "Clear Level 4 first.")
	assert_eq(GameState.pending_level, 0)


func test_t5_the_card_itself_is_wired_to_the_same_check() -> void:
	var screen: LevelSelect = _select_screen()
	screen.card(3).pressed.emit()
	assert_eq(screen.message_text(), "Clear Level 2 first.")


func test_unlocked_level_can_be_selected() -> void:
	assert_true(_select_screen().select_level(1))


func test_every_level_starts_with_the_right_opposition() -> void:
	var expected: Array[int] = [3, 2, 4, 3, 3, 4, 6, 4, 5, 4]
	for level_id: int in range(1, 11):
		await _start(level_id)
		assert_eq(game.rules.enemies.size(), expected[level_id - 1], "level %d" % level_id)
		assert_eq(game.rules.mission.status, Mission.Status.RUNNING, "level %d" % level_id)
		if level_id > 1:
			for enemy: Player in game.rules.enemies:
				var gap: float = enemy.global_position.distance_to(game.local_player.global_position)
				assert_gt(gap, MIN_SPAWN_GAP, "level %d starts a bot too close" % level_id)
		game.queue_free()
		await wait_physics_frames(2, "")


func test_early_levels_have_no_crates_until_a_weapon_is_earned() -> void:
	await _start(2)
	var crates: int = 0
	for child: Node in game.arena.get_children():
		if child is Pickup and (child as Pickup).kind == Pickup.Kind.WEAPON:
			crates += 1
	assert_eq(crates, 0)


func test_crates_only_hold_unlocked_weapons() -> void:
	ProgressService.complete_level(2, 1, 100.0)
	await _start(3)
	var found: int = 0
	for child: Node in game.arena.get_children():
		if child is Pickup and (child as Pickup).kind == Pickup.Kind.WEAPON:
			found += 1
			assert_eq((child as Pickup).weapon_id, "rifle")
	assert_gt(found, 0)


func test_eliminated_bots_come_back() -> void:
	await _start(2)
	game.arena.respawn_delay = 0.1
	var bot: Player = game.rules.enemies[0]
	_kill(bot)
	assert_true(bot.is_dead)
	await wait_physics_frames(15, "")
	assert_false(bot.is_dead)
	assert_eq((game.rules.mission as EliminateMission).kills, 1)


func test_eliminate_clears_after_enough_kills() -> void:
	await _start(2)
	game.arena.respawn_delay = 0.05
	var bot: Player = game.rules.enemies[0]
	for i: int in range(5):
		_kill(bot)
		await wait_physics_frames(8, "")
	assert_true(result.get("cleared", false))
	assert_eq(result["kills"], 5)


func test_survive_clears_when_the_clock_runs_out() -> void:
	await _start(3)
	game.rules.mission.time_left = 0.05
	await wait_physics_frames(10, "")
	assert_true(result["cleared"])
	assert_eq(result["stars"], 3)


func test_third_player_death_fails_the_level() -> void:
	await _start(2)
	game.arena.respawn_delay = 0.05
	_freeze_enemies()
	for i: int in range(3):
		_kill(game.local_player)
		await wait_physics_frames(8, "")
	assert_false(result["cleared"])
	assert_eq(result["deaths"], 3)


func test_one_death_earns_two_stars() -> void:
	await _start(2)
	game.arena.respawn_delay = 0.05
	_kill(game.local_player)
	await wait_physics_frames(8, "")
	var bot: Player = game.rules.enemies[0]
	for i: int in range(5):
		_kill(bot)
		await wait_physics_frames(8, "")
	assert_eq(result["stars"], 2)


func test_capture_progresses_while_the_player_holds_the_zone() -> void:
	await _start(5)
	_freeze_enemies()
	game.local_player.global_position = game.map.capture_zone.get_center() + Vector2(0.0, 40.0)
	await wait_physics_frames(60, "")
	assert_gt((game.rules.mission as CaptureMission).progress, 0.3)


func test_capture_pauses_when_an_enemy_enters() -> void:
	await _start(5)
	_freeze_enemies()
	var zone_centre: Vector2 = game.map.capture_zone.get_center() + Vector2(0.0, 40.0)
	game.local_player.global_position = zone_centre
	game.rules.enemies[0].global_position = zone_centre
	await wait_physics_frames(60, "")
	assert_eq((game.rules.mission as CaptureMission).progress, 0.0)


func test_capture_clears_at_thirty_seconds() -> void:
	await _start(5)
	_freeze_enemies()
	game.local_player.global_position = game.map.capture_zone.get_center() + Vector2(0.0, 40.0)
	(game.rules.mission as CaptureMission).progress = 29.9
	await wait_physics_frames(30, "")
	assert_true(result["cleared"])


func test_leader_has_300_hp_and_killing_it_clears() -> void:
	await _start(8)
	assert_eq(game.rules.leader.health.maximum, 300.0)
	_kill(game.rules.enemies[0])
	await wait_physics_frames(3, "")
	assert_true(result.is_empty(), "escorts do not clear the level")
	_kill(game.rules.leader)
	await wait_physics_frames(3, "")
	assert_true(result["cleared"])


func test_gauntlet_moves_through_all_three_maps() -> void:
	await _start(10)
	assert_eq(game.map.layout_path, "res://data/maps/outpost.json")
	assert_eq(game.rules.enemies.size(), 4)
	_kill_all_enemies()
	await wait_physics_frames(5, "")
	assert_eq(game.map.layout_path, "res://data/maps/canyon.json")
	assert_eq(game.rules.enemies.size(), 4)
	assert_eq(game.local_player.global_position.distance_to(game.map.spawn_points[0]) < 80.0, true)
	_kill_all_enemies()
	await wait_physics_frames(5, "")
	assert_eq(game.map.layout_path, "res://data/maps/skyforge.json")
	assert_true(result.is_empty())
	_kill_all_enemies()
	await wait_physics_frames(5, "")
	assert_true(result["cleared"])


func test_gauntlet_waves_do_not_respawn() -> void:
	await _start(10)
	game.arena.respawn_delay = 0.05
	var bot: Player = game.rules.enemies[0]
	_kill(bot)
	await wait_physics_frames(10, "")
	assert_true(bot.is_dead)


func test_results_show_the_unlock_banner_and_reward() -> void:
	ProgressService.complete_level(1, 3, 40.0)
	GameState.record_level_result({"level_id": 2, "cleared": true, "stars": 2, "time": 100.0, "deaths": 1, "kills": 5})
	var screen: LevelResults = _results_screen(GameState.last_result)
	assert_eq(screen.heading_text(), "Level 2 Clear!")
	assert_eq(screen.banner_text(), "Level 3 unlocked!")
	assert_eq(GameState.last_result["reward_text"], "Assault Rifle")
	assert_true(screen.next_button.visible)


func test_replaying_a_cleared_level_shows_no_unlock_banner() -> void:
	ProgressService.complete_level(1, 3, 40.0)
	GameState.record_level_result({"level_id": 1, "cleared": true, "stars": 1, "time": 60.0, "deaths": 2, "kills": 3})
	assert_eq(_results_screen(GameState.last_result).banner_text(), "")


func test_last_level_clear_has_no_next_button() -> void:
	GameState.record_level_result({"level_id": 10, "cleared": true, "stars": 3, "time": 200.0, "deaths": 0, "kills": 12})
	var screen: LevelResults = _results_screen(GameState.last_result)
	assert_false(screen.next_button.visible)
	assert_eq(screen.banner_text(), "Campaign complete!")
	assert_true(screen.retry_button.visible)
	assert_true(screen.select_button.visible)


func test_kills_are_added_to_lifetime_stats() -> void:
	GameState.record_level_result({"level_id": 2, "cleared": false, "stars": 0, "time": 180.0, "deaths": 0, "kills": 4})
	assert_eq(int(ProgressService.data["stats"]["total_kills"]), 4)
