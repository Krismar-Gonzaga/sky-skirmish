extends Node
## Hosts or joins matches and tracks who is connected. Gameplay code only sees
## Godot's multiplayer API, so it never knows which transport is in use.

signal hosted
signal joined
signal join_failed(message: String)
signal peer_joined(peer_id: int)
signal peer_left(peer_id: int)
signal connection_lost
signal match_starting(map_id: String)
signal scene_ready_changed
signal rematch_votes_changed

const HOST_ID := 1
const UNREACHABLE_MESSAGE := "Could not reach host."
const UPDATE_REQUIRED_MESSAGE := "Update required"
## Gives the rejection message time to arrive before the connection is cut.
const REJECT_DELAY := 0.25
## Only one guest: matches are 1 vs 1.
const MAX_GUESTS := 1

var game_version: String = ""
## peer id to {"name": String, "skin": String}, including this device.
var peers: Dictionary = {}
var last_map: String = ""
## Replaced in tests to simulate losing the network.
var has_network_check: Callable = has_local_network

var _config: Dictionary = {}
var _active: bool = false
var _joining: bool = false
var _join_left: float = 0.0
var _scene_ready: Dictionary = {}
var _rematch_votes: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_config = Tuning.section("net")
	game_version = str(ProjectSettings.get_setting("application/config/version"))
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)


func _process(delta: float) -> void:
	if _joining:
		_join_left -= delta
		if _join_left <= 0.0:
			_fail_join(UNREACHABLE_MESSAGE)


func is_active() -> bool:
	return _active


func is_host() -> bool:
	return _active and multiplayer.is_server()


func has_opponent() -> bool:
	return _active and peers.size() > 1


func opponent_id() -> int:
	for peer_id: int in peers:
		if peer_id != multiplayer.get_unique_id():
			return peer_id
	return 0


func host_lan(port: int = 0) -> bool:
	var peer := ENetMultiplayerPeer.new()
	var chosen_port: int = port if port > 0 else int(_config["lan_port"])
	if peer.create_server(chosen_port, MAX_GUESTS) != OK:
		return false
	_begin_session(peer)
	peers[HOST_ID] = _describe_self()
	hosted.emit()
	return true


func join_lan(address: String, port: int = 0) -> void:
	var peer := ENetMultiplayerPeer.new()
	var chosen_port: int = port if port > 0 else int(_config["lan_port"])
	if not address.is_valid_ip_address() or peer.create_client(address, chosen_port) != OK:
		join_failed.emit(UNREACHABLE_MESSAGE)
		return
	_begin_session(peer)
	_joining = true
	_join_left = _config["join_timeout"]


func leave() -> void:
	_active = false
	_joining = false
	peers.clear()
	_scene_ready.clear()
	_rematch_votes.clear()
	# Deferred: this often runs inside a disconnect callback, and replacing the
	# peer while it is polling crashes the engine.
	_close_peer.call_deferred()


func start_match(map_id: String) -> void:
	if not is_host():
		return
	last_map = map_id
	_scene_ready.clear()
	_rematch_votes.clear()
	_begin_match.rpc(map_id)


## Tells the host this device has loaded the match and can receive spawns.
func report_scene_ready() -> void:
	if multiplayer.is_server():
		_mark_scene_ready(HOST_ID)
	else:
		_scene_is_ready.rpc_id(HOST_ID)


func all_scenes_ready() -> bool:
	for peer_id: int in peers:
		if not _scene_ready.has(peer_id):
			return false
	return true


func vote_rematch() -> void:
	if multiplayer.is_server():
		_add_rematch_vote(HOST_ID)
	else:
		_request_rematch.rpc_id(HOST_ID)


func rematch_vote_count() -> int:
	return _rematch_votes.size()


func has_local_network() -> bool:
	return not local_ipv4_addresses().is_empty()


## Addresses another device could reach this one on.
func local_ipv4_addresses() -> PackedStringArray:
	var found := PackedStringArray()
	for address: String in IP.get_local_addresses():
		var is_ipv4: bool = address.is_valid_ip_address() and not address.contains(":")
		if is_ipv4 and not address.begins_with("127.") and not address.begins_with("169.254."):
			found.append(address)
	return found


