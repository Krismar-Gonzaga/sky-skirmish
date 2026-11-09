extends GutTest
## Stars, timers, lives and every mission type's clear and fail rules.

const LIVES := 3


func _level(type: String, target: int, time_limit: float) -> Dictionary:
	return {"mission_type": type, "target": target, "time_limit": time_limit}


func test_one_star_for_two_or_more_deaths() -> void:
	assert_eq(StarRating.calculate(2, 100.0, 180.0, true), 1)


func test_two_stars_for_one_death() -> void:
	assert_eq(StarRating.calculate(1, 100.0, 180.0, true), 2)


func test_three_stars_need_no_deaths_and_time_left() -> void:
	assert_eq(StarRating.calculate(0, 46.0, 180.0, true), 3)


func test_exactly_a_quarter_left_is_not_enough() -> void:
	assert_eq(StarRating.calculate(0, 45.0, 180.0, true), 2)


func test_three_stars_when_time_does_not_count() -> void:
	assert_eq(StarRating.calculate(0, 0.0, 90.0, false), 3)


func test_time_running_out_fails() -> void:
	var mission := EliminateMission.new(_level("eliminate", 5, 10.0), LIVES)
	mission.update(9.0)
	assert_eq(mission.status, Mission.Status.RUNNING)
	mission.update(2.0)
	assert_eq(mission.status, Mission.Status.FAILED)
	assert_eq(mission.time_left, 0.0)


func test_no_limit_never_times_out() -> void:
	var mission := TutorialMission.new(_level("tutorial", 3, 0.0), LIVES)
	mission.update(100000.0)
	assert_eq(mission.status, Mission.Status.RUNNING)


func test_third_death_fails() -> void:
	var mission := EliminateMission.new(_level("eliminate", 5, 180.0), LIVES)
	mission.on_player_died()
	mission.on_player_died()
	assert_eq(mission.status, Mission.Status.RUNNING)
	assert_eq(mission.lives_left(), 1)
	mission.on_player_died()
	assert_eq(mission.status, Mission.Status.FAILED)


func test_max_deaths_field_limits_lives() -> void:
	var level: Dictionary = _level("eliminate", 10, 210.0)
	level["max_deaths"] = 1
	var mission := EliminateMission.new(level, LIVES)
	mission.on_player_died()
	assert_eq(mission.status, Mission.Status.RUNNING)
	mission.on_player_died()
	assert_eq(mission.status, Mission.Status.FAILED)


func test_eliminate_clears_at_target() -> void:
	var mission := EliminateMission.new(_level("eliminate", 2, 180.0), LIVES)
	mission.on_enemy_killed(false)
	assert_eq(mission.status, Mission.Status.RUNNING)
	mission.on_enemy_killed(false)
	assert_eq(mission.status, Mission.Status.CLEARED)


func test_survive_clears_when_time_runs_out() -> void:
	var mission := SurviveMission.new(_level("survive", 90, 90.0), LIVES)
	mission.update(91.0)
	assert_eq(mission.status, Mission.Status.CLEARED)
	assert_eq(mission.stars(), 3)


func test_survive_still_fails_on_lost_lives() -> void:
	var mission := SurviveMission.new(_level("survive", 90, 90.0), LIVES)
	for i: int in range(LIVES):
		mission.on_player_died()
	assert_eq(mission.status, Mission.Status.FAILED)


func test_capture_needs_the_player_inside() -> void:
	var mission := CaptureMission.new(_level("capture", 30, 150.0), LIVES)
	mission.update_zone(40.0, false, false)
	assert_eq(mission.progress, 0.0)


func test_capture_pauses_while_contested() -> void:
	var mission := CaptureMission.new(_level("capture", 30, 150.0), LIVES)
	mission.update_zone(10.0, true, false)
	mission.update_zone(10.0, true, true)
	assert_eq(mission.progress, 10.0)


func test_capture_is_cumulative_and_clears() -> void:
	var mission := CaptureMission.new(_level("capture", 30, 150.0), LIVES)
	mission.update_zone(20.0, true, false)
	mission.update_zone(5.0, false, false)
	assert_eq(mission.status, Mission.Status.RUNNING)
	mission.update_zone(10.0, true, false)
	assert_eq(mission.status, Mission.Status.CLEARED)


