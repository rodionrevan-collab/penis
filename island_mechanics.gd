extends Node

const SIZE := 8
const TYPES := 6
const COLORS := [Color("#ff5b67"), Color("#4d9cff"), Color("#43d98b"), Color("#ffd34e"), Color("#b978ff"), Color("#ff9b4a")]
const SYMBOLS := ["●", "◆", "■", "★", "⬟", "▲"]

# Реальные механики первого острова.
# Скрипт намеренно работает поверх main.gd, чтобы поле и match-3 ядро
# оставались совместимыми с уже существующими уровнями.

var game: Node
var tier := 0
var level_index := 0
var tide_cells: Dictionary = {}
var tide_row := -1
var previous_tide_row := -1
var monkey_cell := Vector2i(-1, -1)
var map_total := 0
var map_collected := 0
var fog_cells: Dictionary = {}
var fire_cells: Dictionary = {}
var fire_timer := 0
var fire_max := 0
var failed := false
var turn_index := 0
var visuals: Dictionary = {}
var rng := RandomNumberGenerator.new()

func _ready() -> void:
	game = get_parent()
	rng.randomize()

func clear() -> void:
	for node in visuals.values():
		if is_instance_valid(node):
			node.queue_free()
	visuals.clear()
	tide_cells.clear()
	fog_cells.clear()
	fire_cells.clear()
	monkey_cell = Vector2i(-1, -1)
	tide_row = -1
	previous_tide_row = -1
	map_total = 0
	map_collected = 0
	fire_timer = 0
	fire_max = 0
	failed = false
	turn_index = 0
	tier = 0
	level_index = 0

func setup_level(data: Dictionary, index: int) -> void:
	clear()
	tier = int(data.get("mechanic", 0))
	level_index = index
	if tier == 3:
		_setup_tide()
	elif tier == 4:
		pass
	elif tier == 5:
		_setup_monkey()
	elif tier == 6:
		_setup_map()
	elif tier == 7:
		_setup_fog()
	elif tier == 8:
		_setup_fire()
	elif tier == 9:
		pass
	_refresh_visuals()

func _setup_tide() -> void:
	# Прилив блокирует целый внешний ряд; затем он меняется на другой берег.
	var size := SIZE
	tide_row = 0 if level_index % 2 == 0 else size - 1
	previous_tide_row = tide_row
	for x in range(size):
		var p := Vector2i(x, tide_row)
		tide_cells[p] = true
		_remove_cell_content(p)

func _setup_monkey() -> void:
	var board = game.get("board")
	var blockers = game.get("blockers")
	var candidates: Array[Vector2i] = []
	for y in range(1, int(game.get("SIZE")) - 1):
		for x in range(1, int(game.get("SIZE")) - 1):
			var p := Vector2i(x, y)
			if board[y][x] >= 0 and (not blockers is Dictionary or not blockers.has(p)):
				candidates.append(p)
	if candidates.is_empty():
		return
	monkey_cell = candidates[rng.randi_range(0, candidates.size() - 1)]
	var spiders = game.get("spiders")
	if spiders is Dictionary:
		spiders.erase(monkey_cell)
	var spider_nodes = game.get("spider_nodes")
	if spider_nodes is Dictionary and spider_nodes.has(monkey_cell):
		var spider = spider_nodes[monkey_cell]
		spider_nodes.erase(monkey_cell)
		if is_instance_valid(spider):
			spider.queue_free()
	board[monkey_cell.y][monkey_cell.x] = -1

func _setup_map() -> void:
	var board = game.get("board")
	var blockers = game.get("blockers")
	var candidates: Array[Vector2i] = []
	for y in range(0, 4):
		for x in range(int(game.get("SIZE"))):
			var p := Vector2i(x, y)
			if board[y][x] >= 0 and (not blockers is Dictionary or not blockers.has(p)):
				candidates.append(p)
	candidates.shuffle()
	map_total = mini(3, candidates.size())
	var specials = game.get("specials")
	for i in range(map_total):
		specials[candidates[i]] = 5

func _setup_fog() -> void:
	var board = game.get("board")
	var blockers = game.get("blockers")
	var candidates: Array[Vector2i] = []
	var center := Vector2i(3 + (level_index % 2), 3)
	for y in range(1, int(game.get("SIZE")) - 1):
		for x in range(1, int(game.get("SIZE")) - 1):
			var p := Vector2i(x, y)
			if board[y][x] >= 0 and (not blockers is Dictionary or not blockers.has(p)):
				candidates.append(p)
	candidates.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return abs(a.x - center.x) + abs(a.y - center.y) < abs(b.x - center.x) + abs(b.y - center.y)
	)
	var amount := mini(8, candidates.size())
	for i in range(amount):
		fog_cells[candidates[i]] = true

