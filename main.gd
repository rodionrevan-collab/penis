extends Node2D

const SIZE := 8
const TYPES := 6
const CELL := 82.0
const ORIGIN := Vector2(122, 170)

var board: Array = []
var selected := Vector2i(-1, -1)
var busy := false
var score := 0
var best := 0
var score_label: Label
var best_label: Label
var message_label: Label
var new_game_button: Button
var pieces_root: Node2D

func _ready() -> void:
	best = int(FileAccess.get_file_as_string("user://best_score.txt")) if FileAccess.file_exists("user://best_score.txt") else 0
	_build_ui()
	_new_game()

func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.position = Vector2(0, 0)
	bg.size = Vector2(900, 900)
	bg.color = Color("#111827")
	add_child(bg)
	
	var title := Label.new()
	title.text = "ТРИ В РЯД"
	title.position = Vector2(122, 35)
	title.add_theme_font_size_override("font_size", 38)
	add_child(title)
	
	score_label = Label.new()
	score_label.position = Vector2(122, 92)
	score_label.add_theme_font_size_override("font_size", 24)
	add_child(score_label)
	
	best_label = Label.new()
	best_label.position = Vector2(650, 92)
	best_label.add_theme_font_size_override("font_size", 24)
	add_child(best_label)
	
	message_label = Label.new()
	message_label.position = Vector2(122, 120)
	message_label.add_theme_font_size_override("font_size", 16)
	add_child(message_label)
	
	new_game_button = Button.new()
	new_game_button.text = "Новая игра"
	new_game_button.position = Vector2(670, 35)
	new_game_button.size = Vector2(108, 42)
	new_game_button.pressed.connect(_new_game)
	add_child(new_game_button)
	
	pieces_root = Node2D.new()
	pieces_root.name = "Pieces"
	add_child(pieces_root)

func _new_game() -> void:
	busy = true
	selected = Vector2i(-1, -1)
	score = 0
	_generate_board()
	_redraw_board()
	_update_labels()
	message_label.text = "Выберите элемент и соседний элемент для обмена."
	busy = false

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
			row.append(options[randi() % options.size()])
		board.append(row)

func _redraw_board() -> void:
	for child in pieces_root.get_children():
		child.queue_free()
	for y in SIZE:
		for x in SIZE:
			var cell := Button.new()
			cell.position = ORIGIN + Vector2(x * CELL, y * CELL)
			cell.size = Vector2(CELL - 5, CELL - 5)
			cell.focus_mode = Control.FOCUS_NONE
			cell.text = _symbol(board[y][x])
			cell.add_theme_font_size_override("font_size", 34)
			cell.add_theme_color_override("font_color", _piece_color(board[y][x]))
			cell.add_theme_color_override("font_hover_color", Color.WHITE)
			cell.pressed.connect(_on_cell_pressed.bind(Vector2i(x, y)))
			pieces_root.add_child(cell)

func _symbol(t: int) -> String:
	return ["●", "◆", "■", "★", "⬟", "▲"][t]

func _piece_color(t: int) -> Color:
	return [Color("#ef4444"), Color("#3b82f6"), Color("#22c55e"), Color("#facc15"), Color("#a855f7"), Color("#f97316")][t]

func _on_cell_pressed(pos: Vector2i) -> void:
	if busy:
		return
	if selected.x < 0:
		selected = pos
		message_label.text = "Теперь выберите соседний элемент."
		_redraw_board()
		return
	if pos == selected:
		selected = Vector2i(-1, -1)
		_redraw_board()
		return
	if abs(pos.x - selected.x) + abs(pos.y - selected.y) != 1:
		message_label.text = "Можно менять только соседние элементы."
		return
	_swap_and_resolve(selected, pos)

func _swap_and_resolve(a: Vector2i, b: Vector2i) -> void:
	busy = true
	_swap(a, b)
	var matches := _find_matches()
	if matches.is_empty():
		_swap(a, b)
		message_label.text = "Комбинации нет — обмен отменён."
		selected = Vector2i(-1, -1)
		_redraw_board()
		busy = false
		return
	selected = Vector2i(-1, -1)
	var cascade := 1
	while not matches.is_empty():
		score += matches.size() * 10 * cascade
		for p in matches:
			board[p.y][p.x] = -1
		_apply_gravity()
		_fill_empty()
		matches = _find_matches()
		cascade += 1
	_update_best()
	_redraw_board()
	_update_labels()
	message_label.text = "Отлично! Каскад x%d" % (cascade - 1) if cascade > 2 else "Комбинация!"
	busy = false

func _swap(a: Vector2i, b: Vector2i) -> void:
	var temp = board[a.y][a.x]
	board[a.y][a.x] = board[b.y][b.x]
	board[b.y][b.x] = temp

func _find_matches() -> Array[Vector2i]:
	var found: Dictionary = {}
	for y in SIZE:
		var start := 0
		while start < SIZE:
			var t = board[y][start]
			var end := start + 1
			while end < SIZE and board[y][end] == t:
				end += 1
			if t >= 0 and end - start >= 3:
				for x in range(start, end): found[Vector2i(x, y)] = true
			start = end
	for x in SIZE:
		var start := 0
		while start < SIZE:
			var t = board[start][x]
			var end := start + 1
			while end < SIZE and board[end][x] == t:
				end += 1
			if t >= 0 and end - start >= 3:
				for y in range(start, end): found[Vector2i(x, y)] = true
			start = end
	var result: Array[Vector2i] = []
	for p in found.keys(): result.append(p)
	return result

func _apply_gravity() -> void:
	for x in SIZE:
		var write := SIZE - 1
		for y in range(SIZE - 1, -1, -1):
			if board[y][x] >= 0:
				board[write][x] = board[y][x]
				write -= 1
		while write >= 0:
			board[write][x] = -1
			write -= 1

func _fill_empty() -> void:
	for y in SIZE:
		for x in SIZE:
			if board[y][x] < 0:
				board[y][x] = randi() % TYPES

func _update_best() -> void:
	if score > best:
		best = score
		FileAccess.open("user://best_score.txt", FileAccess.WRITE).store_string(str(best))

func _update_labels() -> void:
	score_label.text = "Очки: %d" % score
	best_label.text = "Рекорд: %d" % best
