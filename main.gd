extends Node2D

const SIZE := 8
const TYPES := 6
const CELL := 78.0
const ORIGIN := Vector2(138, 202)
const COLORS := [Color("#ff5b67"), Color("#4d9cff"), Color("#43d98b"), Color("#ffd34e"), Color("#b978ff"), Color("#ff9b4a")]
const SYMBOLS := ["●", "◆", "■", "★", "⬟", "▲"]
const TYPE_NAMES := ["красных кругов", "синих ромбов", "зелёных квадратов", "звёзд", "фиолетовых кристаллов", "оранжевых треугольников"]
const LEVELS := [
	{"moves": 16, "score": 1800, "type": 0, "count": 18},
	{"moves": 20, "score": 3200, "type": 3, "count": 30},
	{"moves": 24, "score": 4500, "type": 1, "count": 35}
]

var board: Array = []
var gems: Dictionary = {}
var selected := Vector2i(-1, -1)
var busy := false
var score := 0
var best := 0
var combo := 0
var current_level := 0
var moves_left := 0
var destroyed_counts: Array = [0, 0, 0, 0, 0, 0]
var unlocked_level := 0
var completed_mask := 0
var rng := RandomNumberGenerator.new()
var root: Node2D
var fx: Node2D
var score_label: Label
var best_label: Label
var combo_label: Label
var level_label: Label
var moves_label: Label
var goal_label: Label
var status: Label
var restart_button: Button
var lobby_button: Button
var next_button: Button
var sounds: Dictionary = {}
var modal: Control
var map_layer: Control
var game_layer: Control

class Gem extends Node2D:
	var kind := 0
	var color := Color.WHITE
	var symbol := "●"
	var chosen := false
	func setup(k: int, c: Color, s: String) -> void:
		kind = k
		color = c
		symbol = s
		queue_redraw()
	func select(v: bool) -> void:
		chosen = v
		var tween := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_property(self, "scale", Vector2.ONE * (1.13 if v else 1.0), 0.12)
		queue_redraw()
	func _draw() -> void:
		var s := 28.0
		draw_circle(Vector2(2, 4), s + 4.0, Color(0, 0, 0, 0.28))
		if chosen:
			draw_circle(Vector2.ZERO, s + 9.0, Color(color.r, color.g, color.b, 0.20))
		match kind:
			0:
				draw_circle(Vector2.ZERO, s, color)
				draw_circle(Vector2.ZERO, s - 5.0, color.darkened(0.08))
			1:
				draw_colored_polygon(PackedVector2Array([Vector2(0, -s), Vector2(s, 0), Vector2(0, s), Vector2(-s, 0)]), color)
			2:
				var square := StyleBoxFlat.new()
				square.bg_color = color
				square.border_color = color.lightened(0.22)
				square.set_border_width_all(3)
				square.set_corner_radius_all(9)
				draw_style_box(square, Rect2(-s, -s, s * 2.0, s * 2.0))
			3:
				var star := PackedVector2Array()
				for i in range(10):
					var angle := -PI / 2.0 + i * PI / 5.0
					var radius := s if i % 2 == 0 else s * 0.43
					star.append(Vector2(cos(angle), sin(angle)) * radius)
				draw_colored_polygon(star, color)
			4:
				var hex := PackedVector2Array()
				for i in range(6):
					var angle := -PI / 2.0 + i * PI / 3.0
					hex.append(Vector2(cos(angle), sin(angle)) * s)
				draw_colored_polygon(hex, color)
			5:
				draw_colored_polygon(PackedVector2Array([Vector2(0, -s), Vector2(s, s), Vector2(-s, s)]), color)
		draw_circle(Vector2(-s * 0.32, -s * 0.34), s * 0.19, Color(1, 1, 1, 0.50))
		draw_circle(Vector2(-s * 0.23, -s * 0.22), s * 0.08, Color.WHITE)

