extends Node
## Player preferences: volumes, stick size, aim assist, name and skin.
## ProgressService owns the file; this owns the live values and applies them.

const MAX_NAME_LENGTH := 12

var music: float = 0.7
var sfx: float = 0.9
var aim_assist: bool = true
var stick_size: float = 1.0
var player_name: String = "Pilot"
var selected_skin: String = ""


func _ready() -> void:
	load_from_save()


## Reads the saved values, discarding anything changed but not saved.
func load_from_save() -> void:
	var saved: Dictionary = ProgressService.data["settings"]
	music = saved["music"]
	sfx = saved["sfx"]
	aim_assist = saved["aim_assist"]
	stick_size = saved["stick_size"]
	player_name = ProgressService.data["player_name"]
	selected_skin = ProgressService.data["selected_skin"]
	apply_audio()


func save() -> void:
	ProgressService.data["settings"] = {
		"music": music, "sfx": sfx, "aim_assist": aim_assist, "stick_size": stick_size,
	}
	ProgressService.data["player_name"] = player_name
	ProgressService.data["selected_skin"] = selected_skin
	ProgressService.save()


func apply_audio() -> void:
	_set_bus_volume(AudioManager.MUSIC_BUS, music)
	_set_bus_volume(AudioManager.SFX_BUS, sfx)


func _set_bus_volume(bus_name: String, volume: float) -> void:
	var bus: int = AudioServer.get_bus_index(bus_name)
	AudioServer.set_bus_mute(bus, volume <= 0.0)
	AudioServer.set_bus_volume_db(bus, linear_to_db(volume))
