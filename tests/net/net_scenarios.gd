extends Node
## One side of a real two-process network test. tools/run_net_tests.sh starts a
## host and a client; each prints NET_TEST PASS or FAIL and exits 0 or 1.

const ScriptedProvider := preload("res://tests/helpers/ScriptedInputProvider.gd")
const WATCHDOG_SECONDS := 45.0
const POLL_FRAMES := 2
const MOVE_NEEDED := 40.0
const PACE_SECONDS := 0.5
const CLIENT_CHECK_SECONDS := 4.0
const HOST_LINGER_SECONDS := 2.0

var role: String = ""
var scenario: String = ""
var port: int = 0

var network: Node
var game_state: Node


func _ready() -> void:
	_start.call_deferred()


func _start() -> void:
	await get_tree().process_frame
	for argument: String in OS.get_cmdline_user_args():
		var parts: PackedStringArray = argument.trim_prefix("--").split("=")
		match parts[0]:
			"role":
				role = parts[1]
			"scenario":
				scenario = parts[1]
			"port":
				port = parts[1].to_int()
	network = get_node("/root/NetworkManager")
	game_state = get_node("/root/GameState")
	var progress: Node = get_node("/root/ProgressService")
	progress.use_directory("user://test_saves/net_%s_%s" % [scenario, role])
	progress.load_save()
	get_node("/root/Settings").player_name = role.capitalize()
	get_tree().create_timer(WATCHDOG_SECONDS, true, false, true).timeout.connect(
			func() -> void: _finish(false, "timed out"))
	network.has_network_check = func() -> bool: return scenario != "t9_no_network"
	call("_%s_%s" % [scenario, role])


func _finish(passed: bool, detail: String) -> void:
	print("NET_TEST %s %s/%s: %s" % ["PASS" if passed else "FAIL", scenario, role, detail])
	get_tree().quit(0 if passed else 1)


func _join() -> void:
	network.join_lan("127.0.0.1", port)


func _wait_until(condition: Callable) -> void:
	while not condition.call():
		for i: int in range(POLL_FRAMES):
			await get_tree().process_frame


func _match_started() -> bool:
	var scene: Node = get_tree().current_scene
	return scene is Match and (scene as Match).deathmatch != null \
			and (scene as Match).deathmatch.fighter_count() == 2 \
			and (scene as Match).local_player != null


func _rules() -> DeathmatchRules:
	return (get_tree().current_scene as Match).deathmatch


func _host_until_match() -> void:
	network.host_lan(port)
	await network.peer_joined
	network.start_match("outpost")
	await _wait_until(_match_started)


func _client_until_match() -> void:
	_join()
	await _wait_until(_match_started)


func _pace_back_and_forth(scripted: ScriptedProvider) -> void:
	scripted.input.move.x = 1.0
	while is_inside_tree():
		await get_tree().create_timer(PACE_SECONDS).timeout
		scripted.input.move.x = -scripted.input.move.x


func _assert_moves(fighter: Player, label: String) -> bool:
	var start: Vector2 = fighter.global_position
	for i: int in range(240):
		if fighter.global_position.distance_to(start) > MOVE_NEEDED:
			return true
		await get_tree().process_frame
	_finish(false, "%s never moved from %s" % [label, start])
	return false


# T6: both sides see each other move, then a whole match plays out.

func _t6_host() -> void:
	await _host_until_match()
	var rules: DeathmatchRules = _rules()
	var mine: NetFighter = rules.fighter(1)
	var theirs: NetFighter = rules.fighter(network.opponent_id())
	var scripted: ScriptedProvider = ScriptedProvider.new()
	add_child(scripted)
	_pace_back_and_forth(scripted)
	mine.input_provider = scripted
	if not await _assert_moves(theirs, "client fighter on host"):
		return
	# The client is still checking movement; ending the match now would free it.
	await get_tree().create_timer(CLIENT_CHECK_SECONDS).timeout
	var arena: Arena = (get_tree().current_scene as Match).arena
	arena.respawn_delay = 0.1
	for i: int in range(10):
		await _wait_until(func() -> bool: return not theirs.is_dead)
		if rules.score.is_over():
			break
		theirs.take_damage(100000.0, mine)
		await get_tree().process_frame
	await _wait_until(func() -> bool: return get_tree().current_scene is MatchResults)
	var result: Dictionary = game_state.last_match_result
	_finish(result["winner"] == "Host" and not result["forfeit"], str(result))


