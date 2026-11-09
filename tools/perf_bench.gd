extends SceneTree
## Measures the heaviest campaign level without rendering, for spotting costly
## game code. Run with: godot --headless --path . --fixed-fps 60 -s tools/perf_bench.gd
## Classes are reached through load(), because -s scripts compile before autoloads exist.

const LEVEL := 7
const WARM_UP_FRAMES := 120
const SAMPLE_FRAMES := 1800
const FRAME_BUDGET_MS := 16.67
const MS_PER_SECOND := 1000.0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	root.get_node("ProgressService").use_directory("user://test_saves/perf")
	root.get_node("ProgressService").load_save()
	var started: int = Time.get_ticks_usec()
	var synth: GDScript = load("res://scripts/core/AssetMap.gd")
	for key: String in synth.music_keys():
		synth.create_music(key)
	for key: String in synth.sound_keys():
		synth.create_sound(key)
	print("Audio synthesis at start-up: %.1f ms" % ((Time.get_ticks_usec() - started) / MS_PER_SECOND))
	var game: Node = (load("res://scenes/game/Match.tscn") as PackedScene).instantiate()
	root.add_child(game)
	started = Time.get_ticks_usec()
	game.begin_campaign(LEVEL)
	print("Level start-up: %.1f ms" % ((Time.get_ticks_usec() - started) / MS_PER_SECOND))
	# An endless fight: the player cannot die and the clock never runs out.
	game.local_player.health.set_maximum(1000000000.0)
	game.rules.mission.time_left = 1000000.0
	for i: int in range(WARM_UP_FRAMES):
		await process_frame
	var loop_started: int = Time.get_ticks_usec()
	for i: int in range(SAMPLE_FRAMES):
		await process_frame
	# Wall-clock time: Godot's frame-time monitors report per-second maximums.
	var frame_mean: float = (Time.get_ticks_usec() - loop_started) / MS_PER_SECOND / SAMPLE_FRAMES
	print("Whole frame without rendering: mean %.2f ms" % frame_mean)
	print("Share of the 60 FPS budget: %.0f%%" % (frame_mean / FRAME_BUDGET_MS * 100.0))
	print("Objects %d, nodes %d" % [
		Performance.get_monitor(Performance.OBJECT_COUNT), Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
	])
	game.queue_free()
	await process_frame
	root.get_node("ProgressService").use_directory("user://")
	quit()
