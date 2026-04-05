extends Node2D
class_name Board

signal gem_clicked(gem: Gem)
signal gem_dragged(gem: Gem, direction: Vector2)
signal board_ready()

const GEM_SIZE := 64

var grid: Array = []
var gems: Array[Array] = []
var gem_scene: PackedScene

var board_offset: Vector2
var drag_start_pos: Vector2
var clicked_gem: Gem = null

func _ready() -> void:
	gem_scene = preload("res://scenes/gem.tscn")
	if not Logger.assert_not_null("Board._ready", gem_scene, "gem_scene"):
		Logger.fatal("Board._ready", "Critical: gem_scene failed to load")
		return
	Logger.info("Board", "Ready, gem_scene loaded")

func _open_log() -> void:
	pass

func _write_log(msg: String) -> void:
	Logger.debug("Board.input", msg)

func handle_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var mb := event as InputEventMouseButton
		
		# 座標轉換
		var viewport := get_viewport()
		if not Logger.assert_not_null("Board.handle_input", viewport, "viewport"):
			return
		var canvas_transform := viewport.get_canvas_transform()
		var canvas_pos: Vector2 = canvas_transform.affine_inverse() * mb.position
		
		Logger.debug("Board.input", "Mouse " + ("DOWN" if mb.pressed else "UP") + " viewport=" + str(mb.position) + " canvas=" + str(canvas_pos))
		
		if mb.pressed:
			clicked_gem = _get_gem_at_position(canvas_pos)
			if clicked_gem:
				drag_start_pos = canvas_pos
				Logger.game_event("gem_touched", {"grid": str(clicked_gem.grid_x) + "," + str(clicked_gem.grid_y), "type": clicked_gem.gem_type})
			else:
				Logger.debug("Board.input", "No gem found at position")
		else:
			if clicked_gem:
				var drag_vector: Vector2 = canvas_pos - drag_start_pos
				var drag_dist := drag_vector.length()
				
				if drag_dist > 20:
					var direction: Vector2 = Vector2.ZERO
					if abs(drag_vector.x) > abs(drag_vector.y):
						direction = Vector2(sign(drag_vector.x), 0)
					else:
						direction = Vector2(0, sign(drag_vector.y))
					Logger.game_event("gem_dragged", {"from": str(clicked_gem.grid_x) + "," + str(clicked_gem.grid_y), "direction": str(direction), "distance": drag_dist})
					gem_dragged.emit(clicked_gem, direction)
				else:
					Logger.game_event("gem_clicked", {"grid": str(clicked_gem.grid_x) + "," + str(clicked_gem.grid_y), "type": clicked_gem.gem_type})
					gem_clicked.emit(clicked_gem)
				clicked_gem = null
			else:
				Logger.debug("Board.input", "Mouse released but no gem was clicked")

func _get_gem_at_position(canvas_pos: Vector2) -> Gem:
	for y in range(Constants.BOARD_SIZE):
		for x in range(Constants.BOARD_SIZE):
			if y >= gems.size() or x >= gems[y].size():
				Logger.error("Board._get_gem_at_position", "Array bounds check failed x=" + str(x) + " y=" + str(y) + " gems_size=" + str(gems.size()))
				continue
			var gem: Gem = gems[y][x]
			if gem:
				var gem_pos := gem.global_position
				var gem_rect := Rect2(gem_pos, Vector2(GEM_SIZE, GEM_SIZE))
				if gem_rect.has_point(canvas_pos):
					Logger.debug("Board._get_gem_at_position", "MATCH grid=(" + str(x) + "," + str(y) + ") type=" + str(gem.gem_type) + " pos=" + str(gem_pos))
					return gem
	return null

func initialize(offset: Vector2) -> void:
	if not Logger.assert_not_null("Board.initialize", offset, "offset"):
		return
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
	Logger.info("Board.initialize", "Grid initialized: size=" + str(Constants.BOARD_SIZE) + " offset=" + str(offset))

