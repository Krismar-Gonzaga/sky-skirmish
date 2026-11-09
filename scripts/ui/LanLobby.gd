class_name LanLobby
extends MenuScreen
## Hosting and joining over local Wi-Fi. Networking is wired up in M6.


func _build() -> void:
	back_target = GameState.MULTIPLAYER_MENU
	add_back_button()
	var column: VBoxContainer = make_centred_column()
	add_heading(column, "Local Match")
	add_label(column, "Local play is not available yet.", BODY_FONT_SIZE, "muted")
	for caption: String in ["Host", "Join", "Start"]:
		add_button(column, caption, func() -> void: pass).disabled = true
