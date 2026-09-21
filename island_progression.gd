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
var completed_events: Dictionary = {}
var claimed_interactives: Dictionary = {}
var completed_activities: Dictionary = {}
var completed_secret_activities: Dictionary = {}
var claimed_collection_rewards: Dictionary = {}
var claimed_secret_collection_reward: bool = false

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
		var values: Array = pair[1].split(",") if not pair[1].is_empty() else []
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
		elif key == "events":
			for id in values:
				if not id.is_empty():
					completed_events[id] = true
		elif key == "interactives":
			for id in values:
				if not id.is_empty():
					claimed_interactives[id] = true
		elif key == "activities":
			for id in values:
				if not id.is_empty():
					completed_activities[id] = true
		elif key == "collection_rewards":
			for id in values:
				if not id.is_empty():
					claimed_collection_rewards[id] = true
		elif key == "secret_activities":
			for id in values:
				if not id.is_empty():
					completed_secret_activities[id] = true
		elif key == "secret_collection_reward":
			claimed_secret_collection_reward = pair[1] == "true"
	_migrate_legacy_quests()

func dev_complete_all() -> void:
	for item in objects:
		repaired[str(item["id"])] = true
	for npc_id in ["lisa","tom","keeper","merchant"]:
		discovered_npcs[npc_id] = true
		var chain:Array = _quest_chain_for(npc_id)
		quest_chain_state[npc_id] = {
			"stage":chain.size(),
			"active":false,
			"base_levels":0,
			"base_zones":0,
			"base_objects":0
		}
		for quest in chain:
			claimed_quests[str(quest["id"])] = true
	for item in get_collection_items():
		var item_id:=str(item["id"])
		if str(item.get("kind",""))=="unique":
			unique_rewards[item_id]=true
	for activity in get_mini_activities():
		completed_activities[str(activity["id"])] = true
	for activity in get_secret_mini_activities():
		completed_secret_activities[str(activity["id"])] = true
	for milestone in get_collection_milestones():
		claimed_collection_rewards[str(milestone["id"])] = true
	claimed_secret_collection_reward = true
	for event in get_island_events():
		completed_events[str(event["id"])] = true
	for item in get_interactive_objects():
		claimed_interactives[str(item["id"])] = true
	for secret in get_secrets():
		claimed_secrets[str(secret["id"])] = true
	for chest in get_chests():
		claimed_chests[str(chest["id"])] = true
	save()

