class_name MatchResults
extends MenuScreen
## Who won a 1 vs 1 match, with kills and deaths for each player.

const WINNER_FONT_SIZE := 56


func _build() -> void:
	back_target = GameState.MULTIPLAYER_MENU
	var result: Dictionary = GameState.last_match_result
	var column: VBoxContainer = make_centred_column()
	add_label(column, _heading_for(result), WINNER_FONT_SIZE, "amber")
	for entry: Dictionary in result.get("players", []):
		var line: String = "%s    Kills %d    Deaths %d" % [entry["name"], entry["kills"], entry["deaths"]]
		add_label(column, line, BODY_FONT_SIZE, "text")
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", COLUMN_SPACING)
	column.add_child(row)
	add_button(row, "Rematch", func() -> void: pass).disabled = true
	add_button(row, "Leave", go_back)


func _heading_for(result: Dictionary) -> String:
	var winner: String = result.get("winner", "")
	if winner.is_empty():
		return "Draw"
	return "%s wins by forfeit" % winner if result.get("forfeit", false) else "%s wins" % winner
