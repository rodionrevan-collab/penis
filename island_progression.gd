extends Node

# Мета-прогресс первого острова: ремонт, зоны, NPC и сундуки.
# Состояние хранится отдельно от прогресса уровней, чтобы ремонт не сбрасывался.
const SAVE_PATH := "user://island_restoration.txt"

var repaired: Dictionary = {}
var claimed_chests: Dictionary = {}
var discovered_npcs: Dictionary = {}
var claimed_quests: Dictionary = {}
var claimed_secrets: Dictionary = {}
var quest_chain_state: Dictionary = {}
var unique_rewards: Dictionary = {}

var objects: Array[Dictionary] = [
	{"id":"bridge","name":"Старый мост","icon":"🌉","cost":5,"zone":1,"description":"Разрушенный мост открывает путь в джунгли.","reward_text":"Открывает зону: Джунгли","map_pos":Vector2(170,245)},
	{"id":"hut","name":"Пляжная хижина","icon":"🏠","cost":8,"zone":0,"description":"После ремонта здесь поселяется первый житель острова.","reward_text":"NPC: Лиза, смотрительница пляжа","map_pos":Vector2(250,500)},
	{"id":"jungle_path","name":"Тропа в джунглях","icon":"🌴","cost":12,"zone":2,"description":"Расчищенная тропа ведёт к старой пристани.","reward_text":"Открывает зону: Старая пристань","map_pos":Vector2(385,210)},
	{"id":"dock","name":"Старая пристань","icon":"⚓","cost":15,"zone":2,"description":"Восстановленная пристань возвращает на остров рыбака.","reward_text":"NPC: Рыбак Том","map_pos":Vector2(465,470)},
	{"id":"pirate_cove","name":"Пиратская бухта","icon":"🏴","cost":20,"zone":3,"description":"За старым проходом скрыта заброшенная пиратская бухта.","reward_text":"Открывает зону: Пиратская бухта + сундук","map_pos":Vector2(640,250)},
	{"id":"lighthouse","name":"Маяк","icon":"🔦","cost":25,"zone":3,"description":"Маяк снова освещает море и привлекает смотрителя.","reward_text":"NPC: Смотритель маяка","map_pos":Vector2(695,470)},
	{"id":"secret_cave","name":"Тайная пещера","icon":"🪨","cost":30,"zone":4,"description":"Старый вход в скале открывает секретную часть острова.","reward_text":"Открывает зону: Тайная пещера + большой сундук","map_pos":Vector2(560,375)},
	{"id":"old_village","name":"Старая деревня","icon":"🏚️","cost":35,"zone":5,"description":"Последний большой объект возвращает острову его поселение.","reward_text":"NPC: Торговец и дополнительная награда","map_pos":Vector2(380,385)}
]

var zones: Array[Dictionary] = [
	{"id":0,"name":"Пляж","required_object":"","description":"Стартовая территория."},
	{"id":1,"name":"Джунгли","required_object":"bridge","description":"Зелёная часть острова за мостом."},
	{"id":2,"name":"Старая пристань","required_object":"jungle_path","description":"Заброшенная береговая линия."},
	{"id":3,"name":"Пиратская бухта","required_object":"pirate_cove","description":"Скрытая бухта со следами пиратов."},
	{"id":4,"name":"Тайная пещера","required_object":"secret_cave","description":"Секретное место с сокровищами."},
	{"id":5,"name":"Старая деревня","required_object":"old_village","description":"Финальная зона восстановления острова."}
]

func _ready() -> void:
	_load()

func _load() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var text := FileAccess.get_file_as_string(SAVE_PATH)
	for part in text.split("|"):
		var pair := part.split("=", true, 1)
		if pair.size() != 2:
			continue
		var key := pair[0]
		var values := pair[1].split(",") if not pair[1].is_empty() else []
		if key == "repaired":
			for id in values:
				if not id.is_empty():
					repaired[id] = true
		elif key == "chests":
			for id in values:
				if not id.is_empty():
					claimed_chests[id] = true
		elif key == "npcs":
			for id in values:
				if not id.is_empty():
					discovered_npcs[id] = true
		elif key == "quests":
			for id in values:
				if not id.is_empty():
					claimed_quests[id] = true
		elif key == "secrets":
			for id in values:
				if not id.is_empty():
					claimed_secrets[id] = true
		elif key == "queststate":
			_load_quest_state(pair[1])
		elif key == "unique":
			for id in values:
				if not id.is_empty():
					unique_rewards[id] = true
	_migrate_legacy_quests()

