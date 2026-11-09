class_name InputFactory
extends RefCounted
## Picks the input provider for the person holding this device.

const TOUCH_FLAG := "--touch"


static func create_local_provider() -> InputProvider:
	var wants_touch: bool = TOUCH_FLAG in OS.get_cmdline_user_args()
	if wants_touch:
		Input.emulate_touch_from_mouse = true
	if wants_touch or OS.has_feature("mobile"):
		return TouchInputProvider.new()
	return KeyboardMouseInputProvider.new()
