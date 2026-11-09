extends GutTest
## Every screen exists and every button leads where the design's flow says.

const DIRECTORY := "user://test_saves/screens"
const SAVE_PATH := DIRECTORY + "/save.json"
const MatchScene := preload("res://scenes/game/Match.tscn")
const ALL_SCREENS: Array[String] = [
	GameState.SPLASH, GameState.MAIN_MENU, GameState.LEVEL_SELECT, GameState.MATCH_SCENE,
	GameState.LEVEL_RESULTS, GameState.MULTIPLAYER_MENU, GameState.LAN_LOBBY,
	GameState.ONLINE_LOBBY, GameState.MATCH_RESULTS, GameState.SETTINGS_SCREEN, GameState.CREDITS,
]


func before_each() -> void:
	ProgressService.use_directory(DIRECTORY)
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)
	ProgressService.load_save()
	Settings.load_from_save()
	GameState.suppress_scene_changes = true
	GameState.last_requested_scene = ""
	GameState.requested_level = 0
	GameState.pending_level = 0
	GameState.last_result = {}
	GameState.last_match_result = {}


func after_each() -> void:
	get_tree().paused = false


func after_all() -> void:
	GameState.suppress_scene_changes = false
	ProgressService.use_directory(ProgressService.DEFAULT_DIRECTORY)
	ProgressService.load_save()
	Settings.load_from_save()


func _open(scene_path: String) -> Control:
	var screen: Control = (load(scene_path) as PackedScene).instantiate() as Control
	add_child_autofree(screen)
	return screen


func _button(screen: Node, caption: String) -> Button:
	var button: Button = screen.find_child(caption.validate_node_name(), true, false) as Button
	assert_not_null(button, "button %s" % caption)
	return button


func _assert_leads_to(scene_path: String, caption: String, target: String) -> void:
	var screen: Control = _open(scene_path)
	GameState.last_requested_scene = ""
	_button(screen, caption).pressed.emit()
	assert_eq(GameState.last_requested_scene, target, "%s on %s" % [caption, scene_path])


func _assert_back_leads_to(scene_path: String, target: String) -> void:
	var screen: Control = _open(scene_path)
	GameState.last_requested_scene = ""
	screen.notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	assert_eq(GameState.last_requested_scene, target, "Android back on %s" % scene_path)


func test_all_eleven_screens_load() -> void:
	assert_eq(ALL_SCREENS.size(), 11)
	for scene_path: String in ALL_SCREENS:
		assert_not_null(load(scene_path), scene_path)


func test_main_menu_reaches_every_section_in_one_tap() -> void:
	_assert_leads_to(GameState.MAIN_MENU, "Campaign", GameState.LEVEL_SELECT)
	_assert_leads_to(GameState.MAIN_MENU, "Multiplayer", GameState.MULTIPLAYER_MENU)
	_assert_leads_to(GameState.MAIN_MENU, "Settings", GameState.SETTINGS_SCREEN)
	_assert_leads_to(GameState.MAIN_MENU, "Credits", GameState.CREDITS)


func test_multiplayer_menu_reaches_both_lobbies() -> void:
	_assert_leads_to(GameState.MULTIPLAYER_MENU, "Local (Wi-Fi/Hotspot)", GameState.LAN_LOBBY)
	_assert_leads_to(GameState.MULTIPLAYER_MENU, "Online", GameState.ONLINE_LOBBY)


func test_no_screen_is_a_dead_end() -> void:
	_assert_leads_to(GameState.LEVEL_SELECT, "Back", GameState.MAIN_MENU)
	_assert_leads_to(GameState.MULTIPLAYER_MENU, "Back", GameState.MAIN_MENU)
	_assert_leads_to(GameState.LAN_LOBBY, "Back", GameState.MULTIPLAYER_MENU)
	_assert_leads_to(GameState.ONLINE_LOBBY, "Back", GameState.MULTIPLAYER_MENU)
	_assert_leads_to(GameState.SETTINGS_SCREEN, "Back", GameState.MAIN_MENU)
	_assert_leads_to(GameState.CREDITS, "Back", GameState.MAIN_MENU)
	_assert_leads_to(GameState.MATCH_RESULTS, "Leave", GameState.MULTIPLAYER_MENU)