func save() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if not file:
		return
	file.store_string("repaired=%s|chests=%s|npcs=%s|quests=%s|secrets=%s|queststate=%s|unique=%s" % [
		_keys_text(repaired),
		_keys_text(claimed_chests),
		_keys_text(discovered_npcs),
		_keys_text(claimed_quests),
		_keys_text(claimed_secrets),
		_quest_state_text(),
		_keys_text(unique_rewards)
	])
	file.flush()

func _keys_text(data: Dictionary) -> String:
	var values := PackedStringArray()
	for key in data.keys():
		values.append(str(key))
	return ",".join(values)

func get_object(id: String) -> Dictionary:
	for item in objects:
		if str(item["id"]) == id:
			return item
	return {}

func is_repaired(id: String) -> bool:
	return bool(repaired.get(id, false))

func is_zone_unlocked(zone_id: int) -> bool:
	if zone_id <= 0:
		return true
	for zone in zones:
		if int(zone["id"]) == zone_id:
			var required := str(zone["required_object"])
			return is_repaired(required)
	return false

func get_unlocked_zone_count() -> int:
	var count := 0
	for zone in zones:
		if is_zone_unlocked(int(zone["id"])):
			count += 1
	return count

func get_repairable_objects() -> Array:
	var result: Array = []
	for item in objects:
		if not is_repaired(str(item["id"])):
			result.append(item)
	return result

func repair(id: String, available_stars: int) -> Dictionary:
	var item := get_object(id)
	if item.is_empty() or is_repaired(id):
		return {"ok":false,"reason":"already"}
	var zone_id := int(item["zone"])
	# Объекты следующей зоны требуют, чтобы предыдущая зона уже была открыта.
	if zone_id > 0 and not is_zone_unlocked(zone_id - 1):
		return {"ok":false,"reason":"zone_locked","required_zone":zone_id - 1}
	var cost := int(item["cost"])
	if available_stars < cost:
		return {"ok":false,"reason":"stars","cost":cost}
	repaired[id] = true
	_register_unlocks_for_object(item)
	save()
	return {"ok":true,"cost":cost,"object":item}

func _register_unlocks_for_object(item: Dictionary) -> void:
	var id := str(item["id"])
	if id == "hut":
		discovered_npcs["lisa"] = true
	elif id == "dock":
		discovered_npcs["tom"] = true
	elif id == "lighthouse":
		discovered_npcs["keeper"] = true
	elif id == "old_village":
		discovered_npcs["merchant"] = true

func get_npc_definition(id: String) -> Dictionary:
	var definitions := [
		{"id":"lisa","name":"Лиза","role":"Смотрительница пляжа","icon":"👩","text":"Спасибо! Теперь здесь снова можно жить.","map_pos":Vector2(250,540)},
		{"id":"tom","name":"Том","role":"Рыбак","icon":"🧑‍🌾","text":"Пристань снова работает. Море хранит много тайн.","map_pos":Vector2(465,510)},
		{"id":"keeper","name":"Смотритель маяка","role":"Хранитель маяка","icon":"🧔","text":"Ночью я буду следить за огнями и кораблями.","map_pos":Vector2(695,510)},
		{"id":"merchant","name":"Торговец","role":"Хозяин лавки","icon":"🧑‍💼","text":"Восстановите остров полностью — и я открою редкие товары.","map_pos":Vector2(380,425)}
	]
	for npc in definitions:
		if str(npc["id"]) == id:
			return npc
	return {}

func get_npc_list() -> Array:
	var result: Array = []
	var definitions := [
		{"id":"lisa","name":"Лиза","role":"Смотрительница пляжа","icon":"👩","text":"Спасибо! Теперь здесь снова можно жить.","map_pos":Vector2(250,540)},
		{"id":"tom","name":"Том","role":"Рыбак","icon":"🧑‍🌾","text":"Пристань снова работает. Море хранит много тайн.","map_pos":Vector2(465,510)},
		{"id":"keeper","name":"Смотритель маяка","role":"Хранитель маяка","icon":"🧔","text":"Ночью я буду следить за огнями и кораблями.","map_pos":Vector2(695,510)},
		{"id":"merchant","name":"Торговец","role":"Хозяин лавки","icon":"🧑‍💼","text":"Восстановите остров полностью — и я открою редкие товары.","map_pos":Vector2(380,425)}
	]
	for npc in definitions:
		if bool(discovered_npcs.get(str(npc["id"]), false)):
			result.append(npc)
	return result

