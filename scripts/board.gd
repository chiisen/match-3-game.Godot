extends Node2D
class_name Board

signal gem_clicked(gem: Gem)
signal gem_dragged(gem: Gem, direction: Vector2)
signal swap_requested(gem1: Gem, gem2: Gem)
signal board_ready()
signal no_moves_available()

const GEM_SIZE := 64

var grid: Array = []
var gems: Array[Array] = []
var gem_scene: PackedScene

var board_offset: Vector2
var drag_start_pos: Vector2
var clicked_gem: Gem = null
var log_file: FileAccess = null

func _open_log() -> void:
	log_file = FileAccess.open("user://input_test.log", FileAccess.WRITE)
	if log_file:
		log_file.store_line("=== Input Test Log ===")

func _write_log(msg: String) -> void:
	if log_file:
		log_file.store_line(msg)
		log_file.flush()

# 共用 log 供 game.gd 使用
func get_log_file() -> FileAccess:
	return log_file

func _ready() -> void:
	gem_scene = preload("res://scenes/gem.tscn")
	_open_log()
	_write_log("Board ready, input handling initialized")

func handle_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var mb := event as InputEventMouseButton
		# 使用 get_global_mouse_position 取得畫布座標（不受 viewport stretch 影響）
		var canvas_pos: Vector2 = get_global_mouse_position()
		_write_log("Mouse at canvas=" + str(canvas_pos))
		
		if mb.pressed:
			clicked_gem = _get_gem_at_position(canvas_pos)
			_write_log("Found gem: " + ("yes" if clicked_gem else "none"))
			if clicked_gem:
				drag_start_pos = canvas_pos
				_write_log("Gem selected at grid(" + str(clicked_gem.grid_x) + "," + str(clicked_gem.grid_y) + ")")
		else:
			if clicked_gem:
				var drag_vector: Vector2 = canvas_pos - drag_start_pos
				_write_log("Mouse released, drag_vector=" + str(drag_vector))
				if drag_vector.length() > 20:
					var direction: Vector2 = Vector2.ZERO
					if abs(drag_vector.x) > abs(drag_vector.y):
						direction = Vector2(sign(drag_vector.x), 0)
					else:
						direction = Vector2(0, sign(drag_vector.y))
					_write_log("Emitting gem_dragged direction=" + str(direction))
					gem_dragged.emit(clicked_gem, direction)
				else:
					_write_log("Emitting gem_clicked")
					gem_clicked.emit(clicked_gem)
				clicked_gem = null

func _get_gem_at_position(canvas_pos: Vector2) -> Gem:
	for y in range(Constants.BOARD_SIZE):
		for x in range(Constants.BOARD_SIZE):
			var gem: Gem = gems[y][x]
			if gem:
				var gem_pos := gem.global_position
				var gem_rect := Rect2(gem_pos, Vector2(GEM_SIZE, GEM_SIZE))
				if gem_rect.has_point(canvas_pos):
					_write_log("  MATCH! Gem at (" + str(x) + "," + str(y) + ") pos=" + str(gem_pos))
					return gem
	return null

func initialize(offset: Vector2) -> void:
	board_offset = offset
	grid.clear()
	gems.clear()
	for y in range(Constants.BOARD_SIZE):
		var row: Array = []
		var gem_row: Array = []
		for x in range(Constants.BOARD_SIZE):
			row.append(0)
			gem_row.append(null)
		grid.append(row)
		gems.append(gem_row)

func setup_initial_board() -> void:
	for y in range(Constants.BOARD_SIZE):
		for x in range(Constants.BOARD_SIZE):
			var gem_type := _get_random_gem_type(x, y)
			grid[y][x] = gem_type
			_create_gem(x, y, gem_type)
	
	while _find_matches().size() > 0:
		_clear_board()
		for y in range(Constants.BOARD_SIZE):
			for x in range(Constants.BOARD_SIZE):
				var gem_type := _get_random_gem_type(x, y)
				grid[y][x] = gem_type
				_create_gem(x, y, gem_type)
	
	board_ready.emit()

