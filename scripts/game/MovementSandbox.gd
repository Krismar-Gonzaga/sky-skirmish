extends Node2D
## M1 test scene: one fighter on the test map.
## Run with -- --touch on desktop to try the on-screen controls with the mouse.

@onready var _map: GameMap = $Map
@onready var _player: Player = $Player
@onready var _camera: AimCamera = $Camera
@onready var _overlay: DebugOverlay = $DebugOverlay


func _ready() -> void:
	_player.global_position = _map.spawn_points[0]
	var provider: InputProvider = _create_provider()
	add_child(provider)
	_player.input_provider = provider
	_camera.target = _player
	_camera.set_bounds(_map.get_bounds())
	_camera.snap_to_target()
	_overlay.watched_player = _player


func _create_provider() -> InputProvider:
	var wants_touch: bool = "--touch" in OS.get_cmdline_user_args()
	if wants_touch:
		Input.emulate_touch_from_mouse = true
	if wants_touch or OS.has_feature("mobile"):
		return TouchInputProvider.new()
	return KeyboardMouseInputProvider.new()
