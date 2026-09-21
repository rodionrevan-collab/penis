class_name Island2Data
extends RefCounted

const ISLAND_ID := 2
const ISLAND_NAME := "Коралловые руины"
const DESCRIPTION := "Затонувший архипелаг, где кораллы, течения и древние механизмы меняют поле."

const MECHANICS: Array[String] = [
	"Коралловые сады • базовая механика",
	"Мягкий коралл • блокираторы",
	"Раковины • многослойные препятствия",
	"Течения • горизонтальный сдвиг поля",
	"Коралловый рост • препятствия разрастаются",
	"Крабы • двигающийся блокиратор",
	"Жемчужины • собрать и опустить вниз",
	"Водоворот • опасные клетки",
	"Медузы • цепная электрическая угроза",
	"Хранитель руин • финальная механика"
]

static func build_levels() -> Array:
	var levels:Array = []
	for i in range(100):
		var tier:int = int(i / 10)
		var moves:int = 20 + tier * 2
		var score:int = 950 + i * 90
		var count:int = 9 + int(i * 0.26)
		var target_type:int = (i + 2) % 6
		var blockers:int = 0 if tier == 0 else mini(14, 2 + tier)
		if i == 25:
			score = 2250
		if i >= 90:
			score = 6500 + (i - 90) * 300
			count = 110
		levels.append({
			"moves":moves,
			"score":score,
			"type":target_type,
			"count":count,
			"mechanic":tier,
			"blockers":blockers
		})
	return levels

static func get_level(index:int) -> Dictionary:
	var levels:=build_levels()
	if index<0 or index>=levels.size():
		return {}
	return levels[index]

static func get_mechanics() -> Array[String]:
	return MECHANICS.duplicate()
