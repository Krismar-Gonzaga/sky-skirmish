class_name DeathmatchRules
extends Node
## Runs a 1 vs 1 match. The host spawns fighters and keeps the score; both sides
## handle the opponent disappearing.

const NetFighterScene := preload("res://scenes/game/NetFighter.tscn")
const ENEMY_TINT := Color(1.0, 0.55, 0.55)

var score: DeathmatchScore
## Shown on the HUD; kept here so tests can read what a client sees.
var my_kills: int = 0
var their_kills: int = 0

var _match: Match
var _spawner: MultiplayerSpawner
var _relay: NetEventRelay
var _fighters: Dictionary = {}
var _started: bool = false
var _finished: bool = false
var _sync_interval: float = 0.0
var _sync_wait: float = 0.0
var _time_left: float = 0.0


func begin(owner_match: Match, map_id: String) -> void:
	_match = owner_match
	var config: Dictionary = Tuning.section("deathmatch")
	_time_left = config["time_limit"]
	_sync_interval = Tuning.section("net")["score_sync_interval"]
	_match.load_map(map_id, WeaponCatalog.crate_weapon_ids(), not multiplayer.is_server())
	_relay = NetEventRelay.new()
	_relay.name = "Relay"
	add_child(_relay)
	_relay.setup(_match.arena, self)
	_spawner = MultiplayerSpawner.new()
	_spawner.name = "FighterSpawner"
	_spawner.spawn_function = _create_fighter
	add_child(_spawner)
	_spawner.spawn_path = _spawner.get_path_to(_match.arena)
	NetworkManager.peer_left.connect(_on_opponent_gone)
	NetworkManager.connection_lost.connect(_on_opponent_gone.bind(0))
	if multiplayer.is_server():
		_relay.bind_host()
		_match.arena.fighter_killed.connect(_on_fighter_killed)
		NetworkManager.scene_ready_changed.connect(_try_start)
	_refresh_hud()
	NetworkManager.report_scene_ready()


## Null if that fighter has gone, which late events must allow for.
func fighter(peer_id: int) -> NetFighter:
	var found: Variant = _fighters.get(peer_id)
	return found as NetFighter if is_instance_valid(found) else null


func fighter_count() -> int:
	return _fighters.size()


## The player chose to leave, which forfeits the match.
func leave_match() -> void:
	_finished = true
	_stop_all_replication()
	ProgressService.record_mp_result("loss")
	NetworkManager.leave()
	GameState.go_to(GameState.MULTIPLAYER_MENU)


func _physics_process(delta: float) -> void:
	if _finished or score == null or not multiplayer.is_server():
		return
	score.update(delta)
	_sync_wait -= delta
	if _sync_wait <= 0.0:
		_broadcast_score()
	if score.is_over():
		_end_normally()


func _try_start() -> void:
	if _started or not NetworkManager.all_scenes_ready():
		return
	_started = true
	var config: Dictionary = Tuning.section("deathmatch")
	var peer_ids: Array = NetworkManager.peers.keys()
	score = DeathmatchScore.new(peer_ids, int(config["kill_limit"]), config["time_limit"])
	var spawns: Array[Vector2] = _match.map.spawn_points
	for i: int in range(peer_ids.size()):
		var peer_id: int = peer_ids[i]
		var info: Dictionary = NetworkManager.peers[peer_id]
		_spawner.spawn({"peer": peer_id, "team": i, "at": spawns[i], "name": info["name"], "skin": info["skin"]})
	_relay.send_all_pickups()
	_broadcast_score()


func _create_fighter(data: Dictionary) -> Node:
	var new_fighter: NetFighter = NetFighterScene.instantiate() as NetFighter
	new_fighter.configure_network(data)
	new_fighter.ready.connect(_on_fighter_ready.bind(new_fighter, data["skin"]), CONNECT_ONE_SHOT)
	return new_fighter


