extends Node2D
class_name Game

signal score_updated(score: int)
signal chain_updated(chain: int)
signal game_over(score: int, high_score: int)
signal state_changed(state: Constants.GameState)
signal time_updated(time_left: float)

var board: Board
var current_state: Constants.GameState = Constants.GameState.IDLE
var game_mode: Constants.GameMode = Constants.GameMode.CLASSIC
var selected_gem: Gem = null
var score: int = 0
var chain_count: int = 0
var time_left: float = 0.0
var hint_timer: float = 0.0
var is_timer_running: bool = false

var timer_node: Timer

func _ready() -> void:
	board = $Board
	if not Logger.assert_not_null("Game._ready", board, "board"):
		Logger.fatal("Game._ready", "Critical: board node not found")
		return
	
	board.gem_clicked.connect(_on_gem_clicked)
	board.board_ready.connect(_on_board_ready)
	board.gem_dragged.connect(_on_gem_dragged)
	
	Logger.info("Game", "Ready, board connected")
	
	timer_node = Timer.new()
	add_child(timer_node)
	timer_node.wait_time = 1.0
	timer_node.timeout.connect(_on_timer_tick)
	
	Logger.info("Game", "Starting new game in CLASSIC mode")
	start_new_game(Constants.GameMode.CLASSIC)

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if not Logger.assert_not_null("Game._input", board, "board"):
			return
		board.handle_input(event)

func start_new_game(mode: Constants.GameMode) -> void:
	Logger.game_event("game_start", {"mode": "CLASSIC" if mode == Constants.GameMode.CLASSIC else "TIMED"})
	
	game_mode = mode
	score = 0
	chain_count = 0
	hint_timer = 0.0
	selected_gem = null
	current_state = Constants.GameState.IDLE
	
	if game_mode == Constants.GameMode.TIMED:
		time_left = Constants.TIMED_MODE_DURATION
		is_timer_running = true
		timer_node.start()
		Logger.info("Game.start_new_game", "Timed mode: " + str(time_left) + " seconds")
	else:
		is_timer_running = false
		Logger.info("Game.start_new_game", "Classic mode")
	
	score_updated.emit(score)
	chain_updated.emit(chain_count)
	state_changed.emit(current_state)
	
	var board_offset := Vector2((640 - Constants.BOARD_SIZE * 64) / 2, (480 - Constants.BOARD_SIZE * 64) / 2)
	board.initialize(board_offset)
	board.setup_initial_board()
	
	Logger.game_event("board_initialized", {"offset": str(board_offset)})

func _process(delta: float) -> void:
	if current_state == Constants.GameState.IDLE:
		hint_timer += delta
		if hint_timer >= Constants.HINT_DELAY:
			_show_hint()

func _on_board_ready() -> void:
	Logger.info("Game._on_board_ready", "Board ready, checking valid moves")
	current_state = Constants.GameState.IDLE
	state_changed.emit(current_state)
	if not board.has_valid_moves():
		Logger.warn("Game._on_board_ready", "No valid moves, restarting")
		_restart_game()

func _on_gem_clicked(gem: Gem) -> void:
	if not Logger.assert_not_null("Game._on_gem_clicked", gem, "gem"):
		return
	
	Logger.game_event("input_gem_clicked", {"grid": str(gem.grid_x) + "," + str(gem.grid_y), "type": gem.gem_type, "state": str(current_state)})
	
	# 點擊已選取的寶石 → 取消選取
	if selected_gem == gem:
		selected_gem.set_selected(false)
		selected_gem = null
		current_state = Constants.GameState.IDLE
		state_changed.emit(current_state)
		Logger.game_event("gem_deselected_same", {"grid": str(gem.grid_x) + "," + str(gem.grid_y)})
		return
	
	# 如果還沒選取寶石 → 選取
	if selected_gem == null:
		selected_gem = gem
		gem.set_selected(true)
		current_state = Constants.GameState.SELECTED
		state_changed.emit(current_state)
		hint_timer = 0.0
		board.clear_hints()
		Logger.game_event("gem_selected_first", {"grid": str(gem.grid_x) + "," + str(gem.grid_y), "type": gem.gem_type})
		return
	
	# 已經有選取寶石時：
	if _is_adjacent(selected_gem, gem):
		# 相鄰 → 交換
		Logger.game_event("adjacent_gem_detected", {"selected": str(selected_gem.grid_x) + "," + str(selected_gem.grid_y), "clicked": str(gem.grid_x) + "," + str(gem.grid_y)})
		_attempt_swap(selected_gem, gem)
	else:
		# 不相鄰 → 切換選取目標
		Logger.game_event("non_adjacent_switch", {"from": str(selected_gem.grid_x) + "," + str(selected_gem.grid_y), "to": str(gem.grid_x) + "," + str(gem.grid_y)})
		selected_gem.set_selected(false)
		selected_gem = gem
		gem.set_selected(true)

