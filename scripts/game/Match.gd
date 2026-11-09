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

@onready var arena: Arena = $Arena
@onready var camera: AimCamera = $Camera
@onready var effects: CombatEffects = $Effects
@onready var hud: Hud = $HUD
@onready var overlay: DebugOverlay = $DebugOverlay


func _ready() -> void:
	if GameState.pending_level > 0:
		var level_id: int = GameState.pending_level
		GameState.pending_level = 0
		match_ended.connect(GameState.finish_level)
		begin_campaign(level_id)


func begin_campaign(level_id: int) -> void:
	rules = CampaignRules.new()
	add_child(rules)
	overlay.level_id = str(level_id)
	rules.begin(self, level_id)


func load_map(map_id: String, crate_pool: Array[String]) -> void:
	if map != null:
		remove_child(map)
		map.queue_free()
		arena.clear_world()
	map = (load(LevelManager.map_scene_path(map_id)) as PackedScene).instantiate() as GameMap
	add_child(map)
	move_child(map, MAP_CHILD_INDEX)
	arena.setup(map, crate_pool)
	context = BotContext.new(map, arena)
	camera.set_bounds(map.get_bounds())


func spawn_local_player() -> void:
	local_player = _spawn(PlayerScene, map.spawn_points[0], PLAYER_TEAM)
	var provider: InputProvider = InputFactory.create_local_provider()
	add_child(provider)
	local_player.input_provider = provider
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
