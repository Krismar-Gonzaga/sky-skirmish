class_name BotBrain
extends InputProvider
## AI driver. Produces the same PlayerInput a thumb would, so bots follow every
## movement, fuel and ammo rule that players do.

var state: BotDecision.State = BotDecision.State.PATROL

var _body: Player
var _context: BotContext
var _config: Dictionary
var _follower: PathFollower
var _aim_error: float = 0.0
var _reaction_time: float = 0.0

var _target: Player
var _target_visible: bool = false
var _unseen_time: float = 0.0
var _reaction_left: float = 0.0
var _think_left: float = 0.0
var _repath_left: float = 0.0
var _aim_refresh_left: float = 0.0
var _aim_offset: float = 0.0
var _strafe_left: float = 0.0
var _strafe_direction: float = 1.0
var _dodge_left: float = 0.0
var _grenade_wait: float = 0.0
var _melee_toggle: bool = false
var _stuck_timer: float = 0.0
var _stuck_anchor: Vector2 = Vector2.ZERO
var _escape_left: float = 0.0
var _escape_direction: float = 1.0


func configure(body: Player, context: BotContext, difficulty: Dictionary) -> void:
	_body = body
	_context = context
	_config = Tuning.section("bot")
	_follower = PathFollower.new(Tuning.section("bot_navigation"))
	_aim_error = deg_to_rad(float(difficulty["aim_error_degrees"]))
	_reaction_time = difficulty["reaction_time"]
	_grenade_wait = _next_grenade_wait()
	_stuck_anchor = body.global_position
	body.respawned.connect(_on_respawned)


func routes_finished() -> int:
	return _follower.routes_finished


func poll(aim_origin: Vector2) -> PlayerInput:
	var delta: float = get_physics_process_delta_time()
	_tick_timers(delta)
	if not is_instance_valid(_target):
		_target = null
	if _think_left <= 0.0:
		_think()
	var input := PlayerInput.new()
	_steer(input)
	_aim_and_attack(input, aim_origin)
	_watch_for_stuck(delta)
	return input


func _tick_timers(delta: float) -> void:
	_think_left -= delta
	_repath_left -= delta
	_aim_refresh_left -= delta
	_strafe_left -= delta
	_dodge_left -= delta
	_escape_left -= delta
	_grenade_wait -= delta
	_reaction_left -= delta


func _think() -> void:
	_think_left = _config["think_interval"]
	_update_target()
	var ratio: float = _body.health.current / _body.health.maximum
	var new_state: BotDecision.State = BotDecision.next_state(state, ratio, _target != null,
			_can_shoot_target(), _config["retreat_below"], _config["recover_at"])
	if new_state != state:
		state = new_state
		_follower.clear()
		_repath_left = 0.0
	_plan_route()


func _update_target() -> void:
	var candidate: Player = _nearest_enemy(_config["sight_range"])
	var sees: bool = candidate != null and _has_line_of_sight(candidate)
	if sees:
		# The delay applies to a fresh sighting, not to a brief loss of sight.
		if candidate != _target or _unseen_time >= float(_config["reacquire_time"]):
			_reaction_left = _reaction_time
		_target = candidate
		_unseen_time = 0.0
	else:
		_unseen_time += float(_config["think_interval"])
		if _target != null and (_target.is_dead or _unseen_time > float(_config["memory_time"])):
			_target = null
	_target_visible = sees


func _nearest_enemy(within: float) -> Player:
	var nearest: Player = null
	var nearest_distance: float = within
	for fighter: Player in _context.fighters:
		if fighter.team == _body.team or fighter.is_dead:
			continue
		var distance: float = fighter.global_position.distance_to(_body.global_position)
		if distance < nearest_distance:
			nearest = fighter
			nearest_distance = distance
	return nearest


func _has_line_of_sight(other: Player) -> bool:
	var query := PhysicsRayQueryParameters2D.create(
			_body.get_aim_origin(), other.get_center(), PhysicsLayers.WORLD)
	return _body.get_world_2d().direct_space_state.intersect_ray(query).is_empty()


func _can_shoot_target() -> bool:
	if _target == null or not _target_visible:
		return false
	return _distance_to_target() <= _usable_weapon_range()


func _usable_weapon_range() -> float:
	return _body.loadout.active().max_range * float(_config["range_use_factor"])


func _distance_to_target() -> float:
	return _target.global_position.distance_to(_body.global_position)


func _plan_route() -> void:
	match state:
		BotDecision.State.PATROL:
			if _follower.is_finished():
				_route_to(_next_patrol_point())
		BotDecision.State.CHASE:
			if _repath_left <= 0.0 and _target != null:
				_repath_left = _config["repath_interval"]
				_route_to(_target.global_position)
		BotDecision.State.RETREAT:
			if _follower.is_finished():
				_route_to(_retreat_point())


