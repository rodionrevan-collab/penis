extends SceneTree

# Headless smoke-test логики поля и специальных фишек.
# Запуск: godot --headless --path . --script tests/smoke_test.gd

func _initialize() -> void:
	var g = load("res://main.gd").new()
	var board:Array = [
		[0,1,2,3,4,5,0,1],
		[1,2,3,4,5,0,1,2],
		[2,3,4,5,0,1,2,3],
		[3,4,5,0,1,2,3,4],
		[4,5,0,1,2,3,4,5],
		[5,0,1,2,3,4,5,0],
		[0,1,2,3,4,5,0,1],
		[1,2,3,4,5,0,1,2]
	]
	g.board = board
	var matches = g._find_matches()
	assert(matches.is_empty())

	# Базовая тройка.
	board[0][0] = 1
	board[0][1] = 1
	board[0][2] = 1
	g.board = board
	matches = g._find_matches()
	assert(matches.size() == 3)

	# Четвёрка создаёт линейную специальную фишку.
	board[1] = [2,2,2,2,4,5,0,1]
	g.board = board
	g.specials.clear()
	var four:Array[Vector2i] = g._find_matches()
	assert(four.size() >= 4)
	g._create_special_from_match(four)
	assert(g.specials.size() == 1)
	var sp_pos:Vector2i = g.specials.keys()[0]
	assert(int(g.specials[sp_pos]) == 1)

	# Бомба очищает область 3x3.
	g.board = board
	g.specials.clear()
	g.specials[Vector2i(3,3)] = 3
	var bomb_cells:Array[Vector2i] = g._special_effect_cells(Vector2i(3,3),Vector2i(3,4))
	assert(bomb_cells.size() == 9)

	# Радужная фишка очищает все фишки выбранного типа.
	g.board = board
	g.specials.clear()
	g.specials[Vector2i(3,3)] = 4
	var rainbow_cells:Array[Vector2i] = g._special_effect_cells(Vector2i(3,3),Vector2i(0,0))
	assert(rainbow_cells.size() > 1)

	print("SMOKE TEST PASSED: matches + special gems")
	quit()