func test_android_back_works_everywhere() -> void:
	_assert_back_leads_to(GameState.LEVEL_SELECT, GameState.MAIN_MENU)
	_assert_back_leads_to(GameState.MULTIPLAYER_MENU, GameState.MAIN_MENU)
	_assert_back_leads_to(GameState.LAN_LOBBY, GameState.MULTIPLAYER_MENU)
	_assert_back_leads_to(GameState.ONLINE_LOBBY, GameState.MULTIPLAYER_MENU)
	_assert_back_leads_to(GameState.SETTINGS_SCREEN, GameState.MAIN_MENU)
	_assert_back_leads_to(GameState.CREDITS, GameState.MAIN_MENU)
	_assert_back_leads_to(GameState.MATCH_RESULTS, GameState.MULTIPLAYER_MENU)
	_assert_back_leads_to(GameState.LEVEL_RESULTS, GameState.LEVEL_SELECT)


func test_level_card_starts_the_match() -> void:
	var screen: LevelSelect = _open(GameState.LEVEL_SELECT) as LevelSelect
	screen.card(1).pressed.emit()
	assert_eq(GameState.last_requested_scene, GameState.MATCH_SCENE)
	assert_eq(GameState.pending_level, 1)


func test_results_buttons_lead_onward() -> void:
	GameState.last_result = {"level_id": 2, "cleared": true, "stars": 2, "time": 100.0, "deaths": 1, "kills": 5}
	_assert_leads_to(GameState.LEVEL_RESULTS, "Next", GameState.MATCH_SCENE)
	assert_eq(GameState.pending_level, 3)
	_assert_leads_to(GameState.LEVEL_RESULTS, "Retry", GameState.MATCH_SCENE)
	assert_eq(GameState.pending_level, 2)
	_assert_leads_to(GameState.LEVEL_RESULTS, "Level Select", GameState.LEVEL_SELECT)


func test_splash_moves_on_to_the_main_menu() -> void:
	var screen: SplashScreen = SplashScreen.new()
	screen.hold_time = 0.01
	add_child_autofree(screen)
	await wait_seconds(0.1, "")
	assert_eq(GameState.last_requested_scene, GameState.MAIN_MENU)


func test_splash_warns_about_a_reset_save_and_waits() -> void:
	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	file.store_string("garbage")
	file.close()
	ProgressService.load_save()
	var screen: SplashScreen = SplashScreen.new()
	screen.hold_time = 0.01
	add_child_autofree(screen)
	await wait_seconds(0.1, "")
	assert_string_contains(screen.warning_text(), "reset to Level 1")
	assert_true(screen.ok_button_visible())
	assert_eq(GameState.last_requested_scene, "", "must wait for OK")
	_button(screen, "OK").pressed.emit()
	assert_eq(GameState.last_requested_scene, GameState.MAIN_MENU)


func test_splash_honours_the_level_flag() -> void:
	GameState.requested_level = 4
	var screen: SplashScreen = SplashScreen.new()
	screen.hold_time = 0.01
	add_child_autofree(screen)
	await wait_seconds(0.1, "")
	assert_eq(GameState.last_requested_scene, GameState.MATCH_SCENE)
	assert_eq(GameState.pending_level, 4)


func test_main_menu_shows_the_player_name() -> void:
	Settings.player_name = "Ace"
	var screen: Control = _open(GameState.MAIN_MENU)
	var found: bool = false
	for child: Node in screen.find_children("*", "Label", true, false):
		found = found or (child as Label).text == "Ace"
	assert_true(found)


