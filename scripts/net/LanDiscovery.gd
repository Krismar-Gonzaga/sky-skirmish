class_name LanDiscovery
extends RefCounted
## The small JSON message hosts announce themselves with.

const GAME_ID := "sky-skirmish"


## Addresses another device could reach this one on.
static func local_ipv4_addresses() -> PackedStringArray:
	var found := PackedStringArray()
	for address: String in IP.get_local_addresses():
		var is_ipv4: bool = address.is_valid_ip_address() and not address.contains(":")
		if is_ipv4 and not address.begins_with("127.") and not address.begins_with("169.254."):
			found.append(address)
	return found


static func encode(version: String, host_name: String, port: int) -> PackedByteArray:
	var message: Dictionary = {"game": GAME_ID, "version": version, "name": host_name, "port": port}
	return JSON.stringify(message).to_utf8_buffer()


## Returns the message, or an empty dictionary if it is not from this game.
static func decode(packet: PackedByteArray) -> Dictionary:
	var json := JSON.new()
	if json.parse(packet.get_string_from_ascii()) != OK or not json.data is Dictionary:
		return {}
	var message: Dictionary = json.data
	if message.get("game") != GAME_ID or not message.has_all(["version", "name", "port"]):
		return {}
	return message
