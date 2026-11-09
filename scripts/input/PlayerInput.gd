class_name PlayerInput
extends RefCounted
## One frame of intent from a human, a bot or the network.
## Buttons are held states, not one-shot events: Player detects the press, so a
## dropped network packet cannot lose a grenade throw.

var move: Vector2 = Vector2.ZERO
var aim: Vector2 = Vector2.ZERO
var fire: bool = false
var jet: bool = false
var grenade: bool = false
var swap: bool = false
var melee: bool = false
var crouch: bool = false
