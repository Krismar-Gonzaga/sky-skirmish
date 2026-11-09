class_name OnlineLobby
extends MenuScreen
## Creating and joining rooms over the internet. Networking is wired up in M7.


func _build() -> void:
	back_target = GameState.MULTIPLAYER_MENU
	add_back_button()
	var column: VBoxContainer = make_centred_column()
	add_heading(column, "Online Match")
	add_label(column, "Online play is not available yet.", BODY_FONT_SIZE, "muted")
	for caption: String in ["Create", "Join", "Start"]:
		add_button(column, caption, func() -> void: pass).disabled = true
