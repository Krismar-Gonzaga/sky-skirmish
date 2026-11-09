class_name LanBroadcaster
extends Node
## Announces a hosted match to the local network once per interval.

const GLOBAL_BROADCAST := "255.255.255.255"

## Overridden by tests to stay on this machine.
var destinations: PackedStringArray = PackedStringArray()
var discovery_port: int = 0
var game_port: int = 0

var _socket := PacketPeerUDP.new()
var _interval: float = 0.0
var _wait: float = 0.0


func _ready() -> void:
	var config: Dictionary = Tuning.section("net")
	_interval = config["discovery_interval"]
	if discovery_port == 0:
		discovery_port = int(config["discovery_port"])
	if game_port == 0:
		game_port = int(config["lan_port"])
	if destinations.is_empty():
		destinations = _broadcast_addresses()
	_socket.set_broadcast_enabled(true)


func _process(delta: float) -> void:
	_wait -= delta
	if _wait > 0.0:
		return
	_wait = _interval
	var packet: PackedByteArray = LanDiscovery.encode(
			NetworkManager.game_version, Settings.player_name, game_port)
	for destination: String in destinations:
		_socket.set_dest_address(destination, discovery_port)
		_socket.put_packet(packet)


func _exit_tree() -> void:
	_socket.close()


## Some phones drop the global address on a hotspot, so each subnet is tried too.
func _broadcast_addresses() -> PackedStringArray:
	var addresses := PackedStringArray([GLOBAL_BROADCAST])
	for local: String in LanDiscovery.local_ipv4_addresses():
		var parts: PackedStringArray = local.split(".")
		parts[3] = "255"
		addresses.append(".".join(parts))
	return addresses