func _get_random_gem_type(x: int, y: int) -> int:
	var type := randi() % Constants.GEM_TYPES + 1
	var attempts := 0
	while attempts < 50:
		type = randi() % Constants.GEM_TYPES + 1
		if not _would_create_match(x, y, type):
			break
		attempts += 1
	return type

func _would_create_match(x: int, y: int, type: int) -> bool:
	if x >= 2:
		if grid[y][x-1] == type and grid[y][x-2] == type:
			return true
	if y >= 2:
		if grid[y-1][x] == type and grid[y-2][x] == type:
			return true
	return false

func _create_gem(x: int, y: int, type: int) -> void:
	var gem: Gem = gem_scene.instantiate()
	add_child(gem)
	gem.setup(type, x, y)
	gem.set_position_from_grid(board_offset)
	gems[y][x] = gem

func get_gem_at(x: int, y: int) -> Gem:
	if x < 0 or x >= Constants.BOARD_SIZE or y < 0 or y >= Constants.BOARD_SIZE:
		return null
	return gems[y][x]

func get_grid_position(gem: Gem) -> Vector2i:
	return Vector2i(gem.grid_x, gem.grid_y)

func swap_gems(gem1: Gem, gem2: Gem) -> void:
	var x1 := gem1.grid_x
	var y1 := gem1.grid_y
	var x2 := gem2.grid_x
	var y2 := gem2.grid_y
	
	grid[y1][x1] = gem2.gem_type
	grid[y2][x2] = gem1.gem_type
	
	gem1.gem_type = gem2.gem_type
	gem2.gem_type = grid[y1][x1]
	
	gem1.grid_x = x2
	gem1.grid_y = y2
	gem2.grid_x = x1
	gem2.grid_y = y1
	
	gems[y1][x1] = gem2
	gems[y2][x2] = gem1
	
	var pos1 := Vector2(x2 * GEM_SIZE, y2 * GEM_SIZE) + board_offset
	var pos2 := Vector2(x1 * GEM_SIZE, y1 * GEM_SIZE) + board_offset
	
	await gem1.animate_swap(pos1, Constants.SWAP_DURATION)
	await gem2.animate_swap(pos2, Constants.SWAP_DURATION)

func revert_swap(gem1: Gem, gem2: Gem) -> void:
	swap_gems(gem1, gem2)

func find_matches() -> Array:
	return _find_matches()

func _find_matches() -> Array:
	var matched_gems: Array = []
	var horizontal: Array = []
	var vertical: Array = []
	
	for y in range(Constants.BOARD_SIZE):
		var match_count := 1
		for x in range(1, Constants.BOARD_SIZE):
			if grid[y][x] == grid[y][x-1] and grid[y][x] != 0:
				match_count += 1
			else:
				if match_count >= 3:
					for i in range(match_count):
						horizontal.append(Vector2i(x - 1 - i, y))
				match_count = 1
		if match_count >= 3:
			for i in range(match_count):
				horizontal.append(Vector2i(Constants.BOARD_SIZE - 1 - i, y))
	
	for x in range(Constants.BOARD_SIZE):
		var match_count := 1
		for y in range(1, Constants.BOARD_SIZE):
			if grid[y][x] == grid[y-1][x] and grid[y][x] != 0:
				match_count += 1
			else:
				if match_count >= 3:
					for i in range(match_count):
						vertical.append(Vector2i(x, y - 1 - i))
				match_count = 1
		if match_count >= 3:
			for i in range(match_count):
				vertical.append(Vector2i(x, Constants.BOARD_SIZE - 1 - i))
	
	var all_matches := {} as Dictionary
	for pos in horizontal:
		all_matches[pos] = true
	for pos in vertical:
		all_matches[pos] = true
	
	matched_gems = all_matches.keys()
	return matched_gems

