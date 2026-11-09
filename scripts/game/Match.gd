class_name Match
extends Node2D
## One round of play. Owns the map, the fighters and the camera; a rules object
## decides what the round means. Campaign and 1 vs 1 share this scene.

signal match_ended(result: Dictionary)

const PlayerScene := preload("res://scenes/game/Player.tscn")
const BotScene := preload("res://scenes/game/Bot.tscn")
const PLAYER_TEAM := 0
const ENEMY_TEAM := 1
const ENEMY_TINT := Color(1.0, 0.55, 0.55)
## The map goes directly above the backdrop in draw order.
const MAP_CHILD_INDEX := 1

var map: GameMap
var context: BotContext
var local_player: Player
var rules: CampaignRules

var _level_id: int = 0
var _local_provider: InputProvider

@onready var arena: Arena = $Arena
@onready var camera: AimCamera = $Camera
@onready var effects: CombatEffects = $Effects
@onready var hud: Hud = $HUD
@onready var overlay: DebugOverlay = $DebugOverlay
@onready var pause_menu: PauseMenu = $PauseMenu


func _ready() -> void:
	# The menu must react to Esc and Android back while the game is frozen.
	process_mode = Node.PROCESS_MODE_ALWAYS
	for gameplay_node: Node in [$Backdrop, arena, effects, camera, hud, overlay]:
		gameplay_node.process_mode = Node.PROCESS_MODE_PAUSABLE
	hud.pause_pressed.connect(pause_game)
	pause_menu.resume_requested.connect(resume_game)
	pause_menu.retry_requested.connect(_retry_level)
	pause_menu.quit_requested.connect(GameState.go_to_level_select)
	if GameState.pending_level > 0:
		var level_id: int = GameState.pending_level
		GameState.pending_level = 0
		match_ended.connect(GameState.finish_level)
		begin_campaign(level_id)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED:
		pause_game()
	elif what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_toggle_pause()


func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_toggle_pause()


func begin_campaign(level_id: int) -> void:
	_level_id = level_id
	rules = CampaignRules.new()
	rules.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(rules)
	overlay.level_id = str(level_id)
	AudioManager.play_music("battle")
	rules.begin(self, level_id)


func pause_game() -> void:
	if not is_inside_tree() or get_tree().paused or rules == null:
		return
	get_tree().paused = true
	pause_menu.visible = true


func resume_game() -> void:
	get_tree().paused = false
	pause_menu.visible = false
	# Fingers lifted while frozen were never seen by the sticks.
	if _local_provider != null:
		_local_provider.reset()


func _toggle_pause() -> void:
	if pause_menu.visible:
		resume_game()
	else:
		pause_game()


func _retry_level() -> void:
	GameState.start_level(_level_id)


func load_map(map_id: String, crate_pool: Array[String]) -> void:
	if map != null:
		remove_child(map)
		map.queue_free()
		arena.clear_world()
	map = (load(LevelManager.map_scene_path(map_id)) as PackedScene).instantiate() as GameMap
	map.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(map)
	move_child(map, MAP_CHILD_INDEX)
	arena.setup(map, crate_pool)
	context = BotContext.new(map, arena)
	camera.set_bounds(map.get_bounds())


func spawn_local_player() -> void:
	local_player = _spawn(PlayerScene, map.spawn_points[0], PLAYER_TEAM)
	local_player.apply_skin(Settings.selected_skin)
	_local_provider = InputFactory.create_local_provider()
	if _local_provider is TouchInputProvider:
		_local_provider = AimAssistProvider.new(_local_provider, local_player, arena.fighters)
	_local_provider.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(_local_provider)
	local_player.input_provider = _local_provider
	camera.target = local_player
	camera.snap_to_target()
	effects.bind(arena, camera, local_player)
	hud.bind(local_player)
	overlay.watched_player = local_player


## Moves the player to the start of a freshly loaded map.
func place_local_player_at_start() -> void:
	local_player.global_position = map.spawn_points[0]
	local_player.velocity = Vector2.ZERO
	camera.snap_to_target()


func spawn_bot(at: Vector2, difficulty_id: String, hp_override: float = 0.0) -> Bot:
	var bot: Bot = _spawn(BotScene, at, ENEMY_TEAM) as Bot
	bot.setup(context, difficulty_id, hp_override)
	bot.modulate = ENEMY_TINT
	return bot


func spawn_dummy(at: Vector2, hp: float) -> Player:
	var dummy: Player = _spawn(PlayerScene, at, ENEMY_TEAM)
	dummy.health.set_maximum(hp)
	dummy.respawns = false
	dummy.modulate = ENEMY_TINT
	return dummy


func remove_fighter(fighter: Player) -> void:
	arena.unregister_fighter(fighter)
	fighter.queue_free()


func end_match(result: Dictionary) -> void:
	match_ended.emit(result)


func _spawn(scene: PackedScene, at: Vector2, team: int) -> Player:
	var fighter: Player = scene.instantiate() as Player
	fighter.team = team
	arena.add_child(fighter)
	fighter.global_position = at
	arena.register_fighter(fighter)
	return fighter
