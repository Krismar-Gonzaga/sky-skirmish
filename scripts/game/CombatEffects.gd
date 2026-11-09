class_name CombatEffects
extends Node2D
## Turns Arena events into flashes, particles, numbers, shake and sound.
## Nothing here affects gameplay, so a client can run it without simulating.

const GLOW_SHADER := preload("res://assets/shaders/muzzle_flash.gdshader")
const MUZZLE_DISTANCE := 34.0
const MUZZLE_SIZE := 46.0
const MUZZLE_TIME := 0.07
const EXPLOSION_GLOW_TIME := 0.25
const DAMAGE_NUMBER_RISE := 54.0
const DAMAGE_NUMBER_TIME := 0.7
const DAMAGE_NUMBER_SIZE := 24
const FRONT_LAYER := 20

var _camera: AimCamera
var _local_player: Player
var _glow_texture: ImageTexture
var _glow_material: ShaderMaterial
var _explosion_trauma: float = 0.0


func _ready() -> void:
	z_index = FRONT_LAYER
	_explosion_trauma = Tuning.section("camera")["explosion_trauma"]
	var pixel := Image.create_empty(1, 1, false, Image.FORMAT_RGBA8)
	pixel.fill(Color.WHITE)
	_glow_texture = ImageTexture.create_from_image(pixel)
	_glow_material = ShaderMaterial.new()
	_glow_material.shader = GLOW_SHADER


func bind(arena: Arena, camera: AimCamera, local_player: Player) -> void:
	_camera = camera
	_local_player = local_player
	arena.shots_fired.connect(_on_shots_fired)
	arena.round_impacted.connect(_on_round_impacted)
	arena.exploded.connect(_on_exploded)
	arena.fighter_damaged.connect(_on_fighter_damaged)
	arena.fighter_killed.connect(_on_fighter_killed)
	arena.fighter_respawned.connect(func(_fighter: Player) -> void: AudioManager.play("respawn"))
	arena.grenade_launched.connect(func(_at: Vector2, _direction: Vector2) -> void: AudioManager.play("grenade_throw"))
	arena.grenade_bounced.connect(func(_at: Vector2) -> void: AudioManager.play("grenade_bounce"))
	arena.melee_swung.connect(func(_at: Vector2) -> void: AudioManager.play("melee"))
	arena.item_taken.connect(func(_at: Vector2) -> void: AudioManager.play("pickup"))


func _physics_process(_delta: float) -> void:
	if _local_player != null:
		AudioManager.set_loop_active("jet", _local_player.is_thrusting)


func _on_shots_fired(origin: Vector2, directions: Array[Vector2], weapon_id: String) -> void:
	_spawn_glow(origin + directions[0] * MUZZLE_DISTANCE, MUZZLE_SIZE, MUZZLE_TIME)
	AudioManager.play("shot_%s" % weapon_id)


func _on_round_impacted(at: Vector2, on_fighter: bool) -> void:
	_burst(at, 8, AssetMap.color("amber" if on_fighter else "muted"), 220.0, 0.22, 3.0)
	if on_fighter:
		AudioManager.play("hit")


func _on_exploded(at: Vector2, radius: float) -> void:
	_spawn_glow(at, radius * 2.4, EXPLOSION_GLOW_TIME)
	_burst(at, 30, AssetMap.color("amber"), radius * 4.0, 0.4, 5.0)
	_burst(at, 22, Color(AssetMap.color("muted"), 0.55), radius * 1.5, 0.8, 12.0)
	_camera.add_trauma(_explosion_trauma)
	AudioManager.play("explosion")


func _on_fighter_damaged(victim: Player, amount: float) -> void:
	var label := Label.new()
	label.text = str(roundi(amount))
	label.add_theme_font_size_override("font_size", DAMAGE_NUMBER_SIZE)
	label.add_theme_color_override("font_color", AssetMap.color("amber"))
	add_child(label)
	label.global_position = victim.get_center() + Vector2(randf_range(-14.0, 14.0), -44.0)
	var tween: Tween = label.create_tween()
	tween.set_parallel()
	tween.tween_property(label, "position:y", label.position.y - DAMAGE_NUMBER_RISE, DAMAGE_NUMBER_TIME)
	tween.tween_property(label, "modulate:a", 0.0, DAMAGE_NUMBER_TIME)
	tween.chain().tween_callback(label.queue_free)


func _on_fighter_killed(victim: Player, _killer: Player) -> void:
	_burst(victim.get_center(), 26, AssetMap.color("teal"), 300.0, 0.6, 4.0)
	AudioManager.play("death")


func _spawn_glow(at: Vector2, size: float, lifetime: float) -> void:
	var glow := Sprite2D.new()
	glow.texture = _glow_texture
	glow.material = _glow_material
	glow.global_position = at
	glow.scale = Vector2(size, size)
	add_child(glow)
	var tween: Tween = glow.create_tween()
	tween.tween_property(glow, "modulate:a", 0.0, lifetime)
	tween.tween_callback(glow.queue_free)


func _burst(at: Vector2, amount: int, color: Color, speed: float, lifetime: float, particle_size: float) -> void:
	var particles := CPUParticles2D.new()
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.amount = amount
	particles.lifetime = lifetime
	particles.spread = 180.0
	particles.gravity = Vector2(0.0, 360.0)
	particles.initial_velocity_min = speed * 0.3
	particles.initial_velocity_max = speed
	particles.scale_amount_min = particle_size * 0.5
	particles.scale_amount_max = particle_size
	particles.color = color
	particles.global_position = at
	particles.finished.connect(particles.queue_free)
	add_child(particles)
	particles.emitting = true
