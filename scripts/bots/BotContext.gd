class_name BotContext
extends RefCounted
## What every bot on a map needs to know. Shared, so the graph is built once.

var nav: JetNavGraph
var patrol_points: Array[Vector2] = []
var health_packs: Array[Vector2] = []
## The live list from Arena, so new fighters are seen automatically.
var fighters: Array[Player] = []


func _init(map: GameMap, arena: Arena) -> void:
	nav = JetNavGraph.new()
	nav.build(map.size_in_tiles(), map.solid_cells(), map.one_way_cells(), map.tile_size())
	patrol_points = map.patrol_points()
	health_packs = map.health_packs
	fighters = arena.fighters
