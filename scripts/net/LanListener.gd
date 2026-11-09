class_name LanListener
extends Node
## Collects the hosts announcing themselves on the local network.

signal hosts_changed

## Host address to {"name", "version", "port", "seen"}.
var hosts: Dictionary = {}
## Overridden by tests.
var discovery_port: int = 0

var _socket := PacketPeerUDP.new()
var _expiry: float = 0.0
var _now: float = 0.0


func _ready() -> void:
	var config: Dictionary = Tuning.section("net")
	_expiry = config["host_expiry"]
	if discovery_port == 0:
		discovery_port = int(config["discovery_port"])
	# A failed bind only means the list stays empty; manual IP entry still works.
	_socket.bind(discovery_port)


func _process(delta: float) -> void:
	_now += delta
	var changed: bool = false
	while _socket.get_available_packet_count() > 0:
		var packet: PackedByteArray = _socket.get_packet()
		var message: Dictionary = LanDiscovery.decode(packet)
		if not message.is_empty():
			var address: String = _socket.get_packet_ip()
			changed = changed or not hosts.has(address)
			message["seen"] = _now
			hosts[address] = message
	for address: String in hosts.keys():
		if _now - float(hosts[address]["seen"]) > _expiry:
			hosts.erase(address)
			changed = true
	if changed:
		hosts_changed.emit()


func _exit_tree() -> void:
	_socket.close()
