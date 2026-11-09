class_name CampaignRules
extends Node
## Runs a campaign level inside a Match: spawns the opposition, feeds events to
## the Mission, keeps the HUD current and reports the outcome.

const LEADER_VISUAL_SCALE := 1.35
const LEADER_TINT := Color(1.0, 0.82, 0.35)

var mission: Mission
var leader: Bot
var enemies: Array[Player] = []
## Pause between the result being decided and leaving the match.
var end_delay: float = 0.0

var _match: Match
var _level: Dictionary = {}
var _level_id: int = 0
var _kills: int = 0
var _finished: bool = false
var _wave_alive: int = 0
var _wave_index: int = 0
var _zone: CaptureZoneVisual
var _player_start: Vector2 = Vector2.ZERO


func begin(owner_match: Match, level_id: int) -> void:
	_match = owner_match
	_level_id = level_id
	_level = LevelManager.level(level_id)
	mission = LevelManager.create_mission(level_id)
	end_delay = Tuning.section("campaign")["end_delay"]
	_match.load_map(_first_map(), ProgressService.crate_pool())
	_match.spawn_local_player()
	_player_start = _match.local_player.global_position
	_match.arena.fighter_killed.connect(_on_fighter_killed)
	_spawn_opposition()
	if mission is CaptureMission:
		_zone = CaptureZoneVisual.new()
		_match.add_child(_zone)
		_zone.show_area(_match.map.capture_zone)
	_refresh_hud()


func _physics_process(delta: float) -> void:
	if _finished or mission == null:
		return
	mission.update(delta)
	if mission is CaptureMission:
		_update_capture(delta)
	if mission is TutorialMission:
		_update_tutorial()
	_refresh_hud()
	if mission.status != Mission.Status.RUNNING:
		_finish()


func _first_map() -> String:
	if _level.has("wave_maps"):
		return _level["wave_maps"][0]
	return _level["map"]


func _spawn_opposition() -> void:
	if mission is TutorialMission:
		for i: int in range(int(_level["target"])):
			enemies.append(_match.spawn_dummy(_spawn_point(i), _level["dummy_hp"]))
		return
	var count: int = int(_level["bot_count"])
	for i: int in range(count):
		var bot: Bot = _match.spawn_bot(_spawn_point(i), _level["difficulty"])
		if mission is GauntletMission:
			bot.respawns = false
		enemies.append(bot)
	_wave_alive = count
	if mission is BossMission:
		_spawn_leader(count)


func _spawn_leader(index: int) -> void:
	leader = _match.spawn_bot(_spawn_point(index), _level["difficulty"], _level["leader_hp"])
	leader.modulate = LEADER_TINT
	leader.set_visual_scale(LEADER_VISUAL_SCALE)
	enemies.append(leader)


## Point 0 is the player's. Bots take the farthest of the rest, so a level never
## opens with one beside the player; tutorial dummies take the nearest instead.
func _spawn_point(index: int) -> Vector2:
	var start: Vector2 = _match.map.spawn_points[0]
	var points: Array[Vector2] = _match.map.spawn_points.slice(1)
	points.sort_custom(func(a: Vector2, b: Vector2) -> bool:
		return a.distance_to(start) < b.distance_to(start))
	if not mission is TutorialMission:
		points.reverse()
	return points[index % points.size()]


func _on_fighter_killed(victim: Player, _killer: Player) -> void:
	if victim == _match.local_player:
		mission.on_player_died()
		return
	_kills += 1
	mission.on_enemy_killed(victim == leader)
	if mission is GauntletMission:
		_wave_alive -= 1
		if _wave_alive <= 0:
			# Deferred: this runs inside the physics step, and swapping maps there
			# would remove colliders the step is still using.
			_advance_wave.call_deferred()


func _advance_wave() -> void:
	var gauntlet: GauntletMission = mission as GauntletMission
	gauntlet.on_wave_cleared()
	if gauntlet.status != Mission.Status.RUNNING:
		return
	_wave_index += 1
	for enemy: Player in enemies:
		_match.remove_fighter(enemy)
	enemies.clear()
	_match.load_map(_level["wave_maps"][_wave_index], ProgressService.crate_pool())
	_match.place_local_player_at_start()
	_spawn_opposition()


func _update_capture(delta: float) -> void:
	var zone: Rect2 = _match.map.capture_zone
	var player: Player = _match.local_player
	var player_inside: bool = not player.is_dead and zone.has_point(player.get_center())
	var enemy_inside: bool = false
	for enemy: Player in enemies:
		if not enemy.is_dead and zone.has_point(enemy.get_center()):
			enemy_inside = true
	(mission as CaptureMission).update_zone(delta, player_inside, enemy_inside)
	_zone.set_state(player_inside, enemy_inside)


func _update_tutorial() -> void:
	var player: Player = _match.local_player
	var walked: bool = absf(player.global_position.x - _player_start.x) > 1.0
	(mission as TutorialMission).note_player_activity(walked, player.is_thrusting)


func _refresh_hud() -> void:
	var hud: Hud = _match.hud
	hud.set_objective("%s    Lives %d" % [mission.objective_text(), mission.lives_left()])
	if mission.time_limit > Mission.NO_LIMIT:
		hud.set_time_left(mission.time_left)
	else:
		hud.hide_time()


func _finish() -> void:
	_finished = true
	var cleared: bool = mission.status == Mission.Status.CLEARED
	_match.hud.show_banner("Level Clear!" if cleared else "Mission Failed")
	if end_delay > 0.0:
		await get_tree().create_timer(end_delay, false).timeout
	_match.end_match({
		"level_id": _level_id,
		"cleared": cleared,
		"stars": mission.stars() if cleared else 0,
		"time": mission.elapsed,
		"deaths": mission.deaths,
		"kills": _kills,
	})