func test_settings_are_saved_and_survive_a_restart() -> void:
	var screen: SettingsScreen = _open(GameState.SETTINGS_SCREEN) as SettingsScreen
	screen.music_slider.value = 0.25
	screen.sfx_slider.value = 0.5
	screen.stick_slider.value = 1.2
	screen.aim_assist_button.pressed.emit()
	screen.name_field.text = "Maverick"
	screen.name_field.text_changed.emit("Maverick")
	_button(screen, "Save").pressed.emit()
	assert_eq(GameState.last_requested_scene, GameState.MAIN_MENU)
	ProgressService.load_save()
	Settings.load_from_save()
	assert_almost_eq(Settings.music, 0.25, 0.001)
	assert_almost_eq(Settings.sfx, 0.5, 0.001)
	assert_almost_eq(Settings.stick_size, 1.2, 0.001)
	assert_false(Settings.aim_assist)
	assert_eq(Settings.player_name, "Maverick")
	assert_eq(ProgressService.reset_reason, "")


func test_leaving_settings_without_saving_discards_changes() -> void:
	var screen: SettingsScreen = _open(GameState.SETTINGS_SCREEN) as SettingsScreen
	screen.music_slider.value = 0.1
	screen.go_back()
	assert_almost_eq(Settings.music, 0.7, 0.001)


func test_volume_reaches_the_audio_bus() -> void:
	Settings.music = 0.5
	Settings.apply_audio()
	var bus: int = AudioServer.get_bus_index(AudioManager.MUSIC_BUS)
	assert_almost_eq(AudioServer.get_bus_volume_db(bus), linear_to_db(0.5), 0.01)
	Settings.music = 0.0
	Settings.apply_audio()
	assert_true(AudioServer.is_bus_mute(bus))
	Settings.load_from_save()


func test_skin_toggle_only_appears_once_earned() -> void:
	var locked: SettingsScreen = _open(GameState.SETTINGS_SCREEN) as SettingsScreen
	assert_false(locked.skin_button.visible)
	ProgressService.complete_level(10, 1, 100.0)
	var earned: SettingsScreen = _open(GameState.SETTINGS_SCREEN) as SettingsScreen
	assert_true(earned.skin_button.visible)
	earned.skin_button.pressed.emit()
	assert_eq(Settings.selected_skin, "sky_ace")


func test_credits_list_every_entry() -> void:
	var screen: Control = _open(GameState.CREDITS)
	var labels: Array[Node] = screen.find_children("*", "Label", true, false)
	var text: String = ""
	for label: Node in labels:
		text += (label as Label).text + "\n"
	var credits: Dictionary = DataFile.load_dictionary(CreditsScreen.PATH)
	for member: String in credits["team"]:
		assert_string_contains(text, member)
	for asset: Dictionary in credits["assets"]:
		assert_string_contains(text, asset["name"])
		assert_string_contains(text, asset["license"])


func test_match_results_show_winner_and_scores() -> void:
	GameState.last_match_result = {
		"winner": "Ace", "forfeit": true,
		"players": [{"name": "Ace", "kills": 7, "deaths": 2}, {"name": "Bo", "kills": 2, "deaths": 7}],
	}
	var screen: Control = _open(GameState.MATCH_RESULTS)
	var text: String = ""
	for label: Node in screen.find_children("*", "Label", true, false):
		text += (label as Label).text + "\n"
	assert_string_contains(text, "Ace wins by forfeit")
	assert_string_contains(text, "Kills 7")
	assert_string_contains(text, "Deaths 7")


func test_match_results_show_a_draw() -> void:
	GameState.last_match_result = {"winner": "", "players": []}
	var screen: Control = _open(GameState.MATCH_RESULTS)
	assert_not_null(screen.find_child("Leave", true, false))


func test_multiplayer_menu_shows_a_notice_once() -> void:
	GameState.notice = "Connection lost"
	var screen: Control = _open(GameState.MULTIPLAYER_MENU)
	var shown: bool = false
	for label: Node in screen.find_children("*", "Label", true, false):
		shown = shown or (label as Label).text == "Connection lost"
	assert_true(shown)
	assert_eq(GameState.notice, "")


func test_lan_lobby_rejects_a_bad_address() -> void:
	var screen: LanLobby = _open(GameState.LAN_LOBBY) as LanLobby
	screen.join_address("not an address")
	assert_string_contains(screen._status.text, "Enter an address")
	assert_false(NetworkManager.is_active())


