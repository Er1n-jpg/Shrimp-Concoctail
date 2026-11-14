extends Node
## Plays drop-in sounds from res://assets/sfx/<name>.ogg (or .wav/.mp3)
## and loops res://assets/music/theme.ogg if it exists. Missing files are skipped silently.

const VOICES := 8
const MUSIC_VOLUME_DB := -8.0

var _players: Array[AudioStreamPlayer] = []
var _cache: Dictionary = {}
var _music: AudioStreamPlayer


func _ready() -> void:
	for i in VOICES:
		var player := AudioStreamPlayer.new()
		add_child(player)
		_players.append(player)

	_music = AudioStreamPlayer.new()
	_music.volume_db = MUSIC_VOLUME_DB
	add_child(_music)
	var theme := Art.load_audio(Art.music("theme"))
	if theme != null:
		_music.stream = theme
		_music.finished.connect(_music.play)
		_music.play()


func play(sound_name: String, pitch_variation: float = 0.08) -> void:
	if not _cache.has(sound_name):
		_cache[sound_name] = Art.load_audio(Art.sfx(sound_name))
	var stream: AudioStream = _cache[sound_name]
	if stream == null:
		return
	for player in _players:
		if not player.playing:
			player.stream = stream
			player.pitch_scale = randf_range(1.0 - pitch_variation, 1.0 + pitch_variation)
			player.play()
			return
