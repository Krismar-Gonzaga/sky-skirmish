class_name Projectile
extends Node2D
## A fired round. Casts a ray along each step's travel, so even the fastest
## bullet cannot jump through a thin wall between two frames.
## Instances are pooled by Arena, so launch() must reset every field.

signal struck(projectile: Projectile, hit_position: Vector2, collider: Object)
signal expired(projectile: Projectile)

## Moves an impact back off the surface so splash line-of-sight rays start clear.
const SURFACE_BACKOFF := 3.0

var shooter: Player
var weapon_damage: float = 0.0
var splash_radius: float = 0.0
var self_damage_factor: float = 0.0
var cosmetic: bool = false

var _hit_mask: int = 0
var _direction: Vector2 = Vector2.RIGHT
var _speed: float = 0.0
var _distance_left: float = 0.0
var _excluded: Array[RID] = []
var _visuals: Dictionary = {}
var _smoke: CPUParticles2D


func _ready() -> void:
	deactivate()


func launch(origin: Vector2, direction: Vector2, weapon: Weapon, owner_player: Player,
		excluded: Array[RID]) -> void:
	global_position = origin
	rotation = direction.angle()
	shooter = owner_player
	weapon_damage = weapon.damage
	splash_radius = weapon.splash_radius
	self_damage_factor = weapon.self_damage_factor
	_direction = direction
	_speed = weapon.projectile_speed
	_distance_left = weapon.max_range
	_excluded = excluded
	_hit_mask = PhysicsLayers.WORLD | PhysicsLayers.PLAYERS
	cosmetic = false
	_show_visual(weapon.projectile_kind)
	visible = true
	set_physics_process(true)


## Client-side copy of a host's shot: flies and stops at walls, but hits nothing.
func launch_cosmetic(origin: Vector2, direction: Vector2, weapon: Weapon) -> void:
	var nothing_excluded: Array[RID] = []
	launch(origin, direction, weapon, null, nothing_excluded)
	_hit_mask = PhysicsLayers.WORLD
	cosmetic = true


func deactivate() -> void:
	visible = false
	set_physics_process(false)
	if _smoke != null:
		_smoke.emitting = false


func _physics_process(delta: float) -> void:
	var travel: float = minf(_speed * delta, _distance_left)
	var destination: Vector2 = global_position + _direction * travel
	var query := PhysicsRayQueryParameters2D.create(
			global_position, destination, _hit_mask, _excluded)
	var hit: Dictionary = get_world_2d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		var hit_position: Vector2 = hit["position"]
		global_position = hit_position - _direction * SURFACE_BACKOFF
		struck.emit(self, global_position, hit["collider"])
		return
	global_position = destination
	_distance_left -= travel
	if _distance_left <= 0.0:
		expired.emit(self)


func _show_visual(kind: String) -> void:
	if not _visuals.has(kind):
		var visual: Node2D = AssetMap.create_visual("projectile.%s" % kind)
		add_child(visual)
		_visuals[kind] = visual
	for visual_kind: String in _visuals:
		var visual: Node2D = _visuals[visual_kind]
		visual.visible = visual_kind == kind
	if kind == "rocket":
		if _smoke == null:
			_smoke = _create_smoke()
			add_child(_smoke)
		_smoke.emitting = true


func _create_smoke() -> CPUParticles2D:
	var smoke := CPUParticles2D.new()
	smoke.local_coords = false
	smoke.amount = 24
	smoke.lifetime = 0.5
	smoke.position = Vector2(-14.0, 0.0)
	smoke.gravity = Vector2.ZERO
	smoke.initial_velocity_min = 8.0
	smoke.initial_velocity_max = 30.0
	smoke.spread = 180.0
	smoke.scale_amount_min = 4.0
	smoke.scale_amount_max = 9.0
	smoke.color = Color(AssetMap.color("muted"), 0.5)
	return smoke
