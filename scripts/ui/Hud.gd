class_name Hud
extends CanvasLayer
## In-match readouts in the top corners, leaving the centre clear for the fight.

signal pause_pressed

const CANVAS_LAYER := 5
const MARGIN := 20.0
const PAUSE_BUTTON_WIDTH := 100.0
const BAR_SIZE := Vector2(300.0, 24.0)
const INFO_FONT_SIZE := 24
const COUNTDOWN_FONT_SIZE := 56
const FADE_ALPHA := 0.6
const FADE_TIME := 0.3

var _health_bar: ProgressBar
var _fuel_bar: ProgressBar
var _weapon_label: Label
var _grenade_label: Label
var _timer_label: Label
var _objective_label: Label
var _countdown_label: Label
var _fade: ColorRect
var _respawn_delay: float = 0.0
var _respawn_left: float = 0.0


func _ready() -> void:
	layer = CANVAS_LAYER
	_respawn_delay = Tuning.section("health")["respawn_delay"]
	_build_fade_and_countdown()
	_build_left_panel()
	_build_right_panel()


func bind(fighter: Player) -> void:
	fighter.health_changed.connect(_on_health_changed)
	fighter.fuel_changed.connect(_on_fuel_changed)
	fighter.weapon_status_changed.connect(_on_weapon_status_changed)
	fighter.grenades_changed.connect(_on_grenades_changed)
	fighter.died.connect(_on_died)
	fighter.respawned.connect(_on_respawned)
	fighter.report_all_status()


func set_objective(text: String) -> void:
	_objective_label.text = text


func set_time_left(seconds: float) -> void:
	var whole: int = ceili(seconds)
	_timer_label.text = "%d:%02d" % [floori(whole / 60.0), whole % 60]


func hide_time() -> void:
	_timer_label.text = ""


func show_banner(text: String) -> void:
	_countdown_label.visible = true
	_countdown_label.text = text
	_respawn_left = 0.0


func _process(delta: float) -> void:
	if _respawn_left > 0.0:
		_respawn_left -= delta
		_countdown_label.text = "Respawning in %d" % ceili(maxf(_respawn_left, 0.0))


func _on_health_changed(current: float, maximum: float) -> void:
	_health_bar.max_value = maximum
	_health_bar.value = current


func _on_fuel_changed(current: float, capacity: float) -> void:
	_fuel_bar.max_value = capacity
	_fuel_bar.value = current


func _on_weapon_status_changed(status: String) -> void:
	_weapon_label.text = status


func _on_grenades_changed(count: int) -> void:
	_grenade_label.text = "Grenades  %d" % count


func _on_died(_victim: Player, _killer: Player) -> void:
	_respawn_left = _respawn_delay
	_countdown_label.visible = true
	_tween_fade(FADE_ALPHA)


func _on_respawned(_fighter: Player) -> void:
	_respawn_left = 0.0
	_countdown_label.visible = false
	_tween_fade(0.0)


func _tween_fade(alpha: float) -> void:
	create_tween().tween_property(_fade, "color:a", alpha, FADE_TIME)


func _build_fade_and_countdown() -> void:
	_fade = ColorRect.new()
	_fade.color = Color(AssetMap.color("ink"), 0.0)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_fade)
	_countdown_label = Label.new()
	_countdown_label.visible = false
	_countdown_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_countdown_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_countdown_label.add_theme_font_size_override("font_size", COUNTDOWN_FONT_SIZE)
	_countdown_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_countdown_label)


func _build_left_panel() -> void:
	var column := VBoxContainer.new()
	column.position = Vector2(MARGIN, MARGIN)
	add_child(column)
	_health_bar = _add_bar(column, "moss")
	_fuel_bar = _add_bar(column, "amber")
	_weapon_label = _add_label(column)
	_grenade_label = _add_label(column)


func _build_right_panel() -> void:
	var pause := Button.new()
	pause.name = "Pause"
	pause.text = "II"
	pause.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	pause.offset_left = -PAUSE_BUTTON_WIDTH - MARGIN
	pause.offset_right = -MARGIN
	pause.offset_top = MARGIN
	pause.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	pause.pressed.connect(func() -> void: pause_pressed.emit())
	add_child(pause)
	var column := VBoxContainer.new()
	column.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	column.offset_left = -MARGIN * 2.0 - PAUSE_BUTTON_WIDTH
	column.offset_right = -MARGIN * 2.0 - PAUSE_BUTTON_WIDTH
	column.offset_top = MARGIN
	column.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	column.alignment = BoxContainer.ALIGNMENT_BEGIN
	add_child(column)
	_timer_label = _add_label(column)
	_objective_label = _add_label(column)
	_timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_objective_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT


func _add_bar(parent: Control, color_name: String) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.custom_minimum_size = BAR_SIZE
	bar.show_percentage = false
	var fill: StyleBoxFlat = (bar.get_theme_stylebox("fill") as StyleBoxFlat).duplicate()
	fill.bg_color = AssetMap.color(color_name)
	bar.add_theme_stylebox_override("fill", fill)
	parent.add_child(bar)
	return bar


func _add_label(parent: Control) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", INFO_FONT_SIZE)
	parent.add_child(label)
	return label
