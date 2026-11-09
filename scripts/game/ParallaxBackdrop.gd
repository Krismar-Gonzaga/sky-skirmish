class_name ParallaxBackdrop
extends Node2D
## Distant scenery from AssetMap that scrolls slower than the map, for depth.

const REPEATS := 4


func _ready() -> void:
	for layer: Dictionary in AssetMap.backdrop_layers():
		var scroll: float = layer["scroll"]
		var parallax := Parallax2D.new()
		parallax.scroll_scale = Vector2(scroll, scroll)
		parallax.repeat_size = Vector2(layer["repeat_width"], 0.0)
		parallax.repeat_times = REPEATS
		var shape := Polygon2D.new()
		shape.polygon = AssetMap.to_points(layer["polygon"])
		shape.color = AssetMap.color(layer["color"])
		shape.position.y = layer["base_y"]
		parallax.add_child(shape)
		add_child(parallax)
