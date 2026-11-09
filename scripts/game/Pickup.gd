class_name Pickup
extends Area2D
## A weapon crate or health pack that comes back after a delay.
## Arena decides what a touch does, so hosts stay in charge in multiplayer.

signal touched(pickup: Pickup, fighter: Player)

enum Kind { WEAPON, HEALTH }

const LABEL_SIZE := 16
const LABEL_OFFSET := Vector2(-40.0, -46.0)
const LABEL_WIDTH := 80.0

var kind: Kind = Kind.WEAPON
var weapon_id: String = ""

var _fixed_weapon: bool = false
var _weapon_pool: Array[String] = []
var _respawn_time: float = 0.0
var _respawn_left: float = 0.0
var _available: bool = true
var _label: Label


## An empty chosen_weapon makes a crate pick from the pool on each respawn.
func setup(pickup_kind: Kind, chosen_weapon: String, weapon_pool: Array[String]) -> void:
	kind = pickup_kind
	_fixed_weapon = not chosen_weapon.is_empty()
	weapon_id = chosen_weapon
	_weapon_pool = weapon_pool
	var config: Dictionary = Tuning.section("pickups")
	_respawn_time = config["respawn_time"]
	collision_layer = PhysicsLayers.PICKUPS
	collision_mask = PhysicsLayers.PLAYERS
	var circle := CircleShape2D.new()
	circle.radius = config["touch_radius"]
	var shape := CollisionShape2D.new()
	shape.shape = circle
	add_child(shape)
	add_child(AssetMap.create_visual("pickup.crate" if kind == Kind.WEAPON else "pickup.health"))
	_label = Label.new()
	_label.position = LABEL_OFFSET
	_label.size = Vector2(LABEL_WIDTH, LABEL_SIZE)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", LABEL_SIZE)
	add_child(_label)
	_prepare_contents()


func is_available() -> bool:
	return _available


func consume() -> void:
	_available = false
	_respawn_left = _respawn_time
	visible = false


func _physics_process(delta: float) -> void:
	if not _available:
		_respawn_left -= delta
		if _respawn_left <= 0.0:
			_prepare_contents()
			_available = true
			visible = true
		return
	# Polling, not body_entered: someone already standing here when the crate
	# comes back must still collect it.
	for body: Node2D in get_overlapping_bodies():
		if body is Player and not (body as Player).is_dead:
			touched.emit(self, body as Player)
			if not _available:
				return


func _prepare_contents() -> void:
	if kind == Kind.WEAPON and not _fixed_weapon and not _weapon_pool.is_empty():
		weapon_id = _weapon_pool.pick_random()
	if kind == Kind.WEAPON:
		_label.text = str(WeaponCatalog.stats(weapon_id)["display_name"])
	else:
		_label.text = "Health"
