extends SceneTree

# Минимальный headless smoke-test логики поля.
# Запуск в Godot: godot --headless --path . --script tests/smoke_test.gd

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

	board[0][0] = 1
	board[0][1] = 1
	board[0][2] = 1
	g.board = board
	matches = g._find_matches()
	assert(matches.size() == 3)

	print("SMOKE TEST PASSED")
	quit()
