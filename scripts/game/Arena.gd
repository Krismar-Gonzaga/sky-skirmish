class_name Arena
extends Node2D
## Resolves combat: turns shots into projectiles, applies damage, handles
## pickups and respawns. Signals report every event, so visuals and sound stay
## out of here and multiplayer can forward the same events to clients.

signal shots_fired(origin: Vector2, directions: Array[Vector2], weapon_id: String)
signal round_impacted(at: Vector2, on_fighter: bool)
signal exploded(at: Vector2, radius: float)
signal fighter_damaged(victim: Player, amount: float)
signal fighter_killed(victim: Player, killer: Player)
signal fighter_respawned(fighter: Player)
signal grenade_launched(at: Vector2, direction: Vector2)
signal grenade_bounced(at: Vector2)
signal melee_swung(at: Vector2)
signal item_taken(at: Vector2)
signal pickup_changed(index: int, available: bool, weapon_id: String)

const ProjectileScene := preload("res://scenes/game/Projectile.tscn")
const GrenadeScene := preload("res://scenes/game/Grenade.tscn")
const PickupScene := preload("res://scenes/game/Pickup.tscn")
const NO_TEAM := -1

## Campaign missions turn this off once a life count runs out.
var respawn_enabled: bool = true
var respawn_delay: float = 0.0
var fighters: Array[Player] = []

var _spawn_points: Array[Vector2] = []
var _idle_projectiles: Array[Projectile] = []
var _pickups: Array[Pickup] = []
var _knockback: float = 0.0
var _health_pack: float = 0.0
var _remote: bool = false


func _ready() -> void:
	respawn_delay = Tuning.section("health")["respawn_delay"]
	_knockback = Tuning.section("explosion")["knockback"]
	_health_pack = Tuning.section("pickups")["health_pack"]


## crate_pool lists the weapons that random crates may contain.
## remote is true on a client, where the host decides everything.
func setup(map: GameMap, crate_pool: Array[String], remote: bool = false) -> void:
	_spawn_points = map.spawn_points
	_remote = remote
	for crate: Dictionary in map.crates:
		# Early levels have no unlocked weapons to put in a random crate.
		if not (crate["weapon"] as String).is_empty() or not crate_pool.is_empty():
			_add_pickup(Pickup.Kind.WEAPON, crate["position"], crate["weapon"], crate_pool)
	for spot: Vector2 in map.health_packs:
		_add_pickup(Pickup.Kind.HEALTH, spot, "", crate_pool)


## Removes everything tied to the current map, ready for setup() with a new one.
func clear_world() -> void:
	_pickups.clear()
	for child: Node in get_children():
		if child is Pickup or child is FragGrenade:
			child.queue_free()
		elif child is Projectile and (child as Projectile).visible:
			_release_projectile(child as Projectile)


func register_fighter(fighter: Player) -> void:
	fighters.append(fighter)
	fighter.fired.connect(_on_fired)
	fighter.grenade_thrown.connect(_on_grenade_thrown)
	fighter.melee_swung.connect(_on_melee_swung)
	fighter.died.connect(_on_fighter_died)


## A client knows about a fighter without simulating any of its combat.
func track_fighter(fighter: Player) -> void:
	fighters.append(fighter)


func unregister_fighter(fighter: Player) -> void:
	fighters.erase(fighter)


## [[index, available, weapon_id], ...] so a client can match the host.
func pickup_states() -> Array:
	var states: Array = []
	for i: int in range(_pickups.size()):
		states.append([i, _pickups[i].is_available(), _pickups[i].weapon_id])
	return states


func apply_remote_pickup(index: int, available: bool, weapon_id: String) -> void:
	if index < _pickups.size():
		_pickups[index].apply_remote_state(available, weapon_id)


func show_remote_shots(origin: Vector2, directions: PackedVector2Array, weapon_id: String) -> void:
	var weapon: Weapon = WeaponCatalog.create(weapon_id)
	var typed_directions: Array[Vector2] = []
	for direction: Vector2 in directions:
		_acquire_projectile().launch_cosmetic(origin, direction, weapon)
		typed_directions.append(direction)
	shots_fired.emit(origin, typed_directions, weapon_id)


func show_remote_grenade(at: Vector2, direction: Vector2) -> void:
	var grenade: FragGrenade = GrenadeScene.instantiate() as FragGrenade
	grenade.cosmetic = true
	add_child(grenade)
	grenade.launch(at, direction, null)
	grenade.detonated.connect(_on_grenade_detonated)
	grenade_launched.emit(at, direction)


func _add_pickup(kind: Pickup.Kind, at: Vector2, weapon_id: String, pool: Array[String]) -> void:
	var pickup: Pickup = PickupScene.instantiate() as Pickup
	pickup.remote_controlled = _remote
	add_child(pickup)
	pickup.global_position = at
	pickup.setup(kind, weapon_id, pool)
	var index: int = _pickups.size()
	_pickups.append(pickup)
	pickup.touched.connect(_on_pickup_touched)
	pickup.state_changed.connect(func(available: bool) -> void:
		pickup_changed.emit(index, available, pickup.weapon_id))


func _on_fired(shooter: Player, weapon: Weapon, origin: Vector2, directions: Array[Vector2]) -> void:
	var excluded: Array[RID] = _team_rids(shooter.team)
	for direction: Vector2 in directions:
		_acquire_projectile().launch(origin, direction, weapon, shooter, excluded)
	shots_fired.emit(origin, directions, weapon.id)


