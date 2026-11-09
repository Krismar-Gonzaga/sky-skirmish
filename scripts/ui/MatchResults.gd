class_name MatchResults
extends MenuScreen
## Who won a 1 vs 1 match, with kills and deaths for each player.

const WINNER_FONT_SIZE := 56

var _rematch_button: Button
var _status: Label


func _build() -> void:
	var result: Dictionary = GameState.last_match_result
	# After a forfeit the survivor goes straight back to the lobby to host again.
	back_target = GameState.current_lobby if result.get("forfeit", false) else GameState.MULTIPLAYER_MENU
	var column: VBoxContainer = make_centred_column()
	add_label(column, _heading_for(result), WINNER_FONT_SIZE, "amber")
	for entry: Dictionary in result.get("players", []):
		var line: String = "%s    Kills %d    Deaths %d" % [entry["name"], entry["kills"], entry["deaths"]]
		add_label(column, line, BODY_FONT_SIZE, "text")
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", COLUMN_SPACING)
	column.add_child(row)
	_rematch_button = add_button(row, "Rematch", _on_rematch_pressed)
	_rematch_button.disabled = not NetworkManager.has_opponent()
	add_button(row, "Leave", go_back)
	_status = add_label(column, "", BODY_FONT_SIZE, "muted")
	NetworkManager.peer_left.connect(_on_opponent_gone.unbind(1))
	NetworkManager.connection_lost.connect(_on_opponent_gone)
	NetworkManager.rematch.votes_changed.connect(_on_votes_changed)


func go_back() -> void:
	NetworkManager.leave()
	super()


func _on_rematch_pressed() -> void:
	_rematch_button.disabled = true
	_status.text = "Waiting for the other player..."
	NetworkManager.rematch.vote()


func _on_votes_changed() -> void:
	if NetworkManager.rematch.count() > 0 and not _rematch_button.disabled:
		_status.text = "The other player wants a rematch."


func _on_opponent_gone() -> void:
	_rematch_button.disabled = true
	_status.text = "The other player left."


func _heading_for(result: Dictionary) -> String:
	var winner: String = result.get("winner", "")
	if winner.is_empty():
		return "Draw"
	return "%s wins by forfeit" % winner if result.get("forfeit", false) else "%s wins" % winner
