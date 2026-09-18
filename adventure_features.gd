extends Node
# Island Adventure feature layer.
# Adds meta progression, streaks, treasure finds and an on-screen combo meter
# without changing the core board algorithm.
var game: Node
var last_combo := 0
var last_level := -1
var treasure := 0
var streak := 0
var best_streak := 0
var fever := 0.0
var banner: Label
var treasure_label: Label
var streak_label: Label
var rng := RandomNumberGenerator.new()

func _ready() -> void:
	game = get_parent()
	rng.randomize()
	call_deferred("_build_hud")
	_load_meta()

func _process(delta: float) -> void:
	if not is_instance_valid(game):
		return
	var level := int(game.get("current_level"))
	if level != last_level:
		last_level = level
		last_combo = 0
		fever = 0.0
		_update_hud()
	var combo := int(game.get("combo"))
	if combo > last_combo:
		if combo >= 3:
			streak += 1
			best_streak = maxi(best_streak, streak)
			fever = minf(100.0, fever + 18.0 + combo * 4.0)
			if combo >= 4:
				_treasure_event(combo)
			_update_hud()
		last_combo = combo
	elif combo == 0 and not bool(game.get("busy")):
		# A completed turn resets the visible streak only after the cascade ends.
		if streak > 0:
			streak = 0
			_update_hud()
	fever = maxf(0.0, fever - delta * 3.5)
	if is_instance_valid(banner) and fever <= 0.1 and banner.modulate.a > 0.0:
		banner.modulate.a = move_toward(banner.modulate.a, 0.0, delta * 2.0)

func _build_hud() -> void:
	var layer := game.get("game_layer")
	if not is_instance_valid(layer):
		return
	banner = Label.new()
	banner.position = Vector2(310, 760)
	banner.size = Vector2(280, 42)
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.add_theme_font_size_override("font_size", 20)
	banner.add_theme_color_override("font_color", Color("#ffd86a"))
	banner.modulate.a = 0.0
	layer.add_child(banner)
	treasure_label = Label.new()
	treasure_label.position = Vector2(690, 45)
	treasure_label.size = Vector2(120, 28)
	treasure_label.text = "💎 0"
	treasure_label.add_theme_font_size_override("font_size", 14)
	treasure_label.add_theme_color_override("font_color", Color("#72e6ff"))
	layer.add_child(treasure_label)
	streak_label = Label.new()
	streak_label.position = Vector2(690, 700)
	streak_label.size = Vector2(120, 32)
	streak_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	streak_label.add_theme_font_size_override("font_size", 13)
	streak_label.add_theme_color_override("font_color", Color("#ffcf6b"))
	layer.add_child(streak_label)
	_update_hud()

func _treasure_event(combo: int) -> void:
	var find := rng.randi_range(1, 3)
	treasure += find
	_save_meta()
	if is_instance_valid(banner):
		banner.text = "СОКРОВИЩЕ! +%d 💎   КОМБО x%d" % [find, combo]
		banner.modulate.a = 1.0
		var tw := banner.create_tween()
		tw.tween_property(banner, "position:y", 725.0, 0.25)
		tw.tween_property(banner, "modulate:a", 0.0, 1.0)
	# Treasure also creates a small score reward. It never replaces the level goals.
	game.set("score", int(game.get("score")) + find * 25)
	game.call("_update_labels")

func _update_hud() -> void:
	if is_instance_valid(treasure_label):
		treasure_label.text = "💎 %d" % treasure
	if is_instance_valid(streak_label):
		streak_label.text = ("СЕРИЯ x%d" % streak) if streak > 1 else ""

func _load_meta() -> void:
	if FileAccess.file_exists("user://treasure.txt"):
		treasure = int(FileAccess.get_file_as_string("user://treasure.txt"))
	if FileAccess.file_exists("user://best_streak.txt"):
		best_streak = int(FileAccess.get_file_as_string("user://best_streak.txt"))

func _save_meta() -> void:
	var f := FileAccess.open("user://treasure.txt", FileAccess.WRITE)
	if f:
		f.store_string(str(treasure))
	var b := FileAccess.open("user://best_streak.txt", FileAccess.WRITE)
	if b:
		b.store_string(str(best_streak))