class BoardFrame extends Node2D:
	func _draw() -> void:
		var outer := StyleBoxFlat.new()
		outer.bg_color = Color("#0e172b")
		outer.border_color = Color("#344e7c")
		outer.set_border_width_all(2)
		outer.set_corner_radius_all(18)
		draw_style_box(outer, Rect2(-314, -314, 628, 628))
		var cell_style := StyleBoxFlat.new()
		cell_style.bg_color = Color("#0b1426")
		cell_style.border_color = Color("#172846")
		cell_style.set_border_width_all(1)
		cell_style.set_corner_radius_all(10)
		for y in SIZE:
			for x in SIZE:
				draw_style_box(cell_style, Rect2(-312 + x * CELL + 4, -312 + y * CELL + 4, CELL - 8, CELL - 8))

func _ready() -> void:
	rng.randomize()
	best = int(FileAccess.get_file_as_string("user://best_score.txt")) if FileAccess.file_exists("user://best_score.txt") else 0
	_load_progress()
	_build_sounds()
	_build_game_layer()
	_build_map_layer()
	_show_map()

func _load_progress() -> void:
	if FileAccess.file_exists("user://unlocked_level.txt"):
		unlocked_level = clampi(int(FileAccess.get_file_as_string("user://unlocked_level.txt")), 0, LEVELS.size() - 1)
	if FileAccess.file_exists("user://completed_levels.txt"):
		completed_mask = int(FileAccess.get_file_as_string("user://completed_levels.txt"))

func _save_progress() -> void:
	var unlocked_file := FileAccess.open("user://unlocked_level.txt", FileAccess.WRITE)
	if unlocked_file:
		unlocked_file.store_string(str(unlocked_level))
	var completed_file := FileAccess.open("user://completed_levels.txt", FileAccess.WRITE)
	if completed_file:
		completed_file.store_string(str(completed_mask))