func ping_ms() -> int:
	var peer := multiplayer.multiplayer_peer as ENetMultiplayerPeer
	if peer == null or not _active or multiplayer.is_server():
		return -1
	var host_peer: ENetPacketPeer = peer.get_peer(HOST_ID)
	if host_peer == null:
		return -1
	return int(host_peer.get_statistic(ENetPacketPeer.PEER_ROUND_TRIP_TIME))


func _close_peer() -> void:
	if _active:
		return
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()


func _begin_session(peer: MultiplayerPeer) -> void:
	multiplayer.multiplayer_peer = peer
	_active = true
	peers.clear()
	_scene_ready.clear()
	_rematch_votes.clear()


func _describe_self() -> Dictionary:
	return {"name": Settings.player_name, "skin": Settings.selected_skin}


func _fail_join(message: String) -> void:
	leave()
	join_failed.emit(message)


## Short limits so a phone that loses Wi-Fi is noticed in seconds, not half a minute.
func _apply_timeouts(peer_id: int) -> void:
	var peer := multiplayer.multiplayer_peer as ENetMultiplayerPeer
	if peer == null:
		return
	var connection: ENetPacketPeer = peer.get_peer(peer_id)
	if connection != null:
		connection.set_timeout(0, int(_config["peer_timeout_min_ms"]), int(_config["peer_timeout_max_ms"]))


func _on_peer_connected(peer_id: int) -> void:
	if multiplayer.is_server():
		_apply_timeouts(peer_id)


func _on_connected_to_server() -> void:
	_apply_timeouts(HOST_ID)
	_hello.rpc_id(HOST_ID, game_version, Settings.player_name, Settings.selected_skin)


func _on_connection_failed() -> void:
	if _joining:
		_fail_join(UNREACHABLE_MESSAGE)


func _on_server_disconnected() -> void:
	if _joining:
		_fail_join(UNREACHABLE_MESSAGE)
	elif _active:
		_active = false
		connection_lost.emit()


func _on_peer_disconnected(peer_id: int) -> void:
	if not _active or not peers.has(peer_id):
		return
	peers.erase(peer_id)
	_rematch_votes.erase(peer_id)
	peer_left.emit(peer_id)


func _mark_scene_ready(peer_id: int) -> void:
	_scene_ready[peer_id] = true
	scene_ready_changed.emit()


func _add_rematch_vote(peer_id: int) -> void:
	_rematch_votes[peer_id] = true
	_broadcast_rematch_votes.rpc(_rematch_votes.keys())
	if _rematch_votes.size() >= peers.size():
		start_match(last_map)


@rpc("any_peer", "call_remote", "reliable")
func _hello(version: String, player_name: String, skin: String) -> void:
	if not multiplayer.is_server():
		return
	var sender: int = multiplayer.get_remote_sender_id()
	if version != game_version:
		_rejected.rpc_id(sender, UPDATE_REQUIRED_MESSAGE)
		await get_tree().create_timer(REJECT_DELAY).timeout
		# The rejected client usually hangs up first.
		if _active and sender in multiplayer.get_peers():
			multiplayer.multiplayer_peer.disconnect_peer(sender)
		return
	peers[sender] = {"name": player_name.left(Settings.MAX_NAME_LENGTH), "skin": skin}
	_welcome.rpc_id(sender, peers)
	peer_joined.emit(sender)


@rpc("authority", "call_remote", "reliable")
func _welcome(all_peers: Dictionary) -> void:
	_joining = false
	peers = all_peers
	joined.emit()


@rpc("authority", "call_remote", "reliable")
func _rejected(message: String) -> void:
	_fail_join(message)


@rpc("authority", "call_local", "reliable")
func _begin_match(map_id: String) -> void:
	last_map = map_id
	_scene_ready.clear()
	_rematch_votes.clear()
	match_starting.emit(map_id)


@rpc("any_peer", "call_remote", "reliable")
func _scene_is_ready() -> void:
	if multiplayer.is_server():
		_mark_scene_ready(multiplayer.get_remote_sender_id())


@rpc("any_peer", "call_remote", "reliable")
func _request_rematch() -> void:
	if multiplayer.is_server():
		_add_rematch_vote(multiplayer.get_remote_sender_id())


@rpc("authority", "call_local", "reliable")
func _broadcast_rematch_votes(voters: Array) -> void:
	_rematch_votes.clear()
	for voter: int in voters:
		_rematch_votes[voter] = true
	rematch_votes_changed.emit()
