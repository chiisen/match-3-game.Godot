extends Node2D

var game_node: Node2D
var ui_controller: CanvasLayer

func _ready() -> void:
	_setup_game()
	_setup_ui()

func _setup_game() -> void:
	game_node = preload("res://scenes/game.tscn").instantiate()
	add_child(game_node)
	game_node.position = Vector2(0, 80)
	
	game_node.score_updated.connect(_on_score_updated)
	game_node.chain_updated.connect(_on_chain_updated)
	game_node.game_over.connect(_on_game_over)
	game_node.time_updated.connect(_on_time_updated)

func _setup_ui() -> void:
	ui_controller = preload("res://scenes/ui/main_ui.tscn").instantiate()
	add_child(ui_controller)
	
	ui_controller.mode_changed.connect(_on_mode_changed)
	ui_controller.restart_requested.connect(_on_restart_requested)
	
	ui_controller.update_high_score(game_node.get_high_score())

func _on_score_updated(score: int) -> void:
	ui_controller.update_score(score)

func _on_chain_updated(chain: int) -> void:
	ui_controller.update_chain(chain)

func _on_game_over(score: int, high_score: int) -> void:
	var is_new_high := score >= high_score and score > 0
	ui_controller.show_game_over(score, high_score, is_new_high)

func _on_time_updated(time_left: float) -> void:
	ui_controller.update_timer(time_left)

func _on_mode_changed(mode: Constants.GameMode) -> void:
	ui_controller.set_mode(mode)
	game_node.start_new_game(mode)

func _on_restart_requested() -> void:
	ui_controller.update_high_score(game_node.get_high_score())
	game_node.start_new_game(ui_controller.game_mode)
