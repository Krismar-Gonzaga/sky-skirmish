extends GutTest
## Frame layout, and the peer's handling of frames without a real socket.

var peer: RelayMultiplayerPeer


func before_each() -> void:
	peer = RelayMultiplayerPeer.new()
	peer._stage = RelayMultiplayerPeer.Stage.HANDSHAKE
	peer._status = MultiplayerPeer.CONNECTION_CONNECTING


func _joined(peer_id: int, code: String) -> PackedByteArray:
	var frame := PackedByteArray()
	frame.resize(5)
	frame[0] = RelayProtocol.Frame.JOINED
	frame.encode_u32(1, peer_id)
	frame.append_array(code.to_ascii_buffer())
	return frame


func _peer_left(peer_id: int) -> PackedByteArray:
	var frame := PackedByteArray()
	frame.resize(5)
	frame[0] = RelayProtocol.Frame.PEER_LEFT
	frame.encode_u32(1, peer_id)
	return frame


func test_create_frame_layout() -> void:
	var frame: PackedByteArray = RelayProtocol.create("1.0.3")
	assert_eq(frame[0], 1)
	assert_eq(frame.slice(1).get_string_from_utf8(), "1.0.3")


func test_join_frame_layout() -> void:
	var frame: PackedByteArray = RelayProtocol.join("K7Q2PX", "1.0.3")
	assert_eq(frame[0], 2)
	assert_eq(frame.slice(1, 7).get_string_from_ascii(), "K7Q2PX")
	assert_eq(frame.slice(7).get_string_from_utf8(), "1.0.3")


func test_data_frame_layout() -> void:
	var frame: PackedByteArray = RelayProtocol.data(-2, 3, 1, PackedByteArray([9, 8]))
	assert_eq(frame[0], 5)
	assert_eq(frame.decode_s32(1), -2)
	assert_eq(frame[5], 3)
	assert_eq(frame[6], 1)
	assert_eq(frame.slice(7), PackedByteArray([9, 8]))


func test_error_messages_match_the_design() -> void:
	assert_eq(RelayProtocol.error_message(RelayProtocol.ErrorCode.ROOM_NOT_FOUND), "Room not found")
	assert_eq(RelayProtocol.error_message(RelayProtocol.ErrorCode.VERSION_MISMATCH), "Update required")


func test_design_port_timings_and_wake_allowance() -> void:
	var net: Dictionary = Tuning.section("net")
	assert_eq(float(net["relay_wake_timeout"]), 60.0)
	assert_eq(float(net["relay_handshake_timeout"]), 10.0)


func test_host_is_connected_when_the_room_is_ready() -> void:
	peer._is_host = true
	peer._unique_id = 1
	watch_signals(peer)
	peer.handle_frame(_joined(1, "K7Q2PX"))
	assert_eq(peer._get_connection_status(), MultiplayerPeer.CONNECTION_CONNECTED)
	assert_signal_emitted_with_parameters(peer, "room_ready", ["K7Q2PX"])


func test_host_hears_about_a_guest_joining() -> void:
	peer._is_host = true
	peer._unique_id = 1
	peer.handle_frame(_joined(1, "K7Q2PX"))
	watch_signals(peer)
	peer.handle_frame(_joined(2, "K7Q2PX"))
	assert_signal_emitted_with_parameters(peer, "peer_connected", [2])


func test_guest_learns_its_id_and_sees_the_host() -> void:
	watch_signals(peer)
	peer.handle_frame(_joined(5, "K7Q2PX"))
	assert_eq(peer._get_unique_id(), 5)
	assert_false(peer._is_server())
	assert_signal_emitted_with_parameters(peer, "peer_connected", [1])


func test_packets_keep_their_order_and_details() -> void:
	peer.handle_frame(RelayProtocol.data(3, 2, 1, PackedByteArray([1])))
	peer.handle_frame(RelayProtocol.data(4, 7, 0, PackedByteArray([2, 2])))
	assert_eq(peer._get_available_packet_count(), 2)
	assert_eq(peer._get_packet_peer(), 3)
	assert_eq(peer._get_packet_channel(), 2)
	assert_eq(peer._get_packet_mode(), MultiplayerPeer.TRANSFER_MODE_UNRELIABLE_ORDERED)
	assert_eq(peer._get_packet_script(), PackedByteArray([1]))
	assert_eq(peer._get_packet_peer(), 4)
	assert_eq(peer._get_packet_script(), PackedByteArray([2, 2]))
	assert_eq(peer._get_available_packet_count(), 0)


func test_host_keeps_the_room_when_the_guest_leaves() -> void:
	peer._is_host = true
	peer._unique_id = 1
	peer.handle_frame(_joined(1, "K7Q2PX"))
	peer.handle_frame(_joined(2, "K7Q2PX"))
	watch_signals(peer)
	peer.handle_frame(_peer_left(2))
	assert_signal_emitted_with_parameters(peer, "peer_disconnected", [2])
	assert_eq(peer._get_connection_status(), MultiplayerPeer.CONNECTION_CONNECTED)


func test_guest_is_disconnected_when_the_host_leaves() -> void:
	peer.handle_frame(_joined(2, "K7Q2PX"))
	watch_signals(peer)
	peer.handle_frame(_peer_left(1))
	assert_signal_emitted_with_parameters(peer, "peer_disconnected", [1])
	assert_signal_emitted(peer, "link_lost")
	assert_eq(peer._get_connection_status(), MultiplayerPeer.CONNECTION_DISCONNECTED)


func test_error_during_handshake_reports_the_message() -> void:
	watch_signals(peer)
	peer.handle_frame(PackedByteArray([RelayProtocol.Frame.ERROR, RelayProtocol.ErrorCode.ROOM_NOT_FOUND]))
	assert_signal_emitted_with_parameters(peer, "failed", ["Room not found"])
	assert_eq(peer._get_connection_status(), MultiplayerPeer.CONNECTION_DISCONNECTED)


func test_online_lobby_needs_a_six_character_code() -> void:
	GameState.suppress_scene_changes = true
	var screen: OnlineLobby = (load(GameState.ONLINE_LOBBY) as PackedScene).instantiate() as OnlineLobby
	add_child_autofree(screen)
	screen.join_room("ABC")
	assert_string_contains(screen._status.text, "6 characters")
	assert_false(NetworkManager.is_active())
	GameState.suppress_scene_changes = false


func test_online_lobby_explains_a_missing_relay() -> void:
	GameState.suppress_scene_changes = true
	var saved: String = GameState.relay_override
	GameState.relay_override = ""
	var screen: OnlineLobby = (load(GameState.ONLINE_LOBBY) as PackedScene).instantiate() as OnlineLobby
	add_child_autofree(screen)
	screen.create_room()
	assert_eq(NetworkManager.relay_url(), "")
	assert_eq(screen._status.text, OnlineLobby.NO_RELAY_MESSAGE)
	GameState.relay_override = saved
	GameState.suppress_scene_changes = false


func test_online_lobby_shows_the_waking_notice() -> void:
	GameState.suppress_scene_changes = true
	var screen: OnlineLobby = (load(GameState.ONLINE_LOBBY) as PackedScene).instantiate() as OnlineLobby
	add_child_autofree(screen)
	NetworkManager.server_waking.emit()
	assert_eq(screen._status.text, "Waking server…")
	GameState.suppress_scene_changes = false