func _on_gem_dragged(gem: Gem, direction: Vector2) -> void:
	if not Logger.assert_not_null("Game._on_gem_dragged", gem, "gem"):
		return
	
	if not Logger.assert_state("Game._on_gem_dragged", current_state, [Constants.GameState.IDLE], "drag operation"):
		return
	
	Logger.game_event("input_gem_dragged", {"grid": str(gem.grid_x) + "," + str(gem.grid_y), "direction": str(direction)})
	
	var target_x: int = gem.grid_x + int(direction.x)
	var target_y: int = gem.grid_y + int(direction.y)
	var target_gem: Gem = board.get_gem_at(target_x, target_y)
	
	if target_gem:
		Logger.game_event("drag_target_found", {"target": str(target_x) + "," + str(target_y), "type": target_gem.gem_type})
		selected_gem = gem
		_attempt_swap(gem, target_gem)
	else:
		Logger.warn("Game._on_gem_dragged", "No gem at drag target x=" + str(target_x) + " y=" + str(target_y))
		gem.set_selected(true)
		selected_gem = gem
		current_state = Constants.GameState.SELECTED
		state_changed.emit(current_state)
		hint_timer = 0.0
		board.clear_hints()

func _is_adjacent(gem1: Gem, gem2: Gem) -> bool:
	if not Logger.assert_not_null("Game._is_adjacent", gem1, "gem1"):
		return false
	if not Logger.assert_not_null("Game._is_adjacent", gem2, "gem2"):
		return false
	
	var dx := absi(gem1.grid_x - gem2.grid_x)
	var dy := absi(gem1.grid_y - gem2.grid_y)
	return (dx == 1 and dy == 0) or (dx == 0 and dy == 1)

func _attempt_swap(gem1: Gem, gem2: Gem) -> void:
	if not Logger.assert_not_null("Game._attempt_swap", gem1, "gem1"):
		return
	if not Logger.assert_not_null("Game._attempt_swap", gem2, "gem2"):
		return
	
	Logger.game_event("swap_attempt", {"gem1": str(gem1.grid_x) + "," + str(gem1.grid_y) + "(type" + str(gem1.gem_type) + ")", "gem2": str(gem2.grid_x) + "," + str(gem2.grid_y) + "(type" + str(gem2.gem_type) + ")"})
	
	current_state = Constants.GameState.SWAPPING
	state_changed.emit(current_state)
	selected_gem.set_selected(false)
	selected_gem = null
	
	AudioManager.play_swap()
	await board.swap_gems(gem1, gem2)
	
	var matches := board.find_matches()
	if matches.size() > 0:
		Logger.game_event("swap_success", {"matches": matches.size()})
		chain_count = 0
		await _process_matches(matches)
	else:
		Logger.game_event("swap_invalid", {"reason": "no matches"})
		AudioManager.play_invalid()
		await board.swap_gems(gem1, gem2)
		current_state = Constants.GameState.IDLE
		state_changed.emit(current_state)