func save() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if not file:
		return
	file.store_string("repaired=%s|chests=%s|npcs=%s|quests=%s|secrets=%s|queststate=%s|unique=%s|events=%s|interactives=%s|activities=%s|collection_rewards=%s|secret_activities=%s|secret_collection_reward=%s" % [
		_keys_text(repaired),
		_keys_text(claimed_chests),
		_keys_text(discovered_npcs),
		_keys_text(claimed_quests),
		_keys_text(claimed_secrets),
		_quest_state_text(),
		_keys_text(unique_rewards),
		_keys_text(completed_events),
		_keys_text(claimed_interactives),
		_keys_text(completed_activities),
		_keys_text(claimed_collection_rewards),
		_keys_text(completed_secret_activities),
		str(claimed_secret_collection_reward)
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
	if get_secret_collection_count() >= get_secret_collection_total() and is_secret_collection_reward_claimed():
		result.append({"id":"secret_island_chest","name":"Тайный сундук острова","icon":"💠","map_pos":Vector2(455,575),"reward":{"stars":12,"booster":"pre_rainbow","amount":2}})
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

func get_npc_quest_dialogue(id:String, stage:int, chain_done:bool=false) -> String:
	var dialogues := {
		"lisa":[
			"Спасибо, что вернулись. Давайте убедимся, что пляж снова становится живым.",
			"Отсюда уже видны джунгли. Ещё немного восстановления — и остров снова соединится в единое целое.",
			"Ты сделал для пляжа больше, чем я могла представить. Возьми этот знак хранительницы — теперь у острова есть настоящий защитник.",
			"Пляж снова живёт благодаря тебе. Этот остров тебя не забудет."
		],
		"tom":[
			"Я проверю море, а ты помоги мне пройти новые маршруты на острове.",
			"Следы ведут к пиратской стороне. Похоже, старые маршруты скрывают ещё одну тайну.",
			"Теперь журнал заполнен. В нём есть места, которые мы ещё обязательно исследуем.",
			"Мой журнал закончен. Когда будешь готов, море всё ещё будет ждать."
		],
		"keeper":[
			"Луч маяка должен видеть новые территории. Открой путь — я проверю дальность света.",
			"Свет уже проходит дальше, но один участок всё ещё закрыт. Восстанови его, и маяк заработает по-настоящему.",
			"Теперь ночной дозор безопасен. Остров снова виден с моря — возьми ключ от маяка.",
			"Маяк горит всю ночь. Спасибо, что вернул острову этот свет."
		],
		"merchant":[
			"Деревня открыта, но торговля только начинается. Посмотрим, сколько новых путешественников доберётся сюда.",
			"Поставка почти готова. Ещё немного работы — и моя лавка сможет снабжать весь остров.",
			"Теперь здесь можно торговать по-настоящему. Этот жетон подтверждает, что остров снова жив.",
			"Лавка открыта, а остров восстановлен. Приходи, когда понадобятся редкие товары."
		]
	}
	if not dialogues.has(id):
		return ""
	var list:Array = dialogues[id]
	var index := stage - 1
	if chain_done:
		index = list.size() - 1
	index = clampi(index,0,list.size()-1)
	return str(list[index])

func _quest_state_text() -> String:
	var values := PackedStringArray()
	for id in quest_chain_state.keys():
		var state:Dictionary = quest_chain_state[id]
		values.append("%s:%d:%d:%d:%d:%d" % [
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
	var next_stage := int(state["stage"]) + (0 if final_stage else 1) # 1-based; final remains at stage_count.
	var raw_state:Dictionary = quest_chain_state[id]
	if final_stage:
		raw_state["stage"] = int(state["stage_count"])
		raw_state["active"] = false
	else:
		# Новый этап начинается прямо в момент выдачи предыдущей награды.
		raw_state["stage"] = int(state["stage"])
		raw_state["active"] = true
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

func get_permanent_bonuses() -> Dictionary:
	var result := {
		"start_moves":0,
		"late_start_moves":0,
		"score_percent":0,
		"three_star_bonus":0
	}
	if is_unique_reward_unlocked("lisa_badge"):
		result["start_moves"] += 1
	if is_unique_reward_unlocked("tom_log"):
		result["score_percent"] += 5
	if is_unique_reward_unlocked("keeper_key"):
		result["late_start_moves"] += 1
	if is_unique_reward_unlocked("merchant_token"):
		result["three_star_bonus"] += 1
	return result

func get_start_move_bonus(level_index:int) -> int:
	var bonuses := get_permanent_bonuses()
	var result := int(bonuses["start_moves"])
	if level_index >= 70:
		result += int(bonuses["late_start_moves"])
	return result

func get_score_multiplier() -> float:
	var bonuses := get_permanent_bonuses()
	return 1.0 + float(bonuses["score_percent"]) / 100.0

func get_three_star_bonus() -> int:
	return int(get_permanent_bonuses()["three_star_bonus"])

func get_permanent_bonus_text() -> String:
	var parts := PackedStringArray()
	var bonuses := get_permanent_bonuses()
	if int(bonuses["start_moves"]) > 0:
		parts.append("+%d ход в начале каждого уровня" % int(bonuses["start_moves"]))
	if int(bonuses["late_start_moves"]) > 0:
		parts.append("+%d дополнительный ход на уровнях 71–100" % int(bonuses["late_start_moves"]))
	if int(bonuses["score_percent"]) > 0:
		parts.append("+%d%% к очкам" % int(bonuses["score_percent"]))
	if int(bonuses["three_star_bonus"]) > 0:
		parts.append("+%d ⭐ за первое получение 3★ на уровне" % int(bonuses["three_star_bonus"]))
	if parts.is_empty():
		return "Постоянные преимущества ещё не открыты."
	return " • ".join(parts)

func get_island_events() -> Array:
	return [
		{
			"id":"lisa_festival",
			"npc_id":"lisa",
			"name":"Праздник пляжа",
			"icon":"🎊",
			"zone":0,
			"map_pos":Vector2(145,205),
			"description":"Лиза устраивает небольшой праздник после полного восстановления своей цепочки.",
			"reward":{"stars":2,"booster":"extra_moves","amount":1},
			"unique_required":"lisa_badge",
			"event_text":"На пляже снова звучит музыка. Лиза благодарит тебя и обещает следить за островом."
		},
		{
			"id":"tom_route",
			"npc_id":"tom",
			"name":"Старый морской маршрут",
			"icon":"🧭",
			"zone":3,
			"map_pos":Vector2(700,300),
			"description":"Том ведёт тебя к старому пиратскому маршруту у бухты.",
			"reward":{"stars":3,"booster":"shuffle","amount":1},
			"unique_required":"tom_log",
			"event_text":"В старом журнале находится отметка. Том показывает путь к месту, где когда-то прятали груз."
		},
		{
			"id":"keeper_night",
			"npc_id":"keeper",
			"name":"Ночной маяк",
			"icon":"🌙",
			"zone":3,
			"map_pos":Vector2(730,430),
			"description":"После полного ремонта маяка смотритель проводит первый ночной запуск.",
			"reward":{"stars":2,"booster":"pre_rainbow","amount":1},
			"unique_required":"keeper_key",
			"event_text":"Маяк вспыхивает над морем. Теперь остров снова виден кораблям даже в тумане."
		},
		{
			"id":"merchant_market",
			"npc_id":"merchant",
			"name":"Открытие лавки",
			"icon":"🛍️",
			"zone":5,
			"map_pos":Vector2(315,450),
			"description":"Торговец открывает восстановленную лавку и приглашает первых покупателей.",
			"reward":{"stars":4,"booster":"hammer","amount":1},
			"unique_required":"merchant_token",
			"event_text":"Первые товары раскладываются на полках. Торговец объявляет остров официально открытым для торговли."
		},
		{
			"id":"island_heart",
			"npc_id":"",
			"name":"Сердце острова",
			"icon":"🌺",
			"zone":5,
			"map_pos":Vector2(455,555),
			"description":"Полная коллекция острова открывает тайник, который раньше был скрыт от всех путников.",
			"reward":{"stars":15,"booster":"pre_rainbow","amount":2},
			"unique_required":"",
			"collection_required":8,
			"event_text":"Все найденные предметы складываются в древний механизм. В центре острова раскрывается тайник — знак того, что ни одна тайна острова не осталась нераскрытой."
		}
	]

func get_island_event(id:String) -> Dictionary:
	for event in get_island_events():
		if str(event["id"]) == id:
			return event
	return {}

func is_event_available(event:Dictionary) -> bool:
	var required := str(event.get("unique_required",""))
	if required.is_empty() or not is_unique_reward_unlocked(required):
		return false
	if not is_zone_unlocked(int(event.get("zone",0))):
		return false
	var collection_required := int(event.get("collection_required",0))
	if collection_required > 0 and get_collection_count() < collection_required:
		return false
	return not bool(completed_events.get(str(event["id"]),false))

func get_available_events() -> Array:
	var result:Array = []
	for event in get_island_events():
		if is_event_available(event):
			result.append(event)
	return result

func is_event_completed(id:String) -> bool:
	return bool(completed_events.get(id,false))

func claim_island_event(id:String) -> Dictionary:
	var event := get_island_event(id)
	if event.is_empty():
		return {"ok":false,"reason":"unknown"}
	if not is_event_available(event):
		if is_event_completed(id):
			return {"ok":false,"reason":"completed"}
		return {"ok":false,"reason":"locked"}
	completed_events[id] = true
	save()
	return {"ok":true,"event":event,"reward":event["reward"]}

func get_interactive_objects() -> Array:
	return [
		{
			"id":"beach_watch_lantern",
			"name":"Фонарь хранительницы",
			"icon":"🏮",
			"zone":0,
			"map_pos":Vector2(190,160),
			"unique_required":"lisa_badge",
			"description":"Знак Лизы открывает старый сигнальный фонарь. Его можно включить только после восстановления пляжа.",
			"reward":{"stars":1,"booster":"extra_moves","amount":1}
		},
		{
			"id":"pirate_chart_table",
			"name":"Стол старого маршрута",
			"icon":"🗺️",
			"zone":3,
			"map_pos":Vector2(675,340),
			"unique_required":"tom_log",
			"description":"Старый журнал Тома позволяет сверить карту с настоящими отметками пиратов.",
			"reward":{"stars":2,"booster":"shuffle","amount":1}
		},
		{
			"id":"cave_ancient_lock",
			"name":"Древний замок",
			"icon":"🔐",
			"zone":4,
			"map_pos":Vector2(620,475),
			"unique_required":"keeper_key",
			"description":"Ключ от маяка подходит к механизму внутри пещеры.",
			"reward":{"stars":3,"booster":"hammer","amount":1}
		},
		{
			"id":"village_trade_scale",
			"name":"Старая торговая мера",
			"icon":"⚖️",
			"zone":5,
			"map_pos":Vector2(430,475),
			"unique_required":"merchant_token",
			"description":"Жетон торговца активирует старую систему учёта товаров в деревне.",
			"reward":{"stars":4,"booster":"pre_bomb","amount":1}
		}
	]

func get_interactive_object(id:String) -> Dictionary:
	for item in get_interactive_objects():
		if str(item["id"]) == id:
			return item
	return {}

func is_interactive_available(item:Dictionary) -> bool:
	var required := str(item.get("unique_required",""))
	if required.is_empty() or not is_unique_reward_unlocked(required):
		return false
	if not is_zone_unlocked(int(item.get("zone",0))):
		return false
	return not bool(claimed_interactives.get(str(item["id"]),false))

func is_interactive_completed(id:String) -> bool:
	return bool(claimed_interactives.get(id,false))

func get_available_interactives() -> Array:
	var result:Array = []
	for item in get_interactive_objects():
		if is_interactive_available(item):
			result.append(item)
	return result

func claim_interactive(id:String) -> Dictionary:
	var item := get_interactive_object(id)
	if item.is_empty():
		return {"ok":false,"reason":"unknown"}
	if not is_interactive_available(item):
		if bool(claimed_interactives.get(id,false)):
			return {"ok":false,"reason":"claimed"}
		return {"ok":false,"reason":"locked"}
	claimed_interactives[id]=true
	save()
	return {"ok":true,"item":item,"reward":item["reward"]}

func get_mini_activities() -> Array:
	return [
		{
			"id":"pirate_navigation",
			"name":"Навигация контрабандистов",
			"icon":"🧭",
			"zone":3,
			"map_pos":Vector2(585,275),
			"unique_required":"tom_log",
			"type":"sequence",
			"variant":"compass",
			"sequence":[0,2,3,1],
			"labels":["↑","→","←","↓"],
			"description":"Повтори четыре направления со старой карты, чтобы открыть пиратский маршрут.",
			"reward":{"stars":3,"booster":"pre_bomb","amount":1},
			"collection_id":"pirate_chart"
		},
		{
			"id":"cave_runes",
			"name":"Руны древнего механизма",
			"icon":"🔮",
			"zone":4,
			"map_pos":Vector2(585,450),
			"unique_required":"keeper_key",
			"type":"odd_one",
			"variant":"rune",
			"target_index":3,
			"labels":["☀","☀","☀","☽","☀"],
			"description":"Среди одинаковых рун спрятана одна лунная. Найди её и активируй первой.",
			"reward":{"stars":4,"booster":"pre_rainbow","amount":1},
			"collection_id":"cave_rune"
		},
		{
			"id":"village_market",
			"name":"Первые товары",
			"icon":"🛒",
			"zone":5,
			"map_pos":Vector2(340,470),
			"unique_required":"merchant_token",
			"type":"collect_three",
			"variant":"goods",
			"labels":["🐟 Рыба","🪵 Дерево","🌿 Травы"],
			"description":"Подготовь три товара для открытия лавки. Нажми каждый товар один раз.",
			"reward":{"stars":5,"booster":"extra_moves","amount":2},
			"collection_id":"market_goods"
		},
		{
			"id":"village_trade_route",
			"name":"Порядок поставок",
			"icon":"📦",
			"zone":5,
			"map_pos":Vector2(465,470),
			"unique_required":"merchant_token",
			"type":"order_goods",
			"variant":"trade_order",
			"sequence":[2,0,1],
			"labels":["🌿 Травы","🐟 Рыба","🪵 Дерево"],
			"description":"Торговец дал список поставки. Отправь товары строго в указанном порядке.",
			"reward":{"stars":3,"booster":"shuffle","amount":1},
			"collection_id":"trade_route"
		}
	]

func get_secret_mini_activities() -> Array:
	return [
		{
			"id":"pirate_navigation_secret",
			"name":"Тайный курс контрабандистов",
			"icon":"💠",
			"zone":3,
			"map_pos":Vector2(620,320),
			"unique_required":"tom_log",
			"normal_required":"pirate_navigation",
			"type":"sequence",
			"variant":"secret_compass",
			"sequence":[1,3,0,2],
			"labels":["↗","↖","↓","←"],
			"description":"Редкая запись в журнале Тома. Повтори скрытый маршрут, который виден только после прохождения основной навигации.",
			"reward":{"stars":6,"booster":"pre_bomb","amount":2},
			"secret_reward":{"id":"pirate_compass","name":"Компас тайного курса","icon":"🧭"}
		},
		{
			"id":"cave_runes_secret",
			"name":"Запечатанная руна",
			"icon":"💠",
			"zone":4,
			"map_pos":Vector2(650,500),
			"unique_required":"keeper_key",
			"normal_required":"cave_runes",
			"type":"odd_one",
			"variant":"secret_rune",
			"target_index":4,
			"labels":["☽","☽","☽","☽","✦"],
			"description":"За обычной руной скрывается редкий символ. Найди единственную звёздную руну, пока механизм снова не запечатался.",
			"reward":{"stars":7,"booster":"pre_rainbow","amount":2},
			"secret_reward":{"id":"sealed_rune","name":"Запечатанная руна","icon":"✦"}
		},
		{
			"id":"village_trade_secret",
			"name":"Секретная поставка",
			"icon":"💠",
			"zone":5,
			"map_pos":Vector2(520,520),
			"unique_required":"merchant_token",
			"normal_required":"village_trade_route",
			"type":"order_goods",
			"variant":"secret_trade",
			"sequence":[3,1,0,2],
			"labels":["🧺 Припасы","🐟 Рыба","🌿 Травы","🪵 Дерево"],
			"description":"Торговец открывает скрытый список поставки. Отправь четыре позиции в точном порядке.",
			"reward":{"stars":8,"booster":"extra_moves","amount":3},
			"secret_reward":{"id":"merchant_seal","name":"Печать тайной торговли","icon":"🔱"}
		}
	]

func get_mini_activity(id:String) -> Dictionary:
	for item in get_mini_activities():
		if str(item["id"]) == id:
			return item
	for item in get_secret_mini_activities():
		if str(item["id"]) == id:
			return item
	return {}

func is_secret_activity_completed(id:String) -> bool:
	return bool(completed_secret_activities.get(id,false))

func is_secret_activity_available(item:Dictionary) -> bool:
	if item.is_empty():
		return false
	if not is_zone_unlocked(int(item.get("zone",0))):
		return false
	var required := str(item.get("unique_required",""))
	if required.is_empty() or not is_unique_reward_unlocked(required):
		return false
	var normal_id := str(item.get("normal_required",""))
	if normal_id.is_empty() or not is_activity_completed(normal_id):
		return false
	return not is_secret_activity_completed(str(item["id"]))

func get_available_secret_activities() -> Array:
	var result:Array=[]
	for item in get_secret_mini_activities():
		if is_secret_activity_available(item):
			result.append(item)
	return result

func claim_secret_activity(id:String) -> Dictionary:
	var item:Dictionary={}
	for candidate in get_secret_mini_activities():
		if str(candidate["id"]) == id:
			item=candidate
			break
	if item.is_empty():
		return {"ok":false,"reason":"unknown"}
	if not is_secret_activity_available(item):
		if is_secret_activity_completed(id):
			return {"ok":false,"reason":"completed"}
		return {"ok":false,"reason":"locked"}
	completed_secret_activities[id]=true
	save()
	return {"ok":true,"activity":item,"reward":item["reward"],"secret_reward":item["secret_reward"]}


func is_activity_available(item:Dictionary) -> bool:
	var required := str(item.get("unique_required",""))
	if required.is_empty() or not is_unique_reward_unlocked(required):
		return false
	if not is_zone_unlocked(int(item.get("zone",0))):
		return false
	return not bool(completed_activities.get(str(item["id"]),false))

func get_available_activities() -> Array:
	var result:Array = []
	for item in get_mini_activities():
		if is_activity_available(item):
			result.append(item)
	return result

func is_activity_completed(id:String) -> bool:
	return bool(completed_activities.get(id,false))

func claim_mini_activity(id:String) -> Dictionary:
	for secret in get_secret_mini_activities():
		if str(secret["id"]) == id:
			return claim_secret_activity(id)
	var item := get_mini_activity(id)
	if item.is_empty():
		return {"ok":false,"reason":"unknown"}
	if not is_activity_available(item):
		if is_activity_completed(id):
			return {"ok":false,"reason":"completed"}
		return {"ok":false,"reason":"locked"}
	completed_activities[id]=true
	save()
	return {"ok":true,"activity":item,"reward":item["reward"]}

func get_secret_collection_items() -> Array:
	return [
		{"id":"pirate_compass","name":"Компас тайного курса","icon":"🧭"},
		{"id":"sealed_rune","name":"Запечатанная руна","icon":"✦"},
		{"id":"merchant_seal","name":"Печать тайной торговли","icon":"🔱"}
	]

func is_secret_collection_item_collected(id:String) -> bool:
	for activity in get_secret_mini_activities():
		var reward:Dictionary=activity.get("secret_reward",{})
		if str(reward.get("id","")) == id:
			return is_secret_activity_completed(str(activity["id"]))
	return false

func get_secret_collection_count() -> int:
	var count:=0
	for item in get_secret_collection_items():
		if is_secret_collection_item_collected(str(item["id"])):
			count += 1
	return count

func get_secret_collection_total() -> int:
	return get_secret_collection_items().size()

func get_secret_collection_text() -> String:
	return "%d / %d секретных наград"%[get_secret_collection_count(),get_secret_collection_total()]

func is_secret_collection_reward_claimed() -> bool:
	return claimed_secret_collection_reward

func is_secret_collection_reward_available() -> bool:
	return get_secret_collection_count() >= get_secret_collection_total() and not claimed_secret_collection_reward

func claim_secret_collection_reward() -> Dictionary:
	if claimed_secret_collection_reward:
		return {"ok":false,"reason":"claimed"}
	if get_secret_collection_count() < get_secret_collection_total():
		return {"ok":false,"reason":"locked"}
	claimed_secret_collection_reward = true
	save()
	return {
		"ok":true,
		"reward":{"stars":10,"booster":"pre_bomb","amount":1},
		"title":"Секретная коллекция завершена",
		"description":"Все три редких трофея найдены. Тайник острова теперь открыт."
	}

func get_collection_items() -> Array:
	return [
		{"id":"lisa_badge","name":"Знак хранительницы","icon":"🏵️","kind":"unique"},
		{"id":"tom_log","name":"Старый морской журнал","icon":"📘","kind":"unique"},
		{"id":"keeper_key","name":"Ключ от маяка","icon":"🗝️","kind":"unique"},
		{"id":"merchant_token","name":"Серебряный жетон торговца","icon":"🪙","kind":"unique"},
		{"id":"pirate_chart","name":"Карта контрабандистов","icon":"🧭","kind":"activity"},
		{"id":"cave_rune","name":"Лунная руна","icon":"☽","kind":"activity"},
		{"id":"market_goods","name":"Первый торговый набор","icon":"🧺","kind":"activity"},
		{"id":"trade_route","name":"Маршрут поставки","icon":"📦","kind":"activity"}
	]

func is_collection_item_collected(id:String) -> bool:
	if is_unique_reward_unlocked(id):
		return true
	for activity in get_mini_activities():
		if str(activity.get("collection_id","")) == id:
			return is_activity_completed(str(activity["id"]))
	return false

func get_collection_count() -> int:
	var count:=0
	for item in get_collection_items():
		if is_collection_item_collected(str(item["id"])):
			count += 1
	return count

func get_collection_total() -> int:
	return get_collection_items().size()

func get_collection_completion_text() -> String:
	return "%d / %d коллекционных предметов"%[get_collection_count(),get_collection_total()]

func get_collection_milestones() -> Array:
	return [
		{
			"id":"collection_25",
			"title":"Первая коллекция",
			"description":"Соберите 25% предметов острова.",
			"threshold":2,
			"reward":{"stars":3,"booster":"shuffle","amount":1}
		},
		{
			"id":"collection_50",
			"title":"Половина архива",
			"description":"Соберите 50% предметов острова.",
			"threshold":4,
			"reward":{"stars":5,"booster":"hammer","amount":1}
		},
		{
			"id":"collection_75",
			"title":"Хроника острова",
			"description":"Соберите 75% предметов острова.",
			"threshold":6,
			"reward":{"stars":7,"booster":"pre_rainbow","amount":1}
		},
		{
			"id":"collection_100",
			"title":"Полная коллекция",
			"description":"Соберите все предметы острова.",
			"threshold":8,
			"reward":{"stars":10,"booster":"extra_moves","amount":2}
		}
	]

func is_collection_milestone_claimed(id:String) -> bool:
	return bool(claimed_collection_rewards.get(id,false))

func is_collection_milestone_available(milestone:Dictionary) -> bool:
	if milestone.is_empty():
		return false
	return get_collection_count() >= int(milestone.get("threshold",999)) and not is_collection_milestone_claimed(str(milestone["id"]))

func get_collection_milestone_status(id:String) -> Dictionary:
	for milestone in get_collection_milestones():
		if str(milestone["id"]) == id:
			var threshold:=int(milestone["threshold"])
			var count:=get_collection_count()
			return {
				"milestone":milestone,
				"claimed":is_collection_milestone_claimed(id),
				"available":is_collection_milestone_available(milestone),
				"progress":min(count,threshold),
				"threshold":threshold
			}
	return {}

func get_available_collection_milestones() -> Array:
	var result:Array=[]
	for milestone in get_collection_milestones():
		if is_collection_milestone_available(milestone):
			result.append(milestone)
	return result

func claim_collection_milestone(id:String) -> Dictionary:
	for milestone in get_collection_milestones():
		if str(milestone["id"]) != id:
			continue
		if is_collection_milestone_claimed(id):
			return {"ok":false,"reason":"claimed"}
		if not is_collection_milestone_available(milestone):
			return {"ok":false,"reason":"locked"}
		claimed_collection_rewards[id]=true
		save()
		return {"ok":true,"milestone":milestone,"reward":milestone["reward"]}
	return {"ok":false,"reason":"unknown"}

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
	completed_events.clear()
	claimed_interactives.clear()
	completed_activities.clear()
	completed_secret_activities.clear()
	claimed_collection_rewards.clear()
	claimed_secret_collection_reward=false
