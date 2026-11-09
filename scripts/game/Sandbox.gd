extends Node2D
## Test scene: one fighter against bots or dummies, with a crate of each weapon.
## Keys 1 to 4 spawn bots at that difficulty; 0 spawns target dummies.
## Run with -- --touch on desktop to try the on-screen controls with the mouse.

const PlayerScene := preload("res://scenes/game/Player.tscn")
const BotScene := preload("res://scenes/game/Bot.tscn")
const PLAYER_TEAM := 0
const ENEMY_TEAM := 1
const ENEMY_TINT := Color(1.0, 0.55, 0.55)
const BOT_COUNT := 2
const BOT_SPAWN_INDEX := 1
const DIFFICULTY_KEYS: Dictionary = {
	KEY_1: "easy", KEY_2: "normal", KEY_3: "hard", KEY_4: "expert",
}

var _context: BotContext
var _enemies: Array[Player] = []

@onready var _map: GameMap = $Map
@onready var _arena: Arena = $Arena
@onready var _camera: AimCamera = $Camera
@onready var _effects: CombatEffects = $Effects
@onready var _hud: Hud = $HUD
@onready var _overlay: DebugOverlay = $DebugOverlay


func _ready() -> void:
	_arena.setup(_map, WeaponCatalog.crate_weapon_ids())
	_context = BotContext.new(_map, _arena)
	var player: Player = _spawn(PlayerScene, _map.spawn_points[0], PLAYER_TEAM)
	var provider: InputProvider = _create_provider()
	add_child(provider)
	player.input_provider = provider
	_camera.target = player
	_camera.set_bounds(_map.get_bounds())
	_camera.snap_to_target()
	_effects.bind(_arena, _camera, player)
	_hud.bind(player)
	_overlay.watched_player = player
	_spawn_bots("easy")


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	if DIFFICULTY_KEYS.has(key.physical_keycode):
		_spawn_bots(DIFFICULTY_KEYS[key.physical_keycode])
	elif key.physical_keycode == KEY_0:
		_spawn_dummies()


func _spawn_bots(difficulty_id: String) -> void:
	_remove_enemies()
	for i: int in range(BOT_COUNT):
		var bot: Bot = _spawn(BotScene, _map.spawn_points[BOT_SPAWN_INDEX + i], ENEMY_TEAM) as Bot
		bot.setup(_context, difficulty_id)
		_track_enemy(bot)
	_hud.set_objective("Bots: %s  (keys 1-4, 0 dummies)" % difficulty_id)


func _spawn_dummies() -> void:
	_remove_enemies()
	for i: int in range(BOT_SPAWN_INDEX, _map.spawn_points.size()):
		_track_enemy(_spawn(PlayerScene, _map.spawn_points[i], ENEMY_TEAM))
	_hud.set_objective("Dummies  (keys 1-4 for bots)")


func _track_enemy(enemy: Player) -> void:
	enemy.modulate = ENEMY_TINT
	_enemies.append(enemy)


func _remove_enemies() -> void:
	for enemy: Player in _enemies:
		_arena.unregister_fighter(enemy)
		enemy.queue_free()
	_enemies.clear()


func _spawn(scene: PackedScene, at: Vector2, team: int) -> Player:
	var fighter: Player = scene.instantiate() as Player
	fighter.team = team
	_arena.add_child(fighter)
	fighter.global_position = at
	_arena.register_fighter(fighter)
	return fighter


func _create_provider() -> InputProvider:
	var wants_touch: bool = "--touch" in OS.get_cmdline_user_args()
	if wants_touch:
		Input.emulate_touch_from_mouse = true
	if wants_touch or OS.has_feature("mobile"):
		return TouchInputProvider.new()
	return KeyboardMouseInputProvider.new()
