extends Area2D
class_name Gem

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
	
	if type in Constants.GEM_TEXTURES:
		var texture_path: String = Constants.GEM_TEXTURES[type]
		var loaded_texture := load(texture_path)
		if loaded_texture:
			sprite.texture = loaded_texture
			# centered=false → Sprite 左上角對齊 Area2D position
			# 這樣視覺效果才會跟碰撞體對齊
			sprite.centered = false
			sprite.scale = Vector2(0.1, 0.1)

func set_position_from_grid(board_offset: Vector2) -> void:
	position = Vector2(grid_x * GEM_SIZE, grid_y * GEM_SIZE) + board_offset

func set_selected(selected: bool) -> void:
	is_selected = selected
	if selected:
		# 明顯的選取效果：放大 + 黃色光暈 + 脈衝動畫
		sprite.modulate = Color(1.5, 1.5, 0.3)
		_stop_pulse()
		_start_pulse()
		print("GEM SELECTED: grid(", grid_x, ",", grid_y, ") type=", gem_type)
	else:
		# 取消選取：恢復原色
		_stop_pulse()
		sprite.modulate = Color(1.0, 1.0, 1.0)
		sprite.scale = Vector2(0.1, 0.1)
		print("GEM DESELECTED: grid(", grid_x, ",", grid_y, ")")

func _start_pulse() -> void:
	# 脈衝動畫：大小在 0.12 和 0.1 之間來回切換
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
	if tween:
		tween.kill()
	tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(self, "position", target, duration)
	await tween.finished

func animate_remove(duration: float) -> void:
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

func animate_fall(target_y: float, duration: float) -> void:
	if tween:
		tween.kill()
	tween = create_tween().set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "position", Vector2(position.x, target_y), duration)
	await tween.finished
