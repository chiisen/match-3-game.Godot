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
	board.gem_clicked.connect(_on_gem_clicked)
	board.board_ready.connect(_on_board_ready)
	board.gem_dragged.connect(_on_gem_dragged)

	timer_node = Timer.new()
	add_child(timer_node)
	timer_node.wait_time = 1.0
	timer_node.timeout.connect(_on_timer_tick)

	start_new_game(Constants.GameMode.CLASSIC)

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		board.handle_input(event)

func start_new_game(mode: Constants.GameMode) -> void:
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
	else:
		is_timer_running = false
	
	score_updated.emit(score)
	chain_updated.emit(chain_count)
	state_changed.emit(current_state)
	
	var board_offset := Vector2((640 - Constants.BOARD_SIZE * 64) / 2, (480 - Constants.BOARD_SIZE * 64) / 2)
	board.initialize(board_offset)
	board.setup_initial_board()

func _process(delta: float) -> void:
	if current_state == Constants.GameState.IDLE:
		hint_timer += delta
		if hint_timer >= Constants.HINT_DELAY:
			_show_hint()

func _on_board_ready() -> void:
	current_state = Constants.GameState.IDLE
	state_changed.emit(current_state)
	if not board.has_valid_moves():
		_restart_game()

func _on_gem_clicked(gem: Gem) -> void:
	board._write_log("GAME: gem_clicked, state=" + str(current_state) + " selected_gem=" + str(selected_gem))

	# 點擊已選取的寶石 → 取消選取
	if selected_gem == gem:
		selected_gem.set_selected(false)
		selected_gem = null
		current_state = Constants.GameState.IDLE
		state_changed.emit(current_state)
		board._write_log("GAME: Deselected gem, state=IDLE")
		return

	# 如果還沒選取寶石 → 選取
	if selected_gem == null:
		selected_gem = gem
		gem.set_selected(true)
		current_state = Constants.GameState.SELECTED
		state_changed.emit(current_state)
		hint_timer = 0.0
		board.clear_hints()
		board._write_log("GAME: Selected gem at grid(" + str(gem.grid_x) + "," + str(gem.grid_y) + ")")
		return

	# 已經有選取寶石時：
	if _is_adjacent(selected_gem, gem):
		# 相鄰 → 交換
		board._write_log("GAME: Adjacent gem detected, attempting swap")
		_attempt_swap(selected_gem, gem)
	else:
		# 不相鄰 → 切換選取目標
		selected_gem.set_selected(false)
		selected_gem = gem
		gem.set_selected(true)
		board._write_log("GAME: Switched selection to grid(" + str(gem.grid_x) + "," + str(gem.grid_y) + ")")

func _on_gem_dragged(gem: Gem, direction: Vector2) -> void:
	if current_state != Constants.GameState.IDLE:
		return
	
	var target_x: int = gem.grid_x + int(direction.x)
	var target_y: int = gem.grid_y + int(direction.y)
	var target_gem: Gem = board.get_gem_at(target_x, target_y)
	
	if target_gem != null:
		selected_gem = gem
		_attempt_swap(gem, target_gem)
	else:
		gem.set_selected(true)
		selected_gem = gem
		current_state = Constants.GameState.SELECTED
		state_changed.emit(current_state)
		hint_timer = 0.0
		board.clear_hints()

func _is_adjacent(gem1: Gem, gem2: Gem) -> bool:
	var dx := absi(gem1.grid_x - gem2.grid_x)
	var dy := absi(gem1.grid_y - gem2.grid_y)
	return (dx == 1 and dy == 0) or (dx == 0 and dy == 1)

func _attempt_swap(gem1: Gem, gem2: Gem) -> void:
	current_state = Constants.GameState.SWAPPING
	state_changed.emit(current_state)
	selected_gem.set_selected(false)
	selected_gem = null
	
	AudioManager.play_swap()
	await board.swap_gems(gem1, gem2)
	
	var matches := board.find_matches()
	if matches.size() > 0:
		chain_count = 0
		await _process_matches(matches)
	else:
		AudioManager.play_invalid()
		await board.swap_gems(gem1, gem2)
		current_state = Constants.GameState.IDLE
		state_changed.emit(current_state)

func _process_matches(matches: Array) -> void:
	current_state = Constants.GameState.REMOVING
	state_changed.emit(current_state)
	
	chain_count += 1
	chain_updated.emit(chain_count)
	
	var match_score := _calculate_score(matches.size())
	score += int(match_score * pow(Constants.CHAIN_MULTIPLIER, chain_count - 1))
	score_updated.emit(score)
	
	AudioManager.play_match()
	board.clear_hints()
	await board.animate_removal(matches)
	
	current_state = Constants.GameState.FALLING
	state_changed.emit(current_state)
	
	var drops := board.drop_gems()
	await board.animate_falling(drops)
	
	matches = board.find_matches()
	if matches.size() > 0:
		await _process_matches(matches)
	else:
		if not board.has_valid_moves():
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
	var hint_positions := board.find_hint()
	if hint_positions.size() >= 2:
		var gem1 := board.get_gem_at(hint_positions[0].x, hint_positions[0].y)
		var gem2 := board.get_gem_at(hint_positions[1].x, hint_positions[1].y)
		if gem1:
			gem1.set_hint(true)
		if gem2:
			gem2.set_hint(true)

func _end_game() -> void:
	current_state = Constants.GameState.GAME_OVER
	state_changed.emit(current_state)
	timer_node.stop()
	is_timer_running = false
	
	var high_score := _get_high_score()
	if score > high_score:
		high_score = score
		_save_high_score(high_score)
	
	AudioManager.play_game_over()
	game_over.emit(score, high_score)

func _restart_game() -> void:
	start_new_game(game_mode)

func _on_timer_tick() -> void:
	if game_mode == Constants.GameMode.TIMED:
		time_left -= 1.0
		time_updated.emit(time_left)
		if time_left <= 0:
			time_left = 0
			_end_game()

func _get_high_score() -> int:
	if FileAccess.file_exists("user://settings.dat"):
		var file: FileAccess = FileAccess.open("user://settings.dat", FileAccess.READ)
		if file:
			var data: Dictionary = JSON.parse_string(file.get_line())
			file.close()
			return data.get(Constants.HIGH_SCORE_KEY, 0)
	return 0

func _save_high_score(high_score: int) -> void:
	var file: FileAccess = FileAccess.open("user://settings.dat", FileAccess.WRITE)
	if file:
		var data: Dictionary = {Constants.HIGH_SCORE_KEY: high_score}
		file.store_line(JSON.stringify(data))
		file.close()

func get_high_score() -> int:
	return _get_high_score()

func toggle_pause() -> void:
	if is_timer_running:
		timer_node.stop()
		is_timer_running = false
	else:
		if game_mode == Constants.GameMode.TIMED and current_state != Constants.GameState.GAME_OVER:
			timer_node.start()
			is_timer_running = true
