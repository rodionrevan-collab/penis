extends Node2D

const SIZE := 8
const TYPES := 6
const CELL := 82.0
const BOARD_POS := Vector2(122, 190)

var rng := RandomNumberGenerator.new()
var board: Array = []
var selected := Vector2i(-1, -1)
var busy := false
var score := 0
var moves_left := 25
var level_index := 0
var level_stars := 0
var goal_target := 1000
var goal_type := "score"
var menu_layer: Control
var map_layer: Control
var game_layer: Control
var status: Label
var score_label: Label
var moves_label: Label
var goal_label: Label
var board_nodes: Array = []
var progress := ConfigFile.new()

const MECHANICS := {
	0: "Лианы",
	1: "Крепкие кокосы",
	2: "Прилив и отлив",
	3: "Проклятие тотема",
	4: "Обезьяна",
	5: "Карта сокровищ",
	6: "Туман",
	7: "Огненные камни",
	8: "Финальный тотем",
	9: "Великий шторм"
}

var LEVELS: Array = []

func _ready() -> void:
	rng.randomize()
	_load_progress()
	_build_levels()
	_build_menu()

func _process(_delta: float) -> void:
	pass

func _build_levels() -> void:
	LEVELS.clear()
	for i in range(100):
		var mechanic := min(9, i / 10)
		var target := 1000 + i * 150
		var moves := max(12, 25 - i / 10)
		LEVELS.append({"mechanic": mechanic, "target": target, "moves": moves})

func _build_menu() -> void:
	menu_layer = Control.new()
	menu_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(menu_layer)
	var bg := ColorRect.new()
	bg.size = Vector2(900, 900)
	bg.color = Color("#080e1c")
	menu_layer.add_child(bg)
	var title := Label.new()
	title.text = "ТРИ В РЯД"
	title.position = Vector2(280, 70)
	title.add_theme_font_size_override("font_size", 42)
	menu_layer.add_child(title)
	for i in range(4):
		var panel := Panel.new()
		panel.position = Vector2(100 + i * 190, 220)
		panel.size = Vector2(160, 220)
		menu_layer.add_child(panel)
		var label := Label.new()
		label.text = "ОСТРОВ %d" % (i + 1)
		label.position = Vector2(25, 30)
		panel.add_child(label)
		var button := Button.new()
		button.text = "Играть" if i == 0 else "Закрыто"
		button.position = Vector2(25, 140)
		button.size = Vector2(110, 45)
		panel.add_child(button)
		if i == 0:
			button.pressed.connect(_start_level)
		else:
			button.disabled = true

func _start_level() -> void:
	_start_level_at(level_index)

func _start_level_at(index: int) -> void:
	level_index = clampi(index, 0, LEVELS.size() - 1)
	var data: Dictionary = LEVELS[level_index]
	if game_layer:
		game_layer.queue_free()
	game_layer = null
	game_layer = Control.new()
	game_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(game_layer)
	selected = Vector2i(-1, -1)
	busy = true
	if map_layer:
		map_layer.visible = false
	if menu_layer:
		menu_layer.visible = false
	game_layer.visible = true
	_generate_board()
	_clear_visuals()
	_create_visuals()
	_update_labels()
	status.text = "Уровень %d • %s" % [level_index + 1, MECHANICS[int(data["mechanic"])] ]
	busy = false

func _build_game_layer() -> void:
	game_layer = Control.new()
	game_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(game_layer)
	var bg := ColorRect.new()
	bg.size = Vector2(900, 900)
	bg.color = Color("#080e1c")
	game_layer.add_child(bg)
	var head := ColorRect.new()
	head.size = Vector2(900, 176)
	head.color = Color("#111b33")
	game_layer.add_child(head)
	status = Label.new()
	status.position = Vector2(24, 18)
	status.add_theme_font_size_override("font_size", 26)
	game_layer.add_child(status)
	score_label = Label.new()
	score_label.position = Vector2(24, 70)
	game_layer.add_child(score_label)
	moves_label = Label.new()
	moves_label.position = Vector2(250, 70)
	game_layer.add_child(moves_label)
	goal_label = Label.new()
	goal_label.position = Vector2(500, 70)
	game_layer.add_child(goal_label)

