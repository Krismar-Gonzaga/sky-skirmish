extends Node
## Plays music and sound effects so scenes never own audio players themselves.

const SFX_BUS := "SFX"
const MUSIC_BUS := "Music"
const VOICE_COUNT := 16
const PITCH_VARIATION := 0.06
const MIXER_DRAIN_MSEC := 150

var _streams: Dictionary = {}
var _music_streams: Dictionary = {}
var _voices: Array[AudioStreamPlayer] = []
var _next_voice: int = 0
var _loop_players: Dictionary = {}
var _music_player: AudioStreamPlayer
var _current_music: String = ""


func _ready() -> void:
	# Music keeps playing under the pause menu.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_bus(SFX_BUS)
	_ensure_bus(MUSIC_BUS)
	# Synthesise everything up front: building a sound mid-fight would hitch.
	for key: String in AssetMap.sound_keys():
		_streams[key] = AssetMap.create_sound(key)
	for key: String in AssetMap.music_keys():
		_music_streams[key] = AssetMap.create_music(key)
	for i: int in range(VOICE_COUNT):
		var voice := AudioStreamPlayer.new()
		voice.bus = SFX_BUS
		add_child(voice)
		_voices.append(voice)
	_music_player = AudioStreamPlayer.new()
	_music_player.bus = MUSIC_BUS
	add_child(_music_player)


## A sound still playing at quit would be reported by Godot as a leak.
func _exit_tree() -> void:
	for voice: AudioStreamPlayer in _voices:
		voice.stop()
		voice.stream = null
	for key: String in _loop_players:
		var loop_player: AudioStreamPlayer = _loop_players[key]
		loop_player.stop()
		loop_player.stream = null
	_music_player.stop()
	_music_player.stream = null
	# A stopped stream is freed by the mixer thread, which needs one more pass.
	OS.delay_msec(MIXER_DRAIN_MSEC)


func play(key: String) -> void:
	if not _streams.has(key):
		push_error("Unknown sound key: %s" % key)
		return
	var voice: AudioStreamPlayer = _voices[_next_voice]
	_next_voice = (_next_voice + 1) % VOICE_COUNT
	voice.stream = _streams[key]
	voice.pitch_scale = randf_range(1.0 - PITCH_VARIATION, 1.0 + PITCH_VARIATION)
	voice.play()


## Starting the track already playing does nothing, so menus do not restart it.
func play_music(key: String) -> void:
	if key == _current_music or not _music_streams.has(key):
		return
	_current_music = key
	_music_player.stream = _music_streams[key]
	_music_player.play()


func current_music() -> String:
	return _current_music


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