func _t6_client() -> void:
	await _client_until_match()
	var rules: DeathmatchRules = _rules()
	var mine: NetFighter = rules.fighter(multiplayer_id())
	var theirs: NetFighter = rules.fighter(1)
	var scripted: ScriptedProvider = ScriptedProvider.new()
	add_child(scripted)
	_pace_back_and_forth(scripted)
	mine.local_input_source = scripted
	if not await _assert_moves(mine, "own fighter on client"):
		return
	if not await _assert_moves(theirs, "host fighter on client"):
		return
	var saw_death: Array[bool] = [false]
	mine.died.connect(func(_v: Player, _k: Player) -> void: saw_death[0] = true)
	await _wait_until(func() -> bool: return get_tree().current_scene is MatchResults)
	var result: Dictionary = game_state.last_match_result
	var host_line: Dictionary = result["players"][0]
	_finish(saw_death[0] and result["winner"] == "Host" and int(host_line["kills"]) == 10, str(result))


func multiplayer_id() -> int:
	return multiplayer.get_unique_id()


# T9: one side vanishes mid-match.

func _t9_client_drops_host() -> void:
	await _host_until_match()
	await _wait_until(func() -> bool: return get_tree().current_scene is MatchResults)
	var result: Dictionary = game_state.last_match_result
	_finish(result["forfeit"] and result["winner"] == "Host", str(result))


func _t9_client_drops_client() -> void:
	await _client_until_match()
	OS.kill(OS.get_process_id())


func _t9_host_drops_host() -> void:
	await _host_until_match()
	await get_tree().create_timer(0.5).timeout
	OS.kill(OS.get_process_id())


func _t9_host_drops_client() -> void:
	await _client_until_match()
	await _wait_until(func() -> bool: return get_tree().current_scene is MatchResults)
	var result: Dictionary = game_state.last_match_result
	_finish(result["forfeit"] and result["winner"] == "Client", str(result))


# T9, the phone that lost its own network.

func _t9_no_network_host() -> void:
	await _host_until_match()
	await get_tree().create_timer(0.5).timeout
	OS.kill(OS.get_process_id())


func _t9_no_network_client() -> void:
	await _client_until_match()
	await _wait_until(func() -> bool: return get_tree().current_scene is MultiplayerMenu)
	var shown: bool = false
	for label: Node in get_tree().current_scene.find_children("*", "Label", true, false):
		shown = shown or (label as Label).text == "Connection lost"
	_finish(shown, "Connection lost shown: %s" % str(shown))


# T10: different game versions.

func _t10_host() -> void:
	network.host_lan(port)
	var joined_up: Array[bool] = [false]
	network.peer_joined.connect(func(_id: int) -> void: joined_up[0] = true)
	await get_tree().create_timer(4.0).timeout
	_finish(not joined_up[0], "peers: %s" % str(network.peers.keys()))


func _t10_client() -> void:
	network.game_version = "0.0.0-old"
	_join()
	var message: Variant = await network.join_failed
	_finish(str(message) == "Update required", str(message))


# Join with nobody listening.

func _no_host_client() -> void:
	_join()
	var started: int = Time.get_ticks_msec()
	var message: Variant = await network.join_failed
	var seconds: float = (Time.get_ticks_msec() - started) / 1000.0
	_finish(str(message) == "Could not reach host." and seconds <= 11.0, "%s after %.1f s" % [str(message), seconds])


# The real lobby screen, driven by the same flags as tools/run_local_mp.sh.

func _lobby_host() -> void:
	game_state.auto_host = true
	game_state.go_to(game_state.LAN_LOBBY)
	await _wait_until(_match_started)
	await get_tree().create_timer(HOST_LINGER_SECONDS).timeout
	_finish(true, "lobby auto-started a match")


func _lobby_client() -> void:
	game_state.auto_join = "127.0.0.1"
	game_state.go_to(game_state.LAN_LOBBY)
	await _wait_until(_match_started)
	_finish(true, "joined through the lobby")


# Both players vote for a rematch after a finished match.

func _play_to_results_as_host() -> void:
	var rules: DeathmatchRules = _rules()
	var mine: NetFighter = rules.fighter(1)
	var theirs: NetFighter = rules.fighter(network.opponent_id())
	(get_tree().current_scene as Match).arena.respawn_delay = 0.1
	for i: int in range(10):
		await _wait_until(func() -> bool: return not theirs.is_dead)
		if rules.score.is_over():
			break
		theirs.take_damage(100000.0, mine)
		await get_tree().process_frame
	await _wait_until(func() -> bool: return get_tree().current_scene is MatchResults)


func _rematch_host() -> void:
	await _host_until_match()
	await get_tree().create_timer(1.0).timeout
	await _play_to_results_as_host()
	network.vote_rematch()
	await _wait_until(_match_started)
	var fresh_score: bool = _rules().score != null and int(_rules().score.kills[1]) == 0
	# Exiting now would cut off a client still loading the match.
	await get_tree().create_timer(HOST_LINGER_SECONDS).timeout
	_finish(fresh_score, "second match started")


func _rematch_client() -> void:
	await _client_until_match()
	await _wait_until(func() -> bool: return get_tree().current_scene is MatchResults)
	network.vote_rematch()
	await _wait_until(_match_started)
	_finish(true, "second match started")
