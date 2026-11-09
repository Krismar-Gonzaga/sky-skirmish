class_name AssetMap
extends RefCounted
## The single place visuals come from. Setting a "texture" path in
## assets/asset_map.json swaps a placeholder for real art with no code change.

const PATH := "res://assets/asset_map.json"

static var _data: Dictionary = {}


static func color(color_name: String) -> Color:
	var palette: Dictionary = _load().get("palette", {})
	var hex: String = palette.get(color_name, "#ff00ff")
	return Color.html(hex)


static func create_visual(key: String) -> Node2D:
	var sprites: Dictionary = _load().get("sprites", {})
	var entry: Dictionary = sprites.get(key, {})
	if entry.is_empty():
		push_error("Unknown sprite key: %s" % key)
		return Node2D.new()
	var texture_path: String = entry.get("texture", "")
	if not texture_path.is_empty():
		var sprite := Sprite2D.new()
		sprite.texture = load(texture_path) as Texture2D
		return sprite
	var polygon := Polygon2D.new()
	polygon.polygon = _to_points(entry["polygon"])
	polygon.color = color(entry["color"])
	return polygon


static func tile_texture(key: String, tile_size: int) -> Texture2D:
	var tiles: Dictionary = _load().get("tiles", {})
	var entry: Dictionary = tiles.get(key, {})
	var texture_path: String = entry.get("texture", "")
	if not texture_path.is_empty():
		return load(texture_path) as Texture2D
	var image := Image.create_empty(tile_size, tile_size, false, Image.FORMAT_RGBA8)
	var height: int = int(entry.get("height", tile_size))
	image.fill_rect(Rect2i(0, 0, tile_size, height), color(entry.get("color", "")))
	if entry.has("top_color"):
		var top_height: int = int(entry.get("top_height", 0))
		image.fill_rect(Rect2i(0, 0, tile_size, top_height), color(entry["top_color"]))
	return ImageTexture.create_from_image(image)


static func sound_keys() -> Array:
	return _load().get("sounds", {}).keys()


static func create_sound(key: String) -> AudioStream:
	var sounds: Dictionary = _load().get("sounds", {})
	var entry: Dictionary = sounds.get(key, {})
	var file_path: String = entry.get("file", "")
	if not file_path.is_empty():
		return load(file_path) as AudioStream
	return SfxSynth.create(entry)


static func music_keys() -> Array:
	return _load().get("music", {}).keys()


static func create_music(key: String) -> AudioStream:
	var tracks: Dictionary = _load().get("music", {})
	var entry: Dictionary = tracks.get(key, {})
	var file_path: String = entry.get("file", "")
	if not file_path.is_empty():
		return load(file_path) as AudioStream
	return SfxSynth.create_music(entry)


static func has_sprite(key: String) -> bool:
	return _load().get("sprites", {}).has(key)


static func backdrop_layers() -> Array:
	return _load().get("backdrop", [])


static func to_points(raw: Array) -> PackedVector2Array:
	return _to_points(raw)


static func _load() -> Dictionary:
	if _data.is_empty():
		_data = DataFile.load_dictionary(PATH)
	return _data


static func _to_points(raw: Array) -> PackedVector2Array:
	var points := PackedVector2Array()
	for pair: Array in raw:
		points.append(Vector2(pair[0], pair[1]))
	return points