func _setup_fire() -> void:
	var board = game.get("board")
	var blockers = game.get("blockers")
	var candidates: Array[Vector2i] = []
	for y in range(1, int(game.get("SIZE")) - 1):
		for x in range(int(game.get("SIZE"))):
			var p := Vector2i(x, y)
			if board[y][x] >= 0 and (not blockers is Dictionary or not blockers.has(p)):
				candidates.append(p)
	candidates.shuffle()
	for i in range(mini(2, candidates.size())):
		fire_cells[candidates[i]] = true
	fire_max = 7 + int(level_index / 10)
	fire_timer = fire_max

func is_cell_blocked(p: Vector2i) -> bool:
	return tide_cells.has(p) or p == monkey_cell

func is_fogged(p: Vector2i) -> bool:
	return fog_cells.has(p)

func get_goal_text() -> String:
	match tier:
		3:
			return "ПРИЛИВ: берег меняется каждые 2 хода"
		4:
			return "ТОТЕМ: после каждого хода меняет цвет нескольких фишек"
		5:
			return "ОБЕЗЬЯНА: блокирует клетку и ворует фишку при перемещении"
		6:
			return "КАРТА: доставьте фрагменты вниз • %d / %d" % [map_collected, map_total]
		7:
			return "ТУМАН: откройте скрытые клетки • осталось %d" % fog_cells.size()
		8:
			return "ОГНЕННЫЕ КАМНИ: %d / %d ходов • камней %d" % [fire_timer, fire_max, fire_cells.size()]
		9:
			return "ФИНАЛЬНЫЙ ТОТЕМ: уничтожите центральные защитные клетки"
		_:
			return ""

func is_complete() -> bool:
	match tier:
		6:
			return map_total == 0 or map_collected >= map_total
		7:
			return fog_cells.is_empty()
		8:
			return fire_cells.is_empty()
		_:
			return true

func is_failed() -> bool:
	return failed

func after_matches_cleared(cleared: Array[Vector2i]) -> void:
	if tier == 7:
		_reveal_fog_near(cleared)
	elif tier == 8:
		_extinguish_fire_near(cleared)
	elif tier == 6:
		_collect_map_pieces()
	_refresh_visuals()

func before_next_collapse() -> void:
	# Публичный hook для main.gd. Пока изменение прилива происходит в конце хода.
	pass

func after_player_move() -> void:
	turn_index += 1
	match tier:
		3:
			if turn_index % 2 == 0:
				await _shift_tide()
		4:
			_curse_random_colors()
		5:
			await _move_monkey()
		8:
			fire_timer -= 1
			if fire_timer <= 0 and not fire_cells.is_empty():
				failed = true
	_refresh_visuals()

func _shift_tide() -> void:
	var size := int(game.get("SIZE"))
	var new_row := size - 1 if tide_row == 0 else 0
	var old_row := tide_row
	previous_tide_row = old_row
	tide_row = new_row
	tide_cells.clear()

	# Сначала освобождаем старый ряд: его клетки остаются пустыми и будут заполнены
	# обычным collapse/refill после этого hook.
	var board = game.get("board")
	for x in range(size):
		var old_p := Vector2i(x, old_row)
		board[old_row][x] = -1

	# Новый ряд становится водой. Удаляем находившиеся там фишки/спецфишки/пауков.
	for x in range(size):
		var p := Vector2i(x, new_row)
		tide_cells[p] = true
		_remove_cell_content(p)

	await game.call("_collapse_and_refill")

func _remove_cell_content(p: Vector2i) -> void:
	var board = game.get("board")
	var gems = game.get("gems")
	var specials = game.get("specials")
	var spiders = game.get("spiders")
	var spider_nodes = game.get("spider_nodes")
	board[p.y][p.x] = -1
	specials.erase(p)
	spiders.erase(p)
	if gems is Dictionary and gems.has(p):
		var gem = gems[p]
		gems.erase(p)
		if is_instance_valid(gem):
			gem.queue_free()
	if spider_nodes is Dictionary and spider_nodes.has(p):
		var spider = spider_nodes[p]
		spider_nodes.erase(p)
		if is_instance_valid(spider):
			spider.queue_free()