func test_lan_lobby_join_panel_opens_with_manual_entry() -> void:
	var screen: LanLobby = _open(GameState.LAN_LOBBY) as LanLobby
	_button(screen, "Join").pressed.emit()
	assert_true(screen._join_panel.visible)
	assert_not_null(screen._address_field)


func test_locked_maps_cannot_be_chosen_by_the_host() -> void:
	var screen: LanLobby = _open(GameState.LAN_LOBBY) as LanLobby
	assert_false(screen._map_chooser.button("outpost").disabled)
	assert_true(screen._map_chooser.button("canyon").disabled)
	assert_true(screen._map_chooser.button("skyforge").disabled)


func test_earned_maps_can_be_chosen_by_the_host() -> void:
	ProgressService.complete_level(5, 1, 100.0)
	var screen: LanLobby = _open(GameState.LAN_LOBBY) as LanLobby
	assert_false(screen._map_chooser.button("canyon").disabled)
	assert_true(screen._map_chooser.button("skyforge").disabled)


func test_rematch_needs_an_opponent() -> void:
	GameState.last_match_result = {"winner": "Ace", "forfeit": true, "players": []}
	var screen: Control = _open(GameState.MATCH_RESULTS)
	assert_true(_button(screen, "Rematch").disabled)


func test_leaving_after_a_forfeit_returns_to_the_lobby() -> void:
	GameState.last_match_result = {"winner": "Ace", "forfeit": true, "players": []}
	_assert_leads_to(GameState.MATCH_RESULTS, "Leave", GameState.LAN_LOBBY)


func test_multiplayer_pause_menu_has_no_retry() -> void:
	var game: Match = MatchScene.instantiate() as Match
	add_child_autofree(game)
	game.pause_menu.use_multiplayer_layout()
	assert_false((game.pause_menu.find_child("Retry", true, false) as Button).visible)


func _started_match() -> Match:
	var game: Match = MatchScene.instantiate() as Match
	add_child_autofree(game)
	game.begin_campaign(1)
	return game


func test_pause_button_freezes_and_resume_unfreezes() -> void:
	var game: Match = _started_match()
	await wait_physics_frames(2, "")
	game.hud.pause_pressed.emit()
	assert_true(get_tree().paused)
	assert_true(game.pause_menu.visible)
	game.pause_menu.resume_requested.emit()
	assert_false(get_tree().paused)
	assert_false(game.pause_menu.visible)


func test_pause_menu_can_leave_the_level() -> void:
	var game: Match = _started_match()
	await wait_physics_frames(2, "")
	game.pause_game()
	game.pause_menu.quit_requested.emit()
	assert_eq(GameState.last_requested_scene, GameState.LEVEL_SELECT)


func test_pause_menu_can_retry() -> void:
	var game: Match = _started_match()
	await wait_physics_frames(2, "")
	game.pause_game()
	game.pause_menu.retry_requested.emit()
	assert_eq(GameState.last_requested_scene, GameState.MATCH_SCENE)
	assert_eq(GameState.pending_level, 1)


func test_going_to_the_background_pauses() -> void:
	var game: Match = _started_match()
	await wait_physics_frames(2, "")
	game.notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	assert_true(get_tree().paused)
	assert_true(game.pause_menu.visible)


func test_going_to_the_background_saves() -> void:
	ProgressService.notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	assert_true(FileAccess.file_exists(SAVE_PATH))


func test_android_back_in_a_match_opens_then_closes_the_pause_menu() -> void:
	var game: Match = _started_match()
	await wait_physics_frames(2, "")
	game.notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	assert_true(game.pause_menu.visible)
	game.notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	assert_false(game.pause_menu.visible)


func test_battle_music_plays_in_a_match() -> void:
	_started_match()
	assert_eq(AudioManager.current_music(), "battle")


func test_skin_is_applied_to_the_local_player() -> void:
	Settings.selected_skin = "sky_ace"
	var game: Match = _started_match()
	await wait_physics_frames(2, "")
	var visual: PlayerVisual = game.local_player.get_node("Visual") as PlayerVisual
	assert_eq((visual._torso as Polygon2D).color, AssetMap.color("amber"))
	Settings.load_from_save()
