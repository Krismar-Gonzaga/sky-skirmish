class_name InputProvider
extends Node
## Source of PlayerInput for one fighter. Player only knows this interface,
## which is what lets the same Player code serve humans, bots and network peers.


## aim_origin is where shots leave the fighter, in world space. Mouse aiming
## needs it; other providers ignore it.
func poll(_aim_origin: Vector2) -> PlayerInput:
	return PlayerInput.new()
