extends GutTest
## Every action must have a sound. Code plays these keys by name.

const ACTION_KEYS: Array[String] = [
	"explosion", "grenade_throw", "grenade_bounce", "melee", "hit",
	"death", "respawn", "pickup", "swap", "jet", "reload",
]


func test_every_action_has_a_sound() -> void:
	var keys: Array = AssetMap.sound_keys()
	for key: String in ACTION_KEYS:
		assert_has(keys, key)


func test_every_weapon_has_a_shot_sound() -> void:
	var keys: Array = AssetMap.sound_keys()
	for weapon_id: String in ["pistol", "rifle", "shotgun", "sniper", "rocket"]:
		assert_has(keys, "shot_%s" % weapon_id)


func test_synthesised_sounds_contain_audio() -> void:
	for key: String in AssetMap.sound_keys():
		var stream: AudioStreamWAV = AssetMap.create_sound(key) as AudioStreamWAV
		assert_gt(stream.data.size(), 0, key)


func test_only_the_jetpack_loops() -> void:
	for key: String in AssetMap.sound_keys():
		var stream: AudioStreamWAV = AssetMap.create_sound(key) as AudioStreamWAV
		var loops: bool = stream.loop_mode == AudioStreamWAV.LOOP_FORWARD
		assert_eq(loops, key == "jet", key)
