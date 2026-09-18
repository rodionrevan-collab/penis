extends Node

# Безопасный слой доработок поверх существующей игры.
# Исправляет навигацию, управление и ситуацию, когда после каскада
# на поле не осталось ни одного допустимого хода.

var game: Node
var shuffle_cooldown := 0.0
var patched_menu: Control
var last_level := -1

func _ready() -> void:
	game = get_parent()
	call_deferred("_patch_menu")

func _process(delta: float) -> void:
	if not is_instance_valid(game):
		return
	shuffle_cooldown = maxf(0.0, shuffle_cooldown - delta)
	var current_level := int(game.get("current_level"))
	if last_level == -1:
		last_level = current_level
	elif current_level != last_level:
		# При переходе на следующий уровень старая модалка должна исчезнуть.
		var old_modal = game.get("modal")
		if is_instance_valid(old_modal):
			old_modal.queue_free()
			game.set("modal", null)
		last_level = current_level
	var menu = game.get("menu_layer")
	if is_instance_valid(menu) and menu.visible and patched_menu != menu:
		_patch_menu()
	var game_layer = game.get("game_layer")
	if not is_instance_valid(game_layer) or not game_layer.visible:
		return

	# main.gd оставляет busy=true после успешного каскада.
	# Снимаем блокировку только когда анимации фишек действительно закончились.
	if bool(game.get("busy")):
		if game.get("modal") == null and _board_animation_finished():
			game.set("busy", false)
		else:
			return

	if shuffle_cooldown > 0.0:
		return
	if int(game.get("moves_left")) <= 0:
		return
	var selected = game.get("selected")
	if selected.x >= 0:
		return
	var board = game.get("board")
	if board is Array and not _has_legal_move(board):
		_shuffle_board()

func _board_animation_finished() -> bool:
	var board = game.get("board")
	var gems = game.get("gems")
	if not board is Array or not gems is Dictionary:
		return false
	for y in range(8):
		for x in range(8):
			if board[y][x] < 0:
				return false
			var p := Vector2i(x, y)
			if not gems.has(p):
				return false
			var gem = gems[p]
			if not is_instance_valid(gem):
				return false
			var target: Vector2 = game.call("_cell_pos", p)
			if gem.position.distance_to(target) > 1.0:
				return false
			if gem.scale.distance_to(Vector2.ONE) > 0.02:
				return false
	return true

func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey:
		return
	var key := event as InputEventKey
	if not key.pressed or key.echo or not is_instance_valid(game):
		return
	match key.keycode:
		KEY_ESCAPE:
			var modal = game.get("modal")
			if is_instance_valid(modal):
				game.call("_show_map")
			else:
				var game_layer = game.get("game_layer")
				if is_instance_valid(game_layer) and game_layer.visible:
					game.call("_show_map")
		KEY_R:
			var game_layer_r = game.get("game_layer")
			if is_instance_valid(game_layer_r) and game_layer_r.visible and not bool(game.get("busy")):
				game.call("_restart_level")
		KEY_M:
			var game_layer_m = game.get("game_layer")
			if is_instance_valid(game_layer_m) and game_layer_m.visible and not bool(game.get("busy")):
				game.call("_show_map")

func _patch_menu() -> void:
	var menu = game.get("menu_layer")
	if not is_instance_valid(menu):
		return
	var cards: Array[Panel] = []
	for child in menu.get_children():
		if child is Panel:
			cards.append(child)
	if cards.size() < 4:
		return
	# В проекте заявлены 3 мира: оставляем три карточки.
	cards[0].position = Vector2(100, 220)
	cards[1].position = Vector2(470, 220)
	cards[2].position = Vector2(285, 520)
	cards[3].visible = false
	patched_menu = menu

func _has_legal_move(board: Array) -> bool:
	# Любая соседняя специальная фишка уже является допустимым ходом:
	# её можно передвинуть для активации даже без обычной тройки.
	var specials = game.get("specials")
	for y in range(8):
		for x in range(8):
			var a := Vector2i(x, y)
			if x + 1 < 8:
				var b := Vector2i(x + 1, y)
				if (specials is Dictionary and (specials.has(a) or specials.has(b))) or _swap_creates_match(board, x, y, x + 1, y):
					return true
			if y + 1 < 8:
				var b := Vector2i(x, y + 1)
				if (specials is Dictionary and (specials.has(a) or specials.has(b))) or _swap_creates_match(board, x, y, x, y + 1):
					return true
	return false

func _swap_creates_match(board: Array, x1: int, y1: int, x2: int, y2: int) -> bool:
	var a = board[y1][x1]
	var b = board[y2][x2]
	if a == b:
		return false
	board[y1][x1] = b
	board[y2][x2] = a
	var result := _cell_has_match(board, x1, y1) or _cell_has_match(board, x2, y2)
	board[y1][x1] = a
	board[y2][x2] = b
	return result

func _cell_has_match(board: Array, x: int, y: int) -> bool:
	var kind = board[y][x]
	if kind < 0:
		return false
	var horizontal := 1
	var i := x - 1
	while i >= 0 and board[y][i] == kind:
		horizontal += 1
		i -= 1
	i = x + 1
	while i < 8 and board[y][i] == kind:
		horizontal += 1
		i += 1
	if horizontal >= 3:
		return true
	var vertical := 1
	i = y - 1
	while i >= 0 and board[i][x] == kind:
		vertical += 1
		i -= 1
	i = y + 1
	while i < 8 and board[i][x] == kind:
		vertical += 1
		i += 1
	return vertical >= 3

func _shuffle_board() -> void:
	shuffle_cooldown = 0.8
	game.set("busy", true)
	game.call("_generate_board")
	var board = game.get("board")
	var attempts := 0
	while not _has_legal_move(board) and attempts < 20:
		game.call("_generate_board")
		board = game.get("board")
		attempts += 1
	game.call("_clear_visuals")
	game.call("_create_visuals")
	var status = game.get("status")
	if is_instance_valid(status):
		status.text = "Поле перемешано — доступных ходов снова достаточно"
	game.set("busy", false)
