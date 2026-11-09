class_name NetFighter
extends Player
## A Player in a networked match. The host simulates it as normal and publishes
## the result; a client only sends input and draws what the host reported.

const STATE_PROPERTIES: Array[String] = [
	":sync_position", ":sync_velocity", ":sync_aim", ":sync_aiming", ":sync_health",
	":sync_fuel", ":sync_status", ":sync_weapon", ":sync_grenades", ":sync_crouch",
	":sync_thrust",
]

var peer_id: int = NetworkManager.HOST_ID
var display_name: String = ""
## On a client, the device input for the fighter this client controls.
var local_input_source: InputProvider

var sync_position: Vector2 = Vector2.ZERO
var sync_velocity: Vector2 = Vector2.ZERO
var sync_aim: Vector2 = Vector2.RIGHT
var sync_aiming: bool = false
var sync_health: float = 0.0
var sync_fuel: float = 0.0
var sync_status: String = ""
var sync_weapon: String = WeaponCatalog.DEFAULT_WEAPON
var sync_grenades: int = 0
var sync_crouch: bool = false
var sync_thrust: bool = false

var net_input: NetInputState

var _snapshots := SnapshotBuffer.new()
var _interpolation_delay: float = 0.0
var _shown_weapon: String = WeaponCatalog.DEFAULT_WEAPON
var _was_reloading: bool = false


## Call before the fighter enters the tree, with the same data on every device.
func configure_network(data: Dictionary) -> void:
	peer_id = data["peer"]
	team = data["team"]
	display_name = data["name"]
	position = data["at"]
	sync_position = position
	name = "Fighter_%d" % peer_id
	net_input = $NetInput as NetInputState
	var state_sync := $StateSync as MultiplayerSynchronizer
	state_sync.replication_config = _build_config(STATE_PROPERTIES)
	state_sync.replication_interval = Tuning.section("net")["state_interval"]
	var input_sync := $InputSync as MultiplayerSynchronizer
	input_sync.root_path = NodePath("../NetInput")
	input_sync.replication_config = _build_config(NetInputState.replicated_properties())
	input_sync.replication_interval = 0.0
	input_sync.set_multiplayer_authority(peer_id)


func _ready() -> void:
	super()
	if multiplayer.is_server():
		return
	_collision_layer = 0
	collision_layer = 0
	collision_mask = 0
	var config: Dictionary = Tuning.section("net")
	var is_mine: bool = peer_id == multiplayer.get_unique_id()
	_interpolation_delay = config["own_interpolation_delay" if is_mine else "interpolation_delay"]
	($StateSync as MultiplayerSynchronizer).synchronized.connect(_on_state_received)


func _physics_process(delta: float) -> void:
	if multiplayer.is_server():
		super(delta)
		_publish_state()
	else:
		_follow_host()


func respawn(at: Vector2) -> void:
	_snapshots.clear()
	super(at)


## A client shows a death the host reported.
func show_death(killer: Player) -> void:
	_die(killer)


func show_hit() -> void:
	_visual.flash_hit()


## Stops replication before the scene goes away, so no packet targets a freed node.
func stop_replication() -> void:
	($StateSync as MultiplayerSynchronizer).public_visibility = false
	($InputSync as MultiplayerSynchronizer).public_visibility = false


func _weapon_status() -> String:
	return super() if multiplayer.is_server() else sync_status


func _publish_state() -> void:
	sync_position = global_position
	sync_velocity = velocity
	sync_aim = aim_direction
	sync_aiming = is_aiming
	sync_health = health.current
	sync_fuel = fuel.amount
	sync_status = _weapon_status()
	sync_weapon = loadout.active().id
	sync_grenades = grenades
	sync_crouch = is_crouching
	sync_thrust = is_thrusting


func _follow_host() -> void:
	_read_own_input()
	if not _snapshots.is_empty():
		global_position = _snapshots.sample(_now() - _interpolation_delay)
	velocity = sync_velocity
	is_thrusting = sync_thrust
	if sync_crouch != is_crouching:
		is_crouching = sync_crouch
		_set_body_height(_crouch_height if is_crouching else _stand_height)
	_show_host_status()
	_visual.update_pose(aim_direction, _capsule.height / _stand_height, is_thrusting)
	_visual.show_weapon(sync_weapon)


func _read_own_input() -> void:
	if local_input_source == null:
		aim_direction = sync_aim
		is_aiming = sync_aiming
		return
	var input: PlayerInput = local_input_source.poll(get_aim_origin())
	net_input.capture(input)
	# Aim is answered locally, so the crosshair never waits for the network.
	is_aiming = input.aim != Vector2.ZERO
	if is_aiming:
		aim_direction = input.aim.normalized()


func _show_host_status() -> void:
	if sync_health != health.current:
		health.current = sync_health
		health_changed.emit(health.current, health.maximum)
	fuel.amount = sync_fuel
	if sync_grenades != grenades:
		grenades = sync_grenades
		grenades_changed.emit(grenades)
	if sync_weapon != _shown_weapon:
		_shown_weapon = sync_weapon
		loadout.reset()
		if sync_weapon != WeaponCatalog.DEFAULT_WEAPON:
			loadout.pickup(sync_weapon)
	var reloading: bool = sync_status.contains("Reloading")
	if reloading and not _was_reloading and local_input_source != null:
		AudioManager.play("reload")
	_was_reloading = reloading
	report_status()


func _on_state_received() -> void:
	_snapshots.push(_now(), sync_position)


func _now() -> float:
	return Time.get_ticks_msec() / 1000.0


func _build_config(properties: Array[String]) -> SceneReplicationConfig:
	var config := SceneReplicationConfig.new()
	for property: String in properties:
		var path := NodePath(property)
		config.add_property(path)
		config.property_set_spawn(path, true)
		config.property_set_replication_mode(path, SceneReplicationConfig.REPLICATION_MODE_ALWAYS)
	return config
