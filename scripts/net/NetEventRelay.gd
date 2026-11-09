class_name NetEventRelay
extends Node
## Forwards Arena events from the host to the client as reliable RPCs, where
## they replay as the same signals. Effects cannot tell the difference.

var _arena: Arena
var _rules: DeathmatchRules


func setup(arena: Arena, rules: DeathmatchRules) -> void:
	_arena = arena
	_rules = rules


func bind_host() -> void:
	_arena.shots_fired.connect(func(origin: Vector2, directions: Array[Vector2], weapon_id: String) -> void:
		_shots.rpc(origin, PackedVector2Array(directions), weapon_id))
	_arena.round_impacted.connect(func(at: Vector2, on_fighter: bool) -> void:
		_impact.rpc(at, on_fighter))
	_arena.exploded.connect(func(at: Vector2, radius: float) -> void: _explosion.rpc(at, radius))
	_arena.fighter_damaged.connect(func(victim: Player, amount: float) -> void:
		_damaged.rpc((victim as NetFighter).peer_id, amount))
	_arena.fighter_killed.connect(func(victim: Player, killer: Player) -> void:
		_killed.rpc((victim as NetFighter).peer_id, _peer_of(killer)))
	_arena.fighter_respawned.connect(func(fighter: Player) -> void:
		_respawned.rpc((fighter as NetFighter).peer_id, fighter.global_position))
	_arena.grenade_launched.connect(func(at: Vector2, direction: Vector2) -> void:
		_grenade.rpc(at, direction))
	_arena.grenade_bounced.connect(func(at: Vector2) -> void: _bounce.rpc(at))
	_arena.melee_swung.connect(func(at: Vector2) -> void: _melee.rpc(at))
	_arena.item_taken.connect(func(at: Vector2) -> void: _item.rpc(at))
	_arena.pickup_changed.connect(func(index: int, available: bool, weapon_id: String) -> void:
		_pickup.rpc(index, available, weapon_id))


func send_all_pickups() -> void:
	for state: Array in _arena.pickup_states():
		_pickup.rpc(state[0], state[1], state[2])


func _peer_of(fighter: Player) -> int:
	return (fighter as NetFighter).peer_id if fighter != null else 0


@rpc("authority", "call_remote", "reliable")
func _shots(origin: Vector2, directions: PackedVector2Array, weapon_id: String) -> void:
	_arena.show_remote_shots(origin, directions, weapon_id)


@rpc("authority", "call_remote", "reliable")
func _impact(at: Vector2, on_fighter: bool) -> void:
	_arena.round_impacted.emit(at, on_fighter)


@rpc("authority", "call_remote", "reliable")
func _explosion(at: Vector2, radius: float) -> void:
	_arena.exploded.emit(at, radius)


@rpc("authority", "call_remote", "reliable")
func _damaged(victim_peer: int, amount: float) -> void:
	var victim: NetFighter = _rules.fighter(victim_peer)
	if victim != null:
		victim.show_hit()
		_arena.fighter_damaged.emit(victim, amount)


@rpc("authority", "call_remote", "reliable")
func _killed(victim_peer: int, killer_peer: int) -> void:
	var victim: NetFighter = _rules.fighter(victim_peer)
	if victim != null:
		var killer: NetFighter = _rules.fighter(killer_peer)
		victim.show_death(killer)
		_arena.fighter_killed.emit(victim, killer)


@rpc("authority", "call_remote", "reliable")
func _respawned(peer_id: int, at: Vector2) -> void:
	var fighter: NetFighter = _rules.fighter(peer_id)
	if fighter != null:
		fighter.respawn(at)
		_arena.fighter_respawned.emit(fighter)


@rpc("authority", "call_remote", "reliable")
func _grenade(at: Vector2, direction: Vector2) -> void:
	_arena.show_remote_grenade(at, direction)


@rpc("authority", "call_remote", "reliable")
func _bounce(at: Vector2) -> void:
	_arena.grenade_bounced.emit(at)


@rpc("authority", "call_remote", "reliable")
func _melee(at: Vector2) -> void:
	_arena.melee_swung.emit(at)


@rpc("authority", "call_remote", "reliable")
func _item(at: Vector2) -> void:
	_arena.item_taken.emit(at)


@rpc("authority", "call_remote", "reliable")
func _pickup(index: int, available: bool, weapon_id: String) -> void:
	_arena.apply_remote_pickup(index, available, weapon_id)
