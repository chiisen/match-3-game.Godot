extends CanvasLayer
class_name UIController

@onready var score_label: Label = $MainUI/ScoreLabel
@onready var high_score_label: Label = $MainUI/HighScoreLabel
@onready var chain_label: Label = $MainUI/ChainLabel
@onready var timer_label: Label = $MainUI/TimerLabel
@onready var mode_button: Button = $MainUI/ModeButton
@onready var mute_button: Button = $MainUI/MuteButton
@onready var restart_button: Button = $MainUI/RestartButton
@onready var game_over_panel: Control = $MainUI/GameOverPanel
@onready var final_score_label: Label = $MainUI/GameOverPanel/FinalScoreLabel
@onready var new_high_score_label: Label = $MainUI/GameOverPanel/NewHighScoreLabel
@onready var video_stream_player : VideoStreamPlayer  = $MainUI/VideoPlayer
@onready var audio_manager: Node = AudioManager

signal mode_changed(mode: Constants.GameMode)
signal restart_requested()
signal mute_toggled()

var game_mode: Constants.GameMode = Constants.GameMode.CLASSIC

func _ready() -> void:
	game_over_panel.visible = false
	mode_button.pressed.connect(_on_mode_button_pressed)
	mute_button.pressed.connect(_on_mute_button_pressed)
	restart_button.pressed.connect(_on_restart_button_pressed)
	$MainUI/GameOverPanel/RestartButton.pressed.connect(_on_restart_button_pressed)
	$MainUI/GameOverPanel/PlayAgainButton.pressed.connect(_on_play_again_button_pressed)
	_update_mode_button()
	_update_mute_button()

func update_score(score: int) -> void:
	score_label.text = "分數: %d" % score

func update_high_score(high_score: int) -> void:
	high_score_label.text = "最高: %d" % high_score

func update_chain(chain: int) -> void:
	if chain > 1:
		chain_label.text = "連鎖 x%d" % chain
		chain_label.visible = true
	else:
		chain_label.visible = false

func update_timer(time_left: float) -> void:
	if game_mode == Constants.GameMode.TIMED:
		timer_label.visible = true
		timer_label.text = "時間: %.0f" % time_left
		if time_left <= 10:
			timer_label.modulate = Color(1.0, 0.3, 0.3)
		else:
			timer_label.modulate = Color.WHITE
	else:
		timer_label.visible = false

func show_game_over(score: int, high_score: int, is_new_high: bool) -> void:
	game_over_panel.visible = true
	final_score_label.text = "最終分數: %d" % score
	if is_new_high:
		new_high_score_label.visible = true
		new_high_score_label.text = "新紀錄!"
		_play_celebration_video()
	else:
		new_high_score_label.visible = false

func _play_celebration_video() -> void:
	video_stream_player.visible = true
	video_stream_player.play()

func stop_video() -> void:
	video_stream_player.stop()
	video_stream_player.visible = false

func hide_game_over() -> void:
	game_over_panel.visible = false
	stop_video()

func set_mode(mode: Constants.GameMode) -> void:
	game_mode = mode
	_update_mode_button()
	if mode == Constants.GameMode.TIMED:
		timer_label.visible = true
	else:
		timer_label.visible = false

func _update_mode_button() -> void:
	if game_mode == Constants.GameMode.CLASSIC:
		mode_button.text = "經典模式"
	else:
		mode_button.text = "計時模式"

func _update_mute_button() -> void:
	if audio_manager.is_muted:
		mute_button.text = "開啟音效"
	else:
		mute_button.text = "靜音"

func _on_mode_button_pressed() -> void:
	if game_mode == Constants.GameMode.CLASSIC:
		game_mode = Constants.GameMode.TIMED
	else:
		game_mode = Constants.GameMode.CLASSIC
	mode_changed.emit(game_mode)

func _on_mute_button_pressed() -> void:
	audio_manager.toggle_mute()
	_update_mute_button()
	mute_toggled.emit()

func _on_restart_button_pressed() -> void:
	hide_game_over()
	restart_requested.emit()

func _on_play_again_button_pressed() -> void:
	hide_game_over()
	restart_requested.emit()
