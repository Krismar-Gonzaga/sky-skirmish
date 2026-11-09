extends Node2D
## Test scene: one fighter, target dummies and one crate of each weapon.
## Run with -- --touch on desktop to try the on-screen controls with the mouse.

const PlayerScene := preload("res://scenes/game/Player.tscn")
const PLAYER_TEAM := 0
const DUMMY_TEAM := 1
const DUMMY_TINT := Color(1.0, 0.55, 0.55)

@onready var _map: GameMap = $Map
@onready var _arena: Arena = $Arena
@onready var _camera: AimCamera = $Camera
@onready var _effects: CombatEffects = $Effects
@onready var _hud: Hud = $HUD
@onready var _overlay: DebugOverlay = $DebugOverlay


func _ready() -> void:
	_arena.setup(_map, WeaponCatalog.crate_weapon_ids())
	var player: Player = _spawn_fighter(_map.spawn_points[0], PLAYER_TEAM)
	var provider: InputProvider = _create_provider()
	add_child(provider)
	player.input_provider = provider
	for i: int in range(1, _map.spawn_points.size()):
		_spawn_fighter(_map.spawn_points[i], DUMMY_TEAM).modulate = DUMMY_TINT
	_camera.target = player
	_camera.set_bounds(_map.get_bounds())
	_camera.snap_to_target()
	_effects.bind(_arena, _camera, player)
	_hud.bind(player)
	_hud.set_objective("Sandbox: shoot the red dummies")
	_overlay.watched_player = player


func _spawn_fighter(at: Vector2, team: int) -> Player:
	var fighter: Player = PlayerScene.instantiate() as Player
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
