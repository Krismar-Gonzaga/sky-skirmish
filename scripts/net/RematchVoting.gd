class_name RematchVoting
extends Node
## Tracks who wants another match. Starts it once everyone has voted.
## Lives under NetworkManager, so its RPC path exists on every device at all times.

signal votes_changed

var _votes: Dictionary = {}


func vote() -> void:
	if multiplayer.is_server():
		_add_vote(NetworkManager.HOST_ID)
	else:
		_request.rpc_id(NetworkManager.HOST_ID)


func count() -> int:
	return _votes.size()


func clear() -> void:
	_votes.clear()


func forget(peer_id: int) -> void:
	_votes.erase(peer_id)


func _add_vote(peer_id: int) -> void:
	_votes[peer_id] = true
	_broadcast.rpc(_votes.keys())
	if _votes.size() >= NetworkManager.peers.size():
		NetworkManager.start_match(NetworkManager.last_map)


@rpc("any_peer", "call_remote", "reliable")
func _request() -> void:
	if multiplayer.is_server():
		_add_vote(multiplayer.get_remote_sender_id())


@rpc("authority", "call_local", "reliable")
func _broadcast(voters: Array) -> void:
	_votes.clear()
	for voter: int in voters:
		_votes[voter] = true
	votes_changed.emit()