func _process_matches(matches: Array) -> void:
	if not Logger.assert_state("Game._process_matches", current_state, [Constants.GameState.SWAPPING, Constants.GameState.IDLE], "match processing"):
		return
	
	Logger.game_event("match_process_start", {"count": matches.size(), "chain": chain_count})
	current_state = Constants.GameState.REMOVING
	state_changed.emit(current_state)

	chain_count += 1
	chain_updated.emit(chain_count)

	var match_score := _calculate_score(matches.size())
	var chain_bonus := int(match_score * pow(Constants.CHAIN_MULTIPLIER, chain_count - 1))
	score += chain_bonus
	score_updated.emit(score)
	
	Logger.game_event("match_scored", {"base": match_score, "chain": chain_count, "bonus": chain_bonus, "total_score": score})

	AudioManager.play_match()
	board.clear_hints()
	
	# 標記 grid 為空，供 drop_gems 計算掉落
	board.remove_matches(matches)
	# 執行消除動畫並釋放節點
	await board.animate_removal(matches)
	
	Logger.game_event("removal_complete", {"count": matches.size()})

	current_state = Constants.GameState.FALLING
	state_changed.emit(current_state)

	var drops := board.drop_gems()
	await board.animate_falling(drops)

	matches = board.find_matches()
	if matches.size() > 0:
		Logger.game_event("chain_continues", {"new_matches": matches.size()})
		await _process_matches(matches)
	else:
		Logger.game_event("chain_ended")
		if not board.has_valid_moves():
			Logger.warn("Game._process_matches", "No valid moves remaining")
			if game_mode == Constants.GameMode.CLASSIC:
				_end_game()
			else:
				if time_left <= 0:
					_end_game()
				else:
					current_state = Constants.GameState.IDLE
					state_changed.emit(current_state)
		else:
			current_state = Constants.GameState.IDLE
			state_changed.emit(current_state)
			hint_timer = 0.0

func _calculate_score(match_count: int) -> int:
	if match_count >= 5:
		return Constants.SCORE_5_MATCH
	elif match_count == 4:
		return Constants.SCORE_4_MATCH
	else:
		return Constants.SCORE_3_MATCH

func _show_hint() -> void:
	Logger.debug("Game._show_hint", "Showing hint")
	var hint_positions := board.find_hint()
	if hint_positions.size() >= 2:
		var gem1 := board.get_gem_at(hint_positions[0].x, hint_positions[0].y)
		var gem2 := board.get_gem_at(hint_positions[1].x, hint_positions[1].y)
		if gem1:
			gem1.set_hint(true)
		if gem2:
			gem2.set_hint(true)
		Logger.debug("Game._show_hint", "Hint shown at " + str(hint_positions[0]) + " and " + str(hint_positions[1]))
	else:
		Logger.warn("Game._show_hint", "No hint found")

func _end_game() -> void:
	Logger.game_event("game_over_start", {"score": score, "mode": "CLASSIC" if game_mode == Constants.GameMode.CLASSIC else "TIMED"})
	current_state = Constants.GameState.GAME_OVER
	state_changed.emit(current_state)
	timer_node.stop()
	is_timer_running = false

	var high_score := _get_high_score()
	var is_new_high := score > high_score
	if is_new_high:
		high_score = score
		_save_high_score(high_score)
		Logger.game_event("new_high_score", {"score": high_score})

	AudioManager.play_game_over()
	game_over.emit(score, high_score)

func _restart_game() -> void:
	Logger.info("Game._restart_game", "Restarting game")
	start_new_game(game_mode)

func _on_timer_tick() -> void:
	if game_mode == Constants.GameMode.TIMED:
		time_left -= 1.0
		time_updated.emit(time_left)
		if time_left <= 0:
			time_left = 0
			Logger.warn("Game._on_timer_tick", "Time expired")
			_end_game()

func _get_high_score() -> int:
	if FileAccess.file_exists("user://settings.dat"):
		var file: FileAccess = FileAccess.open("user://settings.dat", FileAccess.READ)
		if file:
			var data: Dictionary = JSON.parse_string(file.get_line())
			file.close()
			if data != null:
				return data.get(Constants.HIGH_SCORE_KEY, 0)
			else:
				Logger.warn("Game._get_high_score", "Invalid settings data")
	return 0

func _save_high_score(high_score: int) -> void:
	var file: FileAccess = FileAccess.open("user://settings.dat", FileAccess.WRITE)
	if file:
		var data: Dictionary = {Constants.HIGH_SCORE_KEY: high_score}
		file.store_line(JSON.stringify(data))
		file.close()
		Logger.debug("Game._save_high_score", "High score saved: " + str(high_score))
	else:
		Logger.error("Game._save_high_score", "Failed to open settings file")

func get_high_score() -> int:
	return _get_high_score()

func toggle_pause() -> void:
	if is_timer_running:
		timer_node.stop()
		is_timer_running = false
		Logger.info("Game.toggle_pause", "Paused")
	else:
		if game_mode == Constants.GameMode.TIMED and current_state != Constants.GameState.GAME_OVER:
			timer_node.start()
			is_timer_running = true
			Logger.info("Game.toggle_pause", "Resumed")
