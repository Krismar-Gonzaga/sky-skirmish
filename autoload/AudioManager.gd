extends Node
## Plays music and sound effects so scenes never own audio players themselves.

const SFX_BUS := "SFX"
const VOICE_COUNT := 16
const PITCH_VARIATION := 0.06

var _streams: Dictionary = {}
var _voices: Array[AudioStreamPlayer] = []
var _next_voice: int = 0
var _loop_players: Dictionary = {}


func _ready() -> void:
	_ensure_bus(SFX_BUS)
	# Synthesise everything up front: building a sound mid-fight would hitch.
	for key: String in AssetMap.sound_keys():
		_streams[key] = AssetMap.create_sound(key)
	for i: int in range(VOICE_COUNT):
		var voice := AudioStreamPlayer.new()
		voice.bus = SFX_BUS
		add_child(voice)
		_voices.append(voice)


## A sound still playing at quit would be reported by Godot as a leak.
func _exit_tree() -> void:
	for voice: AudioStreamPlayer in _voices:
		voice.stop()
		voice.stream = null
	for key: String in _loop_players:
		var loop_player: AudioStreamPlayer = _loop_players[key]
		loop_player.stop()
		loop_player.stream = null


func play(key: String) -> void:
	if not _streams.has(key):
		push_error("Unknown sound key: %s" % key)
		return
	var voice: AudioStreamPlayer = _voices[_next_voice]
	_next_voice = (_next_voice + 1) % VOICE_COUNT
	voice.stream = _streams[key]
	voice.pitch_scale = randf_range(1.0 - PITCH_VARIATION, 1.0 + PITCH_VARIATION)
	voice.play()


## Starts or stops a looping sound such as the jetpack.
func set_loop_active(key: String, active: bool) -> void:
	if not _loop_players.has(key):
		var player := AudioStreamPlayer.new()
		player.bus = SFX_BUS
		player.stream = _streams[key]
		add_child(player)
		_loop_players[key] = player
	var loop_player: AudioStreamPlayer = _loop_players[key]
	if loop_player.playing != active:
		loop_player.playing = active


func _ensure_bus(bus_name: String) -> void:
	if AudioServer.get_bus_index(bus_name) < 0:
		AudioServer.add_bus()
		AudioServer.set_bus_name(AudioServer.bus_count - 1, bus_name)
