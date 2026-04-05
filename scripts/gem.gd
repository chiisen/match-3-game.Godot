extends Area2D
class_name Gem

signal clicked(gem: Gem)
signal dragged(gem: Gem, direction: Vector2)

var gem_type: int = 0
var grid_x: int = 0
var grid_y: int = 0
var is_selected: bool = false
var is_matched: bool = false
var is_hint: bool = false

var tween: Tween
var pulse_tween: Tween
const GEM_SIZE := 64

@onready var sprite: Sprite2D = $Sprite

func _ready() -> void:
	pass

func setup(type: int, x: int, y: int) -> void:
	gem_type = type
	grid_x = x
	grid_y = y
	
	if not Logger.assert_in_range("Gem.setup", type, 1, Constants.GEM_TYPES, "gem_type"):
		return
	
	if type in Constants.GEM_TEXTURES:
		var texture_path: String = Constants.GEM_TEXTURES[type]
		var loaded_texture := load(texture_path)
		if loaded_texture:
			sprite.texture = loaded_texture
			sprite.centered = false
			sprite.scale = Vector2(0.1, 0.1)
			Logger.debug("Gem", "Texture loaded: type=" + str(type) + " grid=(" + str(x) + "," + str(y) + ")")
		else:
			Logger.error("Gem.setup", "Failed to load texture path=" + texture_path + " type=" + str(type) + " grid=" + str(x) + "," + str(y))
	else:
		Logger.warn("Gem.setup", "No texture defined for type=" + str(type))

func set_position_from_grid(board_offset: Vector2) -> void:
	if not Logger.assert_not_null("Gem.set_position", board_offset, "board_offset"):
		return
	position = Vector2(grid_x * GEM_SIZE, grid_y * GEM_SIZE) + board_offset
	Logger.debug("Gem", "Position set: grid=(" + str(grid_x) + "," + str(grid_y) + ") -> pixel=" + str(position))

func set_selected(selected: bool) -> void:
	is_selected = selected
	if selected:
		sprite.modulate = Color(1.5, 1.5, 0.3)
		_stop_pulse()
		_start_pulse()
		Logger.game_event("gem_selected", {"grid": str(grid_x) + "," + str(grid_y), "type": gem_type})
	else:
		_stop_pulse()
		sprite.modulate = Color(1.0, 1.0, 1.0)
		sprite.scale = Vector2(0.1, 0.1)
		Logger.game_event("gem_deselected", {"grid": str(grid_x) + "," + str(grid_y)})

func _start_pulse() -> void:
	if pulse_tween:
		pulse_tween.kill()
	pulse_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT).set_loops()
	pulse_tween.tween_property(sprite, "scale", Vector2(0.13, 0.13), 0.4)
	pulse_tween.tween_property(sprite, "scale", Vector2(0.1, 0.1), 0.4)

func _stop_pulse() -> void:
	if pulse_tween:
		pulse_tween.kill()
		pulse_tween = null

func set_hint(hint: bool) -> void:
	is_hint = hint
	if hint and not is_selected:
		sprite.modulate = Color(1.5, 1.5, 0.5)
	elif not is_selected:
		sprite.modulate = Color(1.0, 1.0, 1.0)

func animate_swap(target: Vector2, duration: float) -> void:
	Logger.debug("Gem.animate_swap", "Start: from=" + str(position) + " to=" + str(target) + " duration=" + str(duration))
	if tween:
		tween.kill()
	tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(self, "position", target, duration)
	await tween.finished
	Logger.debug("Gem.animate_swap", "Complete: final_pos=" + str(position))

func animate_remove(duration: float) -> void:
	Logger.debug("Gem.animate_remove", "Start: grid=(" + str(grid_x) + "," + str(grid_y) + ") type=" + str(gem_type))
	if tween:
		tween.kill()
	_stop_pulse()
	if tween:
		tween.kill()
	tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(sprite, "scale", Vector2.ZERO, duration)
	tween.parallel().tween_property(sprite, "modulate:a", 0.0, duration)
	await tween.finished
	is_matched = true
	Logger.game_event("gem_removed", {"grid": str(grid_x) + "," + str(grid_y), "type": gem_type})

func animate_fall(target_y: float, duration: float) -> void:
	Logger.debug("Gem.animate_fall", "Start: grid=(" + str(grid_x) + "," + str(grid_y) + ") from_y=" + str(position.y) + " to_y=" + str(target_y))
	if tween:
		tween.kill()
	tween = create_tween().set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "position:y", target_y, duration)
	await tween.finished
	Logger.debug("Gem.animate_fall", "Complete: final_y=" + str(position.y))

func _on_tree_exiting() -> void:
	_stop_pulse()
	if tween:
		tween.kill()
	Logger.debug("Gem", "Node exiting: grid=(" + str(grid_x) + "," + str(grid_y) + ") type=" + str(gem_type))
