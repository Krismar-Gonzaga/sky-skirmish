class_name RelayMultiplayerPeer
extends MultiplayerPeerExtension
## Carries Godot multiplayer packets over a WebSocket to the relay server, so
## online play uses the same gameplay code as LAN play.

signal room_ready(code: String)
## The server has been slow to answer and is probably waking from sleep.
signal waking
signal failed(message: String)
signal link_lost

enum Stage { IDLE, OPENING, HANDSHAKE, IN_ROOM, CLOSED }

const HOST_ID := 1
const MAX_PACKET_BYTES := 60000
const UNREACHABLE_MESSAGE := "Could not reach host."

var room_code: String = ""
var ping_ms: int = -1

var _socket := WebSocketPeer.new()
var _stage: Stage = Stage.IDLE
var _status: MultiplayerPeer.ConnectionStatus = MultiplayerPeer.CONNECTION_DISCONNECTED
var _url: String = ""
var _request: PackedByteArray = PackedByteArray()
var _is_host: bool = false
var _unique_id: int = 0
var _remote_id: int = 0
var _target: int = 0
var _channel: int = 0
var _mode: MultiplayerPeer.TransferMode = MultiplayerPeer.TRANSFER_MODE_RELIABLE
var _refuse_new: bool = false
var _incoming: Array[Dictionary] = []

var _wake_deadline: float = 0.0
var _waking_notice_at: float = 0.0
var _waking_announced: bool = false
var _retry_at: float = 0.0
var _handshake_deadline: float = 0.0
var _next_ping_at: float = 0.0
var _last_heard: float = 0.0
var _ping_sent_at: float = 0.0

var _config: Dictionary = Tuning.section("net")


func create_room(url: String, version: String) -> void:
	_is_host = true
	_unique_id = HOST_ID
	_begin(url, RelayProtocol.create(version))


func join_room(url: String, code: String, version: String) -> void:
	_is_host = false
	_unique_id = 0
	_begin(url, RelayProtocol.join(code, version))


## Reads one frame from the relay. Public so frames can be tested without a socket.
func handle_frame(frame: PackedByteArray) -> void:
	if frame.is_empty():
		return
	_last_heard = _now()
	match frame[0]:
		RelayProtocol.Frame.JOINED:
			_on_joined(RelayProtocol.peer_id_of(frame), RelayProtocol.code_of(frame))
		RelayProtocol.Frame.PEER_LEFT:
			_on_peer_left(RelayProtocol.peer_id_of(frame))
		RelayProtocol.Frame.DATA:
			_incoming.append({
				"peer": frame.decode_s32(RelayProtocol.PEER_ID_OFFSET),
				"channel": frame[RelayProtocol.DATA_CHANNEL_OFFSET],
				"mode": frame[RelayProtocol.DATA_MODE_OFFSET],
				"payload": frame.slice(RelayProtocol.DATA_HEADER_BYTES),
			})
		RelayProtocol.Frame.ERROR:
			_on_error(frame[1])
		RelayProtocol.Frame.PONG:
			ping_ms = roundi((_now() - _ping_sent_at) * 1000.0)


func _poll() -> void:
	if _stage == Stage.IDLE or _stage == Stage.CLOSED:
		return
	_socket.poll()
	if _stage == Stage.OPENING:
		_poll_opening()
	else:
		_poll_open_link()


func _close() -> void:
	_stage = Stage.CLOSED
	_status = MultiplayerPeer.CONNECTION_DISCONNECTED
	_incoming.clear()
	_socket.close()


func _disconnect_peer(p_peer: int, _p_force: bool) -> void:
	_send(RelayProtocol.kick(p_peer))


func _get_packet_script() -> PackedByteArray:
	if _incoming.is_empty():
		return PackedByteArray()
	var packet: Dictionary = _incoming.pop_front()
	return packet["payload"]


func _put_packet_script(p_buffer: PackedByteArray) -> Error:
	if _status != MultiplayerPeer.CONNECTION_CONNECTED:
		return ERR_UNCONFIGURED
	# WebSockets deliver everything in order, so on a slow link old unreliable
	# updates would queue up. Dropping them keeps the newest state moving.
	var limit: int = int(_config["relay_unreliable_buffer_limit"])
	if _mode != MultiplayerPeer.TRANSFER_MODE_RELIABLE and _socket.get_current_outbound_buffered_amount() > limit:
		return OK
	return _send(RelayProtocol.data(_target, _channel, _mode, p_buffer))


func _get_available_packet_count() -> int:
	return _incoming.size()


func _get_max_packet_size() -> int:
	return MAX_PACKET_BYTES


func _get_packet_peer() -> int:
	return int(_incoming[0]["peer"]) if not _incoming.is_empty() else 0


func _get_packet_channel() -> int:
	return int(_incoming[0]["channel"]) if not _incoming.is_empty() else 0


func _get_packet_mode() -> MultiplayerPeer.TransferMode:
	if _incoming.is_empty():
		return MultiplayerPeer.TRANSFER_MODE_RELIABLE
	return _incoming[0]["mode"] as MultiplayerPeer.TransferMode