func setup_initial_board() -> void:
	Logger.info("Board.setup_initial_board", "Start generating board")
	var attempts := 0
	var max_attempts := 10
	
	for y in range(Constants.BOARD_SIZE):
		for x in range(Constants.BOARD_SIZE):
			var gem_type := _get_random_gem_type(x, y)
			grid[y][x] = gem_type
			_create_gem(x, y, gem_type)

	var match_count := _find_matches().size()
	while match_count > 0 and attempts < max_attempts:
		attempts += 1
		Logger.warn("Board.setup_initial_board", "Initial matches found: " + str(match_count) + ", regenerating (attempt " + str(attempts) + ")")
		_clear_board()
		for y in range(Constants.BOARD_SIZE):
			for x in range(Constants.BOARD_SIZE):
				var gem_type := _get_random_gem_type(x, y)
				grid[y][x] = gem_type
				_create_gem(x, y, gem_type)
		match_count = _find_matches().size()
	
	if attempts >= max_attempts:
		Logger.error("Board.setup_initial_board", "Failed to generate valid board after " + str(max_attempts) + " attempts")
	
	Logger.info("Board.setup_initial_board", "Board ready: gems=" + str(Constants.BOARD_SIZE * Constants.BOARD_SIZE) + " valid_moves=" + str(has_valid_moves()))
	board_ready.emit()

func _get_random_gem_type(x: int, y: int) -> int:
	var type := randi() % Constants.GEM_TYPES + 1
	var attempts := 0
	while attempts < 50:
		type = randi() % Constants.GEM_TYPES + 1
		if not _would_create_match(x, y, type):
			break
		attempts += 1
	if attempts >= 50:
		Logger.warn("Board._get_random_gem_type", "Could not avoid match after 50 attempts at x=" + str(x) + " y=" + str(y))
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
	if not Logger.assert_not_null("Board._create_gem", gem_scene, "gem_scene"):
		return
	var gem: Gem = gem_scene.instantiate()
	add_child(gem)
	gem.setup(type, x, y)
	gem.set_position_from_grid(board_offset)
	gems[y][x] = gem
	Logger.debug("Board._create_gem", "Created gem: grid=(" + str(x) + "," + str(y) + ") type=" + str(type))

func get_gem_at(x: int, y: int) -> Gem:
	if not Logger.assert_in_range("Board.get_gem_at", x, 0, Constants.BOARD_SIZE - 1, "x"):
		return null
	if not Logger.assert_in_range("Board.get_gem_at", y, 0, Constants.BOARD_SIZE - 1, "y"):
		return null
	return gems[y][x]

func get_grid_position(gem: Gem) -> Vector2i:
	if not Logger.assert_not_null("Board.get_grid_position", gem, "gem"):
		return Vector2i(-1, -1)
	return Vector2i(gem.grid_x, gem.grid_y)

func swap_gems(gem1: Gem, gem2: Gem) -> void:
	if not Logger.assert_not_null("Board.swap_gems", gem1, "gem1"):
		return
	if not Logger.assert_not_null("Board.swap_gems", gem2, "gem2"):
		return
	
	var x1 := gem1.grid_x
	var y1 := gem1.grid_y
	var x2 := gem2.grid_x
	var y2 := gem2.grid_y
	
	Logger.game_event("swap_start", {"gem1": str(x1) + "," + str(y1) + "(type" + str(gem1.gem_type) + ")", "gem2": str(x2) + "," + str(y2) + "(type" + str(gem2.gem_type) + ")"})
	
	# 更新 grid 資料
	grid[y1][x1] = gem2.gem_type
	grid[y2][x2] = gem1.gem_type
	
	# 更新 gem 屬性
	gem1.gem_type = gem2.gem_type
	gem2.gem_type = grid[y1][x1]
	
	gem1.grid_x = x2
	gem1.grid_y = y2
	gem2.grid_x = x1
	gem2.grid_y = y1
	
	gems[y1][x1] = gem2
	gems[y2][x2] = gem1
	
	# 動畫
	var pos1 := Vector2(x2 * GEM_SIZE, y2 * GEM_SIZE) + board_offset
	var pos2 := Vector2(x1 * GEM_SIZE, y1 * GEM_SIZE) + board_offset
	
	await gem1.animate_swap(pos1, Constants.SWAP_DURATION)
	await gem2.animate_swap(pos2, Constants.SWAP_DURATION)
	
	Logger.game_event("swap_complete", {"gem1_new_pos": str(gem1.grid_x) + "," + str(gem1.grid_y), "gem2_new_pos": str(gem2.grid_x) + "," + str(gem2.grid_y)})

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
	
	if matched_gems.size() > 0:
		Logger.debug("Board._find_matches", "Found " + str(matched_gems.size()) + " gems in " + str(horizontal.size()) + " horizontal + " + str(vertical.size()) + " vertical matches")
	
	return matched_gems