func _route_to(destination: Vector2) -> void:
	_follower.set_path(_context.nav.find_path(_body.global_position, destination))


func _next_patrol_point() -> Vector2:
	# Without this, a player who hides would never meet a bot again.
	var enemy: Player = _nearest_enemy(INF)
	if enemy != null and randf() < float(_config["patrol_hunt_chance"]):
		return enemy.global_position
	return _context.patrol_points.pick_random()


func _retreat_point() -> Vector2:
	var candidates: Array[Vector2] = _context.health_packs
	if candidates.is_empty():
		candidates = _context.patrol_points
	var threats: Array[Vector2] = []
	var enemy: Player = _nearest_enemy(INF)
	if enemy != null:
		threats.append(enemy.global_position)
	return SpawnPicker.farthest_from(candidates, threats)


func _steer(input: PlayerInput) -> void:
	if state == BotDecision.State.ATTACK:
		_steer_while_fighting(input)
	else:
		var fuel_ratio: float = _body.fuel.amount / _body.fuel.capacity
		_follower.steer(_body.global_position, _body.velocity, _body.is_on_floor(), fuel_ratio, input)
	if _escape_left > 0.0:
		input.move.x = _escape_direction
		input.jet = true


func _steer_while_fighting(input: PlayerInput) -> void:
	var preferred: float = minf(_config["preferred_range"], _usable_weapon_range())
	var offset: float = _target.global_position.x - _body.global_position.x if _target != null else 0.0
	if _strafe_left <= 0.0:
		_strafe_left = _config["strafe_interval"]
		_strafe_direction = -_strafe_direction
		var fuel_ratio: float = _body.fuel.amount / _body.fuel.capacity
		if fuel_ratio > float(_config["dodge_min_fuel"]) and randf() < float(_config["dodge_chance"]):
			_dodge_left = _config["dodge_time"]
	if absf(offset) > preferred * 1.3:
		input.move.x = signf(offset)
	elif absf(offset) < preferred * 0.7:
		input.move.x = -signf(offset)
	else:
		input.move.x = _strafe_direction
	input.jet = _dodge_left > 0.0


func _aim_and_attack(input: PlayerInput, aim_origin: Vector2) -> void:
	if _target == null or not _target_visible:
		return
	if _aim_refresh_left <= 0.0:
		_aim_refresh_left = _config["aim_refresh"]
		_aim_offset = randf_range(-_aim_error, _aim_error)
	var weapon: Weapon = _body.loadout.active()
	var distance: float = aim_origin.distance_to(_target.get_center())
	var travel_time: float = distance / weapon.projectile_speed
	var lead: Vector2 = _target.velocity * travel_time * float(_config["lead_factor"])
	var true_aim: Vector2 = (_target.get_center() + lead - aim_origin).normalized()
	input.aim = true_aim.rotated(_aim_offset)
	if _reaction_left > 0.0:
		return
	input.fire = distance <= _usable_weapon_range()
	_maybe_use_close_attacks(input, distance, true_aim)


func _maybe_use_close_attacks(input: PlayerInput, distance: float, true_aim: Vector2) -> void:
	if distance <= float(_config["melee_range"]):
		# Player reacts to a press, so the button has to be released between swings.
		_melee_toggle = not _melee_toggle
		input.melee = _melee_toggle
	if _grenade_wait <= 0.0 and distance >= float(_config["grenade_min_range"]) \
			and distance <= float(_config["grenade_max_range"]):
		_grenade_wait = _next_grenade_wait()
		input.grenade = true
		input.aim = (true_aim + Vector2.UP * float(_config["grenade_lift"])).normalized()


func _next_grenade_wait() -> float:
	return randf_range(_config["grenade_interval_min"], _config["grenade_interval_max"])


func _watch_for_stuck(delta: float) -> void:
	var travelling: bool = state != BotDecision.State.ATTACK and not _follower.is_finished()
	# Waiting for fuel on the ground ends by itself. Waiting in the air does not
	# if the bot is wedged, since fuel only refills on the ground.
	var refuelling: bool = _follower.is_resting() and _body.is_on_floor()
	if not travelling or refuelling:
		_reset_stuck_watch()
		return
	_stuck_timer += delta
	if _stuck_timer < float(_config["stuck_check_interval"]):
		return
	if _body.global_position.distance_to(_stuck_anchor) < float(_config["stuck_distance"]):
		_escape_left = _config["escape_time"]
		_escape_direction = -1.0 if randf() < 0.5 else 1.0
		_follower.clear()
	_reset_stuck_watch()


func _reset_stuck_watch() -> void:
	_stuck_timer = 0.0
	_stuck_anchor = _body.global_position


func _on_respawned(_fighter: Player) -> void:
	state = BotDecision.State.PATROL
	_target = null
	_target_visible = false
	_follower.clear()
	_reset_stuck_watch()
