class_name CreditsScreen
extends MenuScreen
## Team names and every third-party asset, read from data/credits.json.

const PATH := "res://data/credits.json"
const SECTION_FONT_SIZE := 30
const ENTRY_FONT_SIZE := 22
const LIST_SIZE := Vector2(900.0, 460.0)


func _build() -> void:
	back_target = GameState.MAIN_MENU
	add_back_button()
	var credits: Dictionary = DataFile.load_dictionary(PATH)
	var page: VBoxContainer = make_centred_column()
	add_heading(page, "Credits")
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = LIST_SIZE
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	page.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	add_label(list, "Team", SECTION_FONT_SIZE, "amber")
	for member: String in credits.get("team", []):
		add_label(list, member, ENTRY_FONT_SIZE, "text")
	add_label(list, "Tools and assets", SECTION_FONT_SIZE, "amber")
	for asset: Dictionary in credits.get("assets", []):
		var line: String = "%s, %s (%s)" % [asset["name"], asset["author"], asset["license"]]
		add_label(list, line, ENTRY_FONT_SIZE, "text")