func get_chests() -> Array:
	var result: Array = []
	if is_repaired("pirate_cove"):
		result.append({"id":"pirate_chest","name":"Пиратский сундук","icon":"🎁","map_pos":Vector2(730,330),"reward":{"stars":3,"booster":"shuffle","amount":2}})
	if is_repaired("secret_cave"):
		result.append({"id":"cave_chest","name":"Сундук тайной пещеры","icon":"💎","map_pos":Vector2(500,330),"reward":{"stars":5,"booster":"hammer","amount":2}})
	if is_repaired("old_village"):
		result.append({"id":"village_chest","name":"Сундук деревни","icon":"🧰","map_pos":Vector2(330,330),"reward":{"stars":7,"booster":"extra_moves","amount":3}})
	return result

func is_chest_claimed(id: String) -> bool:
	return bool(claimed_chests.get(id, false))

func claim_chest(id: String) -> Dictionary:
	if is_chest_claimed(id):
		return {"ok":false,"reason":"claimed"}
	for chest in get_chests():
		if str(chest["id"]) == id:
			claimed_chests[id] = true
			save()
			return {"ok":true,"reward":chest["reward"],"chest":chest}
	return {"ok":false,"reason":"locked"}


func _quest_chain_for(id: String) -> Array:
	var chains := {
		"lisa": [
			{"id":"lisa_stage_1","title":"Пляж снова оживает","description":"Пройдите 5 новых уровней после разговора с Лизой. Она хочет проверить, что остров снова начинает жить.","kind":"completed_levels","target":5,"reward":{"stars":2,"booster":"hammer","amount":1}},
			{"id":"lisa_stage_2","title":"Дорога к джунглям","description":"Откройте ещё 1 новую зону острова. Лиза хочет убедиться, что восстановленный пляж связан с остальным островом.","kind":"zones","target":1,"reward":{"stars":3,"booster":"extra_moves","amount":1}},
			{"id":"lisa_stage_3","title":"Сердце пляжа","description":"Восстановите ещё 2 объекта. После этого Лиза передаст вам знак хранительницы острова.","kind":"repaired_objects","target":2,"reward":{"stars":5,"booster":"","amount":0,"unique":"lisa_badge","unique_name":"Знак хранительницы","unique_icon":"🏵️"}}
		],
		"tom": [
			{"id":"tom_stage_1","title":"Проверка маршрута","description":"Пройдите 5 новых уровней и помогите Тому проверить, какие морские пути снова доступны.","kind":"completed_levels","target":5,"reward":{"stars":2,"booster":"shuffle","amount":1}},
			{"id":"tom_stage_2","title":"След пиратов","description":"Откройте ещё 1 зону. Том заметил следы старого пиратского маршрута.","kind":"zones","target":1,"reward":{"stars":3,"booster":"pre_bomb","amount":1}},
			{"id":"tom_stage_3","title":"Полный морской журнал","description":"Восстановите ещё 2 объекта и помогите Тому закончить карту старых маршрутов.","kind":"repaired_objects","target":2,"reward":{"stars":6,"booster":"pre_rainbow","amount":1,"unique":"tom_log","unique_name":"Старый морской журнал","unique_icon":"📘"}}
		],
		"keeper": [
			{"id":"keeper_stage_1","title":"Огонь маяка","description":"Откройте ещё 1 зону. Смотритель хочет увидеть, куда теперь может доходить свет маяка.","kind":"zones","target":1,"reward":{"stars":2,"booster":"extra_moves","amount":1}},
			{"id":"keeper_stage_2","title":"Свет над бухтой","description":"Восстановите ещё 1 объект и верните свету маяка безопасный путь к берегу.","kind":"repaired_objects","target":1,"reward":{"stars":4,"booster":"hammer","amount":1}},
			{"id":"keeper_stage_3","title":"Ночной дозор","description":"Пройдите 10 новых уровней. После этого смотритель вручит вам ключ от маяка.","kind":"completed_levels","target":10,"reward":{"stars":7,"booster":"shuffle","amount":2,"unique":"keeper_key","unique_name":"Ключ от маяка","unique_icon":"🗝️"}}
		],
		"merchant": [
			{"id":"merchant_stage_1","title":"Новые покупатели","description":"Пройдите 10 новых уровней. Торговец хочет проверить, появляется ли спрос после восстановления деревни.","kind":"completed_levels","target":10,"reward":{"stars":3,"booster":"pre_bomb","amount":1}},
			{"id":"merchant_stage_2","title":"Большая поставка","description":"Пройдите ещё 15 уровней и докажите торговцу, что остров готов принимать большие поставки.","kind":"completed_levels","target":15,"reward":{"stars":5,"booster":"extra_moves","amount":1}},
			{"id":"merchant_stage_3","title":"Лавка острова","description":"Пройдите ещё 25 уровней. После этого торговец откроет свой особый жетон восстановления острова.","kind":"completed_levels","target":25,"reward":{"stars":10,"booster":"pre_rainbow","amount":2,"unique":"merchant_token","unique_name":"Серебряный жетон торговца","unique_icon":"🪙"}}
		]
	}
	return chains.get(id, [])