func remove_matches(matches: Array) -> void:
	Logger.debug("Board.remove_matches", "Removing " + str(matches.size()) + " gems")
	for pos in matches:
		if not Logger.assert_in_range("Board.remove_matches", pos.x, 0, Constants.BOARD_SIZE - 1, "pos.x"):
			continue
		if not Logger.assert_in_range("Board.remove_matches", pos.y, 0, Constants.BOARD_SIZE - 1, "pos.y"):
			continue
		var gem := get_gem_at(pos.x, pos.y)
		if gem:
			gem.is_matched = true
			grid[pos.y][pos.x] = 0
		else:
			Logger.warn("Board.remove_matches", "Gem not found at " + str(pos))

func animate_removal(matches: Array) -> void:
	Logger.game_event("removal_start", {"count": matches.size()})
	for pos in matches:
		var gem := get_gem_at(pos.x, pos.y)
		if gem:
			await gem.animate_remove(Constants.REMOVE_DURATION)
			gem.queue_free()
			gems[pos.y][pos.x] = null
	Logger.game_event("removal_complete", {"count": matches.size()})

func drop_gems() -> Dictionary:
	var drops: Dictionary = {}
	var total_dropped := 0
	var total_new := 0

	for x in range(Constants.BOARD_SIZE):
		var empty_spaces := 0
		for y in range(Constants.BOARD_SIZE - 1, -1, -1):
			if grid[y][x] == 0:
				empty_spaces += 1
			elif empty_spaces > 0:
				var gem: Gem = gems[y][x]
				if not gem:
					Logger.error("Board.drop_gems", "Gem is null but grid has type at x=" + str(x) + " y=" + str(y))
					continue
				var new_y := y + empty_spaces
				grid[new_y][x] = grid[y][x]
				grid[y][x] = 0
				gems[new_y][x] = gem
				gems[y][x] = null
				gem.grid_y = new_y
				# 保留當前視覺位置作為動畫起點，記錄目標 Y
				drops[gem] = new_y * GEM_SIZE + board_offset.y
				total_dropped += 1

		for i in range(empty_spaces):
			var new_type := randi() % Constants.GEM_TYPES + 1
			var new_y := empty_spaces - 1 - i
			grid[new_y][x] = new_type
			_create_gem(x, new_y, new_type)
			var gem: Gem = gems[new_y][x]
			# 新寶石從畫面外上方開始
			var start_y := board_offset.y - GEM_SIZE * (i + 1)
			gem.position = Vector2(x * GEM_SIZE + board_offset.x, start_y)
			# 記錄目標 Y
			drops[gem] = new_y * GEM_SIZE + board_offset.y
			total_new += 1

	Logger.game_event("gems_dropped", {"existing_dropped": total_dropped, "new_spawned": total_new})
	return drops

func animate_falling(drops: Dictionary) -> void:
	Logger.game_event("falling_start", {"count": drops.size()})
	for gem in drops:
		if not Logger.assert_not_null("Board.animate_falling", gem, "gem"):
			continue
		var target_y: float = drops[gem]
		Logger.debug("Board.animate_falling", "Gem grid=(" + str(gem.grid_x) + "," + str(gem.grid_y) + ") falling to y=" + str(target_y))
		await gem.animate_fall(target_y, Constants.FALL_DURATION)
	Logger.game_event("falling_complete")

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
	Logger.debug("Board._clear_board", "Clearing board")
	for y in range(Constants.BOARD_SIZE):
		for x in range(Constants.BOARD_SIZE):
			var gem := get_gem_at(x, y)
			if gem:
				gem.queue_free()
			grid[y][x] = 0
			gems[y][x] = null
