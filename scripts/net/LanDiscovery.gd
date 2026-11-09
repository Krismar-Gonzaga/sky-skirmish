class_name LanDiscovery
extends RefCounted
## The small JSON message hosts announce themselves with.

const GAME_ID := "sky-skirmish"


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
