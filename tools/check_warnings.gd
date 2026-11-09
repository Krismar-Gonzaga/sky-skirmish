extends SceneTree
## Loads every project script under the debugger (-d), the only headless mode
## where Godot prints GDScript warnings such as missing static types.


func _init() -> void:
	# Autoloads do not exist yet during _init; scripts that use them need them.
	await process_frame
	for directory: String in ["res://autoload", "res://scripts", "res://tests"]:
		_load_scripts_in(directory)
	quit()


func _load_scripts_in(directory: String) -> void:
	for file_name: String in DirAccess.get_files_at(directory):
		if file_name.ends_with(".gd"):
			load(directory.path_join(file_name))
	for child: String in DirAccess.get_directories_at(directory):
		_load_scripts_in(directory.path_join(child))
