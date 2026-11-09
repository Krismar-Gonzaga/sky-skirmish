class_name FragGrenade
extends CharacterBody2D
## Bounces off the world until its fuse runs out. Passes through fighters.

signal detonated(grenade: FragGrenade)
signal bounced(at: Vector2)

const SPIN_SPEED := 9.0
const MIN_AUDIBLE_BOUNCE_SPEED := 90.0

var thrower: Player
## On a client this copy only shows the throw; the host's grenade does the damage.
var cosmetic: bool = false

var _fuse_left: float = 0.0
var _gravity: float = 0.0
var _bounce: float = 0.0
var _rest_speed: float = 0.0
var _visual: Node2D


func _ready() -> void:
	collision_layer = 0
	collision_mask = PhysicsLayers.WORLD | PhysicsLayers.PLATFORMS
	var circle := CircleShape2D.new()
	circle.radius = WeaponCatalog.grenade()["body_radius"]
	var shape := CollisionShape2D.new()
	shape.shape = circle
	add_child(shape)
	_visual = AssetMap.create_visual("grenade.frag")
	add_child(_visual)


func launch(origin: Vector2, direction: Vector2, owner_player: Player) -> void:
	var stats: Dictionary = WeaponCatalog.grenade()
	global_position = origin
	velocity = direction * float(stats["throw_speed"])
	thrower = owner_player
	_fuse_left = stats["fuse"]
	_bounce = stats["bounce"]
	_rest_speed = stats["rest_speed"]
	_gravity = Tuning.section("player")["gravity"]


func _physics_process(delta: float) -> void:
	_fuse_left -= delta
	if _fuse_left <= 0.0:
		detonated.emit(self)
		return
	velocity.y += _gravity * delta
	var collision: KinematicCollision2D = move_and_collide(velocity * delta)
	if collision != null:
		if velocity.length() >= MIN_AUDIBLE_BOUNCE_SPEED:
			bounced.emit(global_position)
		velocity = velocity.bounce(collision.get_normal()) * _bounce
		if velocity.length() < _rest_speed:
			velocity = Vector2.ZERO
	_visual.rotation += velocity.x * delta * SPIN_SPEED * 0.01
