extends SceneTree
## Entry point for one side of a network test. Scripts passed with -s compile
## before autoloads exist, so the real test code is loaded after the first frame.


func _initialize() -> void:
	_start.call_deferred()


func _start() -> void:
	await process_frame
	root.add_child((load("res://tests/net/net_scenarios.gd") as GDScript).new())
