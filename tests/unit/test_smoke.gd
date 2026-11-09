extends GutTest
## Guards the project settings that the rest of the game depends on.

const AUTOLOADS: Array[String] = [
	"GameState", "LevelManager", "ProgressService",
	"NetworkManager", "AudioManager", "Settings",
]

## 48 dp on a phone in landscape: about 360 dp of height maps onto 720 canvas
## units, so one dp is about 2 canvas units.
const MIN_TOUCH_CANVAS_UNITS := 96.0


func test_every_autoload_is_registered() -> void:
	var root: Window = get_tree().root
	for autoload_name: String in AUTOLOADS:
		assert_true(root.has_node(autoload_name), "%s missing" % autoload_name)


func test_renderer_supports_widest_android_range() -> void:
	assert_eq(
		ProjectSettings.get_setting("rendering/renderer/rendering_method"),
		"gl_compatibility"
	)
	assert_eq(
		ProjectSettings.get_setting("rendering/renderer/rendering_method.mobile"),
		"gl_compatibility"
	)


func test_theme_button_meets_touch_target() -> void:
	var button := Button.new()
	button.theme = load("res://assets/theme/sky_theme.tres") as Theme
	button.text = "Play"
	add_child_autofree(button)
	assert_gte(button.get_minimum_size().y, MIN_TOUCH_CANVAS_UNITS)
