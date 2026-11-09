class_name MultiplayerMenu
extends MenuScreen
## Chooses between playing over local Wi-Fi or over the internet.


func _build() -> void:
	back_target = GameState.MAIN_MENU
	add_back_button()
	var column: VBoxContainer = make_centred_column()
	add_heading(column, "Multiplayer")
	if not GameState.notice.is_empty():
		add_label(column, GameState.notice, BODY_FONT_SIZE, "danger")
		GameState.notice = ""
	add_button(column, "Local (Wi-Fi/Hotspot)", goes_to(GameState.LAN_LOBBY))
	add_button(column, "Online", goes_to(GameState.ONLINE_LOBBY))
