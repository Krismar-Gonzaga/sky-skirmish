class_name NetInputState
extends InputProvider
## A fighter's input as properties a MultiplayerSynchronizer can replicate.
## The owning client writes it each frame and the host reads it through poll().

var move: Vector2 = Vector2.ZERO
var aim: Vector2 = Vector2.ZERO
var fire: bool = false
var jet: bool = false
var grenade: bool = false
var swap: bool = false
var melee: bool = false
var crouch: bool = false


func capture(input: PlayerInput) -> void:
	move = input.move
	aim = input.aim
	fire = input.fire
	jet = input.jet
	grenade = input.grenade
	swap = input.swap
	melee = input.melee
	crouch = input.crouch


func poll(_aim_origin: Vector2) -> PlayerInput:
	var input := PlayerInput.new()
	input.move = move
	input.aim = aim
	input.fire = fire
	input.jet = jet
	input.grenade = grenade
	input.swap = swap
	input.melee = melee
	input.crouch = crouch
	return input


static func replicated_properties() -> Array[String]:
	return [":move", ":aim", ":fire", ":jet", ":grenade", ":swap", ":melee", ":crouch"]