func remove_matches(matches: Array) -> void:
	for pos in matches:
		var gem := get_gem_at(pos.x, pos.y)
		if gem:
			gem.is_matched = true
			grid[pos.y][pos.x] = 0

func animate_removal(matches: Array) -> void:
	for pos in matches:
		var gem := get_gem_at(pos.x, pos.y)
		if gem:
			await gem.animate_remove(Constants.REMOVE_DURATION)
			gem.queue_free()
			gems[pos.y][pos.x] = null

func drop_gems() -> Dictionary:
	var drops: Dictionary = {}
	
	for x in range(Constants.BOARD_SIZE):
		var empty_spaces := 0
		for y in range(Constants.BOARD_SIZE - 1, -1, -1):
			if grid[y][x] == 0:
				empty_spaces += 1
			elif empty_spaces > 0:
				var gem := gems[y][x] as Gem
				var new_y := y + empty_spaces
				grid[new_y][x] = grid[y][x]
				grid[y][x] = 0
				gems[new_y][x] = gem
				gems[y][x] = null
				gem.grid_y = new_y
				drops[gem] = empty_spaces
		
		for i in range(empty_spaces):
			var new_type := randi() % Constants.GEM_TYPES + 1
			var new_y := empty_spaces - 1 - i
			grid[new_y][x] = new_type
			_create_gem(x, new_y, new_type)
			var gem := gems[new_y][x] as Gem
			var start_y := -GEM_SIZE * (i + 1)
			gem.position = Vector2(x * GEM_SIZE, start_y) + board_offset
			drops[gem] = new_y * GEM_SIZE
	
	return drops

func animate_falling(drops: Dictionary) -> void:
	for gem in drops:
		var distance: int = drops[gem]
		var target_y: float = gem.grid_y * GEM_SIZE
		await gem.animate_fall(target_y, Constants.FALL_DURATION)

func has_valid_moves() -> bool:
	for y in range(Constants.BOARD_SIZE):
		for x in range(Constants.BOARD_SIZE):
			if x < Constants.BOARD_SIZE - 1:
				_grid_swap(x, y, x + 1, y)
				if _find_matches().size() > 0:
					_grid_swap(x, y, x + 1, y)
					return true
				_grid_swap(x, y, x + 1, y)
			if y < Constants.BOARD_SIZE - 1:
				_grid_swap(x, y, x, y + 1)
				if _find_matches().size() > 0:
					_grid_swap(x, y, x, y + 1)
					return true
				_grid_swap(x, y, x, y + 1)
	return false

func _grid_swap(x1: int, y1: int, x2: int, y2: int) -> void:
	var temp: int = grid[y1][x1]
	grid[y1][x1] = grid[y2][x2]
	grid[y2][x2] = temp

func find_hint() -> Array:
	for y in range(Constants.BOARD_SIZE):
		for x in range(Constants.BOARD_SIZE):
			if x < Constants.BOARD_SIZE - 1:
				_grid_swap(x, y, x + 1, y)
				var matches := _find_matches()
				_grid_swap(x, y, x + 1, y)
				if matches.size() > 0:
					return [Vector2i(x, y), Vector2i(x + 1, y)]
			if y < Constants.BOARD_SIZE - 1:
				_grid_swap(x, y, x, y + 1)
				var matches := _find_matches()
				_grid_swap(x, y, x, y + 1)
				if matches.size() > 0:
					return [Vector2i(x, y), Vector2i(x, y + 1)]
	return []

func clear_hints() -> void:
	for y in range(Constants.BOARD_SIZE):
		for x in range(Constants.BOARD_SIZE):
			var gem := get_gem_at(x, y)
			if gem:
				gem.set_hint(false)

func _clear_board() -> void:
	for y in range(Constants.BOARD_SIZE):
		for x in range(Constants.BOARD_SIZE):
			var gem := get_gem_at(x, y)
			if gem:
				gem.queue_free()
			grid[y][x] = 0
			gems[y][x] = null