func get_npc_quest(id: String) -> Dictionary:
	var chain := _quest_chain_for(id)
	if chain.is_empty():
		return {}
	return chain[0]

func _quest_state_text() -> String:
	var values := PackedStringArray()
	for id in quest_chain_state.keys():
		var state:Dictionary = quest_chain_state[id]
		values.append("%s:%d:%d:%d:%d" % [
			str(id),
			int(state.get("stage",0)),
			1 if bool(state.get("active",false)) else 0,
			int(state.get("base_levels",0)),
			int(state.get("base_zones",0)),
			int(state.get("base_objects",0))
		])
	return ";".join(values)

func _load_quest_state(value:String) -> void:
	if value.is_empty():
		return
	for item in value.split(";"):
		var parts := item.split(":")
		if parts.size() != 6:
			continue
		var id := str(parts[0])
		if id.is_empty():
			continue
		quest_chain_state[id] = {
			"stage": int(parts[1]),
			"active": parts[2] == "1",
			"base_levels": int(parts[3]),
			"base_zones": int(parts[4]),
			"base_objects": int(parts[5])
		}

func _migrate_legacy_quests() -> void:
	var legacy := {
		"lisa_restore":"lisa",
		"tom_journey":"tom",
		"keeper_light":"keeper",
		"merchant_restore":"merchant"
	}
	var changed := false
	for old_id in legacy.keys():
		var npc_id := str(legacy[old_id])
		if bool(claimed_quests.get(old_id,false)) and not quest_chain_state.has(npc_id):
			# Старое одноразовое задание уже выдано; начинаем сразу со 2-го этапа.
			quest_chain_state[npc_id] = {
				"stage":1,
				"active":false,
				"base_levels":0,
				"base_zones":0,
				"base_objects":0
			}
			changed = true
	if changed:
		save()

func _metric_for(kind:String, completed_levels:int, unlocked_zones:int, repaired_objects:int) -> int:
	match kind:
		"completed_levels":
			return completed_levels
		"zones":
			return unlocked_zones
		"repaired_objects":
			return repaired_objects
	return 0

func get_quest_status(id: String, completed_levels: int, unlocked_zones: int, repaired_objects: int) -> Dictionary:
	var chain := _quest_chain_for(id)
	if chain.is_empty():
		return {}
	if not quest_chain_state.has(id):
		quest_chain_state[id] = {
			"stage":0,
			"active":false,
			"base_levels":0,
			"base_zones":0,
			"base_objects":0
		}
	var state:Dictionary = quest_chain_state[id]
	var stage := int(state.get("stage",0))
	if stage >= chain.size():
		return {
			"quest":chain[chain.size()-1],
			"stage":chain.size(),
			"stage_count":chain.size(),
			"current":int(chain[chain.size()-1]["target"]),
			"target":int(chain[chain.size()-1]["target"]),
			"done":true,
			"claimed":true,
			"chain_done":true
		}
	if not bool(state.get("active",false)):
		state["active"] = true
		state["base_levels"] = completed_levels
		state["base_zones"] = unlocked_zones
		state["base_objects"] = repaired_objects
		quest_chain_state[id] = state
		save()
	var quest:Dictionary = chain[stage]
	var metric := _metric_for(str(quest["kind"]),completed_levels,unlocked_zones,repaired_objects)
	var baseline := 0
	match str(quest["kind"]):
		"completed_levels":
			baseline = int(state.get("base_levels",0))
		"zones":
			baseline = int(state.get("base_zones",0))
		"repaired_objects":
			baseline = int(state.get("base_objects",0))
	var current := maxi(0,metric-baseline)
	var target := int(quest["target"])
	return {
		"quest":quest,
		"stage":stage+1,
		"stage_count":chain.size(),
		"current":mini(current,target),
		"target":target,
		"done":current>=target,
		"claimed":false,
		"chain_done":false
	}

