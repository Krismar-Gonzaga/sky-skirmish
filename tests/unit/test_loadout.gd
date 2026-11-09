extends GutTest

const STEP := 1.0 / 60.0

var loadout: Loadout


func before_each() -> void:
	loadout = Loadout.new()


func test_starts_with_only_a_pistol() -> void:
	assert_eq(loadout.active().id, "pistol")
	assert_false(loadout.swap(), "nothing to swap to")


func test_pickup_fills_free_slot_and_selects_it() -> void:
	loadout.pickup("rifle")
	assert_eq(loadout.active().id, "rifle")
	assert_true(loadout.holding("pistol"))


func test_swap_moves_between_the_two_weapons() -> void:
	loadout.pickup("rifle")
	assert_true(loadout.swap())
	assert_eq(loadout.active().id, "pistol")
	assert_true(loadout.swap())
	assert_eq(loadout.active().id, "rifle")


func test_third_weapon_replaces_the_one_in_hand() -> void:
	loadout.pickup("rifle")
	loadout.pickup("sniper")
	assert_eq(loadout.active().id, "sniper")
	assert_false(loadout.holding("rifle"))
	assert_true(loadout.holding("pistol"))


func test_picking_up_a_held_weapon_adds_a_magazine() -> void:
	loadout.pickup("rifle")
	var before: int = loadout.active().reserve
	loadout.pickup("rifle")
	assert_eq(loadout.active().reserve, before + 30)


func test_swap_cancels_a_reload() -> void:
	loadout.pickup("rifle")
	var rifle: Weapon = loadout.active()
	rifle.ammo = 0
	loadout.update(STEP)
	assert_true(rifle.is_reloading())
	loadout.swap()
	assert_false(rifle.is_reloading())


func test_depleted_weapon_is_dropped_for_the_other_slot() -> void:
	loadout.pickup("rocket")
	loadout.active().ammo = 0
	loadout.active().reserve = 0
	loadout.update(STEP)
	assert_eq(loadout.active().id, "pistol")
	assert_false(loadout.holding("rocket"))


func test_losing_both_weapons_returns_the_pistol() -> void:
	loadout.pickup("rifle")
	loadout.swap()
	loadout.pickup("rocket")
	assert_false(loadout.holding("pistol"))
	for i: int in range(2):
		loadout.active().ammo = 0
		loadout.active().reserve = 0
		loadout.update(STEP)
	assert_eq(loadout.active().id, "pistol")


func test_reset_restores_the_starting_state() -> void:
	loadout.pickup("sniper")
	loadout.reset()
	assert_eq(loadout.active().id, "pistol")
	assert_false(loadout.holding("sniper"))
