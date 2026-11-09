class_name Loadout
extends RefCounted
## The two weapons a fighter carries and the rules for changing them.

const SLOT_COUNT := 2

var _slots: Array[Weapon] = []
var _active_slot: int = 0


func _init() -> void:
	reset()


## Back to one pistol, as at the start of every life.
func reset() -> void:
	_slots = [WeaponCatalog.create(WeaponCatalog.DEFAULT_WEAPON), null]
	_active_slot = 0


func active() -> Weapon:
	return _slots[_active_slot]


func holding(weapon_id: String) -> bool:
	for weapon: Weapon in _slots:
		if weapon != null and weapon.id == weapon_id:
			return true
	return false


func update(delta: float) -> void:
	active().update(delta)
	if active().is_depleted():
		_drop_active()


func swap() -> bool:
	var other: int = (_active_slot + 1) % SLOT_COUNT
	if _slots[other] == null:
		return false
	active().cancel_reload()
	_active_slot = other
	return true


## A held weapon gains a magazine. A new one takes the free slot, or replaces
## the weapon in hand, and is selected straight away.
func pickup(weapon_id: String) -> void:
	for weapon: Weapon in _slots:
		if weapon != null and weapon.id == weapon_id:
			weapon.add_magazine()
			return
	var free_slot: int = _slots.find(null)
	if free_slot >= 0:
		_active_slot = free_slot
	_slots[_active_slot] = WeaponCatalog.create(weapon_id)


func _drop_active() -> void:
	_slots[_active_slot] = null
	var other: int = (_active_slot + 1) % SLOT_COUNT
	if _slots[other] == null:
		reset()
	else:
		_active_slot = other
