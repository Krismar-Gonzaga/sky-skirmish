class_name DeathmatchScore
extends RefCounted
## Who is winning a 1 vs 1 match, and whether it has ended.

const DRAW := 0
const NO_WINNER_YET := -1

var time_left: float = 0.0
## peer id to count.
var kills: Dictionary = {}
var deaths: Dictionary = {}

var _kill_limit: int = 0
var _winner: int = NO_WINNER_YET


func _init(peer_ids: Array, kill_limit: int, time_limit: float) -> void:
	_kill_limit = kill_limit
	time_left = time_limit
	for peer_id: int in peer_ids:
		kills[peer_id] = 0
		deaths[peer_id] = 0


## killer_id 0 or equal to victim_id means no kill is awarded, as for a player
## caught in their own rocket.
func record_death(victim_id: int, killer_id: int) -> void:
	if is_over():
		return
	deaths[victim_id] = int(deaths[victim_id]) + 1
	if killer_id != victim_id and kills.has(killer_id):
		kills[killer_id] = int(kills[killer_id]) + 1
		if int(kills[killer_id]) >= _kill_limit:
			_winner = killer_id


func update(delta: float) -> void:
	if is_over():
		return
	time_left = maxf(time_left - delta, 0.0)
	if time_left <= 0.0:
		_winner = _leader()


func is_over() -> bool:
	return _winner != NO_WINNER_YET


## The winning peer, or DRAW.
func winner() -> int:
	return _winner


func _leader() -> int:
	var best: int = DRAW
	var best_kills: int = -1
	var tied: bool = false
	for peer_id: int in kills:
		var count: int = kills[peer_id]
		if count > best_kills:
			best = peer_id
			best_kills = count
			tied = false
		elif count == best_kills:
			tied = true
	return DRAW if tied else best
