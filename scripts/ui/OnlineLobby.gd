class_name OnlineLobby
extends MenuScreen
## Create a room and share its code, or join one by typing the code.

const CODE_FONT_SIZE := 72
const ROW_SPACING := 12
const CODE_FIELD_WIDTH := 340.0
const WAKING_MESSAGE := "Waking server…"
const NO_RELAY_MESSAGE := "Online server is not set up in this build."

var _choice_row: HBoxContainer
var _create_panel: VBoxContainer
var _join_panel: VBoxContainer
var _status: Label
var _code_label: Label
var _code_field: LineEdit
var _start_button: Button
var _map_chooser: MapChooser


func _build() -> void:
	back_target = GameState.MULTIPLAYER_MENU
	GameState.current_lobby = GameState.ONLINE_LOBBY
	add_back_button()
	var column: VBoxContainer = make_centred_column()
	add_heading(column, "Online Match")
	_choice_row = HBoxContainer.new()
	_choice_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_choice_row.add_theme_constant_override("separation", COLUMN_SPACING)
	column.add_child(_choice_row)
	add_button(_choice_row, "Create Room", create_room)
	add_button(_choice_row, "Join Room", show_join)
	_build_create_panel(column)
	_build_join_panel(column)
	_status = add_label(column, "", BODY_FONT_SIZE, "amber")
	NetworkManager.room_created.connect(_on_room_created)
	NetworkManager.server_waking.connect(_on_server_waking)
	NetworkManager.peer_joined.connect(_on_peer_joined)
	NetworkManager.peer_left.connect(_on_peer_left)
	NetworkManager.joined.connect(_on_joined)
	NetworkManager.join_failed.connect(_on_join_failed)
	NetworkManager.connection_lost.connect(_on_connection_lost)
	if not GameState.relay_override.is_empty():
		if not GameState.auto_room.is_empty():
			show_join()
			join_room(GameState.auto_room)
		elif GameState.auto_host:
			create_room()


func go_back() -> void:
	NetworkManager.leave()
	super()


func create_room() -> void:
	if not _has_relay():
		return
	_choice_row.visible = false
	_create_panel.visible = true
	_status.text = "Connecting..."
	NetworkManager.host_online(NetworkManager.relay_url())


func show_join() -> void:
	_choice_row.visible = false
	_join_panel.visible = true


func join_room(code: String) -> void:
	var cleaned: String = code.strip_edges().to_upper()
	if cleaned.length() != RelayProtocol.CODE_LENGTH:
		_status.text = "Room codes have %d characters." % RelayProtocol.CODE_LENGTH
		return
	if not _has_relay():
		return
	_status.text = "Connecting..."
	NetworkManager.join_online(NetworkManager.relay_url(), cleaned)


func _has_relay() -> bool:
	if NetworkManager.relay_url().is_empty():
		_status.text = NO_RELAY_MESSAGE
		return false
	return true


func _start_match() -> void:
	NetworkManager.start_match(_map_chooser.chosen_map)


func _build_create_panel(parent: Control) -> void:
	_create_panel = VBoxContainer.new()
	_create_panel.visible = false
	_create_panel.add_theme_constant_override("separation", ROW_SPACING)
	parent.add_child(_create_panel)
	add_label(_create_panel, "Room code", BODY_FONT_SIZE, "muted")
	_code_label = add_label(_create_panel, "------", CODE_FONT_SIZE, "amber")
	_map_chooser = MapChooser.new()
	_create_panel.add_child(_map_chooser)
	_start_button = add_button(_create_panel, "Start", _start_match)
	_start_button.disabled = true


func _build_join_panel(parent: Control) -> void:
	_join_panel = VBoxContainer.new()
	_join_panel.visible = false
	_join_panel.add_theme_constant_override("separation", ROW_SPACING)
	parent.add_child(_join_panel)
	add_label(_join_panel, "Type the room code", BODY_FONT_SIZE, "muted")
	_code_field = LineEdit.new()
	_code_field.custom_minimum_size.x = CODE_FIELD_WIDTH
	_code_field.max_length = RelayProtocol.CODE_LENGTH
	_code_field.placeholder_text = "K7Q2PX"
	_code_field.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_join_panel.add_child(_code_field)
	add_button(_join_panel, "Join", func() -> void: join_room(_code_field.text))


func _on_room_created(code: String) -> void:
	_code_label.text = code
	_status.text = "Waiting for a player..."


func _on_server_waking() -> void:
	_status.text = WAKING_MESSAGE


func _on_peer_joined(peer_id: int) -> void:
	_status.text = "%s joined" % NetworkManager.peers[peer_id]["name"]
	_start_button.disabled = false
	if GameState.auto_host:
		_start_match()


func _on_peer_left(_peer_id: int) -> void:
	_status.text = "Waiting for a player..."
	_start_button.disabled = true


func _on_joined() -> void:
	_status.text = "Connected. Waiting for the host to start."


func _on_join_failed(message: String) -> void:
	_status.text = message


func _on_connection_lost() -> void:
	_status.text = "Connection lost"