func _curse_random_colors() -> void:
	var board = game.get("board")
	var gems = game.get("gems")
	var specials = game.get("specials")
	var candidates: Array[Vector2i] = []
	var size := int(game.get("SIZE"))
	for y in range(size):
		for x in range(size):
			var p := Vector2i(x, y)
			if board[y][x] >= 0 and (not specials is Dictionary or not specials.has(p)):
				candidates.append(p)
	candidates.shuffle()
	var amount := mini(2 + int(level_index / 30), candidates.size())
	for i in range(amount):
		var p := candidates[i]
		var old_kind := int(board[p.y][p.x])
		var new_kind := (old_kind + 1 + rng.randi_range(0, 4)) % TYPES
		board[p.y][p.x] = new_kind
		if gems is Dictionary and gems.has(p):
			var gem = gems[p]
			gem.kind = new_kind
			gem.color = COLORS[new_kind]
			gem.symbol = SYMBOLS[new_kind]
			gem.queue_redraw()

func _move_monkey() -> void:
	if monkey_cell.x < 0:
		return
	var size := int(game.get("SIZE"))
	var blockers = game.get("blockers")
	var board = game.get("board")
	var candidates: Array[Vector2i] = []
	for delta in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var p := monkey_cell + delta
		if p.x < 0 or p.y < 0 or p.x >= size or p.y >= size:
			continue
		if (blockers is Dictionary and blockers.has(p)) or tide_cells.has(p):
			continue
		if board[p.y][p.x] >= 0:
			candidates.append(p)
	if candidates.is_empty():
		return

	var target := candidates[rng.randi_range(0, candidates.size() - 1)]
	var old := monkey_cell
	_remove_cell_content(target)
	board[old.y][old.x] = -1
	monkey_cell = target
	await game.call("_collapse_and_refill")

func _collect_map_pieces() -> void:
	var specials = game.get("specials")
	var gems = game.get("gems")
	var size := int(game.get("SIZE"))
	var reached: Array[Vector2i] = []
	for key in specials.keys():
		var p: Vector2i = key
		if int(specials.get(p, 0)) == 5 and p.y == size - 1:
			reached.append(p)
	for p in reached:
		specials.erase(p)
		map_collected += 1
		if gems is Dictionary and gems.has(p):
			var gem = gems[p]
			gem.special_type = 0
			gem.queue_redraw()

func _reveal_fog_near(cleared: Array[Vector2i]) -> void:
	var revealed: Array[Vector2i] = []
	for fog_pos in fog_cells.keys():
		var fp: Vector2i = fog_pos
		for p in cleared:
			if abs(fp.x - p.x) <= 1 and abs(fp.y - p.y) <= 1:
				revealed.append(fp)
				break
	for p in revealed:
		fog_cells.erase(p)

func _extinguish_fire_near(cleared: Array[Vector2i]) -> void:
	var gone: Array[Vector2i] = []
	for fire_pos in fire_cells.keys():
		var fp: Vector2i = fire_pos
		for p in cleared:
			if abs(fp.x - p.x) <= 1 and abs(fp.y - p.y) <= 1:
				gone.append(fp)
				break
	for p in gone:
		fire_cells.erase(p)
		fire_timer = mini(fire_max, fire_timer + 2)

func _refresh_visuals() -> void:
	for node in visuals.values():
		if is_instance_valid(node):
			node.queue_free()
	visuals.clear()
	var layer = game.get("game_layer")
	if not is_instance_valid(layer):
		return

	for p in fog_cells.keys():
		_create_mark(layer, p, "?", Color("#5f6f82"), 22)
	for p in fire_cells.keys():
		_create_mark(layer, p, "!", Color("#ff9b4a"), 24)
	if monkey_cell.x >= 0:
		_create_mark(layer, monkey_cell, "M", Color("#d89b50"), 23)
	if tier == 3:
		for p in tide_cells.keys():
			_create_mark(layer, p, "≈", Color("#55bfe8"), 18)
	if tier == 6:
		# Карта отображается самой фишкой (special_type 5).
		pass

func _create_mark(layer: Node, p: Vector2i, text_value: String, color: Color, size: int) -> void:
	var label := Label.new()
	label.text = text_value
	label.position = game.call("_cell_pos", p) - Vector2(18, 25)
	label.size = Vector2(36, 40)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	layer.add_child(label)
	visuals[p] = label