func _make_label(text: String, pos: Vector2, size: Vector2, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.position = pos
	label.size = size
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	add_child(label)
	return label

func _build_game_layer() -> void:
	game_layer = Control.new()
	game_layer.name = "GameLayer"
	game_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(game_layer)
	var bg := ColorRect.new()
	bg.size = Vector2(900, 900)
	bg.color = Color("#080e1c")
	game_layer.add_child(bg)
	var head := ColorRect.new()
	head.position = Vector2(0, 0)
	head.size = Vector2(900, 176)
	head.color = Color("#111b33")
	game_layer.add_child(head)
	var accent := ColorRect.new()
	accent.position = Vector2(100, 166)
	accent.size = Vector2(700, 2)
	accent.color = Color("#263b61")
	game_layer.add_child(accent)
	var title := _make_label("ТРИ В РЯД", Vector2(138, 12), Vector2(500, 42), 36, Color("#f2f5ff"))
	var sub := _make_label("Выполни цель уровня до того, как закончатся ходы", Vector2(140, 53), Vector2(580, 28), 13, Color("#8495bb"))
	level_label = _stat("УРОВЕНЬ", Vector2(138, 88))
	moves_label = _stat("ХОДЫ", Vector2(255, 88))
	score_label = _stat("ОЧКИ", Vector2(372, 88))
	best_label = _stat("РЕКОРД", Vector2(489, 88))
	combo_label = _stat("КОМБО", Vector2(606, 88))
	goal_label = Label.new()
	goal_label.position = Vector2(138, 138)
	goal_label.size = Vector2(624, 28)
	goal_label.add_theme_font_size_override("font_size", 13)
	goal_label.add_theme_color_override("font_color", Color("#dce5ff"))
	game_layer.add_child(goal_label)
	restart_button = Button.new()
	restart_button.text = "↻"
	restart_button.tooltip_text = "Начать уровень заново"
	restart_button.position = Vector2(780, 24)
	restart_button.size = Vector2(48, 42)
	restart_button.add_theme_font_size_override("font_size", 20)
	restart_button.add_theme_stylebox_override("normal", _button_style(Color("#1a2a4b"), Color("#3b5787")))
	restart_button.add_theme_stylebox_override("hover", _button_style(Color("#284069"), Color("#6b8dcc")))
	restart_button.pressed.connect(_restart_level)
	game_layer.add_child(restart_button)
	lobby_button = Button.new()
	lobby_button.text = "КАРТА"
	lobby_button.position = Vector2(670, 86)
	lobby_button.size = Vector2(98, 34)
	lobby_button.add_theme_font_size_override("font_size", 12)
	lobby_button.add_theme_stylebox_override("normal", _button_style(Color("#16243f"), Color("#30486f")))
	lobby_button.add_theme_stylebox_override("hover", _button_style(Color("#24385e"), Color("#597bb4")))
	lobby_button.pressed.connect(_show_map)
	game_layer.add_child(lobby_button)
	var frame := BoardFrame.new()
	frame.position = ORIGIN + Vector2(312, 312)
	game_layer.add_child(frame)
	root = Node2D.new()
	root.name = "Gems"
	game_layer.add_child(root)
	fx = Node2D.new()
	fx.name = "Effects"
	game_layer.add_child(fx)
	status = Label.new()
	status.position = Vector2(138, 832)
	status.size = Vector2(624, 34)
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status.add_theme_font_size_override("font_size", 14)
	status.add_theme_color_override("font_color", Color("#9baad0"))
	game_layer.add_child(status)

func _stat(name: String, pos: Vector2) -> Label:
	var label := Label.new()
	label.position = pos
	label.size = Vector2(105, 45)
	label.text = name + "\n0"
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", Color("#8395bd"))
	game_layer.add_child(label)
	return label

func _button_style(fill: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(11)
	return style

func _build_map_layer() -> void:
	map_layer = Control.new()
	map_layer.name = "MapLayer"
	map_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(map_layer)
	var bg := ColorRect.new()
	bg.size = Vector2(900, 900)
	bg.color = Color("#07152a")
	map_layer.add_child(bg)
	var top := ColorRect.new()
	top.size = Vector2(900, 145)
	top.color = Color("#102541")
	map_layer.add_child(top)
	var title := Label.new()
	title.text = "КАРТА УРОВНЕЙ"
	title.position = Vector2(55, 28)
	title.size = Vector2(600, 46)
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", Color("#f4f7ff"))
	map_layer.add_child(title)
	var sub := Label.new()
	sub.text = "Проходи уровни по порядку и открывай новые платформы"
	sub.position = Vector2(58, 73)
	sub.size = Vector2(650, 28)
	sub.add_theme_font_size_override("font_size", 14)
	sub.add_theme_color_override("font_color", Color("#8fa6ca"))
	map_layer.add_child(sub)
	var legend := Label.new()
	legend.text = "●  ПРОЙДЕН       ●  ДОСТУПЕН       ●  ЗАБЛОКИРОВАН"
	legend.position = Vector2(58, 108)
	legend.size = Vector2(760, 26)
	legend.add_theme_font_size_override("font_size", 12)
	legend.add_theme_color_override("font_color", Color("#b7c5df"))
	map_layer.add_child(legend)
	_create_map_path()
	_create_map_level(0, Vector2(175, 270))
	_create_map_level(1, Vector2(450, 445))
	_create_map_level(2, Vector2(710, 635))
	var hint := Label.new()
	hint.text = "Выбирай доступную платформу, чтобы начать уровень"
	hint.position = Vector2(150, 805)
	hint.size = Vector2(600, 30)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 14)
	hint.add_theme_color_override("font_color", Color("#8fa4c7"))
	map_layer.add_child(hint)

func _create_map_path() -> void:
	var path := Line2D.new()
	path.width = 10.0
	path.default_color = Color("#29466d")
	path.add_point(Vector2(175, 300))
	path.add_point(Vector2(450, 475))
	path.add_point(Vector2(710, 665))
	map_layer.add_child(path)
	var path_inner := Line2D.new()
	path_inner.width = 3.0
	path_inner.default_color = Color("#45658e")
	path_inner.add_point(Vector2(175, 300))
	path_inner.add_point(Vector2(450, 475))
	path_inner.add_point(Vector2(710, 665))
	map_layer.add_child(path_inner)

func _create_map_level(index: int, center: Vector2) -> void:
	var unlocked := index <= unlocked_level
	var completed := (completed_mask & (1 << index)) != 0
	var color := Color("#36c878") if completed else (Color("#398cff") if unlocked else Color("#d94a5f"))
	var platform := Button.new()
	platform.text = str(index + 1)
	platform.position = center - Vector2(62, 62)
	platform.size = Vector2(124, 124)
	platform.add_theme_font_size_override("font_size", 34)
	platform.add_theme_color_override("font_color", Color.WHITE)
	platform.add_theme_stylebox_override("normal", _platform_style(color, false))
	platform.add_theme_stylebox_override("hover", _platform_style(color.lightened(0.08), unlocked))
	platform.add_theme_stylebox_override("pressed", _platform_style(color.darkened(0.06), unlocked))
	platform.disabled = not unlocked
	platform.tooltip_text = "Уровень %d" % (index + 1)
	if completed:
		platform.text = "✓\n%d" % (index + 1)
	elif not unlocked:
		platform.text = "🔒\n%d" % (index + 1)
	platform.pressed.connect(_on_map_level_pressed.bind(index))
	map_layer.add_child(platform)
	var label := Label.new()
	label.text = "УРОВЕНЬ %d" % (index + 1)
	label.position = center + Vector2(-70, 70)
	label.size = Vector2(140, 30)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", color.lightened(0.25))
	map_layer.add_child(label)

func _platform_style(color: Color, glow: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = color.lightened(0.28)
	style.set_border_width_all(3)
	style.set_corner_radius_all(62)
	if glow:
		style.shadow_color = Color(color.r, color.g, color.b, 0.32)
		style.shadow_size = 12
	return style

func _show_map() -> void:
	busy = true
	if modal:
		modal.queue_free()
		modal = null
	if game_layer:
		game_layer.visible = false
	if map_layer:
		map_layer.queue_free()
	_build_map_layer()
	map_layer.visible = true
	busy = false

func _on_map_level_pressed(index: int) -> void:
	_start_level(index)

func _start_level(index: int) -> void:
	if index < 0 or index >= LEVELS.size():
		return
	if index > unlocked_level:
		return
	current_level = index
	var data: Dictionary = LEVELS[current_level]
	moves_left = int(data["moves"])
	score = 0
	combo = 0
	destroyed_counts = [0, 0, 0, 0, 0, 0]
	selected = Vector2i(-1, -1)
	busy = true
	if modal:
		modal.queue_free()
		modal = null
	map_layer.visible = false
	game_layer.visible = true
	_generate_board()
	_clear_visuals()
	_create_visuals(true)
	_update_labels()
	status.text = "Выберите фишку, затем соседнюю"
	busy = false

func _restart_level() -> void:
	_start_level(current_level)

func _generate_board() -> void:
	board.clear()
	for y in SIZE:
		var row: Array = []
		for x in SIZE:
			var options: Array[int] = []
			for t in TYPES:
				if x >= 2 and row[x - 1] == t and row[x - 2] == t:
					continue
				if y >= 2 and board[y - 1][x] == t and board[y - 2][x] == t:
					continue
				options.append(t)
			row.append(options[rng.randi_range(0, options.size() - 1)])
		board.append(row)

func _clear_visuals() -> void:
	for node in root.get_children():
		node.queue_free()
	for node in fx.get_children():
		node.queue_free()
	gems.clear()

func _cell_pos(p: Vector2i) -> Vector2:
	return ORIGIN + Vector2(p.x * CELL + CELL / 2.0, p.y * CELL + CELL / 2.0)

func _make_gem(kind: int) -> Gem:
	var gem := Gem.new()
	gem.setup(kind, COLORS[kind], SYMBOLS[kind])
	root.add_child(gem)
	return gem

func _create_visuals(intro := false) -> void:
	for y in SIZE:
		for x in SIZE:
			var p := Vector2i(x, y)
			var gem := _make_gem(board[y][x])
			gem.position = _cell_pos(p)
			gem.scale = Vector2.ZERO if intro else Vector2.ONE
			gems[p] = gem
			if intro:
				var tween := create_tween()
				tween.tween_interval((x + y) * 0.012)
				tween.tween_property(gem, "scale", Vector2.ONE, 0.20).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _input(event: InputEvent) -> void:
	if busy or not game_layer.visible or not event is InputEventMouseButton:
		return
	var mouse := event as InputEventMouseButton
	if not mouse.pressed or mouse.button_index != MOUSE_BUTTON_LEFT:
		return
	var local := mouse.position - ORIGIN
	var p := Vector2i(floor(local.x / CELL), floor(local.y / CELL))
	if p.x >= 0 and p.y >= 0 and p.x < SIZE and p.y < SIZE:
		_click(p)

func _click(p: Vector2i) -> void:
	if moves_left <= 0:
		return
	if selected.x < 0:
		selected = p
		(gems[p] as Gem).select(true)
		status.text = "Теперь выберите соседнюю фишку"
		_play("select")
		return
	if p == selected:
		(gems[p] as Gem).select(false)
		selected = Vector2i(-1, -1)
		return
	if abs(p.x - selected.x) + abs(p.y - selected.y) != 1:
		status.text = "Можно менять только соседние фишки"
		_play("error")
		return
	var a := selected
	(gems[a] as Gem).select(false)
	selected = Vector2i(-1, -1)
	_resolve(a, p)

func _resolve(a: Vector2i, b: Vector2i) -> void:
	busy = true
	_swap_data(a, b)
	_play("swap")
	await _swap_anim(a, b)
	var matches: Array[Vector2i] = _find_matches()
	if matches.is_empty():
		_swap_data(a, b)
		await _swap_anim(a, b)
		status.text = "Нет комбинации — обмен отменён"
		_play("error")
		busy = false
		return
	moves_left -= 1
	combo = 0
	while not matches.is_empty():
		combo += 1
		var gained: int = matches.size() * 10 * combo
		score += gained
		_play("combo" if combo > 1 else "match")
		_popup(_cell_pos(matches[0]), gained)
		await _destroy_matches(matches)
		await _collapse_and_refill()
		matches = _find_matches()
	_update_best()
	_update_labels()
	_check_level_state()
	busy = false

func _swap_data(a: Vector2i, b: Vector2i) -> void:
	var temp = board[a.y][a.x]
	board[a.y][a.x] = board[b.y][b.x]
	board[b.y][b.x] = temp
	var gem_a = gems[a]
	gems[a] = gems[b]
	gems[b] = gem_a

func _swap_anim(a: Vector2i, b: Vector2i) -> void:
	var tween := create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(gems[a], "position", _cell_pos(a), 0.18)
	tween.tween_property(gems[b], "position", _cell_pos(b), 0.18)
	await tween.finished

func _destroy_matches(matches: Array[Vector2i]) -> void:
	for p in matches:
		var kind: int = board[p.y][p.x]
		destroyed_counts[kind] += 1
		_spawn_fx(_cell_pos(p), COLORS[kind])
		if gems.has(p):
			var gem: Gem = gems[p]
			var tween := create_tween().set_parallel(true)
			tween.tween_property(gem, "scale", Vector2.ZERO, 0.20).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
			tween.tween_property(gem, "rotation", rng.randf_range(-0.5, 0.5), 0.20)
			tween.tween_property(gem, "modulate:a", 0.0, 0.16)
	await get_tree().create_timer(0.21).timeout
	for p in matches:
		board[p.y][p.x] = -1
		if gems.has(p):
			var gem: Gem = gems[p]
			gems.erase(p)
			gem.queue_free()
	_update_labels()

func _collapse_and_refill() -> void:
	var max_fall_time := 0.0
	for x in SIZE:
		var write_y := SIZE - 1
		for read_y in range(SIZE - 1, -1, -1):
			if board[read_y][x] < 0:
				continue
			var from := Vector2i(x, read_y)
			var to := Vector2i(x, write_y)
			if write_y != read_y:
				var kind: int = board[read_y][x]
				board[write_y][x] = kind
				board[read_y][x] = -1
				var gem: Gem = gems[from]
				gems.erase(from)
				gems[to] = gem
				var distance := write_y - read_y
				var duration := 0.18 + distance * 0.055
				max_fall_time = max(max_fall_time, duration)
				var tween := create_tween()
				tween.tween_property(gem, "position", _cell_pos(to), duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
			write_y -= 1
		var spawn_index := 0
		for y in range(write_y, -1, -1):
			var kind := rng.randi_range(0, TYPES - 1)
			board[y][x] = kind
			var p := Vector2i(x, y)
			var gem := _make_gem(kind)
			gem.position = _cell_pos(p) - Vector2(0, CELL * (spawn_index + 2))
			gem.scale = Vector2.ONE * 0.82
			gems[p] = gem
			var spawn_duration := 0.22 + spawn_index * 0.05
			max_fall_time = max(max_fall_time, spawn_duration)
			var tween := create_tween().set_parallel(true)
			tween.tween_property(gem, "position", _cell_pos(p), spawn_duration).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
			tween.tween_property(gem, "scale", Vector2.ONE, 0.18)
			spawn_index += 1
	if max_fall_time > 0.0:
		await get_tree().create_timer(max_fall_time + 0.05).timeout

func _find_matches() -> Array[Vector2i]:
	var found: Dictionary = {}
	for y in SIZE:
		var start := 0
		while start < SIZE:
			var kind = board[y][start]
			var end := start + 1
			while end < SIZE and board[y][end] == kind:
				end += 1
			if kind >= 0 and end - start >= 3:
				for x in range(start, end):
					found[Vector2i(x, y)] = true
			start = end
	for x in SIZE:
		var start := 0
		while start < SIZE:
			var kind = board[start][x]
			var end := start + 1
			while end < SIZE and board[end][x] == kind:
				end += 1
			if kind >= 0 and end - start >= 3:
				for y in range(start, end):
					found[Vector2i(x, y)] = true
			start = end
	var result: Array[Vector2i] = []
	for p in found.keys():
		result.append(p)
	return result

func _check_level_state() -> void:
	var data: Dictionary = LEVELS[current_level]
	var target_type: int = int(data["type"])
	var target_score: int = int(data["score"])
	var target_count: int = int(data["count"])
	var score_done: bool = score >= target_score
	var pieces_done: bool = destroyed_counts[target_type] >= target_count
	if score_done and pieces_done:
		_on_level_won()
		return
	if moves_left <= 0:
		_on_level_lost()
		return
	status.text = "Хорошо! Продолжайте выполнять цель уровня"

func _on_level_won() -> void:
	busy = true
	completed_mask |= 1 << current_level
	if current_level + 1 < LEVELS.size():
		unlocked_level = max(unlocked_level, current_level + 1)
	_save_progress()
	_update_labels()
	_show_result_modal(true)

func _on_level_lost() -> void:
	busy = true
	_update_labels()
	_show_result_modal(false)

func _show_result_modal(won: bool) -> void:
	if modal:
		modal.queue_free()
	modal = null
	modal = Control.new()
	modal.name = "ResultModal"
	modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal.mouse_filter = Control.MOUSE_FILTER_STOP
	var shade := ColorRect.new()
	shade.size = Vector2(900, 900)
	shade.color = Color(0.02, 0.04, 0.09, 0.78)
	modal.add_child(shade)
	var panel := Panel.new()
	panel.position = Vector2(145, 245)
	panel.size = Vector2(610, 350)
	panel.add_theme_stylebox_override("panel", _modal_style())
	modal.add_child(panel)
	var title := Label.new()
	title.text = "УРОВЕНЬ ПРОЙДЕН! 🎉" if won else "ХОДЫ ЗАКОНЧИЛИСЬ"
	title.position = Vector2(45, 34)
	title.size = Vector2(520, 55)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 29)
	title.add_theme_color_override("font_color", Color("#63e6a0") if won else Color("#ff8794"))
	panel.add_child(title)
	var text := Label.new()
	if won:
		text.text = "Поздравляем!\nТы выполнил все цели уровня %d.\n\nОчки: %d     Ходов осталось: %d" % [current_level + 1, score, moves_left]
	else:
		text.text = "Цель уровня не выполнена.\nПопробуй ещё раз и сыграй немного лучше!\n\nОчки: %d     Выполнено: %d / %d" % [score, destroyed_counts[int(LEVELS[current_level]["type"])], int(LEVELS[current_level]["count"])]
	text.position = Vector2(55, 105)
	text.size = Vector2(500, 105)
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text.add_theme_font_size_override("font_size", 16)
	text.add_theme_color_override("font_color", Color("#c5d1e8"))
	panel.add_child(text)
	var primary := Button.new()
	primary.position = Vector2(65, 255)
	primary.size = Vector2(230, 52)
	primary.add_theme_font_size_override("font_size", 14)
	primary.add_theme_stylebox_override("normal", _button_style(Color("#237b50") if won else Color("#334d78"), Color("#62dfa1") if won else Color("#6484b8")))
	primary.add_theme_stylebox_override("hover", _button_style(Color("#2e9b66") if won else Color("#42628f"), Color.WHITE))
	if won:
		primary.text = "СЛЕДУЮЩИЙ УРОВЕНЬ →" if current_level + 1 < LEVELS.size() else "ВЕРНУТЬСЯ НА КАРТУ"
		primary.pressed.connect(_modal_next)
	else:
		primary.text = "ПОПРОБОВАТЬ СНОВА"
		primary.pressed.connect(_modal_retry)
	panel.add_child(primary)
	var secondary := Button.new()
	secondary.position = Vector2(315, 255)
	secondary.size = Vector2(230, 52)
	secondary.text = "ВЕРНУТЬСЯ В ЛОББИ"
	secondary.add_theme_font_size_override("font_size", 14)
	secondary.add_theme_stylebox_override("normal", _button_style(Color("#182943"), Color("#466187")))
	secondary.add_theme_stylebox_override("hover", _button_style(Color("#263e62"), Color("#7091c5")))
	secondary.pressed.connect(_modal_lobby)
	panel.add_child(secondary)
	game_layer.add_child(modal)

func _modal_next() -> void:
	if current_level + 1 < LEVELS.size():
		_start_level(current_level + 1)
	else:
		_show_map()

func _modal_retry() -> void:
	_start_level(current_level)

func _modal_lobby() -> void:
	_show_map()

func _modal_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#111c31")
	style.border_color = Color("#38527d")
	style.set_border_width_all(2)
	style.set_corner_radius_all(22)
	style.shadow_color = Color(0, 0, 0, 0.45)
	style.shadow_size = 24
	return style

func _update_best() -> void:
	if score > best:
		best = score
		var file := FileAccess.open("user://best_score.txt", FileAccess.WRITE)
		if file:
			file.store_string(str(best))

func _update_labels() -> void:
	var data: Dictionary = LEVELS[current_level]
	var target_type: int = int(data["type"])
	level_label.text = "УРОВЕНЬ\n%d" % (current_level + 1)
	moves_label.text = "ХОДЫ\n%d" % moves_left
	score_label.text = "ОЧКИ\n%d" % score
	best_label.text = "РЕКОРД\n%d" % best
	combo_label.text = "КОМБО\n%s" % ("x%d" % combo if combo > 0 else "—")
	goal_label.text = "ЦЕЛЬ: %d / %d очков     •     %d / %d %s" % [score, int(data["score"]), destroyed_counts[target_type], int(data["count"]), TYPE_NAMES[target_type]]

func _build_sounds() -> void:
	for name in ["select", "swap", "match", "combo", "error"]:
		var player := AudioStreamPlayer.new()
		player.stream = _tone(name)
		player.volume_db = -10.0
		add_child(player)
		sounds[name] = player

func _tone(kind: String) -> AudioStreamWAV:
	var frequencies: Dictionary = {"select": 520.0, "swap": 320.0, "match": 680.0, "combo": 900.0, "error": 180.0}
	var durations: Dictionary = {"select": 0.06, "swap": 0.09, "match": 0.14, "combo": 0.22, "error": 0.13}
	var frequency: float = float(frequencies[kind])
	var duration: float = float(durations[kind])
	var rate := 22050
	var count := int(rate * duration)
	var data := PackedByteArray()
	data.resize(count * 2)
	for i in count:
		var t := float(i) / rate
		var env := 1.0 - float(i) / count
		var f := frequency + (t * 220.0 if kind == "match" else 0.0)
		if kind == "combo":
			f += sin(t * 25.0) * 120.0
		data.encode_s16(i * 2, int(sin(TAU * f * t) * env * 0.30 * 32767.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	stream.data = data
	return stream

func _play(name: String) -> void:
	if sounds.has(name):
		sounds[name].play()

func _spawn_fx(p: Vector2, color: Color) -> void:
	for i in 14:
		var dot := Polygon2D.new()
		dot.polygon = PackedVector2Array([Vector2(-3, -3), Vector2(3, -3), Vector2(3, 3), Vector2(-3, 3)])
		dot.color = color.lightened(0.15)
		dot.position = p
		fx.add_child(dot)
		var angle := TAU * float(i) / 14.0
		var tween := create_tween().set_parallel(true)
		tween.tween_property(dot, "position", p + Vector2(cos(angle), sin(angle)) * rng.randf_range(30.0, 58.0), 0.36)
		tween.tween_property(dot, "scale", Vector2.ZERO, 0.36)
		tween.tween_property(dot, "modulate:a", 0.0, 0.36)
		tween.chain().tween_callback(dot.queue_free)
	var flash := Polygon2D.new()
	flash.polygon = PackedVector2Array([Vector2(-20, -20), Vector2(20, -20), Vector2(20, 20), Vector2(-20, 20)])
	flash.color = Color(1, 1, 1, 0.48)
	flash.position = p
	fx.add_child(flash)
	var flash_tween := create_tween().set_parallel(true)
	flash_tween.tween_property(flash, "scale", Vector2(1.6, 1.6), 0.08)
	flash_tween.tween_property(flash, "modulate:a", 0.0, 0.15)
	flash_tween.chain().tween_callback(flash.queue_free)

func _popup(p: Vector2, amount: int) -> void:
	var label := Label.new()
	label.text = "+%d" % amount
	label.position = p - Vector2(18, 15)
	label.add_theme_font_size_override("font_size", 20)
	label.add_theme_color_override("font_color", Color("#f5f7ff"))
	fx.add_child(label)
	var tween := create_tween()
	tween.tween_property(label, "position", label.position - Vector2(0, 40), 0.45)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 0.45)
	tween.tween_callback(label.queue_free)