func _on_fighter_ready(new_fighter: NetFighter, skin: String) -> void:
	_fighters[new_fighter.peer_id] = new_fighter
	# The host's departure despawns fighters here while this scene still runs.
	new_fighter.tree_exiting.connect(_match.arena.unregister_fighter.bind(new_fighter))
	new_fighter.apply_skin(skin)
	var is_server: bool = multiplayer.is_server()
	if is_server:
		_match.arena.register_fighter(new_fighter)
	else:
		_match.arena.track_fighter(new_fighter)
	if new_fighter.peer_id == multiplayer.get_unique_id():
		var provider: InputProvider = _match.bind_local_fighter(new_fighter)
		if is_server:
			new_fighter.input_provider = provider
		else:
			new_fighter.local_input_source = provider
	else:
		new_fighter.modulate = ENEMY_TINT
		if is_server:
			new_fighter.input_provider = new_fighter.net_input


func _on_fighter_killed(victim: Player, killer: Player) -> void:
	var killer_peer: int = (killer as NetFighter).peer_id if killer != null else 0
	score.record_death((victim as NetFighter).peer_id, killer_peer)
	_broadcast_score()


func _broadcast_score() -> void:
	_sync_wait = _sync_interval
	var mine: int = int(score.kills[NetworkManager.HOST_ID])
	var theirs: int = int(score.kills.get(NetworkManager.opponent_id(), 0))
	_show_score.rpc(mine, theirs, score.time_left)


## kills_of_host and kills_of_guest are from the host's point of view.
@rpc("authority", "call_local", "reliable")
func _show_score(kills_of_host: int, kills_of_guest: int, time_left: float) -> void:
	var is_host: bool = multiplayer.is_server()
	my_kills = kills_of_host if is_host else kills_of_guest
	their_kills = kills_of_guest if is_host else kills_of_host
	_time_left = time_left
	_refresh_hud()


func _refresh_hud() -> void:
	_match.hud.set_objective("You %d  -  %d Them" % [my_kills, their_kills])
	_match.hud.set_time_left(_time_left)


func _end_normally() -> void:
	var winner: int = score.winner()
	var winner_name: String = ""
	if winner != DeathmatchScore.DRAW:
		winner_name = str(NetworkManager.peers[winner]["name"])
	var result: Dictionary = {"winner": winner_name, "winner_peer": winner, "forfeit": false, "players": _score_lines()}
	_broadcast_score()
	_match_over.rpc(result)


func _score_lines() -> Array:
	var lines: Array = []
	for peer_id: int in score.kills:
		lines.append({
			"name": NetworkManager.peers[peer_id]["name"],
			"kills": score.kills[peer_id], "deaths": score.deaths[peer_id],
		})
	return lines


@rpc("authority", "call_local", "reliable")
func _match_over(result: Dictionary) -> void:
	if _finished:
		return
	_finished = true
	_stop_all_replication()
	var winner: int = result["winner_peer"]
	var outcome: String = "draw"
	if winner != DeathmatchScore.DRAW:
		outcome = "win" if winner == multiplayer.get_unique_id() else "loss"
	GameState.finish_match(result, outcome)


func _on_opponent_gone(_peer_id: int) -> void:
	if _finished:
		return
	_finished = true
	_stop_all_replication()
	# Each side only sees the other vanish, so this device's own network decides
	# which of them dropped out.
	if not NetworkManager.has_network_check.call():
		NetworkManager.leave()
		GameState.report_connection_lost()
		return
	var my_name: String = Settings.player_name
	GameState.finish_match({
		"winner": my_name, "winner_peer": multiplayer.get_unique_id(), "forfeit": true,
		"players": _forfeit_lines(my_name),
	}, "win")


func _forfeit_lines(my_name: String) -> Array:
	return [
		{"name": my_name, "kills": my_kills, "deaths": 0},
		{"name": "Opponent", "kills": their_kills, "deaths": 0},
	]


func _stop_all_replication() -> void:
	for peer_id: int in _fighters:
		var each: NetFighter = fighter(peer_id)
		if each != null:
			each.stop_replication()
