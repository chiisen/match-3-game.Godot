extends Node

var is_muted: bool = false

var swap_player: AudioStreamPlayer
var match_player: AudioStreamPlayer
var invalid_player: AudioStreamPlayer
var game_over_player: AudioStreamPlayer
var background_music: AudioStreamPlayer

var has_audio_files: bool = false

func _ready() -> void:
	_check_audio_files()
	_setup_audio_players()
	if not has_audio_files:
		is_muted = true
	else:
		_load_settings()

func _check_audio_files() -> bool:
	has_audio_files = false
	return has_audio_files

func _setup_audio_players() -> void:
	swap_player = AudioStreamPlayer.new()
	swap_player.name = "SwapPlayer"
	add_child(swap_player)
	
	match_player = AudioStreamPlayer.new()
	match_player.name = "MatchPlayer"
	add_child(match_player)
	
	invalid_player = AudioStreamPlayer.new()
	invalid_player.name = "InvalidPlayer"
	add_child(invalid_player)
	
	game_over_player = AudioStreamPlayer.new()
	game_over_player.name = "GameOverPlayer"
	add_child(game_over_player)
	
	background_music = AudioStreamPlayer.new()
	background_music.name = "BackgroundMusic"
	background_music.volume_db = -10.0
	add_child(background_music)

func play_swap() -> void:
	if is_muted:
		return

func play_match() -> void:
	if is_muted:
		return

func play_invalid() -> void:
	if is_muted:
		return

func play_game_over() -> void:
	if is_muted:
		return

func toggle_mute() -> void:
	is_muted = not is_muted
	_save_settings()

func set_muted(muted: bool) -> void:
	is_muted = muted
	_save_settings()

func _load_settings() -> void:
	if FileAccess.file_exists("user://settings.dat"):
		var file: FileAccess = FileAccess.open("user://settings.dat", FileAccess.READ)
		if file:
			var json_string: String = file.get_line()
			var data: Dictionary = JSON.parse_string(json_string)
			file.close()
			if data != null:
				is_muted = data.get(Constants.MUTE_KEY, false)
			else:
				is_muted = false
		else:
			is_muted = false
	else:
		is_muted = false

func _save_settings() -> void:
	var file: FileAccess = FileAccess.open("user://settings.dat", FileAccess.WRITE)
	if file:
		var data: Dictionary = {
			Constants.MUTE_KEY: is_muted
		}
		file.store_line(JSON.stringify(data))
		file.close()
