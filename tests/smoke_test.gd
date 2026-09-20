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

	# Комбинация линия + линия очищает крестом.
	g.board = board
	g.specials.clear()
	g.specials[Vector2i(2,2)] = 1
	g.specials[Vector2i(2,3)] = 2
	var line_combo:Array[Vector2i] = g._special_combo_cells(Vector2i(2,2),Vector2i(2,3))
	assert(line_combo.size() == 15)

	# Комбинация бомба + бомба даёт область 5x5.
	g.specials.clear()
	g.specials[Vector2i(3,3)] = 3
	g.specials[Vector2i(3,4)] = 3
	var bomb_combo:Array[Vector2i] = g._special_combo_cells(Vector2i(3,3),Vector2i(3,4))
	assert(bomb_combo.size() == 25)

	# Радужная фишка очищает все фишки выбранного типа.
	g.board = board
	g.specials.clear()
	g.specials[Vector2i(3,3)] = 4
	var rainbow_cells:Array[Vector2i] = g._special_effect_cells(Vector2i(3,3),Vector2i(0,0))
	assert(rainbow_cells.size() > 1)

	# Блокиратор требует попадания рядом и снимается за нужное число ударов.
	g._build_levels()
	g.current_level=10
	g.blockers.clear()
	g.blocker_nodes.clear()
	g.blockers[Vector2i(3,3)] = 2
	g._damage_blockers([Vector2i(3,2)])
	assert(g.blockers.size() == 1)
	assert(int(g.blockers[Vector2i(3,3)]) == 1)
	g._damage_blockers([Vector2i(4,2), Vector2i(2,4)])
	assert(g.blockers.is_empty())


	# Поле без обычных ходов, но со специальной фишкой всё равно считается playable.
	var polish = load("res://polish.gd").new()
	polish.game = g
	var dead_board:Array = [
		[0,1,2,0,1,2,0,1],
		[1,2,0,1,2,0,1,2],
		[2,0,1,2,0,1,2,0],
		[0,1,2,0,1,2,0,1],
		[1,2,0,1,2,0,1,2],
		[2,0,1,2,0,1,2,0],
		[0,1,2,0,1,2,0,1],
		[1,2,0,1,2,0,1,2]
	]
	g.board = dead_board
	g.specials.clear()
	assert(polish._has_legal_move(dead_board) == false)
	g.specials[Vector2i(3,3)] = 1
	assert(polish._has_legal_move(dead_board) == true)

	# Подсказка не должна предлагать обмен с заблокированной клеткой.
	g.blockers.clear()
	g.specials.clear()
	var hint_board:Array = dead_board.duplicate(true)
	hint_board[0] = [0,1,5,-1,5,5,5,0]
	g.board = hint_board
	g.blockers[Vector2i(3,0)] = 1
	assert(g._swap_creates_match(hint_board,2,0,3,0) == false)
	g.blockers.clear()
	g.specials[Vector2i(3,3)] = 1
	var special_hint:Array = g._find_hint_move()
	assert(special_hint.size() == 2)
	assert(special_hint.has(Vector2i(3,3)))

	# Shuffle должен сохранять количество оставшихся пауков.
	g.blockers.clear()
	g.spiders.clear()
	g.board = dead_board.duplicate(true)
	g._setup_spiders(3)
	assert(g.spiders.size() == 3)


	# Механики первого острова: прилив, тотем, обезьяна, карта, туман, огонь и финальный тотем.
	var mechanics = load("res://island_mechanics.gd").new()
	mechanics.game = g
	g.mechanics = mechanics
	g._build_levels()

	g.current_level = 30
	g.board = dead_board.duplicate(true)
	g.blockers.clear()
	g.gems.clear()
	g.specials.clear()
	g.spiders.clear()
	mechanics.setup_level(g.LEVELS[30], 30)
	assert(mechanics.tide_cells.size() == 8)
	assert(mechanics.is_cell_blocked(Vector2i(0, 0)) or mechanics.is_cell_blocked(Vector2i(0, 7)))
	mechanics.clear()

	g.current_level = 40
	g.board = dead_board.duplicate(true)
	g.blockers.clear()
	g.gems.clear()
	g.specials.clear()
	mechanics.setup_level(g.LEVELS[40], 40)
	assert(mechanics.is_complete())
	mechanics.clear()

	g.current_level = 50
	g.board = dead_board.duplicate(true)
	g.blockers.clear()
	g.gems.clear()
	g.specials.clear()
	g.spiders.clear()
	mechanics.setup_level(g.LEVELS[50], 50)
	assert(mechanics.monkey_cell.x >= 0)
	assert(g.board[mechanics.monkey_cell.y][mechanics.monkey_cell.x] == -1)
	mechanics.clear()

	g.current_level = 60
	g.board = dead_board.duplicate(true)
	g.blockers.clear()
	g.gems.clear()
	g.specials.clear()
	mechanics.setup_level(g.LEVELS[60], 60)
	assert(mechanics.map_total == 3)
	assert(g.specials.size() == 3)
	for p in g.specials.keys():
		assert(int(g.specials[p]) == 5)
	assert(g._is_active_special_type(5) == false)
	var map_piece_pos:Vector2i = g.specials.keys()[0]
	mechanics.collect_map_piece_at(map_piece_pos)
	assert(mechanics.map_collected == 1)
	mechanics.clear()

	# Фрагмент карты не должен маскироваться под активную спецфишку для dead-board detection.
	var polish_map = load("res://polish.gd").new()
	polish_map.game = g
	g.mechanics = mechanics
	g.board = dead_board.duplicate(true)
	g.specials.clear()
	g.specials[Vector2i(3,3)] = 5
	assert(polish_map._has_legal_move(g.board) == false)
	polish_map.free()
	mechanics.clear()

	g.current_level = 70
	g.board = dead_board.duplicate(true)
	g.blockers.clear()
	g.gems.clear()
	g.specials.clear()
	mechanics.setup_level(g.LEVELS[70], 70)
	assert(mechanics.fog_cells.size() > 0)
	assert(mechanics.is_complete() == false)
	mechanics.clear()

	g.current_level = 80
	g.board = dead_board.duplicate(true)
	g.blockers.clear()
	g.gems.clear()
	g.specials.clear()
	mechanics.setup_level(g.LEVELS[80], 80)
	assert(mechanics.fire_cells.size() == 2)
	assert(mechanics.fire_timer == mechanics.fire_max)
	mechanics.fire_cells.clear()
	assert(mechanics.is_complete())
	mechanics.clear()

	g.current_level = 10
	g.blockers.clear()
	g._setup_blockers(6)
	assert(g.blockers.size() == 6)
	var liana_cells:Array = g.blockers.keys()
	for p in liana_cells:
		assert(int(g.blockers[p]) == 1)

	g.current_level = 90
	g.blockers.clear()
	g._setup_blockers(4)
	assert(g.blockers.size() == 4)
	for p in g.blockers.keys():
		assert(p.x >= 3 and p.x <= 4)
		assert(p.y >= 3 and p.y <= 4)

	mechanics.free()


	# Система целей и звёзд.
	g._build_levels()
	g.current_level=10
	var blocker_goal:Array = g._goal_defs(10)
	assert(blocker_goal.size() >= 1)
	assert(blocker_goal[0]["kind"] == "blockers")
	g.current_level=60
	var mechanic_goal:Array = g._goal_defs(60)
	assert(mechanic_goal[0]["kind"] == "mechanic")
	g.current_level=0
	g.initial_moves=20
	g.moves_left=15
	g.best_combo_level=6
	g.destroyed_counts=[0,0,0,0,0,0]
	g.score=0
	assert(g._calculate_stars() == 0)
	var early_type:int=int(g.LEVELS[0]["type"])
	g.destroyed_counts[early_type]=int(g.LEVELS[0]["count"])
	g.score=int(g.LEVELS[0]["score"])
	assert(g._calculate_stars() == 3)

	# Бустерный инвентарь корректно уменьшается.
	g.booster_inventory["extra_moves"]=1
	assert(g._consume_booster("extra_moves") == true)
	assert(int(g.booster_inventory["extra_moves"]) == 0)

	# Мета-прогресс острова: звёзды -> ремонт -> зоны -> NPC -> сундуки.
	var progression = load("res://island_progression.gd").new()
	progression.reset_for_tests()
	assert(progression.is_zone_unlocked(0))
	assert(progression.is_zone_unlocked(1) == false)
	var bridge_result:Dictionary = progression.repair("bridge", 5)
	assert(bool(bridge_result["ok"]))
	assert(progression.is_repaired("bridge"))
	assert(progression.is_zone_unlocked(1))
	assert(progression.repair("bridge", 999)["ok"] == false)
	var hut_result:Dictionary = progression.repair("hut", 8)
	assert(bool(hut_result["ok"]))
	assert(progression.get_npc_list().size() == 1)
	assert(progression.is_zone_unlocked(2) == false)
	var path_result:Dictionary = progression.repair("jungle_path", 12)
	assert(bool(path_result["ok"]))
	assert(progression.is_zone_unlocked(2))
	var dock_result:Dictionary = progression.repair("dock", 15)
	assert(bool(dock_result["ok"]))
	assert(progression.get_npc_list().size() == 2)
	var pirate_result:Dictionary = progression.repair("pirate_cove", 20)
	assert(bool(pirate_result["ok"]))
	assert(progression.get_chests().size() == 1)
	var chest_result:Dictionary = progression.claim_chest("pirate_chest")
	assert(bool(chest_result["ok"]))
	assert(progression.is_chest_claimed("pirate_chest"))
	assert(progression.claim_chest("pirate_chest")["ok"] == false)
	assert(progression.get_object("bridge").has("map_pos"))
	assert(progression.get_object("bridge")["map_pos"] == Vector2(170,245))
	var lisa:Dictionary = progression.get_npc_definition("lisa")
	assert(lisa["name"] == "Лиза")
	assert(lisa.has("map_pos"))
	var unknown_npc:Dictionary = progression.get_npc_definition("unknown")
	assert(unknown_npc.is_empty())
	assert(progression.get_chests()[0].has("map_pos"))

	# NPC-цепочки: каждый этап требует новый прогресс после старта цепочки.
	var lisa_state:Dictionary = progression.get_quest_status("lisa",5,4,5)
	assert(lisa_state["stage"] == 1)
	assert(lisa_state["stage_count"] == 3)
	assert(lisa_state["done"] == false)
	var lisa_stage1:Dictionary = progression.claim_npc_quest("lisa",10,4,5)
	assert(lisa_stage1["ok"] == true)
	assert(lisa_stage1["stage"] == 1)
	assert(lisa_stage1["final"] == false)
	var lisa_stage2:Dictionary = progression.get_quest_status("lisa",10,5,5)
	assert(lisa_stage2["stage"] == 2)
	assert(lisa_stage2["done"] == true)
	var lisa_stage2_reward:Dictionary = progression.claim_npc_quest("lisa",10,5,5)
	assert(lisa_stage2_reward["ok"] == true)
	var lisa_stage3:Dictionary = progression.get_quest_status("lisa",10,5,7)
	assert(lisa_stage3["stage"] == 3)
	assert(lisa_stage3["done"] == true)
	var lisa_final:Dictionary = progression.claim_npc_quest("lisa",10,5,7)
	assert(lisa_final["ok"] == true)
	assert(lisa_final["final"] == true)
	assert(lisa_final["reward"].has("unique"))
	assert(progression.get_unique_reward_count() == 1)
	assert(progression.is_unique_reward_unlocked("lisa_badge"))
	assert(progression.get_npc_quest_dialogue("lisa",1,false) != "")
	assert(progression.get_npc_quest_dialogue("lisa",2,false) != progression.get_npc_quest_dialogue("lisa",1,false))
	assert(progression.get_npc_quest_dialogue("lisa",3,true) != "")
	assert(progression.claim_npc_quest("lisa",10,5,7)["ok"] == false)

	# Финальная цепочка открывает мини-событие и постоянный бонус.
	var lisa_event:Dictionary=progression.get_island_event("lisa_festival")
	assert(lisa_event["name"] == "Праздник пляжа")
	assert(progression.is_event_available(lisa_event))
	var event_reward:Dictionary=progression.claim_island_event("lisa_festival")
	assert(event_reward["ok"] == true)
	assert(progression.is_event_completed("lisa_festival"))
	assert(progression.claim_island_event("lisa_festival")["ok"] == false)
	var bonuses:Dictionary=progression.get_permanent_bonuses()
	assert(int(bonuses["start_moves"]) == 1)
	assert(progression.get_start_move_bonus(0) == 1)
	assert(progression.get_score_multiplier() == 1.0)
	progression.unique_rewards["tom_log"]=true
	progression.unique_rewards["keeper_key"]=true
	progression.unique_rewards["merchant_token"]=true
	assert(progression.get_start_move_bonus(0) == 2)
	assert(progression.get_start_move_bonus(69) == 1)
	assert(progression.get_start_move_bonus(70) == 2)
	assert(abs(progression.get_score_multiplier() - 1.05) < 0.001)
	assert(progression.get_three_star_bonus() == 1)
	assert(progression.get_permanent_bonus_text() != "Постоянные преимущества ещё не открыты.")

	# Все четыре события существуют; события новых зон ждут открытия нужной зоны.
	assert(progression.get_island_events().size() == 4)
	assert(progression.get_island_event("tom_route")["npc_id"] == "tom")
	assert(progression.get_island_event("keeper_night")["npc_id"] == "keeper")
	assert(progression.get_island_event("merchant_market")["npc_id"] == "merchant")

	# Интерактивные объекты и мини-активности требуют уникальные предметы и зоны.
	assert(progression.get_interactive_objects().size() == 4)
	assert(progression.get_mini_activities().size() == 3)
	assert(progression.get_interactive_object("pirate_chart_table")["unique_required"] == "tom_log")
	assert(progression.get_mini_activity("pirate_navigation")["unique_required"] == "tom_log")
	assert(progression.get_mini_activity("pirate_navigation")["type"] == "sequence")
	assert(progression.get_mini_activity("cave_runes")["type"] == "odd_one")
	assert(progression.get_mini_activity("village_market")["type"] == "collect_three")
	assert(progression.get_mini_activity("village_trade_route")["type"] == "order_goods")
	assert(progression.get_mini_activities().size() == 4)
	assert(progression.get_collection_total() == 8)
	assert(progression.get_collection_count() == 1)
	assert(progression.get_available_interactives().size() == 0)
	assert(progression.get_available_activities().size() == 0)
	progression.repaired["secret_cave"]=true
	progression.repaired["old_village"]=true
	progression.unique_rewards["tom_log"]=true
	progression.unique_rewards["keeper_key"]=true
	progression.unique_rewards["merchant_token"]=true
	progression.unique_rewards["lisa_badge"]=true
	assert(progression.get_available_interactives().size() == 4)
	assert(progression.get_available_activities().size() == 3)
	var interactive_reward:Dictionary=progression.claim_interactive("pirate_chart_table")
	assert(interactive_reward["ok"] == true)
	assert(progression.claim_interactive("pirate_chart_table")["ok"] == false)
	var activity_reward:Dictionary=progression.claim_mini_activity("pirate_navigation")
	assert(activity_reward["ok"] == true)
	assert(progression.is_activity_completed("pirate_navigation"))
	assert(progression.is_collection_item_collected("pirate_chart"))
	assert(progression.get_collection_count() == 2)
	assert(progression.claim_mini_activity("pirate_navigation")["ok"] == false)
	assert(progression.get_available_interactives().size() == 3)
	assert(progression.get_available_activities().size() == 3)

	# Секреты открываются зоной и забираются только один раз.
	var secrets:Array = progression.get_secrets()
	assert(secrets.size() == 3)
	assert(progression.claim_secret("bottle")["ok"] == true)
	assert(progression.claim_secret("bottle")["ok"] == false)
	assert(progression.claim_secret("parrot_nest")["ok"] == true)
	assert(progression.claim_secret("ancient_statue")["ok"] == false)
	progression.repaired["secret_cave"]=true
	assert(progression.claim_secret("ancient_statue")["ok"] == true)

	# Художественный слой острова загружается и создаёт объекты всех типов.
	var island_art = load("res://island_art.gd").new()
	var backdrop = island_art.call("create_backdrop",[true,false,false,false,false,false])
	assert(backdrop != null)
	var bridge_art = island_art.call("create_object","bridge",false)
	var hut_art = island_art.call("create_object","hut",true)
	var npc_art = island_art.call("create_npc","Рыбак")
	var chest_art = island_art.call("create_chest",false)
	assert(bridge_art != null)
	assert(hut_art != null)
	assert(npc_art != null)
	assert(chest_art != null)
	island_art.free()
	assert(progression.is_zone_unlocked(4) == false)
	progression.free()

	print("SMOKE TEST PASSED: matches + special gems")
	quit()
