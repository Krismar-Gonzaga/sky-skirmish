class_name WeaponCatalog
extends RefCounted
## Access to data/weapons.json and the factory for Weapon objects.

const PATH := "res://data/weapons.json"
const DEFAULT_WEAPON := "pistol"

static var _data: Dictionary = {}


static func stats(weapon_id: String) -> Dictionary:
	return _load()["weapons"][weapon_id]


static func grenade() -> Dictionary:
	return _load()["grenade"]


static func melee() -> Dictionary:
	return _load()["melee"]


static func aim() -> Dictionary:
	return _load()["aim"]


## Every weapon a crate can hold; the default pistol is never a crate prize.
static func crate_weapon_ids() -> Array[String]:
	var ids: Array[String] = []
	for weapon_id: String in _load()["weapons"].keys():
		if weapon_id != DEFAULT_WEAPON:
			ids.append(weapon_id)
	return ids


static func create(weapon_id: String) -> Weapon:
	var weapon_stats: Dictionary = stats(weapon_id)
	match weapon_id:
		"pistol":
			return Pistol.new(weapon_stats)
		"rifle":
			return Rifle.new(weapon_stats)
		"shotgun":
			return Shotgun.new(weapon_stats)
		"sniper":
			return Sniper.new(weapon_stats)
		"rocket":
			return RocketLauncher.new(weapon_stats)
	push_error("Weapon id has no class: %s" % weapon_id)
	return Pistol.new(stats(DEFAULT_WEAPON))


static func _load() -> Dictionary:
	if _data.is_empty():
		_data = DataFile.load_dictionary(PATH)
	return _data