func claim_npc_quest(id: String, completed_levels: int, unlocked_zones: int, repaired_objects: int) -> Dictionary:
	var state := get_quest_status(id,completed_levels,unlocked_zones,repaired_objects)
	if state.is_empty():
		return {"ok":false,"reason":"unknown"}
	if bool(state.get("chain_done",false)):
		return {"ok":false,"reason":"claimed"}
	if not bool(state.get("done",false)):
		return {"ok":false,"reason":"not_done","current":int(state["current"]),"target":int(state["target"])}
	var quest:Dictionary = state["quest"]
	var reward:Dictionary = quest["reward"]
	claimed_quests[str(quest["id"])] = true
	var final_stage := int(state["stage"]) >= int(state["stage_count"])
	if final_stage and reward.has("unique"):
		unique_rewards[str(reward["unique"])] = true
	var next_stage := int(state["stage"]) # 1-based; final remains at stage_count.
	var raw_state:Dictionary = quest_chain_state[id]
	if final_stage:
		raw_state["stage"] = int(state["stage_count"])
	else:
		raw_state["stage"] = int(state["stage"])
	raw_state["active"] = false
	raw_state["base_levels"] = completed_levels
	raw_state["base_zones"] = unlocked_zones
	raw_state["base_objects"] = repaired_objects
	quest_chain_state[id] = raw_state
	save()
	return {
		"ok":true,
		"reward":reward,
		"quest":quest,
		"stage":int(state["stage"]),
		"stage_count":int(state["stage_count"]),
		"final":final_stage,
		"next_stage":next_stage
	}

func get_unique_rewards() -> Array:
	return [
		{"id":"lisa_badge","name":"Знак хранительницы","icon":"🏵️","npc_id":"lisa"},
		{"id":"tom_log","name":"Старый морской журнал","icon":"📘","npc_id":"tom"},
		{"id":"keeper_key","name":"Ключ от маяка","icon":"🗝️","npc_id":"keeper"},
		{"id":"merchant_token","name":"Серебряный жетон торговца","icon":"🪙","npc_id":"merchant"}
	]

func get_unique_reward_count() -> int:
	var count := 0
	for reward in get_unique_rewards():
		if bool(unique_rewards.get(str(reward["id"]),false)):
			count += 1
	return count

func is_unique_reward_unlocked(id:String) -> bool:
	return bool(unique_rewards.get(id,false))

func get_secrets() -> Array:
	return [
		{"id":"bottle","name":"Послание в бутылке","icon":"🍾","zone":0,"map_pos":Vector2(125,175),"description":"Старая бутылка на пляже.","reward":{"stars":2,"booster":"extra_moves","amount":1}},
		{"id":"parrot_nest","name":"Гнездо попугая","icon":"🥚","zone":1,"map_pos":Vector2(320,135),"description":"Попугай спрятал здесь блестящую вещь.","reward":{"stars":2,"booster":"shuffle","amount":1}},
		{"id":"ancient_statue","name":"Древняя статуя","icon":"🗿","zone":4,"map_pos":Vector2(610,430),"description":"На статуе видны старые символы острова.","reward":{"stars":4,"booster":"pre_rainbow","amount":1}}
	]

func get_secret(id: String) -> Dictionary:
	for secret in get_secrets():
		if str(secret["id"])==id:
			return secret
	return {}

func is_secret_available(secret: Dictionary) -> bool:
	return is_zone_unlocked(int(secret.get("zone",0)))

func is_secret_claimed(id: String) -> bool:
	return bool(claimed_secrets.get(id,false))

func claim_secret(id: String) -> Dictionary:
	if is_secret_claimed(id):
		return {"ok":false,"reason":"claimed"}
	var secret:=get_secret(id)
	if secret.is_empty():
		return {"ok":false,"reason":"unknown"}
	if not is_secret_available(secret):
		return {"ok":false,"reason":"locked"}
	claimed_secrets[id]=true
	save()
	return {"ok":true,"secret":secret,"reward":secret["reward"]}

func get_progress_text() -> String:
	return "%d / %d объектов восстановлено • %d / %d зон открыто" % [repaired.size(),objects.size(),get_unlocked_zone_count(),zones.size()]

func reset_for_tests() -> void:
	repaired.clear()
	claimed_chests.clear()
	discovered_npcs.clear()
	claimed_quests.clear()
	claimed_secrets.clear()
	quest_chain_state.clear()
	unique_rewards.clear()