func test_boss_only_cleared_by_the_leader() -> void:
	var mission := BossMission.new(_level("boss", 1, 180.0), LIVES)
	mission.on_enemy_killed(false)
	assert_eq(mission.status, Mission.Status.RUNNING)
	mission.on_enemy_killed(true)
	assert_eq(mission.status, Mission.Status.CLEARED)


func test_gauntlet_clears_after_every_wave() -> void:
	var mission := GauntletMission.new(_level("gauntlet", 3, 360.0), LIVES)
	mission.on_wave_cleared()
	mission.on_wave_cleared()
	assert_eq(mission.status, Mission.Status.RUNNING)
	mission.on_wave_cleared()
	assert_eq(mission.status, Mission.Status.CLEARED)


func test_tutorial_hints_follow_the_player() -> void:
	var mission := TutorialMission.new(_level("tutorial", 3, 0.0), LIVES)
	assert_string_contains(mission.objective_text(), "Walk")
	mission.note_player_activity(true, false)
	assert_string_contains(mission.objective_text(), "Fly")
	mission.note_player_activity(false, true)
	assert_string_contains(mission.objective_text(), "dummies")


func test_outcome_cannot_change_once_decided() -> void:
	var mission := EliminateMission.new(_level("eliminate", 1, 180.0), LIVES)
	mission.on_enemy_killed(false)
	for i: int in range(LIVES):
		mission.on_player_died()
	assert_eq(mission.status, Mission.Status.CLEARED)
	assert_eq(mission.deaths, 0)


func test_level_table_matches_design() -> void:
	var expected: Dictionary = {
		1: ["outpost", "tutorial", 3, 0, 0.0],
		2: ["outpost", "eliminate", 5, 2, 180.0],
		3: ["outpost", "survive", 90, 4, 90.0],
		4: ["canyon", "eliminate", 8, 3, 180.0],
		5: ["canyon", "capture", 30, 3, 150.0],
		6: ["canyon", "eliminate", 10, 4, 210.0],
		7: ["skyforge", "survive", 120, 6, 120.0],
		8: ["skyforge", "boss", 1, 3, 180.0],
		9: ["skyforge", "eliminate", 15, 5, 240.0],
		10: ["outpost", "gauntlet", 3, 4, 360.0],
	}
	assert_eq(LevelManager.level_count(), 10)
	for level_id: int in expected:
		var row: Array = expected[level_id]
		var level: Dictionary = LevelManager.level(level_id)
		assert_eq(level["map"], row[0], "level %d" % level_id)
		assert_eq(level["mission_type"], row[1], "level %d" % level_id)
		assert_eq(int(level["target"]), row[2], "level %d" % level_id)
		assert_eq(int(level["bot_count"]), row[3], "level %d" % level_id)
		assert_eq(float(level["time_limit"]), row[4], "level %d" % level_id)


func test_level_difficulties_rewards_and_specials_match_design() -> void:
	var difficulties: Array[String] = [
		"easy", "easy", "easy", "normal", "normal", "normal", "hard", "hard", "hard", "expert",
	]
	for i: int in range(difficulties.size()):
		assert_eq(LevelManager.level(i + 1)["difficulty"], difficulties[i])
	assert_eq(int(LevelManager.level(6)["max_deaths"]), 2)
	assert_eq(float(LevelManager.level(8)["leader_hp"]), 300.0)
	assert_eq(LevelManager.level(10)["wave_maps"], ["outpost", "canyon", "skyforge"])
	assert_eq(LevelManager.level(2)["reward"]["id"], "rifle")
	assert_eq(LevelManager.level(4)["reward"]["id"], "shotgun")
	assert_eq(LevelManager.level(5)["reward"]["id"], "canyon")
	assert_eq(LevelManager.level(6)["reward"]["id"], "sniper")
	assert_eq(LevelManager.level(8)["reward"]["id"], "rocket")
	assert_eq(LevelManager.level(9)["reward"]["id"], "skyforge")
	assert_eq(LevelManager.level(10)["reward"]["id"], "sky_ace")
	assert_null(LevelManager.level(3)["reward"])
	assert_null(LevelManager.level(7)["reward"])
