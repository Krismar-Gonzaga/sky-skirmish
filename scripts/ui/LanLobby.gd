class_name LanLobby
extends MenuScreen
## Host a match on this device, or find and join one on the same network.

const ADDRESS_FONT_SIZE := 64
const FOUND_HOSTS_SHOWN := 3
const MAP_IDS: Array[String] = ["outpost", "canyon", "skyforge"]
const ROW_SPACING := 12
const MANUAL_FIELD_WIDTH := 340.0
const JOIN_COLUMNS_GAP := 40

var _choice_row: HBoxContainer
var _host_panel: VBoxContainer
var _join_panel: HBoxContainer
var _status: Label
var _address_label: Label
var _found_list: VBoxContainer
var _address_field: LineEdit
var _start_button: Button
var _map_buttons: Dictionary = {}
var _chosen_map: String = "outpost"
var _broadcaster: LanBroadcaster
var _listener: LanListener


func _build() -> void:
	back_target = GameState.MULTIPLAYER_MENU
	add_back_button()
	var column: VBoxContainer = make_centred_column()
	add_heading(column, "Local Match")
	_choice_row = HBoxContainer.new()
	_choice_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_choice_row.add_theme_constant_override("separation", COLUMN_SPACING)
	column.add_child(_choice_row)
	add_button(_choice_row, "Host", show_host)
	add_button(_choice_row, "Join", show_join)
	_build_host_panel(column)
	_build_join_panel(column)
	_status = add_label(column, "", BODY_FONT_SIZE, "amber")
	NetworkManager.hosted.connect(_on_hosted)
	NetworkManager.peer_joined.connect(_on_peer_joined)
	NetworkManager.peer_left.connect(_on_peer_left)
	NetworkManager.joined.connect(_on_joined)
	NetworkManager.join_failed.connect(_on_join_failed)
	NetworkManager.connection_lost.connect(_on_connection_lost)
	if GameState.auto_host:
		show_host()
	elif not GameState.auto_join.is_empty():
		show_join()
		join_address(GameState.auto_join)


func go_back() -> void:
	NetworkManager.leave()
	super()


func show_host() -> void:
	_choice_row.visible = false
	_host_panel.visible = true
	if not NetworkManager.host_lan():
		_status.text = "Could not start hosting."
		return
	_broadcaster = LanBroadcaster.new()
	add_child(_broadcaster)


func show_join() -> void:
	_choice_row.visible = false
	_join_panel.visible = true
	_listener = LanListener.new()
	add_child(_listener)
	_listener.hosts_changed.connect(_refresh_found_hosts)


func join_address(address: String) -> void:
	if not address.is_valid_ip_address():
		_status.text = "Enter an address like 192.168.1.5"
		return
	_status.text = "Connecting..."
	NetworkManager.join_lan(address)


func _start_match() -> void:
	NetworkManager.start_match(_chosen_map)


func _build_host_panel(parent: Control) -> void:
	_host_panel = VBoxContainer.new()
	_host_panel.visible = false
	_host_panel.add_theme_constant_override("separation", ROW_SPACING)
	parent.add_child(_host_panel)
	add_label(_host_panel, "Your address", BODY_FONT_SIZE, "muted")
	_address_label = add_label(_host_panel, "", ADDRESS_FONT_SIZE, "amber")
	var maps := HBoxContainer.new()
	maps.alignment = BoxContainer.ALIGNMENT_CENTER
	maps.add_theme_constant_override("separation", ROW_SPACING)
	_host_panel.add_child(maps)
	for map_id: String in MAP_IDS:
		var button: Button = add_button(maps, map_id.capitalize(), _choose_map.bind(map_id))
		button.disabled = not ProgressService.is_map_unlocked(map_id)
		_map_buttons[map_id] = button
	_start_button = add_button(_host_panel, "Start", _start_match)
	_start_button.disabled = true
	_choose_map(_chosen_map)


func _build_join_panel(parent: Control) -> void:
	_join_panel = HBoxContainer.new()
	_join_panel.visible = false
	_join_panel.add_theme_constant_override("separation", JOIN_COLUMNS_GAP)
	parent.add_child(_join_panel)
	_found_list = VBoxContainer.new()
	_found_list.add_theme_constant_override("separation", ROW_SPACING)
	_join_panel.add_child(_found_list)
	add_label(_found_list, "Searching for hosts...", BODY_FONT_SIZE, "muted")
	var manual := VBoxContainer.new()
	manual.add_theme_constant_override("separation", ROW_SPACING)
	_join_panel.add_child(manual)
	add_label(manual, "Or type the host's address", BODY_FONT_SIZE, "muted")
	_address_field = LineEdit.new()
	_address_field.custom_minimum_size.x = MANUAL_FIELD_WIDTH
	_address_field.placeholder_text = "192.168.1.5"
	_address_field.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_NUMBER_DECIMAL
	manual.add_child(_address_field)
	add_button(manual, "Connect", func() -> void: join_address(_address_field.text.strip_edges()))


func _choose_map(map_id: String) -> void:
	_chosen_map = map_id
	for each: String in _map_buttons:
		var button: Button = _map_buttons[each]
		button.modulate = AssetMap.color("amber") if each == map_id else Color.WHITE


func _refresh_found_hosts() -> void:
	for child: Node in _found_list.get_children():
		_found_list.remove_child(child)
		child.queue_free()
	if _listener.hosts.is_empty():
		add_label(_found_list, "Searching for hosts...", BODY_FONT_SIZE, "muted")
		return
	var shown: int = 0
	for address: String in _listener.hosts:
		if shown >= FOUND_HOSTS_SHOWN:
			break
		var caption: String = "%s  (%s)" % [_listener.hosts[address]["name"], address]
		add_button(_found_list, caption, join_address.bind(address))
		shown += 1


func _on_hosted() -> void:
	var addresses: PackedStringArray = NetworkManager.local_ipv4_addresses()
	_address_label.text = addresses[0] if not addresses.is_empty() else "No network"
	_status.text = "Waiting for a player..."


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
