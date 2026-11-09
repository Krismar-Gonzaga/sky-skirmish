class_name SfxSynth
extends RefCounted
## Builds placeholder sound effects from numbers, so the game has sound for
## every action with no downloaded assets.

const MIX_RATE := 22050
const MAX_SAMPLE := 32767.0
## Lower than the effects: music is generated at start-up on the phone's CPU.
const MUSIC_MIX_RATE := 11025
const PLUCK_DECAY := 2.5
const BASS_LEVEL := 0.7
const LEAD_LEVEL := 0.3


static func create(entry: Dictionary) -> AudioStreamWAV:
	var count: int = int(float(entry["duration"]) * MIX_RATE)
	var data := PackedByteArray()
	data.resize(count * 2)
	var wave: String = entry["wave"]
	var start_hz: float = entry.get("start_hz", 0.0)
	var end_hz: float = entry.get("end_hz", 0.0)
	var decay: float = entry["decay"]
	var volume: float = entry["volume"]
	# Lower values muffle the noise; explosions need that low rumble.
	var smooth: float = entry.get("smooth", 1.0)
	var phase: float = 0.0
	var filtered: float = 0.0
	for i: int in range(count):
		var progress: float = float(i) / count
		phase += lerpf(start_hz, end_hz, progress) / MIX_RATE
		filtered = lerpf(filtered, _oscillator(wave, phase), smooth)
		var sample: float = filtered * volume * pow(1.0 - progress, decay)
		data.encode_s16(i * 2, int(clampf(sample, -1.0, 1.0) * MAX_SAMPLE))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = MIX_RATE
	stream.data = data
	if entry.get("loop", false):
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_end = count
	return stream


## A short looping pattern: a bass line under a plucked lead.
## Notes are semitones above root_hz.
static func create_music(entry: Dictionary) -> AudioStreamWAV:
	var bass: Array = entry["bass"]
	var lead: Array = entry["lead"]
	var root_hz: float = entry["root_hz"]
	var volume: float = entry["volume"]
	var step_samples: int = int(float(entry["step_seconds"]) * MUSIC_MIX_RATE)
	var data := PackedByteArray()
	data.resize(bass.size() * step_samples * 2)
	var bass_phase: float = 0.0
	var lead_phase: float = 0.0
	for step: int in range(bass.size()):
		var bass_hz: float = root_hz * pow(2.0, float(bass[step]) / 12.0)
		var lead_hz: float = root_hz * pow(2.0, float(lead[step]) / 12.0)
		for i: int in range(step_samples):
			var pluck: float = pow(1.0 - float(i) / step_samples, PLUCK_DECAY)
			bass_phase += bass_hz / MUSIC_MIX_RATE
			lead_phase += lead_hz / MUSIC_MIX_RATE
			var sample: float = sin(bass_phase * TAU) * BASS_LEVEL
			sample += _oscillator("square", lead_phase) * pluck * LEAD_LEVEL
			var at: int = (step * step_samples + i) * 2
			data.encode_s16(at, int(clampf(sample * volume, -1.0, 1.0) * MAX_SAMPLE))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = MUSIC_MIX_RATE
	stream.data = data
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_end = bass.size() * step_samples
	return stream


static func _oscillator(wave: String, phase: float) -> float:
	match wave:
		"noise":
			return randf_range(-1.0, 1.0)
		"square":
			return 1.0 if fposmod(phase, 1.0) < 0.5 else -1.0
		_:
			return sin(phase * TAU)
