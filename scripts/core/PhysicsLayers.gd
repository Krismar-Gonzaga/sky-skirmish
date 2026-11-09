class_name PhysicsLayers
extends RefCounted
## Collision layer bits, matching the names in project.godot.
## One-way platforms have their own layer so bullets can pass through them.

const WORLD := 1
const PLAYERS := 2
const PROJECTILES := 4
const PICKUPS := 8
const PLATFORMS := 16
