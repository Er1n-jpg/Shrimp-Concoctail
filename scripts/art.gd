class_name Art
extends RefCounted
## Finds drop-in files in res://assets/ by name (no extension needed).
## Missing files return null so the game can show placeholders instead.
## See res://assets/README.md for every file name the game looks for.

const ROOT := "res://assets/"
const IMAGE_EXTENSIONS := ["png", "webp", "jpg", "jpeg", "svg"]
const AUDIO_EXTENSIONS := ["ogg", "wav", "mp3"]
const FONT_EXTENSIONS := ["ttf", "otf", "woff2", "woff"]


static func ingredient(id: String) -> String:
	return ROOT + "ingredients/" + id


static func customer(id: String, mood: String = "") -> String:
	return ROOT + "customers/" + id + ("_" + mood if mood != "" else "")


static func ui(file_name: String) -> String:
	return ROOT + "ui/" + file_name


static func sfx(file_name: String) -> String:
	return ROOT + "sfx/" + file_name


static func music(file_name: String) -> String:
	return ROOT + "music/" + file_name


static func load_texture(base_path: String) -> Texture2D:
	return _find(base_path, IMAGE_EXTENSIONS) as Texture2D


static func load_audio(base_path: String) -> AudioStream:
	return _find(base_path, AUDIO_EXTENSIONS) as AudioStream


## Uses res://assets/fonts/main.ttf (or .otf/.woff2/.woff) for all text if it exists.
static func apply_custom_font() -> void:
	var font := _find(ROOT + "fonts/main", FONT_EXTENSIONS) as Font
	if font == null:
		return
	var theme := ThemeDB.get_project_theme()
	if theme != null:
		theme.default_font = font
	else:
		ThemeDB.fallback_font = font


static func _find(base_path: String, extensions: Array) -> Resource:
	if base_path.is_empty():
		return null
	for ext: String in extensions:
		var path := "%s.%s" % [base_path, ext]
		if ResourceLoader.exists(path):
			return load(path)
	return null
