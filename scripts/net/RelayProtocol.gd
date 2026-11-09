class_name RelayProtocol
extends RefCounted
## Builds and reads the binary frames described in docs/RELAY_PROTOCOL.md.
## server/relay.js is the other half of this file; change them together.

enum Frame { CREATE = 1, JOIN = 2, JOINED = 3, PEER_LEFT = 4, DATA = 5, ERROR = 6, PING = 7, PONG = 8, KICK = 9 }
enum ErrorCode { ROOM_NOT_FOUND = 1, ROOM_FULL = 2, VERSION_MISMATCH = 3, BAD_FRAME = 4, ROOM_EXPIRED = 5, SERVER_FULL = 6 }

const CODE_LENGTH := 6
const DATA_HEADER_BYTES := 7
const PEER_ID_OFFSET := 1
const JOINED_CODE_OFFSET := 5
const DATA_CHANNEL_OFFSET := 5
const DATA_MODE_OFFSET := 6


static func create(version: String) -> PackedByteArray:
	var frame := PackedByteArray([Frame.CREATE])
	frame.append_array(version.to_utf8_buffer())
	return frame


static func join(code: String, version: String) -> PackedByteArray:
	var frame := PackedByteArray([Frame.JOIN])
	frame.append_array(code.to_ascii_buffer())
	frame.append_array(version.to_utf8_buffer())
	return frame


static func data(target: int, channel: int, mode: int, payload: PackedByteArray) -> PackedByteArray:
	var frame := PackedByteArray()
	frame.resize(DATA_HEADER_BYTES)
	frame[0] = Frame.DATA
	frame.encode_s32(PEER_ID_OFFSET, target)
	frame[DATA_CHANNEL_OFFSET] = channel
	frame[DATA_MODE_OFFSET] = mode
	frame.append_array(payload)
	return frame


static func ping(token: int) -> PackedByteArray:
	var frame := PackedByteArray()
	frame.resize(5)
	frame[0] = Frame.PING
	frame.encode_u32(PEER_ID_OFFSET, token)
	return frame


static func kick(peer_id: int) -> PackedByteArray:
	var frame := PackedByteArray()
	frame.resize(5)
	frame[0] = Frame.KICK
	frame.encode_u32(PEER_ID_OFFSET, peer_id)
	return frame


static func peer_id_of(frame: PackedByteArray) -> int:
	return frame.decode_u32(PEER_ID_OFFSET)


static func code_of(joined_frame: PackedByteArray) -> String:
	return joined_frame.slice(JOINED_CODE_OFFSET, JOINED_CODE_OFFSET + CODE_LENGTH).get_string_from_ascii()


static func error_message(code: int) -> String:
	match code:
		ErrorCode.ROOM_NOT_FOUND:
			return "Room not found"
		ErrorCode.ROOM_FULL:
			return "Room is full"
		ErrorCode.VERSION_MISMATCH:
			return "Update required"
		ErrorCode.ROOM_EXPIRED:
			return "Room expired"
		ErrorCode.SERVER_FULL:
			return "Server is busy. Try again soon."
	return "Could not reach host."
