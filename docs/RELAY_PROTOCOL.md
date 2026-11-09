# Relay protocol

Sky Skirmish talks to `server/relay.js` over one WebSocket per player. Every message is one binary frame. The first byte is the frame type. Numbers are little-endian. The relay never looks inside a `DATA` payload.

`scripts/net/RelayProtocol.gd` and `server/relay.js` implement both ends. Change them together.

## Frames

| Type | Name | Direction | Body after the type byte |
| --- | --- | --- | --- |
| 1 | CREATE | client to relay | game version (UTF-8, rest of frame) |
| 2 | JOIN | client to relay | room code (6 ASCII bytes), game version (UTF-8, rest of frame) |
| 3 | JOINED | relay to client | peer id (u32), room code (6 ASCII bytes) |
| 4 | PEER_LEFT | relay to client | peer id (u32) |
| 5 | DATA | both | peer id (i32), channel (u8), mode (u8), payload |
| 6 | ERROR | relay to client | error code (u8) |
| 7 | PING | client to relay | token (u32) |
| 8 | PONG | relay to client | same token (u32) |
| 9 | KICK | host to relay | guest peer id (u32) |

In `DATA`, the peer id is the target when a client sends it. The relay overwrites it with the sender's id before forwarding, so a client cannot impersonate another. `mode` is Godot's `MultiplayerPeer.TransferMode`.

## How a match connects

1. The host sends `CREATE`. The relay answers `JOINED` with peer id 1 and a new room code.
2. The guest sends `JOIN` with the code. The relay sends `JOINED` with the guest's id (2 or higher) to both players.
3. Both sides exchange `DATA`.
4. When a player leaves, the other receives `PEER_LEFT`. If the host leaves, the room is deleted. If the guest leaves, the room stays open for a new guest.

## Error codes

| Code | Name | Shown to the player |
| --- | --- | --- |
| 1 | ROOM_NOT_FOUND | Room not found |
| 2 | ROOM_FULL | Room is full |
| 3 | VERSION_MISMATCH | Update required |
| 4 | BAD_FRAME | Could not reach host. |
| 5 | ROOM_EXPIRED | Room expired |
| 6 | SERVER_FULL | Server is busy. Try again soon. |

## Timing

- The relay deletes a room after 10 minutes without a `CREATE`, `JOIN` or `DATA` frame. `PING` does not count, so an abandoned lobby still expires.
- The relay sends a WebSocket ping every 5 seconds and drops a player who misses one round.
- The client sends `PING` every 2 seconds and treats 6 seconds of silence as a lost connection.
- The client retries a failed connection for up to 60 seconds, because a free-tier server may be waking. After the socket opens, the relay has 10 seconds to answer.
