extends "res://main.gd"

# This layer keeps the existing game logic but binds every animation to the
# object it animates. When a level is restarted/changed, old gems and effects
# are freed immediately and their tweens cannot keep affecting the new board.

func _clear_visuals() -> void:
	for n in root.get_children():
		n.free()
	for n in fx.get_children():
		n.free()
	gems.clear()

func _create_visuals(intro := false) -> void:
	for y in SIZE:
		for x in SIZE:
			var p := Vector2i(x, y)
			var g = _make_gem(board[y][x])
			g.position = _cell_pos(p)
			g.scale = Vector2.ZERO if intro else Vector2.ONE
			gems[p] = g
			if intro:
				var t := g.create_tween()
				t.tween_interval((x + y) * 0.012)
				t.tween_property(g, "scale", Vector2.ONE, 0.20).set_trans(Tween.TRANS_BACK)

func _swap_anim(a: Vector2i, b: Vector2i) -> void:
	var ga = gems[a]
	var gb = gems[b]
	var t := ga.create_tween().set_parallel(true)
	t.set_trans(Tween.TRANS_BACK)
	t.tween_property(ga, "position", _cell_pos(a), 0.18)
	t.tween_property(gb, "position", _cell_pos(b), 0.18)
	await t.finished

func _destroy_matches(matches: Array[Vector2i]) -> void:
	for p in matches:
		var kind: int = board[p.y][p.x]
		destroyed_counts[kind] += 1
		_spawn_fx(_cell_pos(p), COLORS[kind])
		if gems.has(p):
			var g = gems[p]
			var t := g.create_tween().set_parallel(true)
			t.tween_property(g, "scale", Vector2.ZERO, 0.20).set_trans(Tween.TRANS_BACK)
			t.tween_property(g, "rotation", rng.randf_range(-0.5, 0.5), 0.20)
			t.tween_property(g, "modulate:a", 0.0, 0.16)
	await get_tree().create_timer(0.21).timeout
	for p in matches:
		board[p.y][p.x] = -1
		if gems.has(p):
			var g = gems[p]
			gems.erase(p)
			if is_instance_valid(g):
				g.free()

func _collapse_and_refill() -> void:
	var max_time := 0.0
	for x in SIZE:
		var write_y := SIZE - 1
		for read_y in range(SIZE - 1, -1, -1):
			if board[read_y][x] < 0:
				continue
			if write_y != read_y:
				var old_pos := Vector2i(x, read_y)
				var new_pos := Vector2i(x, write_y)
				var kind: int = board[read_y][x]
				board[write_y][x] = kind
				board[read_y][x] = -1
				var g = gems[old_pos]
				gems.erase(old_pos)
				gems[new_pos] = g
				var distance := write_y - read_y
				var duration := 0.18 + distance * 0.055
				max_time = max(max_time, duration)
				var tween := g.create_tween()
				tween.tween_property(g, "position", _cell_pos(new_pos), duration).set_trans(Tween.TRANS_QUAD)
			write_y -= 1

		var spawn := 0
		for y in range(write_y, -1, -1):
			var kind := rng.randi_range(0, TYPES - 1)
			board[y][x] = kind
			var p := Vector2i(x, y)
			var g = _make_gem(kind)
			g.position = _cell_pos(p) - Vector2(0, CELL * (spawn + 2))
			g.scale = Vector2.ONE * 0.82
			gems[p] = g
			var duration := 0.22 + spawn * 0.05
			max_time = max(max_time, duration)
			var tween := g.create_tween().set_parallel(true)
			tween.tween_property(g, "position", _cell_pos(p), duration).set_trans(Tween.TRANS_BOUNCE)
			tween.tween_property(g, "scale", Vector2.ONE, 0.18)
			spawn += 1
	if max_time > 0.0:
		await get_tree().create_timer(max_time + 0.05).timeout

func _spawn_fx(p: Vector2, c: Color) -> void:
	for i in 14:
		var d := Polygon2D.new()
		d.polygon = PackedVector2Array([Vector2(-3,-3), Vector2(3,-3), Vector2(3,3), Vector2(-3,3)])
		d.color = c.lightened(0.15)
		d.position = p
		fx.add_child(d)
		var a := TAU * float(i) / 14.0
		var tween := d.create_tween().set_parallel(true)
		tween.tween_property(d, "position", p + Vector2(cos(a), sin(a)) * rng.randf_range(30,58), 0.36)
		tween.tween_property(d, "scale", Vector2.ZERO, 0.36)
		tween.tween_property(d, "modulate:a", 0.0, 0.36)
		tween.chain().tween_callback(d.queue_free)
	var flash := Polygon2D.new()
	flash.polygon = PackedVector2Array([Vector2(-20,-20), Vector2(20,-20), Vector2(20,20), Vector2(-20,20)])
	flash.color = Color(1,1,1,0.55)
	flash.position = p
	fx.add_child(flash)
	var ft := flash.create_tween().set_parallel(true)
	ft.tween_property(flash, "scale", Vector2(1.7,1.7), 0.07)
	ft.tween_property(flash, "modulate:a", 0.0, 0.14)
	ft.chain().tween_callback(flash.queue_free)

func _popup(p: Vector2, n: int) -> void:
	var l := Label.new()
	l.text = "+%d" % n
	l.position = p - Vector2(18,15)
	l.add_theme_font_size_override("font_size",20)
	fx.add_child(l)
	var tween := l.create_tween()
	tween.tween_property(l, "position", l.position - Vector2(0,40), 0.45)
	tween.parallel().tween_property(l, "modulate:a", 0.0, 0.45)
	tween.tween_callback(l.queue_free)
