extends Node

# Мета-прогресс первого острова: ремонт, зоны, NPC и сундуки.
# Состояние хранится отдельно от прогресса уровней, чтобы ремонт не сбрасывался.
const SAVE_PATH := "user://island_restoration.txt"

var repaired: Dictionary = {}
var claimed_chests: Dictionary = {}
var discovered_npcs: Dictionary = {}

var objects: Array[Dictionary] = [
	{"id":"bridge","name":"Старый мост","icon":"🌉","cost":5,"zone":1,"description":"Разрушенный мост открывает путь в джунгли.","reward_text":"Открывает зону: Джунгли"},
	{"id":"hut","name":"Пляжная хижина","icon":"🏠","cost":8,"zone":0,"description":"После ремонта здесь поселяется первый житель острова.","reward_text":"NPC: Лиза, смотрительница пляжа"},
	{"id":"jungle_path","name":"Тропа в джунглях","icon":"🌴","cost":12,"zone":2,"description":"Расчищенная тропа ведёт к старой пристани.","reward_text":"Открывает зону: Старая пристань"},
	{"id":"dock","name":"Старая пристань","icon":"⚓","cost":15,"zone":2,"description":"Восстановленная пристань возвращает на остров рыбака.","reward_text":"NPC: Рыбак Том"},
	{"id":"pirate_cove","name":"Пиратская бухта","icon":"🏴","cost":20,"zone":3,"description":"За старым проходом скрыта заброшенная пиратская бухта.","reward_text":"Открывает зону: Пиратская бухта + сундук"},
	{"id":"lighthouse","name":"Маяк","icon":"🔦","cost":25,"zone":3,"description":"Маяк снова освещает море и привлекает смотрителя.","reward_text":"NPC: Смотритель маяка"},
	{"id":"secret_cave","name":"Тайная пещера","icon":"🪨","cost":30,"zone":4,"description":"Старый вход в скале открывает секретную часть острова.","reward_text":"Открывает зону: Тайная пещера + большой сундук"},
	{"id":"old_village","name":"Старая деревня","icon":"🏚️","cost":35,"zone":5,"description":"Последний большой объект возвращает острову его поселение.","reward_text":"NPC: Торговец и дополнительная награда"}
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

func save() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if not file:
		return
	file.store_string("repaired=%s|chests=%s|npcs=%s" % [
		_keys_text(repaired),
		_keys_text(claimed_chests),
		_keys_text(discovered_npcs)
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

func get_npc_list() -> Array:
	var result: Array = []
	var definitions := [
		{"id":"lisa","name":"Лиза","role":"Смотрительница пляжа","icon":"👩","text":"Спасибо! Теперь здесь снова можно жить."},
		{"id":"tom","name":"Том","role":"Рыбак","icon":"🧑‍🌾","text":"Пристань снова работает. Море хранит много тайн."},
		{"id":"keeper","name":"Смотритель маяка","role":"Хранитель маяка","icon":"🧔","text":"Ночью я буду следить за огнями и кораблями."},
		{"id":"merchant","name":"Торговец","role":"Хозяин лавки","icon":"🧑‍💼","text":"Восстановите остров полностью — и я открою редкие товары."}
	]
	for npc in definitions:
		if bool(discovered_npcs.get(str(npc["id"]), false)):
			result.append(npc)
	return result

func get_chests() -> Array:
	var result: Array = []
	if is_repaired("pirate_cove"):
		result.append({"id":"pirate_chest","name":"Пиратский сундук","icon":"🎁","reward":{"stars":3,"booster":"shuffle","amount":2}})
	if is_repaired("secret_cave"):
		result.append({"id":"cave_chest","name":"Сундук тайной пещеры","icon":"💎","reward":{"stars":5,"booster":"hammer","amount":2}})
	if is_repaired("old_village"):
		result.append({"id":"village_chest","name":"Сундук деревни","icon":"🧰","reward":{"stars":7,"booster":"extra_moves","amount":3}})
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

func get_progress_text() -> String:
	return "%d / %d объектов восстановлено • %d / %d зон открыто" % [repaired.size(),objects.size(),get_unlocked_zone_count(),zones.size()]

func reset_for_tests() -> void:
	repaired.clear()
	claimed_chests.clear()
	discovered_npcs.clear()