func _generate_board() -> void:
	board.clear()
	for y in range(SIZE):
		var row: Array = []
		for x in range(SIZE):
			var value := rng.randi_range(0, TYPES - 1)
			while (x >= 2 and row[x - 1] == value and row[x - 2] == value) or (y >= 2 and board[y - 1][x] == value and board[y - 2][x] == value):
				value = rng.randi_range(0, TYPES - 1)
			row.append(value)
		board.append(row)

func _clear_visuals() -> void:
	for node in board_nodes:
		if is_instance_valid(node):
			node.queue_free()
	board_nodes.clear()

func _create_visuals() -> void:
	for y in range(SIZE):
		for x in range(SIZE):
			var button := Button.new()
			button.position = BOARD_POS + Vector2(x * CELL, y * CELL)
			button.size = Vector2(CELL - 4, CELL - 4)
			button.text = str(board[y][x] + 1)
			button.pressed.connect(_cell_pressed.bind(Vector2i(x, y)))
			game_layer.add_child(button)
			board_nodes.append(button)

func _cell_pressed(cell: Vector2i) -> void:
	if busy:
		return
	if selected.x < 0:
		selected = cell
		return
	if selected == cell:
		selected = Vector2i(-1, -1)
		return
	if abs(selected.x - cell.x) + abs(selected.y - cell.y) != 1:
		selected = cell
		return
	var first := selected
	selected = Vector2i(-1, -1)
	_swap_cells(first, cell)

func _swap_cells(a: Vector2i, b: Vector2i) -> void:
	busy = true
	var temp = board[a.y][a.x]
	board[a.y][a.x] = board[b.y][b.x]
	board[b.y][b.x] = temp
	if _find_matches().is_empty():
		temp = board[a.y][a.x]
		board[a.y][a.x] = board[b.y][b.x]
		board[b.y][b.x] = temp
		busy = false
		return
	_resolve_board()

func _find_matches() -> Array:
	var matches: Array = []
	for y in range(SIZE):
		var run: Array = []
		for x in range(SIZE):
			if run.is_empty() or board[y][x] == board[y][run[0].x]:
				run.append(Vector2i(x, y))
			else:
				if run.size() >= 3:
					matches.append_array(run)
				run = [Vector2i(x, y)]
		if run.size() >= 3:
			matches.append_array(run)
	for x in range(SIZE):
		var run: Array = []
		for y in range(SIZE):
			if run.is_empty() or board[y][x] == board[run[0].y][x]:
				run.append(Vector2i(x, y))
			else:
				if run.size() >= 3:
					matches.append_array(run)
				run = [Vector2i(x, y)]
		if run.size() >= 3:
			matches.append_array(run)
		var unique: Array = []
		for cell in matches:
			if cell not in unique:
				unique.append(cell)
		return unique

func _resolve_board() -> void:
	var matches := _find_matches()
	if matches.is_empty():
		busy = false
		return
	score += matches.size() * 100
	moves_left -= 1
	for cell in matches:
		board[cell.y][cell.x] = -1
	for x in range(SIZE):
		var write_y := SIZE - 1
		for y in range(SIZE - 1, -1, -1):
			if board[y][x] != -1:
				board[write_y][x] = board[y][x]
				write_y -= 1
		while write_y >= 0:
			board[write_y][x] = rng.randi_range(0, TYPES - 1)
			write_y -= 1
	_clear_visuals()
	_create_visuals()
	_update_labels()
	if score >= goal_target:
		busy = false
		return
	if moves_left <= 0:
		busy = false
		return
	busy = false

func _update_labels() -> void:
	if not status:
		return
	score_label.text = "Очки: %d" % score
	moves_label.text = "Ходы: %d" % moves_left
	goal_label.text = "Цель: %d" % goal_target

func _restart_level() -> void:
	score = 0
	moves_left = int(LEVELS[level_index]["moves"])
	goal_target = int(LEVELS[level_index]["target"])
	_start_level_at(level_index)

func _show_map() -> void:
	if game_layer:
		game_layer.visible = false
	if menu_layer:
		menu_layer.visible = true

func _load_progress() -> void:
	if progress.load("user://progress.cfg") == OK:
		level_index = int(progress.get_value("progress", "level", 0))

func _save_progress() -> void:
	progress.set_value("progress", "level", level_index)
	progress.save("user://progress.cfg")