func _set_target_peer(p_peer: int) -> void:
	_target = p_peer


func _set_transfer_channel(p_channel: int) -> void:
	_channel = p_channel


func _get_transfer_channel() -> int:
	return _channel


func _set_transfer_mode(p_mode: MultiplayerPeer.TransferMode) -> void:
	_mode = p_mode


func _get_transfer_mode() -> MultiplayerPeer.TransferMode:
	return _mode


func _is_server() -> bool:
	return _is_host


func _get_unique_id() -> int:
	return _unique_id


func _get_connection_status() -> MultiplayerPeer.ConnectionStatus:
	return _status


func _is_server_relay_supported() -> bool:
	return false


func _set_refuse_new_connections(p_enable: bool) -> void:
	_refuse_new = p_enable


func _is_refusing_new_connections() -> bool:
	return _refuse_new


func _begin(url: String, request: PackedByteArray) -> void:
	_url = url
	_request = request
	_status = MultiplayerPeer.CONNECTION_CONNECTING
	_stage = Stage.OPENING
	var now: float = _now()
	_wake_deadline = now + float(_config["relay_wake_timeout"])
	_waking_notice_at = now + float(_config["relay_waking_notice_after"])
	_open_socket()


func _open_socket() -> void:
	_socket = WebSocketPeer.new()
	if _socket.connect_to_url(_url) != OK:
		_fail(UNREACHABLE_MESSAGE)


## A free server can take most of a minute to wake, and may refuse connections
## while it does, so failures here are retried until the deadline.
func _poll_opening() -> void:
	var now: float = _now()
	match _socket.get_ready_state():
		WebSocketPeer.STATE_OPEN:
			_stage = Stage.HANDSHAKE
			_handshake_deadline = now + float(_config["relay_handshake_timeout"])
			_last_heard = now
			_send(_request)
			return
		WebSocketPeer.STATE_CLOSED:
			if _retry_at == 0.0:
				_retry_at = now + float(_config["relay_retry_interval"])
			elif now >= _retry_at:
				_retry_at = 0.0
				_open_socket()
	if now >= _wake_deadline:
		_fail(UNREACHABLE_MESSAGE)
	elif now >= _waking_notice_at and not _waking_announced:
		_waking_announced = true
		waking.emit()


func _poll_open_link() -> void:
	if _socket.get_ready_state() != WebSocketPeer.STATE_OPEN:
		_on_link_down()
		return
	while _socket.get_available_packet_count() > 0 and _stage != Stage.CLOSED:
		handle_frame(_socket.get_packet())
	if _stage == Stage.CLOSED:
		return
	var now: float = _now()
	if _stage == Stage.HANDSHAKE and now >= _handshake_deadline:
		_fail(UNREACHABLE_MESSAGE)
	elif _stage == Stage.IN_ROOM:
		if now - _last_heard > float(_config["relay_silence_limit"]):
			_on_link_down()
		elif now >= _next_ping_at:
			_next_ping_at = now + float(_config["relay_ping_interval"])
			_ping_sent_at = now
			_send(RelayProtocol.ping(0))


func _on_joined(peer_id: int, code: String) -> void:
	if _stage == Stage.HANDSHAKE:
		_stage = Stage.IN_ROOM
		_status = MultiplayerPeer.CONNECTION_CONNECTED
		room_code = code
		if _is_host:
			room_ready.emit(code)
		else:
			_unique_id = peer_id
			_remote_id = HOST_ID
			peer_connected.emit(HOST_ID)
	elif _is_host:
		_remote_id = peer_id
		peer_connected.emit(peer_id)


func _on_peer_left(peer_id: int) -> void:
	if _is_host:
		_remote_id = 0
		# Godot reports an error for a packet from a peer it no longer knows.
		_incoming = _incoming.filter(func(packet: Dictionary) -> bool: return packet["peer"] != peer_id)
		peer_disconnected.emit(peer_id)
	else:
		_on_link_down()


func _on_error(code: int) -> void:
	if _stage == Stage.HANDSHAKE:
		_fail(RelayProtocol.error_message(code))
	elif code == RelayProtocol.ErrorCode.ROOM_EXPIRED:
		_on_link_down()


func _on_link_down() -> void:
	var remote: int = _remote_id
	_stage = Stage.CLOSED
	_status = MultiplayerPeer.CONNECTION_DISCONNECTED
	_remote_id = 0
	_incoming.clear()
	_socket.close()
	if remote != 0:
		peer_disconnected.emit(remote)
	link_lost.emit()


func _fail(message: String) -> void:
	_stage = Stage.CLOSED
	_status = MultiplayerPeer.CONNECTION_DISCONNECTED
	_socket.close()
	failed.emit(message)


func _send(frame: PackedByteArray) -> Error:
	return _socket.send(frame, WebSocketPeer.WRITE_MODE_BINARY)


func _now() -> float:
	return Time.get_ticks_msec() / 1000.0