func _acquire_projectile() -> Projectile:
	if not _idle_projectiles.is_empty():
		return _idle_projectiles.pop_back()
	var projectile: Projectile = ProjectileScene.instantiate() as Projectile
	add_child(projectile)
	projectile.struck.connect(_on_projectile_struck)
	projectile.expired.connect(_on_projectile_expired)
	return projectile


func _release_projectile(projectile: Projectile) -> void:
	projectile.deactivate()
	_idle_projectiles.append(projectile)


func _on_projectile_struck(projectile: Projectile, at: Vector2, collider: Object) -> void:
	if projectile.cosmetic:
		_release_projectile(projectile)
		return
	if projectile.splash_radius > 0.0:
		_explode_projectile(projectile, at)
	else:
		var victim: Player = collider as Player
		if victim != null:
			_deal(victim, projectile.weapon_damage, _still_present(projectile.shooter))
		round_impacted.emit(at, victim != null)
	_release_projectile(projectile)


func _on_projectile_expired(projectile: Projectile) -> void:
	if not projectile.cosmetic and projectile.splash_radius > 0.0:
		_explode_projectile(projectile, projectile.global_position)
	_release_projectile(projectile)


func _explode_projectile(projectile: Projectile, at: Vector2) -> void:
	_explode(at, projectile.splash_radius, projectile.weapon_damage,
			_still_present(projectile.shooter), projectile.self_damage_factor)


func _on_grenade_thrown(thrower: Player, origin: Vector2, direction: Vector2) -> void:
	var grenade: FragGrenade = GrenadeScene.instantiate() as FragGrenade
	add_child(grenade)
	grenade.launch(origin, direction, thrower)
	grenade.detonated.connect(_on_grenade_detonated)
	grenade.bounced.connect(func(at: Vector2) -> void: grenade_bounced.emit(at))
	grenade_launched.emit(origin, direction)


func _on_grenade_detonated(grenade: FragGrenade) -> void:
	if not grenade.cosmetic:
		var stats: Dictionary = WeaponCatalog.grenade()
		_explode(grenade.global_position, stats["splash_radius"], stats["damage"],
				_still_present(grenade.thrower), stats["self_damage_factor"])
	grenade.queue_free()


## A shot can outlive its owner, for example after a disconnect.
## Untyped because a freed object cannot be passed as a typed argument.
func _still_present(fighter: Variant) -> Player:
	return fighter as Player if is_instance_valid(fighter) else null


## A null attacker means the owner left the match; its blast hurts everyone.
func _explode(at: Vector2, radius: float, damage: float, attacker: Player, self_factor: float) -> void:
	var attacker_team: int = attacker.team if attacker != null else NO_TEAM
	for fighter: Player in fighters:
		if fighter.is_dead or (fighter != attacker and fighter.team == attacker_team):
			continue
		var amount: float = Splash.damage_at(fighter.distance_from(at), radius, damage)
		if fighter == attacker:
			amount *= self_factor
		if amount > 0.0 and _is_clear_line(at, fighter.get_center()):
			fighter.apply_knockback((fighter.get_center() - at).normalized() * _knockback)
			_deal(fighter, amount, attacker)
	exploded.emit(at, radius)


func _on_melee_swung(attacker: Player, origin: Vector2, direction: Vector2) -> void:
	var stats: Dictionary = WeaponCatalog.melee()
	var min_alignment: float = cos(deg_to_rad(float(stats["cone_degrees"])))
	for target: Player in fighters:
		if target.is_dead or target.team == attacker.team:
			continue
		var to_target: Vector2 = (target.get_center() - origin).normalized()
		if target.distance_from(origin) <= float(stats["range"]) \
				and direction.dot(to_target) >= min_alignment \
				and _is_clear_line(origin, target.get_center()):
			_deal(target, stats["damage"], attacker)
	melee_swung.emit(origin)


func _deal(victim: Player, amount: float, attacker: Player) -> void:
	var dealt: float = victim.take_damage(amount, attacker)
	if dealt > 0.0:
		fighter_damaged.emit(victim, dealt)


func _on_fighter_died(victim: Player, killer: Player) -> void:
	fighter_killed.emit(victim, killer)
	if respawn_enabled and victim.respawns:
		await get_tree().create_timer(respawn_delay, false).timeout
		if is_instance_valid(victim):
			victim.respawn(_choose_spawn(victim))
			fighter_respawned.emit(victim)


func _choose_spawn(fighter: Player) -> Vector2:
	var threats: Array[Vector2] = []
	for other: Player in fighters:
		if other.team != fighter.team and not other.is_dead:
			threats.append(other.global_position)
	return SpawnPicker.farthest_from(_spawn_points, threats)


func _on_pickup_touched(pickup: Pickup, fighter: Player) -> void:
	if pickup.kind == Pickup.Kind.HEALTH:
		if fighter.health.is_full():
			return
		fighter.heal(_health_pack)
	else:
		fighter.give_weapon(pickup.weapon_id)
	pickup.consume()
	item_taken.emit(pickup.global_position)


func _is_clear_line(from: Vector2, to: Vector2) -> bool:
	var query := PhysicsRayQueryParameters2D.create(from, to, PhysicsLayers.WORLD)
	return get_world_2d().direct_space_state.intersect_ray(query).is_empty()


func _team_rids(team: int) -> Array[RID]:
	var rids: Array[RID] = []
	for fighter: Player in fighters:
		if fighter.team == team:
			rids.append(fighter.get_rid())
	return rids
