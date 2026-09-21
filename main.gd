extends Node2D

const SIZE := 8
const TYPES := 6
const CELL := 78.0
const ORIGIN := Vector2(138, 202)
const COLORS := [Color("#ff5b67"), Color("#4d9cff"), Color("#43d98b"), Color("#ffd34e"), Color("#b978ff"), Color("#ff9b4a")]
const SYMBOLS := ["●", "◆", "■", "★", "⬟", "▲"]
const TYPE_NAMES := ["красных кругов", "синих ромбов", "зелёных квадратов", "звёзд", "фиолетовых кристаллов", "оранжевых треугольников"]
const ISLAND_ART = preload("res://island_art.gd")
const MENU_BACKGROUND = preload("res://art/backgrounds/menu_background.svg")
const GAME_BACKGROUND = preload("res://art/backgrounds/game_background.svg")
const BOARD_FRAME_TEXTURE = preload("res://art/ui/board_frame.svg")
const CELL_TEXTURE = preload("res://art/ui/cell.svg")
const SELECTION_TEXTURE = preload("res://art/ui/selection.svg")
const BOOSTER_TEXTURES = {
	"🔨": preload("res://art/ui/booster_hammer.svg"),
	"+3": preload("res://art/ui/booster_moves.svg"),
	"↻": preload("res://art/ui/booster_shuffle.svg")
}
const MATCH_BURST_TEXTURE = preload("res://art/fx/match_burst.svg")
const COMBO_RING_TEXTURE = preload("res://art/fx/combo_ring.svg")
const SPECIAL_RAY_TEXTURE = preload("res://art/fx/special_ray.svg")
const GEM_TEXTURES = [
	preload("res://art/gems/gem_red.svg"),
	preload("res://art/gems/gem_blue.svg"),
	preload("res://art/gems/gem_green.svg"),
	preload("res://art/gems/gem_yellow.svg"),
	preload("res://art/gems/gem_purple.svg"),
	preload("res://art/gems/gem_orange.svg")
]
const SPECIAL_TEXTURES = {
	1: preload("res://art/specials/horizontal.svg"),
	2: preload("res://art/specials/vertical.svg"),
	3: preload("res://art/specials/bomb.svg"),
	4: preload("res://art/specials/rainbow.svg"),
	5: preload("res://art/specials/map_fragment.svg")
}
const VINE_TEXTURE = preload("res://art/obstacles/vine_blocker.svg")
const COCONUT_TEXTURE = preload("res://art/obstacles/coconut.svg")
const FIRE_STONE_TEXTURE = preload("res://art/obstacles/fire_stone.svg")
const SPIDER_TEXTURE = preload("res://art/obstacles/spider.svg")
const MECHANICS := [
	"Фрукты • базовая механика",
	"Лианы • блокираторы",
	"Крепкие кокосы • прочные препятствия",
	"Прилив и отлив • изменение поля",
	"Проклятие тотема • смена цветов",
	"Воришка-обезьяна • движущийся блокиратор",
	"Части карты сокровищ • нужно опускать вниз",
	"Тропический туман • скрытые клетки",
	"Огненные камни • угроза по таймеру",
	"Финальный тотем • босс"
]

var LEVELS: Array = []
var board: Array = []
var gems: Dictionary = {}
var selected := Vector2i(-1, -1)
var busy := false
var score := 0
var best := 0
var combo := 0
var current_level := 0
var moves_left := 0
var initial_moves := 0
var best_combo_level := 0
var level_stars: Array[int] = []
var pre_selected: Array[String] = []
var booster_inventory: Dictionary = {"hammer":3, "extra_moves":2, "shuffle":2, "pre_bomb":2, "pre_rainbow":1}
var active_booster := ""
var hammer_button: Button
var extra_moves_button: Button
var shuffle_button: Button
var destroyed_counts: Array = [0, 0, 0, 0, 0, 0]
var specials: Dictionary = {} # 1 horizontal, 2 vertical, 3 bomb, 4 rainbow
var blockers: Dictionary = {} # cell -> remaining hits
var blocker_nodes: Dictionary = {}
var spiders: Dictionary = {} # cell -> true
var spider_nodes: Dictionary = {}
var unlocked_level := 0
var completed: Array[bool] = []
var rng := RandomNumberGenerator.new()
var root: Node2D
var fx: Node2D
var game_layer: Control
var menu_layer: Control
var map_layer: Control
var modal: Control
var score_label: Label
var best_label: Label
var combo_label: Label
var level_label: Label
var moves_label: Label
var goal_label: Label
var status: Label
var sounds: Dictionary = {}
var touch_start := Vector2.ZERO
var touch_active := false
var mechanics: Node
var island_progression: Node
var island_stars := 0
var island_art_factory: Node
var mini_activity_id := ""
var mini_sequence_progress := 0
var mini_goods_collected := {}
var mini_status_label: Label
var mini_activity_buttons: Array[Button] = []

class Gem extends Node2D:
	var kind := 0
	var color := Color.WHITE
	var symbol := "●"
	var chosen := false
	var special_type := 0
	var texture: Texture2D
	var special_texture: Texture2D
	func setup(k: int, c: Color, s: String, sp: int = 0, tex: Texture2D = null, special_tex: Texture2D = null) -> void:
		kind = k
		color = c
		symbol = s
		special_type = sp
		texture = tex
		special_texture = special_tex
		queue_redraw()
	func select(v: bool) -> void:
		chosen = v
		var t := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		t.tween_property(self, "scale", Vector2.ONE * (1.13 if v else 1.0), 0.12)
		queue_redraw()
	func _draw() -> void:
		var s := 28.0
		draw_circle(Vector2(2, 4), s + 4.0, Color(0, 0, 0, 0.28))
		if chosen:
			draw_circle(Vector2.ZERO, s + 9.0, Color(color.r, color.g, color.b, 0.20))
			draw_texture_rect(SELECTION_TEXTURE,Rect2(-47,-47,94,94),false)
		if special_type != 0 and special_texture != null:
			draw_texture_rect(special_texture,Rect2(-s,-s,s*2,s*2),false)
			return
		if texture != null:
			draw_texture_rect(texture,Rect2(-s,-s,s*2,s*2),false)
			return
		if special_type != 0:
			if special_type == 1:
				draw_circle(Vector2(-s*.62,0),s*.38,Color("#ffd45a"))
				draw_circle(Vector2(s*.62,0),s*.38,Color("#ffd45a"))
				draw_rect(Rect2(-s*.62,-s*.38,s*1.24,s*.76),Color("#ffd45a"))
				draw_line(Vector2(-s*.55,0),Vector2(s*.55,0),Color.WHITE,5.0)
				draw_line(Vector2(-s*.40,-s*.16),Vector2(-s*.18,0),Color.WHITE,3.0)
				draw_line(Vector2(-s*.40,s*.16),Vector2(-s*.18,0),Color.WHITE,3.0)
				draw_line(Vector2(s*.40,-s*.16),Vector2(s*.18,0),Color.WHITE,3.0)
				draw_line(Vector2(s*.40,s*.16),Vector2(s*.18,0),Color.WHITE,3.0)
			elif special_type == 2:
				draw_circle(Vector2(0,-s*.62),s*.38,Color("#ffd45a"))
				draw_circle(Vector2(0,s*.62),s*.38,Color("#ffd45a"))
				draw_rect(Rect2(-s*.38,-s*.62,s*.76,s*1.24),Color("#ffd45a"))
				draw_line(Vector2(0,-s*.55),Vector2(0,s*.55),Color.WHITE,5.0)
				draw_line(Vector2(-s*.16,-s*.40),Vector2(0,-s*.18),Color.WHITE,3.0)
				draw_line(Vector2(s*.16,-s*.40),Vector2(0,-s*.18),Color.WHITE,3.0)
				draw_line(Vector2(-s*.16,s*.40),Vector2(0,s*.18),Color.WHITE,3.0)
				draw_line(Vector2(s*.16,s*.40),Vector2(0,s*.18),Color.WHITE,3.0)
			elif special_type == 3:
				draw_circle(Vector2(2,4),s*.82,Color(0,0,0,.32))
				draw_circle(Vector2.ZERO,s*.72,Color("#27344b"))
				draw_circle(Vector2(-s*.20,-s*.20),s*.22,Color("#8ea0bd"))
				draw_circle(Vector2(s*.18,s*.22),s*.14,Color("#111827"))
				draw_line(Vector2(s*.34,-s*.52),Vector2(s*.60,-s*.78),Color("#f4b34d"),4.0)
				draw_circle(Vector2(s*.64,-s*.82),s*.10,Color("#ff6b4a"))
			elif special_type == 4:
				var rainbow_colors:Array[Color]=[Color("#ff5b67"),Color("#ff9b4a"),Color("#ffd34e"),Color("#43d98b"),Color("#4d9cff"),Color("#b978ff")]
				draw_circle(Vector2(2,4),s*.78,Color(0,0,0,.28))
				draw_circle(Vector2.ZERO,s*.70,Color.WHITE)
				for i in range(6):
					draw_arc(Vector2.ZERO,s*.58,-PI/2.0+i*TAU/6.0,-PI/2.0+(i+1)*TAU/6.0,8,rainbow_colors[i],7.0)
				draw_circle(Vector2.ZERO,s*.20,Color("#f5f7ff"))
			elif special_type == 5:
				draw_circle(Vector2(2,4),s*.84,Color(0,0,0,.30))
				draw_rect(Rect2(-s*.74,-s*.74,s*1.48,s*1.48),Color("#e6c792"))
				draw_rect(Rect2(-s*.74,-s*.74,s*1.48,s*1.48),Color("#b9864d"),false,2.0)
				draw_line(Vector2(-s*.30,-s*.15),Vector2(s*.25,-s*.15),Color("#6b4d2e"),3.0)
				draw_line(Vector2(-s*.30,s*.12),Vector2(s*.10,s*.12),Color("#6b4d2e"),3.0)
				var map_x:=PackedVector2Array([Vector2(-s*.52,s*.36),Vector2(-s*.10,s*.02),Vector2(s*.24,s*.34),Vector2(s*.52,-s*.30)])
				draw_polyline(map_x,Color("#c47f3d"),3.0)
			return
		match kind:
			0:
				draw_circle(Vector2.ZERO, s, color)
			1:
				draw_colored_polygon(PackedVector2Array([Vector2(0,-s),Vector2(s,0),Vector2(0,s),Vector2(-s,0)]), color)
			2:
				var b := StyleBoxFlat.new()
				b.bg_color = color
				b.border_color = color.lightened(.22)
				b.set_border_width_all(3)
				b.set_corner_radius_all(9)
				draw_style_box(b, Rect2(-s,-s,s*2,s*2))
			3:
				var a := PackedVector2Array()
				for i in range(10):
					var ang := -PI/2.0 + i*PI/5.0
					a.append(Vector2(cos(ang),sin(ang))*(s if i%2==0 else s*.43))
				draw_colored_polygon(a,color)
			4:
				var h := PackedVector2Array()
				for i in range(6):
					var ang := -PI/2.0 + i*PI/3.0
					h.append(Vector2(cos(ang),sin(ang))*s)
				draw_colored_polygon(h,color)
			5:
				draw_colored_polygon(PackedVector2Array([Vector2(0,-s),Vector2(s,s),Vector2(-s,s)]), color)
		draw_circle(Vector2(-s*.32,-s*.34), s*.19, Color(1,1,1,.5))
		draw_circle(Vector2(-s*.23,-s*.22), s*.08, Color.WHITE)

class SpiderMark extends Node2D:
	func _draw() -> void:
		draw_circle(Vector2(1,2),8,Color(0,0,0,.35))
		draw_circle(Vector2.ZERO,6,Color("#2b2330"))
		draw_circle(Vector2(0,-5),4,Color("#35293a"))
		for i in range(4):
			var y:=float(i-1.5)*3.0
			draw_line(Vector2(-4,y),Vector2(-13,y-4),Color("#6d5575"),2.0)
			draw_line(Vector2(4,y),Vector2(13,y-4),Color("#6d5575"),2.0)
		draw_circle(Vector2(-1.5,-6),1.2,Color("#ff5d6c"))
		draw_circle(Vector2(1.5,-6),1.2,Color("#ff5d6c"))

class BoardFrame extends Node2D:
	func _draw() -> void:
		draw_texture_rect(BOARD_FRAME_TEXTURE,Rect2(-340,-340,680,680),false)
		for y in SIZE:
			for x in SIZE:
				draw_texture_rect(CELL_TEXTURE,Rect2(-312+x*CELL+3,-312+y*CELL+3,CELL-6,CELL-6),false)

func _ready() -> void:
	rng.randomize()
	mechanics = get_node_or_null("IslandMechanics")
	island_progression = get_node_or_null("IslandProgression")
	island_art_factory = ISLAND_ART.new()
	_build_levels()
	level_stars.resize(100)
	for i in range(100): level_stars[i] = 0
	_load_progress()
	_build_sounds()
	_build_game_layer()
	_show_menu()

func _build_levels() -> void:
	LEVELS.clear()
	for i in range(100):
		var tier := int(i / 10)
		var moves := 18 + tier * 2
		var target_score := 800 + i * 75
		var target_count := 10 + int(i * 0.28)
		var target_type := i % TYPES
		if i >= 90:
			target_score = 6000 + (i - 90) * 250
			target_count = 100
			target_type = (i - 90) % TYPES
		var blocker_count:=0 if tier==0 else mini(12,2+tier)
		var spider_count:=0 if tier<2 else mini(5,1+int((tier-2)/2))
		LEVELS.append({"moves":moves,"score":target_score,"type":target_type,"count":target_count,"mechanic":tier,"blockers":blocker_count,"spiders":spider_count})
	completed.resize(100)
	for i in range(100):
		completed[i] = false

func _load_progress() -> void:
	if FileAccess.file_exists("user://island_unlocked.txt"):
		unlocked_level=clampi(int(FileAccess.get_file_as_string("user://island_unlocked.txt")),0,99)
	if FileAccess.file_exists("user://island_completed.txt"):
		var text:=FileAccess.get_file_as_string("user://island_completed.txt")
		var parts:=text.split(",")
		for i in range(min(parts.size(),100)):
			completed[i]=parts[i]=="1"
	if FileAccess.file_exists("user://best_score.txt"):
		best=int(FileAccess.get_file_as_string("user://best_score.txt"))
	if FileAccess.file_exists("user://level_stars.txt"):
		var star_parts:=FileAccess.get_file_as_string("user://level_stars.txt").split(",")
		for i in range(mini(star_parts.size(),100)):
			level_stars[i]=clampi(int(star_parts[i]),0,3)
	if FileAccess.file_exists("user://island_stars.txt"):
		island_stars=maxi(0,int(FileAccess.get_file_as_string("user://island_stars.txt")))
	else:
		island_stars=0
		for value in level_stars:
			island_stars+=int(value)
	if FileAccess.file_exists("user://booster_inventory.txt"):
		var boost_parts:=FileAccess.get_file_as_string("user://booster_inventory.txt").split(",")
		for part in boost_parts:
			var pair:=part.split(":")
			if pair.size()==2 and booster_inventory.has(pair[0]):
				booster_inventory[pair[0]]=maxi(0,int(pair[1]))

func _save_progress() -> void:
	var u:=FileAccess.open("user://island_unlocked.txt",FileAccess.WRITE)
	if u:
		u.store_string(str(unlocked_level))
	var f:=FileAccess.open("user://island_completed.txt",FileAccess.WRITE)
	if f:
		var parts:=PackedStringArray()
		for v in completed:
			parts.append("1" if v else "0")
		f.store_string(",".join(parts))
	var s:=FileAccess.open("user://level_stars.txt",FileAccess.WRITE)
	if s:
		var star_parts:=PackedStringArray()
		for v in level_stars:
			star_parts.append(str(v))
		s.store_string(",".join(star_parts))
	var ib:=FileAccess.open("user://island_stars.txt",FileAccess.WRITE)
	if ib:
		ib.store_string(str(island_stars))
	var b:=FileAccess.open("user://booster_inventory.txt",FileAccess.WRITE)
	if b:
		var boost_parts:=PackedStringArray()
		for key in booster_inventory.keys():
			boost_parts.append("%s:%d"%[key,int(booster_inventory[key])])
		b.store_string(",".join(boost_parts))

func _style(fill:Color,border:Color,r:=12)->StyleBoxFlat:
	var s:=StyleBoxFlat.new()
	s.bg_color=fill
	s.border_color=border
	s.set_border_width_all(1)
	s.set_corner_radius_all(r)
	return s

func _show_menu() -> void:
	busy=true
	if game_layer: game_layer.visible=false
	if map_layer: map_layer.visible=false
	if modal:
		modal.queue_free()
		modal=null
	if menu_layer: menu_layer.queue_free()
	menu_layer=Control.new()
	menu_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(menu_layer)

	var bg:=TextureRect.new()
	bg.texture=MENU_BACKGROUND
	bg.position=Vector2.ZERO
	bg.size=Vector2(900,900)
	bg.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode=TextureRect.STRETCH_SCALE
	bg.mouse_filter=Control.MOUSE_FILTER_IGNORE
	menu_layer.add_child(bg)
	var bg_tint:=ColorRect.new()
	bg_tint.size=Vector2(900,900)
	bg_tint.color=Color(0.02,0.08,0.11,0.28)
	bg_tint.mouse_filter=Control.MOUSE_FILTER_IGNORE
	menu_layer.add_child(bg_tint)

	var header:=ColorRect.new()
	header.size=Vector2(900,145)
	header.color=Color("#102f48")
	menu_layer.add_child(header)

	var title:=Label.new()
	title.text="ТРИ В РЯД"
	title.position=Vector2(58,25)
	title.add_theme_font_size_override("font_size",40)
	title.add_theme_color_override("font_color",Color("#f5f8ff"))
	menu_layer.add_child(title)

	var sub:=Label.new()
	sub.text="ЗАБЫТЫЕ ТРОПИКИ"
	sub.position=Vector2(61,76)
	sub.add_theme_font_size_override("font_size",15)
	sub.add_theme_color_override("font_color",Color("#71d7ad"))
	menu_layer.add_child(sub)

	var progress:=Label.new()
	var completed_count:=0
	for done in completed:
		if done: completed_count+=1
	progress.text="ПРОГРЕСС\n%d / 100 уровней"%completed_count
	progress.position=Vector2(690,31)
	progress.size=Vector2(145,70)
	progress.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
	progress.add_theme_font_size_override("font_size",13)
	progress.add_theme_color_override("font_color",Color("#b9cce1"))
	menu_layer.add_child(progress)

	var hero:=Panel.new()
	hero.position=Vector2(55,175)
	hero.size=Vector2(790,245)
	hero.add_theme_stylebox_override("panel",_style(Color("#0d2236"),Color("#315c79"),24))
	menu_layer.add_child(hero)

	var hero_title:=Label.new()
	hero_title.text="ОТПРАВЛЯЙСЯ В ПУТЕШЕСТВИЕ"
	hero_title.position=Vector2(32,28)
	hero_title.add_theme_font_size_override("font_size",27)
	hero_title.add_theme_color_override("font_color",Color("#f3f7ff"))
	hero.add_child(hero_title)

	var hero_text:=Label.new()
	hero_text.text="Собирай комбинации, открывай новые механики\nи проходи остров за островом."
	hero_text.position=Vector2(34,72)
	hero_text.size=Vector2(430,65)
	hero_text.add_theme_font_size_override("font_size",14)
	hero_text.add_theme_color_override("font_color",Color("#8faac2"))
	hero.add_child(hero_text)

	var continue_btn:=Button.new()
	continue_btn.text="ПРОДОЛЖИТЬ • УРОВЕНЬ %d"%(unlocked_level+1)
	continue_btn.position=Vector2(32,157)
	continue_btn.size=Vector2(300,50)
	continue_btn.add_theme_font_size_override("font_size",13)
	continue_btn.add_theme_stylebox_override("normal",_style(Color("#21835b"),Color("#62dfa1"),14))
	continue_btn.pressed.connect(_show_map)
	hero.add_child(continue_btn)

	var island:=Panel.new()
	island.position=Vector2(520,25)
	island.size=Vector2(235,195)
	island.add_theme_stylebox_override("panel",_style(Color("#102b3e"),Color("#3a7890"),20))
	hero.add_child(island)

	var island_icon:=Label.new()
	island_icon.text="✦"
	island_icon.position=Vector2(86,15)
	island_icon.add_theme_font_size_override("font_size",55)
	island_icon.add_theme_color_override("font_color",Color("#55d7a0"))
	island.add_child(island_icon)

	var island_title:=Label.new()
	island_title.text="ЗАБЫТЫЕ ТРОПИКИ"
	island_title.position=Vector2(15,78)
	island_title.size=Vector2(205,28)
	island_title.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	island_title.add_theme_font_size_override("font_size",16)
	island_title.add_theme_color_override("font_color",Color("#f4f7ff"))
	island.add_child(island_title)

	var island_desc:=Label.new()
	island_desc.text="Остров 1 • 100 уровней"
	island_desc.position=Vector2(15,111)
	island_desc.size=Vector2(205,25)
	island_desc.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	island_desc.add_theme_font_size_override("font_size",12)
	island_desc.add_theme_color_override("font_color",Color("#82a8bf"))
	island.add_child(island_desc)

	var road_title:=Label.new()
	road_title.text="ПУТЕШЕСТВИЕ ПО МИРАМ"
	road_title.position=Vector2(60,455)
	road_title.add_theme_font_size_override("font_size",20)
	road_title.add_theme_color_override("font_color",Color("#e7eff8"))
	menu_layer.add_child(road_title)

	var road_sub:=Label.new()
	road_sub.text="Каждый мир открывается дальше по дороге приключений"
	road_sub.position=Vector2(60,488)
	road_sub.add_theme_font_size_override("font_size",12)
	road_sub.add_theme_color_override("font_color",Color("#718ca4"))
	menu_layer.add_child(road_sub)

	var road:=Line2D.new()
	road.width=24
	road.default_color=Color("#214b5b")
	road.points=PackedVector2Array([Vector2(150,615),Vector2(360,550),Vector2(585,625),Vector2(770,550)])
	menu_layer.add_child(road)
	var road_inner:=Line2D.new()
	road_inner.width=5
	road_inner.default_color=Color("#4f8790")
	road_inner.points=road.points
	menu_layer.add_child(road_inner)

	_create_world_menu_node(0,Vector2(150,615),"1","ЗАБЫТЫЕ\nТРОПИКИ",true)
	_create_world_menu_node(1,Vector2(470,590),"2","???",false)
	_create_world_menu_node(2,Vector2(770,550),"3","???",false)

	var foot:=Label.new()
	foot.text="100 уровней • специальные фишки • препятствия • новые механики каждые 10 уровней"
	foot.position=Vector2(70,805)
	foot.size=Vector2(760,30)
	foot.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	foot.add_theme_font_size_override("font_size",11)
	foot.add_theme_color_override("font_color",Color("#617b92"))
	menu_layer.add_child(foot)
	busy=false

func _create_world_menu_node(index:int,pos:Vector2,number:String,title_text:String,open:bool)->void:
	var b:=Button.new()
	b.position=pos-Vector2(48,48)
	b.size=Vector2(96,96)
	b.text=number
	b.add_theme_font_size_override("font_size",24)
	b.add_theme_color_override("font_color",Color.WHITE if open else Color("#6d7c8d"))
	b.add_theme_stylebox_override("normal",_style(Color("#26845c") if open else Color("#182535"),Color("#71e1aa") if open else Color("#35495c"),48))
	b.add_theme_stylebox_override("hover",_style(Color("#2e9c6d") if open else Color("#1c2b3e"),Color.WHITE if open else Color("#42566d"),48))
	b.disabled=not open
	if open:
		b.pressed.connect(_show_map)
	menu_layer.add_child(b)
	var l:=Label.new()
	l.text=title_text
	l.position=pos+Vector2(-75,57)
	l.size=Vector2(150,42)
	l.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size",11)
	l.add_theme_color_override("font_color",Color("#b8d3df") if open else Color("#5f7184"))
	menu_layer.add_child(l)

func _create_island_card(index:int,pos:Vector2,open:bool,title_text:String,subtitle:String,desc:String)->void:
	var panel:=Panel.new(); panel.position=pos; panel.size=Vector2(330,250); panel.add_theme_stylebox_override("panel",_style(Color("#11243b") if open else Color("#0d1828"),Color("#3a6a92") if open else Color("#26374e"),20)); menu_layer.add_child(panel)
	var icon:=Label.new(); icon.text="🌴" if open else "🔒"; icon.position=Vector2(135,18); icon.add_theme_font_size_override("font_size",55); panel.add_child(icon)
	var t:=Label.new(); t.text=title_text; t.position=Vector2(20,82); t.size=Vector2(290,38); t.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; t.add_theme_font_size_override("font_size",23); t.add_theme_color_override("font_color",Color("#f4f7ff") if open else Color("#697991")); panel.add_child(t)
	var st:=Label.new(); st.text=subtitle; st.position=Vector2(20,123); st.size=Vector2(290,30); st.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; st.add_theme_font_size_override("font_size",13); st.add_theme_color_override("font_color",Color("#80a6c6")); panel.add_child(st)
	var d:=Label.new(); d.text=desc; d.position=Vector2(20,157); d.size=Vector2(290,40); d.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; d.add_theme_font_size_override("font_size",11); d.add_theme_color_override("font_color",Color("#7388a5")); panel.add_child(d)
	var b:=Button.new(); b.text="ОТКРЫТЬ ОСТРОВ" if open else "ЗАБЛОКИРОВАНО"; b.position=Vector2(55,204); b.size=Vector2(220,36); b.disabled=not open; b.add_theme_stylebox_override("normal",_style(Color("#237e55") if open else Color("#192535"),Color("#61d79d") if open else Color("#33445b"))); panel.add_child(b)
	if open: b.pressed.connect(_show_map)

func _show_map()->void:
	busy=true
	if modal:
		modal.queue_free()
		modal=null
	if menu_layer: menu_layer.visible=false
	if game_layer: game_layer.visible=false
	if modal: modal.queue_free(); modal=null
	if map_layer: map_layer.queue_free()
	map_layer=Control.new(); map_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); add_child(map_layer)
	var bg:=ColorRect.new(); bg.size=Vector2(900,900); bg.color=Color("#062033"); map_layer.add_child(bg)
	var top:=ColorRect.new(); top.size=Vector2(900,130); top.color=Color("#0d2c43"); map_layer.add_child(top)
	var title:=Label.new(); title.text="ЗАБЫТЫЕ ТРОПИКИ"; title.position=Vector2(48,20); title.add_theme_font_size_override("font_size",31); title.add_theme_color_override("font_color",Color("#f4f7ff")); map_layer.add_child(title)
	var sub:=Label.new(); sub.text="Остров 1 • 100 уровней • каждые 10 уровней — новая механика"; sub.position=Vector2(50,62); sub.add_theme_font_size_override("font_size",13); sub.add_theme_color_override("font_color",Color("#8eafc9")); map_layer.add_child(sub)
	var back:=Button.new(); back.text="← МИРЫ"; back.position=Vector2(735,28); back.size=Vector2(115,42); back.add_theme_stylebox_override("normal",_style(Color("#162f49"),Color("#42688b"))); back.pressed.connect(_show_menu); map_layer.add_child(back)
	var legend:=Label.new(); legend.text="🟢 ПРОЙДЕН   🔵 ДОСТУПЕН   🔴 ЗАБЛОКИРОВАН"; legend.position=Vector2(50,96); legend.add_theme_font_size_override("font_size",11); legend.add_theme_color_override("font_color",Color("#b6c8dc")); map_layer.add_child(legend)
	var star_bank:=Label.new(); star_bank.text="⭐ ЗВЁЗДЫ: %d"%island_stars; star_bank.position=Vector2(420,92); star_bank.size=Vector2(170,28); star_bank.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; star_bank.add_theme_font_size_override("font_size",14); star_bank.add_theme_color_override("font_color",Color("#ffd86a")); map_layer.add_child(star_bank)
	var island_btn:=Button.new(); island_btn.text="🏝️ КАРТА ОСТРОВА"; island_btn.position=Vector2(600,88); island_btn.size=Vector2(250,36); island_btn.add_theme_font_size_override("font_size",11); island_btn.add_theme_stylebox_override("normal",_style(Color("#1c594f"),Color("#5fd9aa"))); island_btn.pressed.connect(_show_island_visual_map); map_layer.add_child(island_btn)
	var scroll:=ScrollContainer.new(); scroll.position=Vector2(25,140); scroll.size=Vector2(850,735); scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED; map_layer.add_child(scroll)
	var world:=Control.new(); world.custom_minimum_size=Vector2(850,2050); scroll.add_child(world)
	var path:=Line2D.new(); path.width=18; path.default_color=Color("#315e70"); world.add_child(path)
	var points:=PackedVector2Array()
	for i in range(100): points.append(Vector2(85 + (i%10)*76 if int(i/10)%2==0 else 765-(i%10)*76, 80+int(i/10)*195))
	path.points=points
	var inner:=Line2D.new(); inner.width=5; inner.default_color=Color("#5b8991"); inner.points=points; world.add_child(inner)
	for i in range(100): _create_level_node(world,i,points[i])
	var note:=Label.new(); note.text="ПРОЛИСТАЙ ВНИЗ • ПУТЕШЕСТВИЕ ПРОДОЛЖАЕТСЯ"; note.position=Vector2(190,1990); note.size=Vector2(470,35); note.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; note.add_theme_font_size_override("font_size",12); note.add_theme_color_override("font_color",Color("#6f94a5")); world.add_child(note)
	busy=false

func _island_zone_name(zone_id:int)->String:
	if not is_instance_valid(island_progression): return "Зона"
	for zone in island_progression.zones:
		if int(zone["id"])==zone_id:
			return str(zone["name"])
	return "Зона"

func _show_island_visual_map(focus_id:String="")->void:
	if modal:
		modal.queue_free()
		modal=null
	modal=Control.new()
	modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal.mouse_filter=Control.MOUSE_FILTER_STOP
	var shade:=ColorRect.new()
	shade.size=Vector2(900,900)
	shade.color=Color(0.02,0.06,0.09,.94)
	modal.add_child(shade)
	var panel:=Panel.new()
	panel.position=Vector2(30,30)
	panel.size=Vector2(840,840)
	panel.add_theme_stylebox_override("panel",_style(Color("#0b2531"),Color("#4f8f84"),24))
	modal.add_child(panel)
	var title:=Label.new()
	title.text="🏝️ ЗАБЫТЫЕ ТРОПИКИ — ОСТРОВ"
	title.position=Vector2(30,18)
	title.size=Vector2(780,40)
	title.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size",25)
	title.add_theme_color_override("font_color",Color("#f3f8f4"))
	panel.add_child(title)
	var bank:=Label.new()
	var unique_count:int = 0
	var collection_text:String = "Коллекция недоступна"
	var secret_collection_text:String = "Секреты недоступны"
	var progress_text:String = "Прогресс недоступен"
	if is_instance_valid(island_progression):
		unique_count = int(island_progression.call("get_unique_reward_count"))
		collection_text = str(island_progression.call("get_collection_completion_text"))
		secret_collection_text = str(island_progression.call("get_secret_collection_text"))
		progress_text = str(island_progression.call("get_progress_text"))
	bank.text="⭐ %d    •    %s    •    🏆 %d/4    •    %s    •    💠 %s"%[island_stars,progress_text,unique_count,collection_text,secret_collection_text]
	bank.position=Vector2(35,58)
	bank.size=Vector2(770,28)
	bank.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	bank.add_theme_font_size_override("font_size",12)
	bank.add_theme_color_override("font_color",Color("#ffd86a"))
	panel.add_child(bank)

	var island:=Panel.new()
	island.position=Vector2(35,100)
	island.size=Vector2(770,655)
	island.add_theme_stylebox_override("panel",_style(Color("#14506a"),Color("#4f8f84"),32))
	panel.add_child(island)

	# Рисуемый фон острова.
	var states:Array[bool]=[]
	for zone_id in range(6):
		states.append(bool(island_progression.call("is_zone_unlocked",zone_id)) if is_instance_valid(island_progression) else zone_id==0)
	var backdrop:Node2D = island_art_factory.call("create_backdrop",states) as Node2D
	island.add_child(backdrop)

	# Объекты, которые можно ремонтировать/осматривать.
	if is_instance_valid(island_progression):
		for item in island_progression.objects:
			_add_island_object_marker(island,str(item["id"]),item,focus_id)

	# NPC появляются только после ремонта соответствующих объектов.
	if is_instance_valid(island_progression):
		for npc in island_progression.get_npc_list():
			_add_island_npc_marker(island,npc)
		for chest in island_progression.get_chests():
			_add_island_chest_marker(island,chest)
		for secret in island_progression.get_secrets():
			if island_progression.is_secret_available(secret):
				_add_island_secret_marker(island,secret)
		for event in island_progression.get_island_events():
			if island_progression.is_event_available(event):
				_add_island_event_marker(island,event)
		for item in island_progression.get_interactive_objects():
			var item_zone_open:=bool(island_progression.call("is_zone_unlocked",int(item.get("zone",0))))
			var item_available:=bool(island_progression.call("is_interactive_available",item))
			var item_done:=bool(island_progression.call("is_interactive_completed",str(item["id"])))
			if item_zone_open:
				_add_island_interactive_marker(island,item,1 if item_available else (2 if item_done else 0))
		for activity in island_progression.get_mini_activities():
			var activity_zone_open:=bool(island_progression.call("is_zone_unlocked",int(activity.get("zone",0))))
			var activity_available:=bool(island_progression.call("is_activity_available",activity))
			var activity_done:=bool(island_progression.call("is_activity_completed",str(activity["id"])))
			if activity_zone_open:
				_add_island_activity_marker(island,activity,1 if activity_available else (2 if activity_done else 0),false)
		for secret_activity in island_progression.get_secret_mini_activities():
			var secret_zone_open:=bool(island_progression.call("is_zone_unlocked",int(secret_activity.get("zone",0))))
			var secret_available:=bool(island_progression.call("is_secret_activity_available",secret_activity))
			var secret_done:=bool(island_progression.call("is_secret_activity_completed",str(secret_activity["id"])))
			if secret_zone_open and (secret_available or secret_done):
				_add_island_activity_marker(island,secret_activity,1 if secret_available else 2,true)

	var legend:=Label.new()
	legend.text="🟢 восстановлено   🟠 ремонт   🔵 NPC   🎁 сундук   ✨ событие   🔑 интерактив   🎮 активность   💠 секрет"
	legend.position=Vector2(45,770)
	legend.size=Vector2(750,25)
	legend.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	legend.add_theme_font_size_override("font_size",10)
	legend.add_theme_color_override("font_color",Color("#a5bfca"))
	panel.add_child(legend)

	var repair:=Button.new()
	repair.text="🔨 РЕМОНТ"
	repair.position=Vector2(35,797)
	repair.size=Vector2(175,32)
	repair.add_theme_font_size_override("font_size",10)
	repair.add_theme_stylebox_override("normal",_style(Color("#225b50"),Color("#61d6a2"),10))
	repair.pressed.connect(_show_island_repair)
	panel.add_child(repair)
	var collection:=Button.new()
	collection.text="🏆 КОЛЛЕКЦИЯ"
	collection.position=Vector2(220,797)
	collection.size=Vector2(175,32)
	collection.add_theme_font_size_override("font_size",10)
	collection.add_theme_stylebox_override("normal",_style(Color("#47335f"),Color("#d6adff"),10))
	collection.pressed.connect(_show_island_collection)
	panel.add_child(collection)
	var close:=Button.new()
	close.text="← УРОВНИ"
	close.position=Vector2(405,797)
	close.size=Vector2(175,32)
	close.add_theme_font_size_override("font_size",10)
	close.add_theme_stylebox_override("normal",_style(Color("#182c45"),Color("#4a6989"),10))
	close.pressed.connect(_close_island_visual_map)
	panel.add_child(close)
	var main_map:=Button.new()
	main_map.text="🎁 СУНДУКИ"
	main_map.position=Vector2(590,797)
	main_map.size=Vector2(175,32)
	main_map.add_theme_font_size_override("font_size",10)
	main_map.add_theme_stylebox_override("normal",_style(Color("#604b25"),Color("#d3a94f"),10))
	main_map.pressed.connect(_show_island_chests)
	panel.add_child(main_map)
	map_layer.add_child(modal)

func _add_island_object_marker(parent:Control,id:String,item:Dictionary,focus_id:String="")->void:
	var repaired_now:=bool(island_progression.call("is_repaired",id))
	var zone_id:=int(item["zone"])
	var zone_open:=bool(island_progression.call("is_zone_unlocked",zone_id))
	var p:Vector2=item.get("map_pos",Vector2(100,100))
	var marker:=Button.new()
	marker.position=p-Vector2(42,32)
	marker.size=Vector2(84,64)
	marker.tooltip_text=str(item["name"])
	marker.disabled=not zone_open
	marker.flat=true
	marker.mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
	marker.add_theme_stylebox_override("normal",_style(Color(0,0,0,0),Color(0,0,0,0),14))
	marker.add_theme_stylebox_override("hover",_style(Color(1,1,1,.08),Color(1,1,1,.18),14))
	marker.add_theme_stylebox_override("pressed",_style(Color(1,1,1,.14),Color(1,1,1,.25),14))
	var art_node:Node2D = island_art_factory.call("create_object",id,repaired_now) as Node2D
	art_node.position=Vector2(42,32)
	marker.add_child(art_node)
	marker.pressed.connect(_island_object_clicked.bind(id))
	parent.add_child(marker)
	if focus_id==id and repaired_now:
		art_node.play_repair()
	var label:=Label.new()
	label.text=str(item["name"])+(" ✓" if repaired_now else "")
	label.position=p+Vector2(-60,34)
	label.size=Vector2(120,30)
	label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size",9)
	label.add_theme_color_override("font_color",Color("#ddf2dd") if repaired_now else Color("#e6d0a1"))
	parent.add_child(label)

func _island_object_clicked(id:String)->void:
	if is_instance_valid(island_progression) and bool(island_progression.call("is_repaired",id)):
		var item:Dictionary=island_progression.call("get_object",id)
		_show_island_object_info(item)
	else:
		_show_island_repair()

func _show_island_object_info(item:Dictionary)->void:
	if modal:
		modal.queue_free()
		modal=null
	modal=Control.new()
	modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal.mouse_filter=Control.MOUSE_FILTER_STOP
	var shade:=ColorRect.new(); shade.size=Vector2(900,900); shade.color=Color(0.02,0.04,0.09,.78); modal.add_child(shade)
	var box:=Panel.new(); box.position=Vector2(190,275); box.size=Vector2(520,315); box.add_theme_stylebox_override("panel",_style(Color("#10263a"),Color("#5bb58f"),20)); modal.add_child(box)
	var title:=Label.new(); title.text=str(item["icon"])+" "+str(item["name"])+" ✓"; title.position=Vector2(25,24); title.size=Vector2(470,42); title.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; title.add_theme_font_size_override("font_size",23); title.add_theme_color_override("font_color",Color("#70dfa9")); box.add_child(title)
	var body:=Label.new(); body.text=str(item["description"])+"\n\n"+str(item["reward_text"]); body.position=Vector2(35,82); body.size=Vector2(450,110); body.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; body.vertical_alignment=VERTICAL_ALIGNMENT_CENTER; body.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; body.add_theme_font_size_override("font_size",14); body.add_theme_color_override("font_color",Color("#bfd2df")); box.add_child(body)
	var close:=Button.new(); close.text="ПОНЯТНО"; close.position=Vector2(100,225); close.size=Vector2(320,50); close.add_theme_stylebox_override("normal",_style(Color("#237b57"),Color("#63d5a2"),12)); close.pressed.connect(_close_island_visual_map); box.add_child(close)
	map_layer.add_child(modal)

func _add_island_npc_marker(parent:Control,npc:Dictionary)->void:
	var p:Vector2=npc.get("map_pos",Vector2(100,100))
	var b:=Button.new()
	b.position=p-Vector2(30,30)
	b.size=Vector2(60,60)
	b.flat=true
	b.mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
	b.add_theme_stylebox_override("normal",_style(Color(0,0,0,0),Color(0,0,0,0),30))
	b.add_theme_stylebox_override("hover",_style(Color(1,1,1,.08),Color(1,1,1,.18),30))
	var art_node:Node2D = island_art_factory.call("create_npc",str(npc["role"])) as Node2D
	art_node.position=Vector2(30,30)
	b.add_child(art_node)
	b.pressed.connect(_show_island_npc_dialog.bind(str(npc["id"])))
	parent.add_child(b)
	var l:=Label.new(); l.text=str(npc["name"]); l.position=p+Vector2(-50,31); l.size=Vector2(100,22); l.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; l.add_theme_font_size_override("font_size",9); l.add_theme_color_override("font_color",Color("#b8dcf1")); parent.add_child(l)

func _add_island_chest_marker(parent:Control,chest:Dictionary)->void:
	var p:Vector2=chest.get("map_pos",Vector2(100,100))
	var claimed:=bool(island_progression.call("is_chest_claimed",str(chest["id"])))
	var b:=Button.new()
	b.position=p-Vector2(30,28)
	b.size=Vector2(60,56)
	b.flat=true
	b.mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
	b.add_theme_stylebox_override("normal",_style(Color(0,0,0,0),Color(0,0,0,0),20))
	b.add_theme_stylebox_override("hover",_style(Color(1,1,1,.08),Color("#f0d36f"),20))
	var art_node:Node2D = island_art_factory.call("create_chest",claimed) as Node2D
	art_node.position=Vector2(30,28)
	b.add_child(art_node)
	b.pressed.connect(_show_island_chests)
	parent.add_child(b)
	var l:=Label.new(); l.text=str(chest["name"])+(" • получено" if claimed else " • доступно"); l.position=p+Vector2(-65,28); l.size=Vector2(130,30); l.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; l.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; l.add_theme_font_size_override("font_size",8); l.add_theme_color_override("font_color",Color("#c9d7c4")); parent.add_child(l)

func _completed_level_count()->int:
	var count:=0
	for done in completed:
		if done: count+=1
	return count

func _repaired_object_count()->int:
	if not is_instance_valid(island_progression): return 0
	return int(island_progression.repaired.size())

func _claim_npc_quest(id:String)->void:
	if not is_instance_valid(island_progression): return
	var result:Dictionary=island_progression.call("claim_npc_quest",id,_completed_level_count(),island_progression.get_unlocked_zone_count(),_repaired_object_count())
	if not bool(result.get("ok",false)): return
	_apply_island_reward(result["reward"])
	if bool(result.get("final",false)):
		_show_island_npc_dialog(id)
	else:
		# После промежуточной награды NPC сразу показывает новую реплику следующего этапа.
		_show_island_npc_dialog(id)

func _show_island_event(id:String)->void:
	if not is_instance_valid(island_progression): return
	var event:Dictionary=island_progression.call("get_island_event",id)
	if event.is_empty(): return
	var completed_event:=bool(island_progression.call("is_event_completed",id))
	if modal:
		modal.queue_free()
		modal=null
	modal=Control.new()
	modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal.mouse_filter=Control.MOUSE_FILTER_STOP
	var shade:=ColorRect.new(); shade.size=Vector2(900,900); shade.color=Color(0.03,0.02,0.08,.84); modal.add_child(shade)
	var box:=Panel.new(); box.position=Vector2(145,215); box.size=Vector2(610,455); box.add_theme_stylebox_override("panel",_style(Color("#18233b"),Color("#a77bd2"),24)); modal.add_child(box)
	var title:=Label.new(); title.text="%s %s"%[str(event["icon"]),str(event["name"])]; title.position=Vector2(35,24); title.size=Vector2(540,45); title.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; title.add_theme_font_size_override("font_size",24); title.add_theme_color_override("font_color",Color("#f1ddff")); box.add_child(title)
	var desc:=Label.new(); desc.text=str(event["description"]); desc.position=Vector2(45,82); desc.size=Vector2(520,64); desc.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; desc.vertical_alignment=VERTICAL_ALIGNMENT_CENTER; desc.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; desc.add_theme_font_size_override("font_size",14); desc.add_theme_color_override("font_color",Color("#c9c5d9")); box.add_child(desc)
	var story:=Label.new(); story.text="«%s»"%str(event["event_text"]); story.position=Vector2(45,150); story.size=Vector2(520,72); story.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; story.vertical_alignment=VERTICAL_ALIGNMENT_CENTER; story.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; story.add_theme_font_size_override("font_size",13); story.add_theme_color_override("font_color",Color("#e5d9ea")); box.add_child(story)
	var reward:Dictionary=event["reward"]
	var reward_text:="🎁 Награда: ⭐ +%d"%int(reward.get("stars",0))
	var booster:=str(reward.get("booster",""))
	var amount:=int(reward.get("amount",0))
	if not booster.is_empty() and amount>0:
		reward_text+="   •   %s +%d"%[booster,amount]
	var reward_label:=Label.new(); reward_label.text=reward_text; reward_label.position=Vector2(35,231); reward_label.size=Vector2(540,30); reward_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; reward_label.add_theme_font_size_override("font_size",13); reward_label.add_theme_color_override("font_color",Color("#ffd86a")); box.add_child(reward_label)
	var bonus:=Label.new(); bonus.text="✨ Постоянные преимущества: %s"%str(island_progression.call("get_permanent_bonus_text")); bonus.position=Vector2(35,267); bonus.size=Vector2(540,58); bonus.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; bonus.vertical_alignment=VERTICAL_ALIGNMENT_CENTER; bonus.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; bonus.add_theme_font_size_override("font_size",10); bonus.add_theme_color_override("font_color",Color("#d7c8ed")); box.add_child(bonus)
	var claim:=Button.new(); claim.position=Vector2(85,345); claim.size=Vector2(440,50); claim.add_theme_font_size_override("font_size",14); box.add_child(claim)
	if completed_event:
		claim.text="СОБЫТИЕ ЗАВЕРШЕНО"; claim.disabled=true; claim.add_theme_stylebox_override("normal",_style(Color("#28434b"),Color("#67ae9d"),12))
	else:
		claim.text="ПРОВЕСТИ СОБЫТИЕ"; claim.add_theme_stylebox_override("normal",_style(Color("#51376a"),Color("#d9b2ff"),12)); claim.pressed.connect(_claim_island_event.bind(id))
	var close:=Button.new(); close.text="← КАРТА ОСТРОВА"; close.position=Vector2(85,402); close.size=Vector2(440,34); close.add_theme_stylebox_override("normal",_style(Color("#18334a"),Color("#527a99"),10)); close.pressed.connect(_close_island_visual_map); box.add_child(close)
	map_layer.add_child(modal)

func _claim_island_event(id:String)->void:
	if not is_instance_valid(island_progression): return
	var result:Dictionary=island_progression.call("claim_island_event",id)
	if not bool(result.get("ok",false)): return
	_apply_island_reward(result["reward"])
	_show_island_visual_map()

func _claim_secret(id:String)->void:
	if not is_instance_valid(island_progression): return
	var result:Dictionary=island_progression.call("claim_secret",id)
	if not bool(result.get("ok",false)): return
	_apply_island_reward(result["reward"])
	_show_secret_dialog(id)

func _show_npc_quest(id:String)->void:
	if not is_instance_valid(island_progression): return
	var npc:Dictionary=island_progression.call("get_npc_definition",id)
	var state:Dictionary=island_progression.call("get_quest_status",id,_completed_level_count(),island_progression.get_unlocked_zone_count(),_repaired_object_count())
	if npc.is_empty() or state.is_empty(): return
	if modal:
		modal.queue_free()
		modal=null
	modal=Control.new()
	modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal.mouse_filter=Control.MOUSE_FILTER_STOP
	var shade:=ColorRect.new(); shade.size=Vector2(900,900); shade.color=Color(0.02,0.04,0.09,.78); modal.add_child(shade)
	var box:=Panel.new(); box.position=Vector2(145,220); box.size=Vector2(610,455); box.add_theme_stylebox_override("panel",_style(Color("#10263b"),Color("#5b8eb0"),22)); modal.add_child(box)
	var head:=Label.new(); head.text=str(npc["name"])+": "+str(state["quest"]["title"]); head.position=Vector2(35,22); head.size=Vector2(540,43); head.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; head.add_theme_font_size_override("font_size",22); head.add_theme_color_override("font_color",Color("#f2f7ff")); box.add_child(head)
	var stage_label:=Label.new(); stage_label.text="Этап %d из %d"%[int(state["stage"]),int(state["stage_count"])]; stage_label.position=Vector2(35,64); stage_label.size=Vector2(540,24); stage_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; stage_label.add_theme_font_size_override("font_size",12); stage_label.add_theme_color_override("font_color",Color("#71d7b0")); box.add_child(stage_label)
	var desc:=Label.new(); desc.text=str(state["quest"]["description"]); desc.position=Vector2(45,100); desc.size=Vector2(520,74); desc.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; desc.vertical_alignment=VERTICAL_ALIGNMENT_CENTER; desc.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; desc.add_theme_font_size_override("font_size",14); desc.add_theme_color_override("font_color",Color("#b8cbe0")); box.add_child(desc)
	var progress:=Label.new(); progress.text="Прогресс: %d / %d"%[int(state["current"]),int(state["target"])]; progress.position=Vector2(50,181); progress.size=Vector2(510,32); progress.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; progress.add_theme_font_size_override("font_size",18); progress.add_theme_color_override("font_color",Color("#72d7b0")); box.add_child(progress)
	var reward:Dictionary=state["quest"]["reward"]
	var reward_text:="🎁 Награда: ⭐ +%d"%int(reward.get("stars",0))
	var booster_name:=str(reward.get("booster",""))
	var booster_amount:=int(reward.get("amount",0))
	if not booster_name.is_empty() and booster_amount>0:
		reward_text+="   •   %s +%d"%[booster_name,booster_amount]
	var reward_label:=Label.new(); reward_label.text=reward_text; reward_label.position=Vector2(35,225); reward_label.size=Vector2(540,32); reward_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; reward_label.add_theme_font_size_override("font_size",13); reward_label.add_theme_color_override("font_color",Color("#ffd86a")); box.add_child(reward_label)
	if reward.has("unique"):
		var unique_label:=Label.new(); unique_label.text="🏆 Финальная награда цепочки: %s %s"%[str(reward.get("unique_icon","🏆")),str(reward.get("unique_name","Уникальный предмет"))]; unique_label.position=Vector2(35,258); unique_label.size=Vector2(540,31); unique_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; unique_label.add_theme_font_size_override("font_size",11); unique_label.add_theme_color_override("font_color",Color("#e7c56c")); box.add_child(unique_label)
	var claim:=Button.new(); claim.position=Vector2(85,305); claim.size=Vector2(440,52); claim.add_theme_font_size_override("font_size",14); box.add_child(claim)
	if bool(state.get("chain_done",false)):
		claim.text="🏆 ЦЕПОЧКА ЗАВЕРШЕНА"; claim.disabled=true; claim.add_theme_stylebox_override("normal",_style(Color("#245c4c"),Color("#4db98b"),12))
	elif bool(state["done"]):
		claim.text="ПОЛУЧИТЬ НАГРАДУ • ЭТАП %d"%int(state["stage"]); claim.add_theme_stylebox_override("normal",_style(Color("#5c4a25"),Color("#d8b354"),12)); claim.pressed.connect(_claim_npc_quest.bind(id))
	else:
		claim.text="ЕЩЁ НУЖНО ПРОГРЕССА"; claim.disabled=true
	var close:=Button.new(); close.text="← НАЗАД К NPC"; close.position=Vector2(85,378); close.size=Vector2(440,42); close.add_theme_stylebox_override("normal",_style(Color("#18334a"),Color("#527a99"),12)); close.pressed.connect(_show_island_npc_dialog.bind(id)); box.add_child(close)
	map_layer.add_child(modal)

func _show_secret_dialog(id:String)->void:
	if not is_instance_valid(island_progression): return
	var secret:Dictionary=island_progression.call("get_secret",id)
	if secret.is_empty(): return
	var claimed:=bool(island_progression.call("is_secret_claimed",id))
	if modal:
		modal.queue_free()
		modal=null
	modal=Control.new(); modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); modal.mouse_filter=Control.MOUSE_FILTER_STOP
	var shade:=ColorRect.new(); shade.size=Vector2(900,900); shade.color=Color(0.02,0.04,0.09,.78); modal.add_child(shade)
	var box:=Panel.new(); box.position=Vector2(160,270); box.size=Vector2(580,335); box.add_theme_stylebox_override("panel",_style(Color("#142b35"),Color("#8a7443"),22)); modal.add_child(box)
	var title:=Label.new(); title.text=str(secret["icon"])+" "+str(secret["name"]); title.position=Vector2(35,25); title.size=Vector2(510,40); title.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; title.add_theme_font_size_override("font_size",23); title.add_theme_color_override("font_color",Color("#f4e2a7")); box.add_child(title)
	var desc:=Label.new(); desc.text=str(secret["description"]); desc.position=Vector2(40,85); desc.size=Vector2(500,80); desc.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; desc.vertical_alignment=VERTICAL_ALIGNMENT_CENTER; desc.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; desc.add_theme_font_size_override("font_size",15); desc.add_theme_color_override("font_color",Color("#c7d5d4")); box.add_child(desc)
	var reward:Dictionary=secret["reward"]; var reward_label:=Label.new(); reward_label.text="⭐ +%d   •   %s +%d"%[int(reward["stars"]),str(reward["booster"]),int(reward["amount"])]; reward_label.position=Vector2(40,175); reward_label.size=Vector2(500,32); reward_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; reward_label.add_theme_font_size_override("font_size",14); reward_label.add_theme_color_override("font_color",Color("#ffd86a")); box.add_child(reward_label)
	var claim:=Button.new(); claim.position=Vector2(90,230); claim.size=Vector2(400,48); claim.add_theme_font_size_override("font_size",14); box.add_child(claim)
	if claimed:
		claim.text="НАЙДЕНО"; claim.disabled=true
	else:
		claim.text="ЗАБРАТЬ НАХОДКУ"; claim.add_theme_stylebox_override("normal",_style(Color("#5c4a25"),Color("#d8b354"),12)); claim.pressed.connect(_claim_secret.bind(id))
	var close:=Button.new(); close.text="← КАРТА ОСТРОВА"; close.position=Vector2(90,285); close.size=Vector2(400,34); close.add_theme_stylebox_override("normal",_style(Color("#18334a"),Color("#527a99"),10)); close.pressed.connect(_close_island_visual_map); box.add_child(close)
	map_layer.add_child(modal)

func _add_island_event_marker(parent:Control,event:Dictionary)->void:
	var p:Vector2=event.get("map_pos",Vector2(100,100))
	var b:=Button.new()
	b.position=p-Vector2(29,29)
	b.size=Vector2(58,58)
	b.flat=true
	b.tooltip_text=str(event["name"])
	b.mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
	b.add_theme_stylebox_override("normal",_style(Color(0,0,0,0),Color(0,0,0,0),30))
	b.add_theme_stylebox_override("hover",_style(Color(0.35,0.24,0.55,.18),Color("#d9b9ff"),30))
	var icon:=Label.new()
	icon.text=str(event["icon"])
	icon.position=Vector2.ZERO
	icon.size=Vector2(58,58)
	icon.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	icon.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
	icon.add_theme_font_size_override("font_size",23)
	icon.add_theme_color_override("font_color",Color("#d9b9ff"))
	b.add_child(icon)
	b.pressed.connect(_show_island_event.bind(str(event["id"])))
	parent.add_child(b)
	var l:=Label.new()
	l.text=str(event["name"])
	l.position=p+Vector2(-62,28)
	l.size=Vector2(124,26)
	l.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size",8)
	l.add_theme_color_override("font_color",Color("#e2c8ff"))
	parent.add_child(l)

func _add_island_interactive_marker(parent:Control,item:Dictionary,visual_state:int)->void:
	var p:Vector2=item.get("map_pos",Vector2(100,100))
	var b:=Button.new()
	b.position=p-Vector2(29,29)
	b.size=Vector2(58,58)
	b.flat=true
	b.tooltip_text=str(item["name"])
	b.disabled=visual_state==0
	b.mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
	b.add_theme_stylebox_override("normal",_style(Color(0,0,0,0),Color(0,0,0,0),30))
	b.add_theme_stylebox_override("hover",_style(Color(.25,.55,.72,.18),Color("#83ddff"),30))
	var art:Node2D = island_art_factory.call("create_interactive",str(item["id"]),visual_state) as Node2D
	art.position=Vector2(29,29)
	b.add_child(art)
	b.pressed.connect(_show_interactive_object.bind(str(item["id"])))
	parent.add_child(b)
	var l:=Label.new()
	l.text=str(item["name"])+(" ✓" if visual_state==2 else "")
	l.position=p+Vector2(-65,28)
	l.size=Vector2(130,28)
	l.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size",8)
	l.add_theme_color_override("font_color",Color("#bfeaff"))
	parent.add_child(l)

func _add_island_activity_marker(parent:Control,activity:Dictionary,visual_state:int,is_secret:bool=false)->void:
	var p:Vector2=activity.get("map_pos",Vector2(100,100))
	var b:=Button.new()
	b.position=p-Vector2(29,29)
	b.size=Vector2(58,58)
	b.flat=true
	b.tooltip_text=("🌟 " if is_secret else "")+str(activity["name"])
	b.disabled=visual_state==0
	b.mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
	b.add_theme_stylebox_override("normal",_style(Color(0,0,0,0),Color(0,0,0,0),30))
	b.add_theme_stylebox_override("hover",_style(Color(.55,.34,.18,.18),Color("#ffc56e"),30))
	var art:Node2D = island_art_factory.call("create_activity",str(activity["icon"]),visual_state,is_secret) as Node2D
	art.position=Vector2(29,29)
	b.add_child(art)
	b.pressed.connect(_show_mini_activity.bind(str(activity["id"])))
	parent.add_child(b)
	var l:=Label.new()
	l.text=("🌟 " if is_secret else "")+str(activity["name"])+(" ✓" if visual_state==2 else "")
	l.position=p+Vector2(-65,28)
	l.size=Vector2(130,28)
	l.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size",8)
	l.add_theme_color_override("font_color",Color("#ffe0a8") if not is_secret else Color("#e7c5ff"))
	parent.add_child(l)

func _show_interactive_object(id:String)->void:
	if not is_instance_valid(island_progression): return
	var item:Dictionary=island_progression.call("get_interactive_object",id)
	if item.is_empty(): return
	var claimed:=bool(island_progression.call("is_interactive_completed",id))
	if modal:
		modal.queue_free()
		modal=null
	modal=Control.new()
	modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal.mouse_filter=Control.MOUSE_FILTER_STOP
	var shade:=ColorRect.new(); shade.size=Vector2(900,900); shade.color=Color(0.02,0.07,0.11,.84); modal.add_child(shade)
	var box:=Panel.new(); box.position=Vector2(155,235); box.size=Vector2(590,410); box.add_theme_stylebox_override("panel",_style(Color("#122a3b"),Color("#69c7e7"),22)); modal.add_child(box)
	var title:=Label.new(); title.text="%s %s"%[str(item["icon"]),str(item["name"])]; title.position=Vector2(35,25); title.size=Vector2(520,40); title.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; title.add_theme_font_size_override("font_size",23); title.add_theme_color_override("font_color",Color("#e6f8ff")); box.add_child(title)
	var desc:=Label.new(); desc.text=str(item["description"]); desc.position=Vector2(45,85); desc.size=Vector2(500,90); desc.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; desc.vertical_alignment=VERTICAL_ALIGNMENT_CENTER; desc.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; desc.add_theme_font_size_override("font_size",14); desc.add_theme_color_override("font_color",Color("#c4dbe6")); box.add_child(desc)
	var reward:Dictionary=item["reward"]
	var reward_label:=Label.new(); reward_label.text="🎁 Награда: ⭐ +%d   •   %s +%d"%[int(reward.get("stars",0)),str(reward.get("booster","")),int(reward.get("amount",0))]; reward_label.position=Vector2(40,183); reward_label.size=Vector2(510,30); reward_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; reward_label.add_theme_font_size_override("font_size",13); reward_label.add_theme_color_override("font_color",Color("#ffd86a")); box.add_child(reward_label)
	var available:=bool(island_progression.call("is_interactive_available",item))
	var claim:=Button.new(); claim.position=Vector2(85,242); claim.size=Vector2(420,48); claim.add_theme_font_size_override("font_size",14); box.add_child(claim)
	if claimed:
		claim.text="ОБЪЕКТ УЖЕ АКТИВИРОВАН"; claim.disabled=true
	elif not available:
		claim.text="НУЖЕН: %s"%str(item.get("unique_required","особый предмет")); claim.disabled=true; claim.add_theme_stylebox_override("normal",_style(Color("#202d3b"),Color("#45586d"),12))
	else:
		claim.text="ИСПОЛЬЗОВАТЬ ПРЕДМЕТ"; claim.add_theme_stylebox_override("normal",_style(Color("#22586f"),Color("#75d7f2"),12)); claim.pressed.connect(_claim_interactive.bind(id))
	var close:=Button.new(); close.text="← КАРТА ОСТРОВА"; close.position=Vector2(85,315); close.size=Vector2(420,38); close.add_theme_stylebox_override("normal",_style(Color("#18334a"),Color("#527a99"),10)); close.pressed.connect(_close_island_visual_map); box.add_child(close)
	map_layer.add_child(modal)

func _claim_interactive(id:String)->void:
	if not is_instance_valid(island_progression): return
	var result:Dictionary=island_progression.call("claim_interactive",id)
	if not bool(result.get("ok",false)): return
	_apply_island_reward(result["reward"])
	_show_island_visual_map()

func _show_mini_activity(id:String)->void:
	if not is_instance_valid(island_progression): return
	var activity:Dictionary=island_progression.call("get_mini_activity",id)
	if activity.is_empty(): return
	mini_activity_id=id
	mini_sequence_progress=0
	mini_goods_collected.clear()
	mini_activity_buttons.clear()
	if modal:
		modal.queue_free()
		modal=null
	modal=Control.new()
	modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal.mouse_filter=Control.MOUSE_FILTER_STOP
	var shade:=ColorRect.new(); shade.size=Vector2(900,900); shade.color=Color(0.06,0.035,0.015,.90); modal.add_child(shade)
	var box:=Panel.new(); box.position=Vector2(75,145); box.size=Vector2(750,610); box.add_theme_stylebox_override("panel",_style(Color("#332514"),Color("#c78b47"),24)); modal.add_child(box)
	var title:=Label.new(); title.text=("%s %s • РЕДКАЯ ВЕРСИЯ"%[str(activity["icon"]),str(activity["name"])]) if activity.has("secret_reward") else "%s %s"%[str(activity["icon"]),str(activity["name"])]; title.position=Vector2(40,25); title.size=Vector2(670,46); title.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; title.add_theme_font_size_override("font_size",25); title.add_theme_color_override("font_color",Color("#ffe6bd")); box.add_child(title)
	var desc:=Label.new(); desc.text=str(activity["description"]); desc.position=Vector2(55,82); desc.size=Vector2(640,62); desc.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; desc.vertical_alignment=VERTICAL_ALIGNMENT_CENTER; desc.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; desc.add_theme_font_size_override("font_size",14); desc.add_theme_color_override("font_color",Color("#e3cfb5")); box.add_child(desc)
	mini_status_label=Label.new(); mini_status_label.text=""; mini_status_label.position=Vector2(50,150); mini_status_label.size=Vector2(650,38); mini_status_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; mini_status_label.add_theme_font_size_override("font_size",15); mini_status_label.add_theme_color_override("font_color",Color("#ffd36d")); box.add_child(mini_status_label)
	var secret_reward:Dictionary=activity.get("secret_reward",{})
	if not secret_reward.is_empty():
		var secret_label:=Label.new(); secret_label.text="💠 Уникальная награда: %s %s"%[str(secret_reward.get("icon","💠")),str(secret_reward.get("name","Секретный трофей"))]; secret_label.position=Vector2(45,195); secret_label.size=Vector2(660,28); secret_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; secret_label.add_theme_font_size_override("font_size",12); secret_label.add_theme_color_override("font_color",Color("#e0b8ff")); box.add_child(secret_label)
	var type:=str(activity.get("type",""))
	var labels:Array=activity.get("labels",[])
	match type:
		"sequence":
			for i in range(labels.size()):
				var seq_button:=Button.new(); seq_button.text=str(labels[i]); seq_button.position=Vector2(75+i*150,235); seq_button.size=Vector2(115,100); seq_button.add_theme_font_size_override("font_size",28); seq_button.add_theme_stylebox_override("normal",_style(Color("#4a351f"),Color("#c8904d"),16)); seq_button.pressed.connect(_mini_sequence_press.bind(i)); box.add_child(seq_button); mini_activity_buttons.append(seq_button)
			mini_status_label.text="Повтори последовательность"
		"odd_one":
			for i in range(labels.size()):
				var rune_button:=Button.new(); rune_button.text=str(labels[i]); rune_button.position=Vector2(55+(i%5)*132,235+int(i/5)*120); rune_button.size=Vector2(105,95); rune_button.add_theme_font_size_override("font_size",25); rune_button.add_theme_stylebox_override("normal",_style(Color("#403123"),Color("#b0844e"),16)); rune_button.pressed.connect(_mini_odd_press.bind(i)); box.add_child(rune_button); mini_activity_buttons.append(rune_button)
			mini_status_label.text="Найди единственную отличающуюся руну"
		"collect_three":
			for i in range(labels.size()):
				var good_button:=Button.new(); good_button.text=str(labels[i]); good_button.position=Vector2(90+i*210,255); good_button.size=Vector2(185,105); good_button.add_theme_font_size_override("font_size",13); good_button.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; good_button.add_theme_stylebox_override("normal",_style(Color("#4a351f"),Color("#c8904d"),16)); good_button.pressed.connect(_mini_collect_press.bind(i)); box.add_child(good_button); mini_activity_buttons.append(good_button)
			mini_status_label.text="Подготовь все три товара"
		"order_goods":
			for i in range(labels.size()):
				var columns:=2 if labels.size()>3 else labels.size()
				var gap_x:=25 if columns==2 else 25
				var row_index:=int(i/columns)
				var col_index:=i%columns
				var order_button:=Button.new(); order_button.text=str(labels[i]); order_button.position=Vector2(80+col_index*310,235+row_index*125); order_button.size=Vector2(280,105); order_button.add_theme_font_size_override("font_size",13); order_button.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; order_button.add_theme_stylebox_override("normal",_style(Color("#4a351f"),Color("#c8904d"),16)); order_button.pressed.connect(_mini_sequence_press.bind(i)); box.add_child(order_button); mini_activity_buttons.append(order_button)
			mini_status_label.text="Отправь товары в нужном порядке"
	var close:=Button.new(); close.text="← НАЗАД"; close.position=Vector2(170,520); close.size=Vector2(410,45); close.add_theme_stylebox_override("normal",_style(Color("#3a2d25"),Color("#826a54"),12)); close.pressed.connect(_close_mini_activity); box.add_child(close)
	map_layer.add_child(modal)

func _mini_sequence_press(index:int)->void:
	if mini_activity_id.is_empty() or not is_instance_valid(mini_status_label): return
	var activity:Dictionary=island_progression.call("get_mini_activity",mini_activity_id)
	var sequence:Array=activity.get("sequence",[])
	if mini_sequence_progress>=sequence.size(): return
	if int(sequence[mini_sequence_progress])==index:
		mini_sequence_progress+=1
		if index<mini_activity_buttons.size():
			mini_activity_buttons[index].disabled=true
		if mini_sequence_progress>=sequence.size():
			_finish_mini_activity()
		else:
			mini_status_label.text="Правильно! %d / %d"%[mini_sequence_progress,sequence.size()]
	else:
		mini_sequence_progress=0
		for b in mini_activity_buttons:
			b.disabled=false
		mini_status_label.text="Ошибка! Последовательность сброшена."

func _mini_odd_press(index:int)->void:
	if mini_activity_id.is_empty() or not is_instance_valid(mini_status_label): return
	var activity:Dictionary=island_progression.call("get_mini_activity",mini_activity_id)
	var target_index:=int(activity.get("target_index",-1))
	if index==target_index:
		_finish_mini_activity()
		return
	mini_status_label.text="Это не та руна. Попробуй ещё раз."
	if index<mini_activity_buttons.size():
		mini_activity_buttons[index].disabled=true
func _mini_collect_press(index:int)->void:
	if mini_activity_id.is_empty(): return
	if mini_goods_collected.has(index): return
	mini_goods_collected[index]=true
	if index<mini_activity_buttons.size():
		mini_activity_buttons[index].disabled=true
	var count:=mini_goods_collected.size()
	if count>=3:
		_finish_mini_activity()
	elif is_instance_valid(mini_status_label):
		mini_status_label.text="Товар принят: %d / 3"%count

func _finish_mini_activity()->void:
	if not is_instance_valid(island_progression): return
	var id:=mini_activity_id
	var result:Dictionary=island_progression.call("claim_mini_activity",id)
	if not bool(result.get("ok",false)):
		return
	_apply_island_reward(result["reward"])
	mini_activity_id=""
	mini_sequence_progress=0
	mini_goods_collected.clear()
	mini_activity_buttons.clear()
	_show_island_visual_map()

func _close_mini_activity()->void:
	mini_activity_id=""
	mini_sequence_progress=0
	mini_goods_collected.clear()
	mini_activity_buttons.clear()
	_close_island_visual_map()

func _add_island_secret_marker(parent:Control,secret:Dictionary)->void:
	var p:Vector2=secret.get("map_pos",Vector2(100,100))
	var claimed:=bool(island_progression.call("is_secret_claimed",str(secret["id"])))
	var b:=Button.new(); b.position=p-Vector2(26,26); b.size=Vector2(52,52); b.flat=true; b.mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND; b.add_theme_stylebox_override("normal",_style(Color(0,0,0,0),Color(0,0,0,0),20)); b.add_theme_stylebox_override("hover",_style(Color(1,1,1,.09),Color("#e7cb72"),20))
	var icon:=Label.new(); icon.text="✓" if claimed else str(secret["icon"]); icon.position=Vector2.ZERO; icon.size=Vector2(52,52); icon.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; icon.vertical_alignment=VERTICAL_ALIGNMENT_CENTER; icon.add_theme_font_size_override("font_size",23); icon.add_theme_color_override("font_color",Color("#a9b8ad") if claimed else Color("#f1d679")); b.add_child(icon)
	b.pressed.connect(_show_secret_dialog.bind(str(secret["id"]))); parent.add_child(b)
	var l:=Label.new(); l.text=str(secret["name"]); l.position=p+Vector2(-55,25); l.size=Vector2(110,24); l.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; l.add_theme_font_size_override("font_size",8); l.add_theme_color_override("font_color",Color("#d7c993")); parent.add_child(l)

func _show_island_npc_dialog(id:String)->void:
	if not is_instance_valid(island_progression): return
	var npc:Dictionary=island_progression.call("get_npc_definition",id)
	if npc.is_empty(): return
	if modal:
		modal.queue_free()
		modal=null
	modal=Control.new()
	modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal.mouse_filter=Control.MOUSE_FILTER_STOP
	var shade:=ColorRect.new(); shade.size=Vector2(900,900); shade.color=Color(0.02,0.04,0.09,.72); modal.add_child(shade)
	var box:=Panel.new(); box.position=Vector2(150,265); box.size=Vector2(600,350); box.add_theme_stylebox_override("panel",_style(Color("#10263b"),Color("#5b8eb0"),22)); modal.add_child(box)
	var face_art:Node2D = island_art_factory.call("create_npc",str(npc["role"])) as Node2D; face_art.position=Vector2(92,90); box.add_child(face_art)
	var name:=Label.new(); name.text=str(npc["name"]); name.position=Vector2(165,40); name.size=Vector2(390,35); name.add_theme_font_size_override("font_size",24); name.add_theme_color_override("font_color",Color("#f2f7ff")); box.add_child(name)
	var role:=Label.new(); role.text=str(npc["role"]); role.position=Vector2(165,78); role.size=Vector2(390,25); role.add_theme_font_size_override("font_size",11); role.add_theme_color_override("font_color",Color("#71d7b0")); box.add_child(role)
	var dialogue:=str(npc["text"])
	var qstate:Dictionary=island_progression.call("get_quest_status",id,_completed_level_count(),island_progression.get_unlocked_zone_count(),_repaired_object_count())
	if not qstate.is_empty():
		dialogue=str(island_progression.call("get_npc_quest_dialogue",id,int(qstate.get("stage",1)),bool(qstate.get("chain_done",false))))
		if dialogue.is_empty():
			dialogue=str(npc["text"])
	var text_label:=Label.new(); text_label.text="«%s»"%dialogue; text_label.position=Vector2(45,145); text_label.size=Vector2(510,100); text_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; text_label.vertical_alignment=VERTICAL_ALIGNMENT_CENTER; text_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; text_label.add_theme_font_size_override("font_size",17); text_label.add_theme_color_override("font_color",Color("#c4d3e2")); box.add_child(text_label)
	var quest_state:Dictionary=island_progression.call("get_quest_status",id,_completed_level_count(),island_progression.get_unlocked_zone_count(),_repaired_object_count())
	var quest_text:="📜 ЗАДАНИЕ"
	if not quest_state.is_empty():
		quest_text="🏆 ЦЕПОЧКА ЗАВЕРШЕНА" if bool(quest_state.get("chain_done",false)) else "📜 ЭТАП %d/%d"%[int(quest_state.get("stage",1)),int(quest_state.get("stage_count",1))]
	var quest:=Button.new(); quest.text=quest_text; quest.position=Vector2(85,235); quest.size=Vector2(220,44); quest.add_theme_stylebox_override("normal",_style(Color("#5c4a25"),Color("#d8b354"),12)); quest.pressed.connect(_show_npc_quest.bind(id)); box.add_child(quest)
	var event_to_show:Dictionary={}
	for event in island_progression.get_available_events():
		if str(event.get("npc_id",""))==id:
			event_to_show=event
			break
	if not event_to_show.is_empty():
		var event_button:=Button.new(); event_button.text="✨ СОБЫТИЕ"; event_button.position=Vector2(85,286); event_button.size=Vector2(220,40); event_button.add_theme_stylebox_override("normal",_style(Color("#47335f"),Color("#d6adff"),12)); event_button.pressed.connect(_show_island_event.bind(str(event_to_show["id"]))); box.add_child(event_button)
	var close:=Button.new(); close.text="ЗАКРЫТЬ"; close.position=Vector2(315,235); close.size=Vector2(155,44); close.add_theme_stylebox_override("normal",_style(Color("#193b52"),Color("#63a6d3"),12)); close.pressed.connect(_close_island_visual_map); box.add_child(close)
	map_layer.add_child(modal)

func _close_island_visual_map()->void:
	if modal:
		modal.queue_free()
		modal=null

func _show_island_collection()->void:
	if not is_instance_valid(island_progression): return
	if modal:
		modal.queue_free()
		modal=null
	modal=Control.new()
	modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal.mouse_filter=Control.MOUSE_FILTER_STOP
	var shade:=ColorRect.new(); shade.size=Vector2(900,900); shade.color=Color(0.03,0.02,0.08,.90); modal.add_child(shade)
	var panel:=Panel.new(); panel.position=Vector2(70,70); panel.size=Vector2(760,760); panel.add_theme_stylebox_override("panel",_style(Color("#141e35"),Color("#a77bd2"),24)); modal.add_child(panel)
	var title:=Label.new(); title.text="🏆 КОЛЛЕКЦИЯ ОСТРОВА"; title.position=Vector2(30,25); title.size=Vector2(700,42); title.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; title.add_theme_font_size_override("font_size",26); title.add_theme_color_override("font_color",Color("#f4e5ff")); panel.add_child(title)
	var count:=Label.new(); count.text=island_progression.call("get_collection_completion_text"); count.position=Vector2(30,67); count.size=Vector2(700,30); count.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; count.add_theme_font_size_override("font_size",14); count.add_theme_color_override("font_color",Color("#d3b9f0")); panel.add_child(count)

	var scroll:=ScrollContainer.new(); scroll.position=Vector2(30,110); scroll.size=Vector2(700,565); scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED; panel.add_child(scroll)
	var content:=VBoxContainer.new(); content.custom_minimum_size=Vector2(680,0); content.add_theme_constant_override("separation",14); scroll.add_child(content)

	var grid:=GridContainer.new(); grid.columns=2; grid.add_theme_constant_override("h_separation",12); grid.add_theme_constant_override("v_separation",12); grid.custom_minimum_size=Vector2(680,0); content.add_child(grid)
	for item in island_progression.get_collection_items():
		var collected:=bool(island_progression.call("is_collection_item_collected",str(item["id"])))
		var card:=Panel.new(); card.custom_minimum_size=Vector2(330,105); card.add_theme_stylebox_override("panel",_style(Color("#244437") if collected else Color("#1b2637"),Color("#69c7a5") if collected else Color("#38475c"),14)); grid.add_child(card)
		var icon:=Label.new(); icon.text=str(item["icon"]); icon.position=Vector2(15,18); icon.size=Vector2(55,55); icon.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; icon.vertical_alignment=VERTICAL_ALIGNMENT_CENTER; icon.add_theme_font_size_override("font_size",29); icon.add_theme_color_override("font_color",Color("#e6f8ee") if collected else Color("#718094")); card.add_child(icon)
		var name:=Label.new(); name.text=str(item["name"]); name.position=Vector2(78,17); name.size=Vector2(225,32); name.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; name.add_theme_font_size_override("font_size",12); name.add_theme_color_override("font_color",Color("#f2f6ff") if collected else Color("#7f8ba0")); card.add_child(name)
		var state:=Label.new(); state.text="ПОЛУЧЕНО" if collected else "ЕЩЁ НЕ НАЙДЕНО"; state.position=Vector2(78,58); state.size=Vector2(225,24); state.add_theme_font_size_override("font_size",9); state.add_theme_color_override("font_color",Color("#71d7b0") if collected else Color("#657386")); card.add_child(state)

	var milestone_title:=Label.new(); milestone_title.text="🎁 НАГРАДЫ ЗА ЗАПОЛНЕНИЕ"; milestone_title.custom_minimum_size=Vector2(680,32); milestone_title.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; milestone_title.add_theme_font_size_override("font_size",16); milestone_title.add_theme_color_override("font_color",Color("#ead7ff")); content.add_child(milestone_title)
	for milestone in island_progression.get_collection_milestones():
		var id:=str(milestone["id"])
		var threshold:=int(milestone["threshold"])
		var collected_count:=int(island_progression.call("get_collection_count"))
		var claimed:=bool(island_progression.call("is_collection_milestone_claimed",id))
		var available:=bool(island_progression.call("is_collection_milestone_available",milestone))
		var reward:Dictionary=milestone["reward"]
		var row:=Panel.new(); row.custom_minimum_size=Vector2(680,72); row.add_theme_stylebox_override("panel",_style(Color("#29434a") if claimed else (Color("#4b3b26") if available else Color("#1b2637")),Color("#65b79c") if claimed else (Color("#d9b35c") if available else Color("#39485b")),12)); content.add_child(row)
		var label:=Label.new(); label.text=str(milestone["title"]); label.position=Vector2(15,9); label.size=Vector2(245,23); label.add_theme_font_size_override("font_size",12); label.add_theme_color_override("font_color",Color("#f1f5ff")); row.add_child(label)
		var progress:=Label.new(); progress.text="%d / %d предметов"%[mini(collected_count,threshold),threshold]; progress.position=Vector2(15,36); progress.size=Vector2(150,20); progress.add_theme_font_size_override("font_size",10); progress.add_theme_color_override("font_color",Color("#9bb0c1")); row.add_child(progress)
		var reward_text:="⭐ +%d"%int(reward.get("stars",0))
		var booster:=str(reward.get("booster",""))
		var amount:=int(reward.get("amount",0))
		if not booster.is_empty() and amount>0:
			reward_text+="  •  %s +%d"%[booster,amount]
		var reward_label:=Label.new(); reward_label.text=reward_text; reward_label.position=Vector2(270,20); reward_label.size=Vector2(190,28); reward_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; reward_label.add_theme_font_size_override("font_size",10); reward_label.add_theme_color_override("font_color",Color("#ffd86a")); row.add_child(reward_label)
		var claim:=Button.new(); claim.position=Vector2(500,13); claim.size=Vector2(160,46); claim.add_theme_font_size_override("font_size",10); row.add_child(claim)
		if claimed:
			claim.text="✓ ПОЛУЧЕНО"; claim.disabled=true; claim.add_theme_stylebox_override("normal",_style(Color("#28433c"),Color("#4d806e"),10))
		elif available:
			claim.text="ПОЛУЧИТЬ"; claim.add_theme_stylebox_override("normal",_style(Color("#604b25"),Color("#d8b354"),10)); claim.pressed.connect(_claim_collection_milestone.bind(id))
		else:
			claim.text="ЕЩЁ %d"%maxi(0,threshold-collected_count); claim.disabled=true; claim.add_theme_stylebox_override("normal",_style(Color("#172231"),Color("#33485d"),10))

	var secret_count:=int(island_progression.call("get_secret_collection_count"))
	var secret_hint:=Label.new(); secret_hint.text="💠 Секретная коллекция: %d / %d"%[secret_count,int(island_progression.call("get_secret_collection_total"))]; secret_hint.custom_minimum_size=Vector2(680,28); secret_hint.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; secret_hint.add_theme_font_size_override("font_size",12); secret_hint.add_theme_color_override("font_color",Color("#d5b5ff")); content.add_child(secret_hint)
	var secret_items:=Label.new(); var secret_lines:Array[String]=[]
	for secret_item in island_progression.call("get_secret_collection_items"):
		var collected:=bool(island_progression.call("is_secret_collection_item_collected",str(secret_item["id"])))
		secret_lines.append(("%s %s" if collected else "○ %s")%[str(secret_item["icon"]),str(secret_item["name"])])
	secret_items.text=" • ".join(secret_lines); secret_items.custom_minimum_size=Vector2(680,30); secret_items.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; secret_items.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; secret_items.add_theme_font_size_override("font_size",10); secret_items.add_theme_color_override("font_color",Color("#b7a7c7")); content.add_child(secret_items)

	var secret_reward_available:=bool(island_progression.call("is_secret_collection_reward_available"))
	var secret_reward_claimed:=bool(island_progression.call("is_secret_collection_reward_claimed"))
	var secret_reward_row:=Panel.new(); secret_reward_row.custom_minimum_size=Vector2(680,72); secret_reward_row.add_theme_stylebox_override("panel",_style(Color("#29434a") if secret_reward_claimed else (Color("#4b365d") if secret_reward_available else Color("#1b2637")),Color("#65b79c") if secret_reward_claimed else (Color("#d5a7ff") if secret_reward_available else Color("#39485b")),12)); content.add_child(secret_reward_row)
	var secret_reward_title:=Label.new(); secret_reward_title.text="💠 Секретная коллекция 3/3"; secret_reward_title.position=Vector2(15,10); secret_reward_title.size=Vector2(245,23); secret_reward_title.add_theme_font_size_override("font_size",12); secret_reward_title.add_theme_color_override("font_color",Color("#f1f5ff")); secret_reward_row.add_child(secret_reward_title)
	var secret_reward_desc:=Label.new(); secret_reward_desc.text="⭐ +10  •  💣 Бомба на старт"; secret_reward_desc.position=Vector2(15,37); secret_reward_desc.size=Vector2(270,22); secret_reward_desc.add_theme_font_size_override("font_size",10); secret_reward_desc.add_theme_color_override("font_color",Color("#d5b5ff")); secret_reward_row.add_child(secret_reward_desc)
	var secret_claim:=Button.new(); secret_claim.position=Vector2(500,13); secret_claim.size=Vector2(160,46); secret_claim.add_theme_font_size_override("font_size",10); secret_reward_row.add_child(secret_claim)
	if secret_reward_claimed:
		secret_claim.text="✓ ПОЛУЧЕНО"; secret_claim.disabled=true; secret_claim.add_theme_stylebox_override("normal",_style(Color("#28433c"),Color("#4d806e"),10))
	elif secret_reward_available:
		secret_claim.text="ПОЛУЧИТЬ"; secret_claim.add_theme_stylebox_override("normal",_style(Color("#51376a"),Color("#d9b2ff"),10)); secret_claim.pressed.connect(_claim_secret_collection_reward)
	else:
		secret_claim.text="ЕЩЁ НУЖНО %d"%maxi(0,int(island_progression.call("get_secret_collection_total"))-secret_count); secret_claim.disabled=true; secret_claim.add_theme_stylebox_override("normal",_style(Color("#172231"),Color("#33485d"),10))

	var hint:=Label.new(); hint.text="При 100% основной коллекции открывается секретное событие «Сердце острова» на карте. Редкие мини-версии открываются после обычных."; hint.custom_minimum_size=Vector2(680,40); hint.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; hint.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; hint.add_theme_font_size_override("font_size",10); hint.add_theme_color_override("font_color",Color("#b7a7c7")); content.add_child(hint)

	var close:=Button.new(); close.text="← НАЗАД НА ОСТРОВ"; close.position=Vector2(170,700); close.size=Vector2(420,42); close.add_theme_stylebox_override("normal",_style(Color("#18334a"),Color("#527a99"),12)); close.pressed.connect(_close_island_visual_map); panel.add_child(close)
	map_layer.add_child(modal)

func _claim_collection_milestone(id:String)->void:
	if not is_instance_valid(island_progression): return
	var result:Dictionary=island_progression.call("claim_collection_milestone",id)
	if not bool(result.get("ok",false)): return
	_apply_island_reward(result["reward"])
	_show_island_collection()

func _claim_secret_collection_reward()->void:
	if not is_instance_valid(island_progression): return
	var result:Dictionary=island_progression.call("claim_secret_collection_reward")
	if not bool(result.get("ok",false)): return
	_apply_island_reward(result["reward"])
	_show_island_collection()

func _show_island_repair()->void:
	if modal:
		modal.queue_free()
		modal=null
	modal=Control.new()
	modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal.mouse_filter=Control.MOUSE_FILTER_STOP
	var shade:=ColorRect.new(); shade.size=Vector2(900,900); shade.color=Color(0.02,0.04,0.09,.88); modal.add_child(shade)
	var panel:=Panel.new(); panel.position=Vector2(55,45); panel.size=Vector2(790,810); panel.add_theme_stylebox_override("panel",_style(Color("#0e2034"),Color("#416b7c"),24)); modal.add_child(panel)
	var title:=Label.new(); title.text="🏝️ ВОССТАНОВЛЕНИЕ ОСТРОВА"; title.position=Vector2(35,22); title.size=Vector2(720,42); title.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; title.add_theme_font_size_override("font_size",26); title.add_theme_color_override("font_color",Color("#f4f7ff")); panel.add_child(title)
	var bank:=Label.new(); bank.name="IslandStarBank"; bank.text="⭐ Доступно звёзд: %d"%island_stars; bank.position=Vector2(35,66); bank.size=Vector2(720,30); bank.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; bank.add_theme_font_size_override("font_size",16); bank.add_theme_color_override("font_color",Color("#ffd86a")); panel.add_child(bank)
	var progress:=Label.new(); progress.text=island_progression.get_progress_text() if is_instance_valid(island_progression) else "Прогресс недоступен"; progress.position=Vector2(35,99); progress.size=Vector2(720,28); progress.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; progress.add_theme_font_size_override("font_size",11); progress.add_theme_color_override("font_color",Color("#83a9bd")); panel.add_child(progress)
	var scroll:=ScrollContainer.new(); scroll.position=Vector2(25,135); scroll.size=Vector2(740,560); scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED; panel.add_child(scroll)
	var list:=VBoxContainer.new(); list.custom_minimum_size=Vector2(700,0); list.add_theme_constant_override("separation",10); scroll.add_child(list)
	if is_instance_valid(island_progression):
		for item in island_progression.objects:
			var id:=str(item["id"])
			var repaired_now:=bool(island_progression.call("is_repaired",id))
			var unlocked:=int(item["zone"])==0 or bool(island_progression.call("is_zone_unlocked",int(item["zone"])-1))
			var row:=Panel.new(); row.custom_minimum_size=Vector2(700,92); row.add_theme_stylebox_override("panel",_style(Color("#17334a") if unlocked else Color("#111e2d"),Color("#3b7080") if repaired_now else (Color("#4f6d85") if unlocked else Color("#293b4d")),14)); list.add_child(row)
			var icon:=Label.new(); icon.text=str(item["icon"]); icon.position=Vector2(14,16); icon.add_theme_font_size_override("font_size",32); row.add_child(icon)
			var name:=Label.new(); name.text=str(item["name"])+("  ✓" if repaired_now else ""); name.position=Vector2(62,12); name.size=Vector2(310,27); name.add_theme_font_size_override("font_size",15); name.add_theme_color_override("font_color",Color("#70dfa9") if repaired_now else Color("#f1f6ff")); row.add_child(name)
			var desc:=Label.new(); desc.text=str(item["description"]); desc.position=Vector2(62,42); desc.size=Vector2(390,36); desc.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; desc.add_theme_font_size_override("font_size",10); desc.add_theme_color_override("font_color",Color("#8aa5ba")); row.add_child(desc)
			var btn:=Button.new(); btn.position=Vector2(505,18); btn.size=Vector2(170,52); btn.add_theme_font_size_override("font_size",11); row.add_child(btn)
			if repaired_now:
				btn.text="ВОССТАНОВЛЕНО"
				btn.disabled=true
				btn.add_theme_stylebox_override("normal",_style(Color("#245c4c"),Color("#4db98b"),12))
			elif not unlocked:
				btn.text="ЗОНА ЗАКРЫТА"
				btn.disabled=true
				btn.add_theme_stylebox_override("normal",_style(Color("#172231"),Color("#33485d"),12))
			else:
				btn.text="🔨 РЕМОНТ • %d ⭐"%int(item["cost"])
				btn.add_theme_stylebox_override("normal",_style(Color("#225b50"),Color("#61d6a2"),12))
				btn.pressed.connect(_repair_island_object.bind(id))
			var reward:=Label.new(); reward.text=str(item["reward_text"]); reward.position=Vector2(505,70); reward.size=Vector2(170,18); reward.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; reward.add_theme_font_size_override("font_size",9); reward.add_theme_color_override("font_color",Color("#7194aa")); row.add_child(reward)
	var npcs:=Label.new(); npcs.text="👥 NPC: %d   🎁 Сундуки: %d"%[(island_progression.get_npc_list().size() if is_instance_valid(island_progression) else 0),(island_progression.get_chests().size() if is_instance_valid(island_progression) else 0)]; npcs.position=Vector2(35,710); npcs.size=Vector2(720,28); npcs.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; npcs.add_theme_font_size_override("font_size",12); npcs.add_theme_color_override("font_color",Color("#9ab4c8")); panel.add_child(npcs)
	var close:=Button.new(); close.text="← НАЗАД НА КАРТУ"; close.position=Vector2(35,752); close.size=Vector2(340,42); close.add_theme_stylebox_override("normal",_style(Color("#182c45"),Color("#4a6989"))); close.pressed.connect(_close_island_repair); panel.add_child(close)
	var chest_btn:=Button.new(); chest_btn.text="🎁 ПРОВЕРИТЬ СУНДУКИ"; chest_btn.position=Vector2(395,752); chest_btn.size=Vector2(340,42); chest_btn.add_theme_stylebox_override("normal",_style(Color("#604b25"),Color("#d3a94f"))); chest_btn.pressed.connect(_show_island_chests); panel.add_child(chest_btn)
	map_layer.add_child(modal)

func _close_island_repair()->void:
	if modal:
		modal.queue_free()
		modal=null

func _repair_island_object(id:String)->void:
	if not is_instance_valid(island_progression): return
	var result:Dictionary=island_progression.call("repair",id,island_stars)
	if not bool(result.get("ok",false)):
		if status: status.text="Недостаточно звёзд или зона ещё закрыта"
		return
	island_stars-=int(result["cost"])
	_save_progress()
	_show_island_visual_map(id)

func _apply_island_reward(reward:Dictionary)->void:
	island_stars+=int(reward.get("stars",0))
	var booster:=str(reward.get("booster",""))
	var amount:=int(reward.get("amount",0))
	if not booster.is_empty() and amount>0:
		booster_inventory[booster]=int(booster_inventory.get(booster,0))+amount
	_save_progress()

func _show_island_chests()->void:
	if not is_instance_valid(island_progression): return
	if modal:
		modal.queue_free()
		modal=null
	modal=Control.new(); modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); modal.mouse_filter=Control.MOUSE_FILTER_STOP
	var shade:=ColorRect.new(); shade.size=Vector2(900,900); shade.color=Color(0.02,0.04,0.09,.88); modal.add_child(shade)
	var panel:=Panel.new(); panel.position=Vector2(135,190); panel.size=Vector2(630,500); panel.add_theme_stylebox_override("panel",_style(Color("#112238"),Color("#5f7049"),24)); modal.add_child(panel)
	var title:=Label.new(); title.text="🎁 СУНДУКИ ОСТРОВА"; title.position=Vector2(30,25); title.size=Vector2(570,40); title.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; title.add_theme_font_size_override("font_size",25); title.add_theme_color_override("font_color",Color("#f4f7ff")); panel.add_child(title)
	var bank:=Label.new(); bank.text="⭐ %d"%island_stars; bank.position=Vector2(30,68); bank.size=Vector2(570,25); bank.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; bank.add_theme_font_size_override("font_size",14); bank.add_theme_color_override("font_color",Color("#ffd86a")); panel.add_child(bank)
	var list:=VBoxContainer.new(); list.position=Vector2(35,110); list.size=Vector2(560,300); list.add_theme_constant_override("separation",12); panel.add_child(list)
	var chests:Array = island_progression.call("get_chests") as Array
	if chests.is_empty():
		var empty:=Label.new(); empty.text="Сундуков пока нет.\nВосстанавливайте новые зоны острова."; empty.size=Vector2(560,90); empty.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; empty.vertical_alignment=VERTICAL_ALIGNMENT_CENTER; empty.add_theme_font_size_override("font_size",16); empty.add_theme_color_override("font_color",Color("#8ba3bb")); list.add_child(empty)
	else:
		for chest in chests:
			var id:=str(chest["id"]); var claimed:=bool(island_progression.call("is_chest_claimed",id))
			var row:=Panel.new(); row.custom_minimum_size=Vector2(560,82); row.add_theme_stylebox_override("panel",_style(Color("#1a3045"),Color("#596b49") if not claimed else Color("#38515a"),14)); list.add_child(row)
			var label:=Label.new(); label.text=str(chest["icon"])+" "+str(chest["name"]); label.position=Vector2(15,10); label.size=Vector2(270,30); label.add_theme_font_size_override("font_size",14); label.add_theme_color_override("font_color",Color("#f2f6ff")); row.add_child(label)
			var reward:Dictionary = chest["reward"] as Dictionary; var reward_label:=Label.new(); reward_label.text="⭐ +%d   •   %s +%d"%[int(reward["stars"]),str(reward["booster"]),int(reward["amount"])]; reward_label.position=Vector2(15,43); reward_label.size=Vector2(300,24); reward_label.add_theme_font_size_override("font_size",10); reward_label.add_theme_color_override("font_color",Color("#c7d39a")); row.add_child(reward_label)
			var btn:=Button.new(); btn.text="ПОЛУЧЕНО" if claimed else "ОТКРЫТЬ"; btn.position=Vector2(390,15); btn.size=Vector2(145,48); btn.disabled=claimed; btn.add_theme_stylebox_override("normal",_style(Color("#625126") if not claimed else Color("#28433c"),Color("#d6ae4e") if not claimed else Color("#4d806e"),12)); row.add_child(btn)
			if not claimed: btn.pressed.connect(_claim_island_chest.bind(id))
	var close:=Button.new(); close.text="← НАЗАД"; close.position=Vector2(35,430); close.size=Vector2(560,42); close.add_theme_stylebox_override("normal",_style(Color("#182c45"),Color("#4a6989"))); close.pressed.connect(_show_island_repair); panel.add_child(close)
	map_layer.add_child(modal)

func _claim_island_chest(id:String)->void:
	if not is_instance_valid(island_progression): return
	var result:Dictionary=island_progression.call("claim_chest",id)
	if not bool(result.get("ok",false)): return
	_apply_island_reward(result["reward"])
	_show_island_chests()

func _create_level_node(parent:Control,index:int,pos:Vector2)->void:
	var unlocked:=index<=unlocked_level
	var done:=completed[index]
	var c:=Color("#39cf78") if done else (Color("#328dff") if unlocked else Color("#c94253"))
	var b:=Button.new(); b.position=pos-Vector2(28,28); b.size=Vector2(56,56); b.text=("✓" if done else (str(index+1) if unlocked else "🔒")); b.disabled=not unlocked; b.add_theme_font_size_override("font_size",18); b.add_theme_color_override("font_color",Color.WHITE); b.add_theme_stylebox_override("normal",_style(c,c.lightened(.25),28)); b.add_theme_stylebox_override("hover",_style(c.lightened(.12),Color.WHITE,28)); b.add_theme_stylebox_override("pressed",_style(c.darkened(.08),Color.WHITE,28)); b.tooltip_text="Уровень %d"%(index+1); b.pressed.connect(_show_level_intro.bind(index)); parent.add_child(b)
	if unlocked:
		var stars:=Label.new()
		stars.text=_stars_string(level_stars[index])
		stars.position=pos+Vector2(-30,52)
		stars.size=Vector2(60,20)
		stars.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
		stars.add_theme_font_size_override("font_size",10)
		stars.add_theme_color_override("font_color",Color("#ffd86a"))
		parent.add_child(stars)
	var l:=Label.new(); l.text=str(index+1); l.position=pos+Vector2(-30,31); l.size=Vector2(60,22); l.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; l.add_theme_font_size_override("font_size",10); l.add_theme_color_override("font_color",Color("#b8d2d9")); parent.add_child(l)
	if index%10==0:
		var chapter:=Label.new(); chapter.text="ГЛАВА %d"%(int(index/10)+1); chapter.position=pos+Vector2(-65,-55); chapter.size=Vector2(130,24); chapter.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; chapter.add_theme_font_size_override("font_size",11); chapter.add_theme_color_override("font_color",c.lightened(.25)); parent.add_child(chapter)

func _stars_string(value:int)->String:
	return ("★" if value>=1 else "☆")+" "+("★" if value>=2 else "☆")+" "+("★" if value>=3 else "☆")

func _goal_defs(index:int)->Array:
	var d:Dictionary=LEVELS[index]
	var tier:=int(d["mechanic"])
	var goals:Array=[]
	var type_name:String=str(TYPE_NAMES[int(d["type"])])
	var type_count:=int(d["count"])
	var score_target:=int(d["score"])
	if tier in [1,2,9]:
		goals.append({"kind":"blockers","target":int(d.get("blockers",0)),"label":"разрушить все препятствия"})
	elif tier==5 and int(d.get("spiders",0))>0:
		goals.append({"kind":"spiders","target":int(d.get("spiders",0)),"label":"убрать всех пауков"})
	elif tier in [6,7,8]:
		goals.append({"kind":"mechanic","target":1,"label":"выполнить механику острова"})
	else:
		var pattern:=index%4
		if pattern==0:
			goals.append({"kind":"collect","target":type_count,"type":int(d["type"]),"label":"собрать %d %s"%[type_count,type_name]})
		elif pattern==1:
			goals.append({"kind":"score","target":score_target,"label":"набрать %d очков"%score_target})
		elif pattern==2:
			goals.append({"kind":"collect","target":type_count,"type":int(d["type"]),"label":"собрать %d %s"%[type_count,type_name]})
			goals.append({"kind":"score","target":score_target,"label":"набрать %d очков"%score_target})
		else:
			var target_score:=score_target+maxi(200,index*10)
			goals.append({"kind":"score","target":target_score,"label":"набрать %d очков"%target_score})
	if goals.size()<2 and tier>=1:
		if index%2==0:
			goals.append({"kind":"collect","target":type_count,"type":int(d["type"]),"label":"собрать %d %s"%[type_count,type_name]})
		else:
			goals.append({"kind":"score","target":score_target,"label":"набрать %d очков"%score_target})
	return goals

func _goal_done(goal:Dictionary)->bool:
	match str(goal["kind"]):
		"score":
			return score>=int(goal["target"])
		"collect":
			return destroyed_counts[int(goal["type"])]>=int(goal["target"])
		"blockers":
			return blockers.is_empty()
		"spiders":
			return spiders.is_empty()
		"mechanic":
			return not is_instance_valid(mechanics) or bool(mechanics.call("is_complete"))
	return false

func _goals_complete()->bool:
	for goal in _goal_defs(current_level):
		if not _goal_done(goal): return false
	return true

func _goal_text_for_level(index:int)->String:
	var lines:Array[String]=[]
	for goal in _goal_defs(index):
		lines.append("• "+str(goal["label"]))
	return "\n".join(lines)

func _goal_text()->String:
	var lines:Array[String]=[]
	for goal in _goal_defs(current_level):
		var prefix:="✓" if _goal_done(goal) else "•"
		var progress:=""
		match str(goal["kind"]):
			"score":
				progress=" %d / %d"%[score,int(goal["target"])]
			"collect":
				progress=" %d / %d"%[destroyed_counts[int(goal["type"])],int(goal["target"])]
			"blockers":
				progress=" %d осталось"%blockers.size()
			"spiders":
				progress=" %d осталось"%spiders.size()
			"mechanic":
				progress=" выполнено" if _goal_done(goal) else " в процессе"
		lines.append("%s %s%s"%[prefix,str(goal["label"]),progress])
	return "\n".join(lines)

func _calculate_stars()->int:
	if not _goals_complete(): return 0
	var ratio:=float(moves_left)/maxf(1.0,float(initial_moves))
	if ratio>=0.55 or best_combo_level>=5: return 3
	if ratio>=0.28 or best_combo_level>=3: return 2
	return 1

func _consume_booster(key:String)->bool:
	var amount:=int(booster_inventory.get(key,0))
	if amount<=0: return false
	booster_inventory[key]=amount-1
	_save_progress()
	return true

func _apply_preboosters()->void:
	var selected:=pre_selected.duplicate()
	pre_selected.clear()
	for key in selected:
		if key=="moves":
			if _consume_booster("extra_moves"): moves_left+=3
		elif key=="bomb":
			if _consume_booster("pre_bomb"): _place_start_special(3)
		elif key=="rainbow":
			if _consume_booster("pre_rainbow"): _place_start_special(4)

func _place_start_special(sp:int)->void:
	var candidates:Array[Vector2i]=[]
	for y in range(SIZE):
		for x in range(SIZE):
			var p:=Vector2i(x,y)
			if board[y][x]>=0 and not specials.has(p):
				candidates.append(p)
	if candidates.is_empty(): return
	var p:Vector2i=candidates[rng.randi_range(0,candidates.size()-1)]
	specials[p]=sp

func _toggle_prebooster(key:String, button:Button)->void:
	var inventory_key:="extra_moves" if key=="moves" else "pre_"+key
	if int(booster_inventory.get(inventory_key,0))<=0: return
	if pre_selected.has(key):
		pre_selected.erase(key)
	else:
		if pre_selected.size()>=2: return
		pre_selected.append(key)
	button.add_theme_stylebox_override("normal",_style(Color("#256e62") if pre_selected.has(key) else Color("#182d49"),Color("#63dfa5") if pre_selected.has(key) else Color("#466c94"),14))

func _close_level_intro()->void:
	if modal:
		modal.queue_free()
		modal=null

func _show_level_intro(index:int)->void:
	if index>unlocked_level: return
	if modal:
		modal.queue_free()
		modal=null
	pre_selected.clear()
	modal=Control.new()
	modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal.mouse_filter=Control.MOUSE_FILTER_STOP
	var shade:=ColorRect.new(); shade.size=Vector2(900,900); shade.color=Color(0.02,0.04,0.09,.82); modal.add_child(shade)
	var panel:=Panel.new(); panel.position=Vector2(120,150); panel.size=Vector2(660,610); panel.add_theme_stylebox_override("panel",_style(Color("#102039"),Color("#3f638d"),24)); modal.add_child(panel)
	var title:=Label.new(); title.text="УРОВЕНЬ %d"%(index+1); title.position=Vector2(40,25); title.size=Vector2(580,50); title.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; title.add_theme_font_size_override("font_size",31); title.add_theme_color_override("font_color",Color("#f4f7ff")); panel.add_child(title)
	var chapter:=Label.new(); chapter.text=MECHANICS[int(LEVELS[index]["mechanic"])]; chapter.position=Vector2(45,75); chapter.size=Vector2(570,30); chapter.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; chapter.add_theme_font_size_override("font_size",12); chapter.add_theme_color_override("font_color",Color("#72d7b0")); panel.add_child(chapter)
	var goals_title:=Label.new(); goals_title.text="ЦЕЛИ УРОВНЯ"; goals_title.position=Vector2(55,125); goals_title.add_theme_font_size_override("font_size",15); goals_title.add_theme_color_override("font_color",Color("#dce8ff")); panel.add_child(goals_title)
	var goals:=Label.new(); goals.position=Vector2(65,155); goals.size=Vector2(530,100); goals.text=_goal_text_for_level(index); goals.add_theme_font_size_override("font_size",16); goals.add_theme_color_override("font_color",Color("#b8cae5")); panel.add_child(goals)
	var booster_title:=Label.new(); booster_title.text="БОНУСЫ НА СТАРТЕ — выберите до 2"; booster_title.position=Vector2(55,270); booster_title.add_theme_font_size_override("font_size",15); booster_title.add_theme_color_override("font_color",Color("#dce8ff")); panel.add_child(booster_title)
	var b1:=Button.new(); b1.text="💣 БОМБА • %d"%int(booster_inventory["pre_bomb"]); b1.position=Vector2(55,305); b1.size=Vector2(170,55); b1.pressed.connect(_toggle_prebooster.bind("bomb",b1)); b1.add_theme_stylebox_override("normal",_style(Color("#182d49"),Color("#466c94"),14)); panel.add_child(b1)
	var b2:=Button.new(); b2.text="🌈 РАДУГА • %d"%int(booster_inventory["pre_rainbow"]); b2.position=Vector2(245,305); b2.size=Vector2(170,55); b2.pressed.connect(_toggle_prebooster.bind("rainbow",b2)); b2.add_theme_stylebox_override("normal",_style(Color("#182d49"),Color("#466c94"),14)); panel.add_child(b2)
	var b3:=Button.new(); b3.text="+3 ХОДА • %d"%int(booster_inventory["extra_moves"]); b3.position=Vector2(435,305); b3.size=Vector2(170,55); b3.pressed.connect(_toggle_prebooster.bind("moves",b3)); b3.add_theme_stylebox_override("normal",_style(Color("#182d49"),Color("#466c94"),14)); panel.add_child(b3)
	var info:=Label.new(); info.text="Оставшиеся бустеры сохраняются между уровнями."; info.position=Vector2(55,375); info.size=Vector2(550,30); info.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; info.add_theme_font_size_override("font_size",11); info.add_theme_color_override("font_color",Color("#7891ae")); panel.add_child(info)
	var start:=Button.new(); start.text="ИГРАТЬ"; start.position=Vector2(55,495); start.size=Vector2(250,62); start.add_theme_font_size_override("font_size",16); start.add_theme_stylebox_override("normal",_style(Color("#237f57"),Color("#63dfa5"),16)); start.pressed.connect(_start_level.bind(index)); panel.add_child(start)
	var back:=Button.new(); back.text="← НАЗАД"; back.position=Vector2(325,495); back.size=Vector2(250,62); back.add_theme_stylebox_override("normal",_style(Color("#1a2a43"),Color("#4a6386"),16)); back.pressed.connect(_close_level_intro); panel.add_child(back)
	map_layer.add_child(modal)

func _start_level(index:int)->void:
	if index>unlocked_level: return
	if modal:
		modal.queue_free()
		modal=null
	current_level=index
	var data:Dictionary=LEVELS[index]
	var passive_moves:=0
	if is_instance_valid(island_progression):
		passive_moves=int(island_progression.call("get_start_move_bonus",index))
	initial_moves=int(data["moves"])+passive_moves
	moves_left=initial_moves
	score=0
	combo=0
	best_combo_level=0
	destroyed_counts=[0,0,0,0,0,0]
	active_booster=""
	selected=Vector2i(-1,-1)
	busy=true
	if map_layer: map_layer.visible=false
	if menu_layer: menu_layer.visible=false
	game_layer.visible=true
	# Сначала удаляем старые визуальные блокираторы, затем создаём состояние нового уровня.
	_clear_visuals()
	_setup_blockers(int(data.get("blockers",0)))
	_generate_board()
	_setup_spiders(int(data.get("spiders",0)))
	if is_instance_valid(mechanics):
		mechanics.call("setup_level", data, index)
	_apply_preboosters()
	_create_visuals()
	_update_labels()
	status.text="Уровень %d • %s"%[index+1,MECHANICS[int(data["mechanic"])]]
	busy=false

func _build_game_layer()->void:
	game_layer=Control.new(); game_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); add_child(game_layer)
	var bg:=TextureRect.new(); bg.texture=GAME_BACKGROUND; bg.position=Vector2.ZERO; bg.size=Vector2(900,900); bg.expand_mode=TextureRect.EXPAND_IGNORE_SIZE; bg.stretch_mode=TextureRect.STRETCH_SCALE; bg.mouse_filter=Control.MOUSE_FILTER_IGNORE; game_layer.add_child(bg)
	var bg_tint:=ColorRect.new(); bg_tint.size=Vector2(900,900); bg_tint.color=Color(0.02,0.05,0.09,0.20); bg_tint.mouse_filter=Control.MOUSE_FILTER_IGNORE; game_layer.add_child(bg_tint)
	var head:=ColorRect.new(); head.size=Vector2(900,176); head.color=Color(0.067,0.106,0.20,0.92); game_layer.add_child(head)
	var title:=Label.new(); title.text="ТРИ В РЯД"; title.position=Vector2(138,12); title.add_theme_font_size_override("font_size",36); title.add_theme_color_override("font_color",Color("#f2f5ff")); game_layer.add_child(title)
	var hint_desc:=Label.new(); hint_desc.text="Выполни все цели уровня до окончания ходов"; hint_desc.position=Vector2(140,53); hint_desc.add_theme_font_size_override("font_size",13); hint_desc.add_theme_color_override("font_color",Color("#8495bb")); game_layer.add_child(hint_desc)
	level_label=_stat("УРОВЕНЬ",Vector2(138,88)); moves_label=_stat("ХОДЫ",Vector2(255,88)); score_label=_stat("ОЧКИ",Vector2(372,88)); best_label=_stat("РЕКОРД",Vector2(489,88)); combo_label=_stat("КОМБО",Vector2(606,88))
	goal_label=Label.new(); goal_label.position=Vector2(138,138); goal_label.size=Vector2(620,28); goal_label.add_theme_font_size_override("font_size",13); goal_label.add_theme_color_override("font_color",Color("#dce5ff")); game_layer.add_child(goal_label)
	var restart:=Button.new(); restart.text="↻"; restart.position=Vector2(780,24); restart.size=Vector2(48,42); restart.add_theme_font_size_override("font_size",20); restart.add_theme_stylebox_override("normal",_style(Color("#1a2a4b"),Color("#3b5787"))); restart.pressed.connect(_restart_level); game_layer.add_child(restart)
	var mapb:=Button.new(); mapb.text="КАРТА"; mapb.position=Vector2(670,86); mapb.size=Vector2(98,34); mapb.add_theme_font_size_override("font_size",12); mapb.add_theme_stylebox_override("normal",_style(Color("#16243f"),Color("#30486f"))); mapb.pressed.connect(_show_map); game_layer.add_child(mapb)
	var hint_button:=Button.new(); hint_button.text="ПОДСКАЗКА"; hint_button.position=Vector2(670,126); hint_button.size=Vector2(98,34); hint_button.add_theme_font_size_override("font_size",10); hint_button.add_theme_stylebox_override("normal",_style(Color("#18324b"),Color("#3f7292"))); hint_button.pressed.connect(_show_hint); game_layer.add_child(hint_button)
	hammer_button=_booster_button("🔨",Vector2(138,840))
	extra_moves_button=_booster_button("+3",Vector2(255,840))
	shuffle_button=_booster_button("↻",Vector2(372,840))
	var booster_note:=Label.new(); booster_note.position=Vector2(500,840); booster_note.size=Vector2(260,32); booster_note.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; booster_note.add_theme_font_size_override("font_size",10); booster_note.add_theme_color_override("font_color",Color("#88a7b9")); booster_note.text="БУСТЕРЫ • нажмите, затем выберите клетку"; game_layer.add_child(booster_note)
	var frame:=BoardFrame.new(); frame.position=ORIGIN+Vector2(312,312); game_layer.add_child(frame)
	root=Node2D.new(); game_layer.add_child(root); fx=Node2D.new(); game_layer.add_child(fx)
	status=Label.new(); status.position=Vector2(138,803); status.size=Vector2(624,30); status.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; status.add_theme_font_size_override("font_size",14); status.add_theme_color_override("font_color",Color("#9baad0")); game_layer.add_child(status)

func _booster_button(icon:String,p:Vector2)->Button:
	var b:=Button.new()
	b.position=p
	b.size=Vector2(105,38)
	b.icon=BOOSTER_TEXTURES.get(icon) as Texture2D
	b.text="0"
	b.alignment=HORIZONTAL_ALIGNMENT_CENTER
	b.expand_icon=true
	b.add_theme_font_size_override("font_size",11)
	b.add_theme_color_override("font_color",Color("#eef8ff"))
	b.add_theme_stylebox_override("normal",_style(Color("#132a40"),Color("#4e7893"),12))
	b.add_theme_stylebox_override("hover",_style(Color("#1c3b54"),Color("#75d9b5"),12))
	b.add_theme_stylebox_override("pressed",_style(Color("#102536"),Color("#d7bc6b"),12))
	b.pressed.connect(_booster_pressed.bind(icon))
	game_layer.add_child(b)
	return b

func _booster_pressed(icon:String)->void:
	if busy: return
	if icon=="🔨":
		if int(booster_inventory["hammer"])<=0: return
		active_booster="hammer"
		status.text="Молот: выберите клетку"
	elif icon=="+3":
		if _consume_booster("extra_moves"):
			moves_left+=3
			_update_labels()
	elif icon=="↻":
		if int(booster_inventory["shuffle"])<=0: return
		if _consume_booster("shuffle"):
			var p=get_node_or_null("Polish")
			if is_instance_valid(p): p.call("_shuffle_board")

func _use_active_booster(p:Vector2i)->void:
	if active_booster!="hammer": return
	active_booster=""
	if p.x<0 or p.y<0 or p.x>=SIZE or p.y>=SIZE: return
	if not _consume_booster("hammer"): return
	if blockers.has(p):
		_damage_blockers([p])
		_update_labels()
		return
	if _cell_is_blocked(p) or board[p.y][p.x]<0:
		return
	busy=true
	await _destroy_matches([p])
	await _collapse_and_refill()
	if is_instance_valid(mechanics):
		mechanics.call("after_matches_cleared",[p])
	_update_labels()
	busy=false

func _stat(n:String,p:Vector2)->Label:
	var l:=Label.new(); l.position=p; l.size=Vector2(105,45); l.text=n+"\n0"; l.add_theme_font_size_override("font_size",12); l.add_theme_color_override("font_color",Color("#8395bd")); game_layer.add_child(l); return l

func _generate_board()->void:
	board.clear()
	for y in range(SIZE):
		var row:Array=[]
		for x in range(SIZE):
			if _cell_is_blocked(Vector2i(x,y)):
				row.append(-1)
				continue
			var opts:Array[int]=[]
			for t in range(TYPES):
				if x>=2 and row[x-1]==t and row[x-2]==t: continue
				if y>=2 and board[y-1][x]==t and board[y-2][x]==t: continue
				opts.append(t)
			row.append(opts[rng.randi_range(0,opts.size()-1)])
		board.append(row)

func _clear_visuals(preserve_mechanics:bool=false)->void:
	for n in root.get_children(): n.free()
	for n in fx.get_children(): n.free()
	for n in blocker_nodes.values():
		if is_instance_valid(n): n.free()
	blocker_nodes.clear()
	gems.clear()
	specials.clear()
	spiders.clear()
	for n in spider_nodes.values():
		if is_instance_valid(n): n.free()
	spider_nodes.clear()
	if is_instance_valid(mechanics) and not preserve_mechanics:
		mechanics.call("clear")
func _is_active_special_type(sp:int)->bool:
	return sp>=1 and sp<=4

func _cell_is_blocked(p:Vector2i)->bool:
	if blockers.has(p):
		return true
	if is_instance_valid(mechanics):
		return bool(mechanics.call("is_cell_blocked", p))
	return false

func _cell_pos(p:Vector2i)->Vector2: return ORIGIN+Vector2(p.x*CELL+CELL/2,p.y*CELL+CELL/2)
func _make_gem(k:int, sp:int = 0)->Gem:
	var g:=Gem.new()
	var tex:Texture2D=GEM_TEXTURES[k]
	var special_tex:Texture2D=null
	if sp>0:
		special_tex=SPECIAL_TEXTURES.get(sp) as Texture2D
	g.setup(k,COLORS[k],SYMBOLS[k],sp,tex,special_tex)
	root.add_child(g)
	return g

func _setup_blockers(count:int)->void:
	blockers.clear()
	if count <= 0:
		return
	var tier:=int(LEVELS[current_level]["mechanic"])
	var hits:=1 if current_level < 20 else (2 if current_level < 60 else 3)
	if tier==1:
		# Лианы образуют компактные узоры, а не случайный разброс.
		var center:=Vector2i(3 if current_level%2==0 else 4,3 if current_level%3 else 4)
		var pattern:Array[Vector2i]=[
			center, center+Vector2i(1,0), center+Vector2i(-1,0),
			center+Vector2i(0,1), center+Vector2i(0,-1),
			center+Vector2i(1,1), center+Vector2i(-1,-1)
		]
		for p in pattern:
			if p.x>=1 and p.x<SIZE-1 and p.y>=1 and p.y<SIZE-1 and blockers.size()<count:
				blockers[p]=1
		return
	if tier==2:
		# Кокосы идут плотными группами и требуют несколько ударов.
		var start:=Vector2i(2+(current_level%3),2+(current_level%2))
		var pattern2:Array[Vector2i]=[
			start,start+Vector2i(1,0),start+Vector2i(0,1),start+Vector2i(1,1),
			start+Vector2i(2,0),start+Vector2i(0,2)
		]
		var coconut_hits:=2 if current_level<50 else 3
		for p in pattern2:
			if p.x>=1 and p.x<SIZE-1 and p.y>=1 and p.y<SIZE-1 and blockers.size()<count:
				blockers[p]=coconut_hits
		return
	if tier==9:
		# Финальный тотем занимает центральный блок.
		var boss_center:=Vector2i(3,3)
		for p in [boss_center,boss_center+Vector2i(1,0),boss_center+Vector2i(0,1),boss_center+Vector2i(1,1)]:
			blockers[p]=mini(5,3+int(current_level/20))
		return
	var center:=Vector2i(rng.randi_range(2,5),rng.randi_range(2,5))
	var candidates:Array[Vector2i]=[]
	for y in range(1,SIZE-1):
		for x in range(1,SIZE-1):
			candidates.append(Vector2i(x,y))
	candidates.sort_custom(func(a:Vector2i,b:Vector2i)->bool:
		return abs(a.x-center.x)+abs(a.y-center.y) < abs(b.x-center.x)+abs(b.y-center.y)
	)
	for p in candidates:
		if blockers.size() >= mini(count,candidates.size()): break
		blockers[p]=hits

func _setup_spiders(count:int)->void:
	spiders.clear()
	if count<=0: return
	var candidates:Array[Vector2i]=[]
	for y in range(SIZE):
		for x in range(SIZE):
			var p:=Vector2i(x,y)
			if not _cell_is_blocked(p) and board[y][x]>=0:
				candidates.append(p)
	candidates.shuffle()
	for i in range(mini(count,candidates.size())):
		spiders[candidates[i]]=true

func _create_spider_visuals()->void:
	for n in spider_nodes.values():
		if is_instance_valid(n): n.queue_free()
	spider_nodes.clear()
	for p in spiders.keys():
		var mark:=Sprite2D.new()
		mark.texture=SPIDER_TEXTURE
		mark.position=_cell_pos(p)+Vector2(20,-21)
		mark.scale=Vector2.ONE*.58
		mark.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
		root.add_child(mark)
		spider_nodes[p]=mark

func _blocker_name()->String:
	var tier:=int(LEVELS[current_level]["mechanic"])
	return ["Фрукты","Лианы","Кокосы","Прилив","Тотемы","Обезьяны","Карты","Туман","Огненные камни","Финальный тотем"][tier]

func _blocker_symbol(hits:int)->String:
	var tier:=int(LEVELS[current_level]["mechanic"])
	if tier==1: return "≋"
	if tier==2: return "●" if hits>=2 else "◌"
	if tier==3: return "~"
	if tier==4: return "◆"
	if tier==5: return "☻"
	if tier==6: return "▣"
	if tier==7: return "?"
	if tier==8: return "!"
	if tier==9: return "☠"
	return "X"

func _create_blocker_visuals()->void:
	for n in blocker_nodes.values():
		if is_instance_valid(n): n.queue_free()
	blocker_nodes.clear()
	var tier:=int(LEVELS[current_level]["mechanic"])
	for p in blockers.keys():
		var node:Node2D
		if tier==1 or tier==2 or tier==8:
			var sprite:=Sprite2D.new()
			sprite.texture=VINE_TEXTURE if tier==1 else (COCONUT_TEXTURE if tier==2 else FIRE_STONE_TEXTURE)
			sprite.position=_cell_pos(p)
			sprite.scale=Vector2.ONE*.64
			sprite.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
			node=sprite
		else:
			var l:=Label.new()
			l.text=_blocker_symbol(int(blockers[p]))
			l.position=_cell_pos(p)-Vector2(24,25)
			l.size=Vector2(48,48)
			l.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
			l.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
			l.mouse_filter=Control.MOUSE_FILTER_IGNORE
			l.add_theme_font_size_override("font_size",24)
			l.add_theme_color_override("font_color",Color(1,1,1,.82))
			node=l
		game_layer.add_child(node)
		blocker_nodes[p]=node

func _damage_blockers(cleared:Array[Vector2i])->void:
	if blockers.is_empty(): return
	var damaged:Dictionary={}
	for p in cleared:
		for dy in range(-1,2):
			for dx in range(-1,2):
				var q:=Vector2i(p.x+dx,p.y+dy)
				if blockers.has(q): damaged[q]=true
	for p in damaged.keys():
		blockers[p]=int(blockers[p])-1
		if blockers[p] <= 0:
			blockers.erase(p)
			if blocker_nodes.has(p):
				var node=blocker_nodes[p]
				if is_instance_valid(node): node.queue_free()
				blocker_nodes.erase(p)
		else:
			if blocker_nodes.has(p) and is_instance_valid(blocker_nodes[p]):
				var blocker_node:Node=blocker_nodes[p]
				if blocker_node is Label:
					(blocker_node as Label).text=_blocker_symbol(int(blockers[p]))
				else:
					blocker_node.scale=Vector2.ONE*.54
					var pulse:=blocker_node.create_tween()
					pulse.tween_property(blocker_node,"scale",Vector2.ONE*.64,.12)
	if not blockers.is_empty() and status:
		status.text="%s: осталось %d"%[_blocker_name(),blockers.size()]

func _create_visuals()->void:
	for y in range(SIZE):
		for x in range(SIZE):
			var p:=Vector2i(x,y)
			if _cell_is_blocked(p) or board[y][x] < 0:
				continue
			var sp:int=int(specials.get(p,0))
			var g:=_make_gem(board[y][x],sp)
			g.position=_cell_pos(p)
			g.scale=Vector2.ONE
			g.modulate=Color.WHITE
			g.rotation=0.0
			gems[p]=g
	_create_blocker_visuals()
	_create_spider_visuals()

func _input(event:InputEvent)->void:
	if busy or not game_layer.visible:
		return
	if event is InputEventScreenTouch:
		var touch:=event as InputEventScreenTouch
		if touch.pressed:
			touch_start=touch.position
			touch_active=true
		else:
			if not touch_active: return
			touch_active=false
			var delta:=touch.position-touch_start
			if delta.length()>24.0:
				var from:=_board_cell_from_position(touch_start)
				var dir:=Vector2i.ZERO
				if abs(delta.x)>abs(delta.y): dir=Vector2i(1 if delta.x>0 else -1,0)
				else: dir=Vector2i(0,1 if delta.y>0 else -1)
				var to:=from+dir
				if active_booster=="hammer":
					if from.x>=0 and from.y>=0 and from.x<SIZE and from.y<SIZE: _click(from)
				elif _valid_cell(from) and _valid_cell(to):
					_swipe_move(from,to)
			elif active_booster=="hammer":
				var bp:=_board_cell_from_position(touch.position)
				if bp.x>=0 and bp.y>=0 and bp.x<SIZE and bp.y<SIZE: _click(bp)
			elif _valid_cell(_board_cell_from_position(touch.position)):
				_click(_board_cell_from_position(touch.position))
		return
	if event is InputEventMouseButton:
		var m:=event as InputEventMouseButton
		if not m.pressed or m.button_index!=MOUSE_BUTTON_LEFT: return
		var p:=_board_cell_from_position(m.position)
		if active_booster=="hammer":
			if p.x>=0 and p.y>=0 and p.x<SIZE and p.y<SIZE: _click(p)
		elif _valid_cell(p): _click(p)

func _board_cell_from_position(pos:Vector2)->Vector2i:
	var local:=pos-ORIGIN
	return Vector2i(floor(local.x/CELL),floor(local.y/CELL))

func _valid_cell(p:Vector2i)->bool:
	return p.x>=0 and p.y>=0 and p.x<SIZE and p.y<SIZE and not _cell_is_blocked(p) and not (is_instance_valid(mechanics) and mechanics.call("is_fogged", p)) and board[p.y][p.x]>=0

func _swipe_move(a:Vector2i,b:Vector2i)->void:
	if selected.x>=0:
		if selected!=a:
			(gems[selected] as Gem).select(false)
			selected=Vector2i(-1,-1)
		_click(a)
	if selected==a:
		(gems[a] as Gem).select(false)
		selected=Vector2i(-1,-1)
		_resolve(a,b)
	else:
		_click(a)


func _click(p:Vector2i)->void:
	if active_booster=="hammer":
		_use_active_booster(p)
		return
	if moves_left<=0: return
	if not gems.has(p): return
	if selected.x<0:
		selected=p
		(gems[p] as Gem).select(true)
		status.text="Выберите соседнюю фишку"
		_play("select")
		return
	if p==selected:
		(gems[p] as Gem).select(false)
		selected=Vector2i(-1,-1)
		return
	if abs(p.x-selected.x)+abs(p.y-selected.y)!=1:
		status.text="Можно менять только соседние фишки"
		_play("error")
		return
	var a:=selected
	(gems[a] as Gem).select(false)
	selected=Vector2i(-1,-1)
	_resolve(a,p)

func _resolve(a:Vector2i,b:Vector2i)->void:
	busy=true
	_swap_data(a,b)
	_play("swap")
	await _swap_anim(a,b)
	var special_a := int(specials.get(a,0))
	var special_b := int(specials.get(b,0))
	var special_a_active := _is_active_special_type(special_a)
	var special_b_active := _is_active_special_type(special_b)
	var special_triggered := special_a_active or special_b_active
	var special_combo := special_a_active and special_b_active
	var matches:Array[Vector2i]=_find_matches()
	if matches.is_empty() and not special_triggered:
		_swap_data(a,b)
		await _swap_anim(a,b)
		status.text="Нет комбинации — обмен отменён"
		_play("error")
		busy=false
		return
	moves_left-=1
	combo=0
	var turn_cleared:Array[Vector2i]=[]
	while true:
		combo+=1
		best_combo_level=maxi(best_combo_level,combo)
		var wave:Array[Vector2i]=matches.duplicate()
		if special_combo:
			wave.append_array(_special_combo_cells(a,b))
			special_combo=false
			special_triggered=false
		elif special_triggered:
			wave.append_array(_special_effect_cells(a,b))
			special_triggered=false
		var matched_specials:Array[Vector2i]=[]
		for p in wave:
			if specials.has(p) and _is_active_special_type(int(specials.get(p,0))):
				matched_specials.append(p)
		for p in matched_specials:
			wave.append_array(_special_effect_cells(p,p))
		wave=_unique_cells(wave)
		for cleared_cell in wave:
			if not turn_cleared.has(cleared_cell):
				turn_cleared.append(cleared_cell)
		if wave.is_empty():
			break
		if not matches.is_empty():
			_create_special_from_match(wave)
		var gained:int=wave.size()*10*combo
		if is_instance_valid(island_progression):
			gained=int(round(float(gained)*float(island_progression.call("get_score_multiplier"))))
		score+=gained
		_play("combo" if combo>1 else "match")
		if combo>1:
			_spawn_combo_fx(_cell_pos(wave[0]))
		else:
			var burst_kind:int=board[wave[0].y][wave[0].x]
			var burst_color:Color=COLORS[burst_kind] if burst_kind>=0 and burst_kind<COLORS.size() else Color.WHITE
			_spawn_match_burst(_cell_pos(wave[0]),burst_color)
		_popup(_cell_pos(wave[0]),gained)
		await _destroy_matches(wave)
		await _collapse_and_refill()
		matches=_find_matches()
		if matches.is_empty():
			break
	if is_instance_valid(mechanics):
		mechanics.call("after_matches_cleared", turn_cleared)
		await mechanics.call("after_player_move")
	_update_best()
	_update_labels()
	_check_level_state()
	if not busy:
		busy=false

func _swap_data(a:Vector2i,b:Vector2i)->void:
	var temp=board[a.y][a.x]
	board[a.y][a.x]=board[b.y][b.x]
	board[b.y][b.x]=temp
	var sp_a:=int(specials.get(a,0))
	var sp_b:=int(specials.get(b,0))
	specials.erase(a)
	specials.erase(b)
	if sp_a != 0: specials[b]=sp_a
	if sp_b != 0: specials[a]=sp_b
	var spider_a:=bool(spiders.get(a,false))
	var spider_b:=bool(spiders.get(b,false))
	spiders.erase(a)
	spiders.erase(b)
	if spider_a: spiders[b]=true
	if spider_b: spiders[a]=true
	if spider_nodes.has(a) and spider_nodes.has(b):
		var sn_a=spider_nodes[a]
		var sn_b=spider_nodes[b]
		spider_nodes.erase(a)
		spider_nodes.erase(b)
		spider_nodes[a]=sn_b
		spider_nodes[b]=sn_a
		spider_nodes[a].position=_cell_pos(a)+Vector2(20,-21)
		spider_nodes[b].position=_cell_pos(b)+Vector2(20,-21)
	elif spider_a or spider_b:
		_create_spider_visuals()
	var ga=gems[a]
	gems[a]=gems[b]
	gems[b]=ga

func _swap_anim(a:Vector2i,b:Vector2i)->void:
	var ga:Gem=gems[a]
	var gb:Gem=gems[b]
	var t:=ga.create_tween().set_parallel(true)
	t.set_trans(Tween.TRANS_BACK)
	t.tween_property(ga,"position",_cell_pos(a),.18)
	t.tween_property(gb,"position",_cell_pos(b),.18)
	await t.finished

func _destroy_matches(matches:Array[Vector2i])->void:
	var preserved_rainbows:Dictionary={}
	for p in matches:
		var kind:int=board[p.y][p.x]
		var sp:int=int(specials.get(p,0))
		if sp==5 and is_instance_valid(mechanics):
			mechanics.call("collect_map_piece_at", p)
		if kind >= 0 and kind < destroyed_counts.size():
			destroyed_counts[kind]+=1
		var fx_color:Color=COLORS[kind] if kind>=0 and kind<COLORS.size() else Color.WHITE
		_spawn_fx(_cell_pos(p),fx_color)
		if _is_active_special_type(sp):
			_spawn_special_flash(_cell_pos(p))
		if sp==4 and rng.randf()<0.05:
			preserved_rainbows[p]=true
			if gems.has(p):
				var survivor:Gem=gems[p]
				var st:=survivor.create_tween()
				st.tween_property(survivor,"scale",Vector2.ONE*1.16,.10)
				st.tween_property(survivor,"scale",Vector2.ONE,.18)
			continue
		if gems.has(p):
			var g:Gem=gems[p]
			var t:=g.create_tween().set_parallel(true)
			t.tween_property(g,"scale",Vector2.ZERO,.20).set_trans(Tween.TRANS_BACK)
			t.tween_property(g,"rotation",rng.randf_range(-.5,.5),.20)
			t.tween_property(g,"modulate:a",0,.16)
	_damage_blockers(matches)
	await get_tree().create_timer(.21).timeout
	for p in matches:
		if preserved_rainbows.has(p):
			continue
		board[p.y][p.x]=-1
		specials.erase(p)
		spiders.erase(p)
		if spider_nodes.has(p):
			var sn=spider_nodes[p]
			spider_nodes.erase(p)
			if is_instance_valid(sn): sn.queue_free()
		if gems.has(p):
			var g:Gem=gems[p]
			gems.erase(p)
			g.queue_free()
	if not preserved_rainbows.is_empty() and status:
		status.text="Радужная фишка выжила!"

func _collapse_and_refill()->void:
	var max_time:=0.0
	for x in range(SIZE):
		var segment_bottom:=SIZE-1
		while segment_bottom>=0:
			while segment_bottom>=0 and _cell_is_blocked(Vector2i(x,segment_bottom)):
				segment_bottom-=1
			if segment_bottom<0: break
			var segment_top:=segment_bottom
			while segment_top>=0 and not _cell_is_blocked(Vector2i(x,segment_top)):
				segment_top-=1
			var write_y:=segment_bottom
			for read_y in range(segment_bottom,segment_top,-1):
				if board[read_y][x]<0: continue
				if write_y!=read_y:
					var kind:int=board[read_y][x]
					var old_p:=Vector2i(x,read_y)
					var new_p:=Vector2i(x,write_y)
					var old_special:=int(specials.get(old_p,0))
					var old_spider:=bool(spiders.get(old_p,false))
					var dur:float=.18+(write_y-read_y)*.055
					board[write_y][x]=kind
					board[read_y][x]=-1
					specials.erase(old_p)
					if old_special!=0: specials[new_p]=old_special
					spiders.erase(old_p)
					if old_spider: spiders[new_p]=true
					if gems.has(old_p):
						var g:Gem=gems[old_p]
						gems.erase(old_p)
						gems[new_p]=g
						max_time=max(max_time,dur)
						g.create_tween().tween_property(g,"position",_cell_pos(new_p),dur).set_trans(Tween.TRANS_QUAD)
					if spider_nodes.has(old_p):
						var sn=spider_nodes[old_p]
						spider_nodes.erase(old_p)
						spider_nodes[new_p]=sn
						sn.create_tween().tween_property(sn,"position",_cell_pos(new_p)+Vector2(20,-21),dur).set_trans(Tween.TRANS_QUAD)
				write_y-=1
			for y in range(write_y,segment_top,-1):
				var kind:=rng.randi_range(0,TYPES-1)
				board[y][x]=kind
				var p:=Vector2i(x,y)
				var g:=_make_gem(kind,0)
				g.position=_cell_pos(p)-Vector2(0,CELL*(write_y-y+2))
				g.scale=Vector2.ONE*.82
				gems[p]=g
				var spawn:=write_y-y
				var dur:=.22+spawn*.05
				max_time=max(max_time,dur)
				var tw:=g.create_tween().set_parallel(true)
				tw.tween_property(g,"position",_cell_pos(p),dur).set_trans(Tween.TRANS_BOUNCE)
				tw.tween_property(g,"scale",Vector2.ONE,.18)
			segment_bottom=segment_top
	if max_time>0:
		await get_tree().create_timer(max_time+.05).timeout
	_create_spider_visuals()

func _unique_cells(cells:Array[Vector2i])->Array[Vector2i]:
	var seen:Dictionary={}
	var result:Array[Vector2i]=[]
	for p in cells:
		if _valid_cell(p) and not seen.has(p):
			seen[p]=true
			result.append(p)
	return result

func _match_groups()->Array:
	var groups:Array=[]
	for y in range(SIZE):
		var x:=0
		while x<SIZE:
			var k:int=int(board[y][x])
			var e:=x+1
			while e<SIZE and board[y][e]==k: e+=1
			if k>=0 and e-x>=3:
				var cells:Array[Vector2i]=[]
				for xx in range(x,e): cells.append(Vector2i(xx,y))
				groups.append({"cells":cells,"horizontal":true})
			x=e
	for x in range(SIZE):
		var y:=0
		while y<SIZE:
			var k:int=int(board[y][x])
			var e:=y+1
			while e<SIZE and board[e][x]==k: e+=1
			if k>=0 and e-y>=3:
				var cells:Array[Vector2i]=[]
				for yy in range(y,e): cells.append(Vector2i(x,yy))
				groups.append({"cells":cells,"horizontal":false})
			y=e
	return groups

func _create_special_from_match(cells:Array[Vector2i])->void:
	var groups:=_match_groups()
	for group in groups:
		var gc:Array=group["cells"]
		var overlap:=0
		for p in gc:
			if cells.has(p): overlap+=1
		if overlap < 3: continue
		var chosen:Vector2i=gc[mini(2,gc.size()-1)]
		var found_free:=false
		for candidate in gc:
			if not specials.has(candidate) and cells.has(candidate):
				chosen=candidate
				found_free=true
				break
		if not found_free:
			continue
		var special_type:=0
		if gc.size() >= 5:
			special_type=4
		elif gc.size() == 4:
			special_type=1 if bool(group["horizontal"]) else 2
		else:
			for other in groups:
				if other == group: continue
				var oc:Array=other["cells"]
				for p in gc:
					if oc.has(p) and cells.has(p):
						special_type=3
						chosen=p
						break
				if special_type==3: break
		if special_type != 0:
			specials[chosen]=special_type
			if gems.has(chosen):
				var g:Gem=gems[chosen]
				g.special_type=special_type
				g.scale=Vector2.ONE
				g.modulate.a=1.0
				g.queue_redraw()
			cells.erase(chosen)
			return

func _special_combo_cells(a:Vector2i,b:Vector2i)->Array[Vector2i]:
	var result:Array[Vector2i]=[]
	var sa:=int(specials.get(a,0))
	var sb:=int(specials.get(b,0))
	if sa==4 and sb==4:
		for y in range(SIZE):
			for x in range(SIZE):
				result.append(Vector2i(x,y))
		return result
	if sa==4 or sb==4:
		var normal_p:=b if sa==4 else a
		var target:int=int(board[normal_p.y][normal_p.x])
		if target>=0 and target<TYPES:
			for y in range(SIZE):
				for x in range(SIZE):
					if board[y][x]==target:
						result.append(Vector2i(x,y))
			return result
		for y in range(SIZE):
			for x in range(SIZE):
				result.append(Vector2i(x,y))
		return result
	if (sa==1 or sa==2) and (sb==1 or sb==2):
		for x in range(SIZE): result.append(Vector2i(x,a.y))
		for y in range(SIZE): result.append(Vector2i(a.x,y))
		return result
	if (sa==3 and (sb==1 or sb==2)) or (sb==3 and (sa==1 or sa==2)):
		var line_p:=a if (sa==1 or sa==2) else b
		for y in range(maxi(0,line_p.y-1),mini(SIZE,line_p.y+2)):
			for x in range(SIZE): result.append(Vector2i(x,y))
		for x in range(maxi(0,line_p.x-1),mini(SIZE,line_p.x+2)):
			for y in range(SIZE): result.append(Vector2i(x,y))
		return result
	if sa==3 and sb==3:
		for y in range(maxi(0,a.y-2),mini(SIZE,a.y+3)):
			for x in range(maxi(0,a.x-2),mini(SIZE,a.x+3)):
				result.append(Vector2i(x,y))
		return result
	return _special_effect_cells(a,b)

func _special_effect_cells(a:Vector2i,b:Vector2i)->Array[Vector2i]:
	var result:Array[Vector2i]=[]
	for p in [a,b]:
		var sp:=int(specials.get(p,0))
		if not _is_active_special_type(sp):
			continue
		if sp==1:
			for x in range(SIZE): result.append(Vector2i(x,p.y))
		elif sp==2:
			for y in range(SIZE): result.append(Vector2i(p.x,y))
		elif sp==3:
			for y in range(maxi(0,p.y-1),mini(SIZE,p.y+2)):
				for x in range(maxi(0,p.x-1),mini(SIZE,p.x+2)): result.append(Vector2i(x,y))
		elif sp==4:
			var target:int=int(board[b.y][b.x] if p==a else board[a.y][a.x])
			if target>=0 and target<TYPES:
				for y in range(SIZE):
					for x in range(SIZE):
						if board[y][x]==target: result.append(Vector2i(x,y))
			else:
				for y in range(SIZE):
					for x in range(SIZE): result.append(Vector2i(x,y))
	return _unique_cells(result)

func _find_matches()->Array[Vector2i]:
	var found:Dictionary={}
	for y in range(SIZE):
		var s:=0
		while s<SIZE:
			var k=board[y][s]
			var e:=s+1
			while e<SIZE and board[y][e]==k: e+=1
			if k>=0 and e-s>=3:
				for x in range(s,e): found[Vector2i(x,y)]=true
			s=e
	for x in range(SIZE):
		var s:=0
		while s<SIZE:
			var k=board[s][x]
			var e:=s+1
			while e<SIZE and board[e][x]==k: e+=1
			if k>=0 and e-s>=3:
				for y in range(s,e): found[Vector2i(x,y)]=true
			s=e
	var result:Array[Vector2i]=[]
	for p in found.keys(): result.append(p)
	return result

func _show_hint()->void:
	if busy or moves_left<=0: return
	var move:=_find_hint_move()
	if move.is_empty():
		status.text="Ходов нет — поле будет перемешано"
		return
	var a:Vector2i=move[0]
	var b:Vector2i=move[1]
	(gems[a] as Gem).select(true)
	(gems[b] as Gem).select(true)
	status.text="Подсказка: поменяйте соседние фишки"
	_play("select")
	await get_tree().create_timer(0.65).timeout
	if is_instance_valid(gems.get(a)) and selected.x<0: (gems[a] as Gem).select(false)
	if is_instance_valid(gems.get(b)) and selected.x<0: (gems[b] as Gem).select(false)

func _find_hint_move()->Array:
	for y in range(SIZE):
		for x in range(SIZE):
			var a:=Vector2i(x,y)
			if not _valid_cell(a):
				continue
			if x+1<SIZE:
				var b1:=Vector2i(x+1,y)
				if _valid_cell(b1) and (_is_active_special_type(int(specials.get(a,0))) or _is_active_special_type(int(specials.get(b1,0))) or _swap_creates_match(board,x,y,x+1,y)):
					return [a,b1]
			if y+1<SIZE:
				var b2:=Vector2i(x,y+1)
				if _valid_cell(b2) and (_is_active_special_type(int(specials.get(a,0))) or _is_active_special_type(int(specials.get(b2,0))) or _swap_creates_match(board,x,y,x,y+1)):
					return [a,b2]
	return []

func _swap_creates_match(b:Array,x1:int,y1:int,x2:int,y2:int)->bool:
	if x1<0 or y1<0 or x1>=SIZE or y1>=SIZE or x2<0 or y2<0 or x2>=SIZE or y2>=SIZE:
		return false
	var a=b[y1][x1]
	var c=b[y2][x2]
	if a<0 or c<0 or a==c: return false
	b[y1][x1]=c
	b[y2][x2]=a
	var ok:=_cell_has_match(b,x1,y1) or _cell_has_match(b,x2,y2)
	b[y1][x1]=a
	b[y2][x2]=c
	return ok

func _cell_has_match(b:Array,x:int,y:int)->bool:
	var k=b[y][x]
	if k<0: return false
	var n:=1
	var i:=x-1
	while i>=0 and b[y][i]==k: n+=1; i-=1
	i=x+1
	while i<SIZE and b[y][i]==k: n+=1; i+=1
	if n>=3: return true
	n=1
	i=y-1
	while i>=0 and b[i][x]==k: n+=1; i-=1
	i=y+1
	while i<SIZE and b[i][x]==k: n+=1; i+=1
	return n>=3

func _check_level_state()->void:
	if is_instance_valid(mechanics) and bool(mechanics.call("is_failed")):
		_lose()
		return
	if _goals_complete():
		_win()
		return
	if moves_left<=0:
		_lose()
		return
	status.text="Продолжайте! %s"%MECHANICS[int(LEVELS[current_level]["mechanic"])]

func _win()->void:
	busy=true
	completed[current_level]=true
	var stars:=_calculate_stars()
	var previous_stars:=int(level_stars[current_level])
	var new_stars:=maxi(previous_stars,stars)
	var star_delta:=new_stars-previous_stars
	level_stars[current_level]=new_stars
	island_stars+=star_delta
	var passive_star_bonus:=0
	if star_delta>0 and new_stars>=3 and is_instance_valid(island_progression):
		passive_star_bonus=int(island_progression.call("get_three_star_bonus"))
		island_stars+=passive_star_bonus
	if current_level<99: unlocked_level=max(unlocked_level,current_level+1)
	_save_progress()
	_update_labels()
	_result_modal(true)

func _lose()->void:
	busy=true
	_result_modal(false)

func _result_modal(won:bool)->void:
	modal=Control.new()
	modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal.mouse_filter=Control.MOUSE_FILTER_STOP
	var shade:=ColorRect.new(); shade.size=Vector2(900,900); shade.color=Color(0.02,0.04,0.09,.8); modal.add_child(shade)
	var p:=Panel.new(); p.position=Vector2(145,215); p.size=Vector2(610,410); p.add_theme_stylebox_override("panel",_style(Color("#111c31"),Color("#38527d"),22)); modal.add_child(p)
	var t:=Label.new(); t.text="УРОВЕНЬ ПРОЙДЕН! 🎉" if won else "ХОДЫ ЗАКОНЧИЛИСЬ"; t.position=Vector2(40,25); t.size=Vector2(530,55); t.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; t.add_theme_font_size_override("font_size",29); t.add_theme_color_override("font_color",Color("#63e6a0") if won else Color("#ff8794")); p.add_child(t)
	var stars:=Label.new(); stars.text=_stars_string(_calculate_stars()) if won else "☆ ☆ ☆"; stars.position=Vector2(55,78); stars.size=Vector2(500,48); stars.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; stars.add_theme_font_size_override("font_size",30); stars.add_theme_color_override("font_color",Color("#ffd86a")); p.add_child(stars)
	var tx:=Label.new(); tx.text=("Все цели выполнены!\nОчки: %d\nХодов осталось: %d\nЛучшее комбо: x%d"%[score,moves_left,best_combo_level]) if won else ("Цели не выполнены.\nОчки: %d\nЛучшее комбо: x%d"%[score,best_combo_level]); tx.position=Vector2(55,135); tx.size=Vector2(500,110); tx.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; tx.add_theme_font_size_override("font_size",16); tx.add_theme_color_override("font_color",Color("#c5d1e8")); p.add_child(tx)
	var primary:=Button.new(); primary.position=Vector2(65,320); primary.size=Vector2(230,52); primary.add_theme_font_size_override("font_size",13); primary.add_theme_stylebox_override("normal",_style(Color("#237b50") if won else Color("#334d78"),Color("#62dfa1") if won else Color("#6484b8"))); primary.text=("СЛЕДУЮЩИЙ УРОВЕНЬ →" if current_level<99 else "ВЕРНУТЬСЯ НА КАРТУ") if won else "ПОПРОБОВАТЬ СНОВА"; primary.pressed.connect(_modal_primary.bind(won)); p.add_child(primary)
	var secondary:=Button.new(); secondary.position=Vector2(315,320); secondary.size=Vector2(230,52); secondary.text="ВЕРНУТЬСЯ В ЛОББИ"; secondary.add_theme_stylebox_override("normal",_style(Color("#182943"),Color("#466187"))); secondary.pressed.connect(_show_map); p.add_child(secondary); game_layer.add_child(modal)

func _modal_primary(won:bool)->void:
	if modal:
		modal.queue_free()
		modal=null
	if won and current_level<99:
		_start_level(current_level+1)
	elif won:
		_show_map()
	else:
		_start_level(current_level)

func _restart_level()->void:
	_start_level(current_level)

func _update_best()->void:
	if score>best:
		best=score
		var f:=FileAccess.open("user://best_score.txt",FileAccess.WRITE)
		if f: f.store_string(str(best))

func _update_labels()->void:
	level_label.text="УРОВЕНЬ\n%d"%(current_level+1)
	moves_label.text="ХОДЫ\n%d"%moves_left
	score_label.text="ОЧКИ\n%d"%score
	best_label.text="РЕКОРД\n%d"%best
	combo_label.text="КОМБО\n%s"%("x%d"%combo if combo>0 else "—")
	goal_label.text=_goal_text()
	goal_label.size=Vector2(624,54)
	goal_label.add_theme_font_size_override("font_size",11)
	if is_instance_valid(hammer_button):
		hammer_button.text="%d"%int(booster_inventory["hammer"])
		extra_moves_button.text="+3  %d"%int(booster_inventory["extra_moves"])
		shuffle_button.text="%d"%int(booster_inventory["shuffle"])

func _spawn_match_burst(p:Vector2,c:Color)->void:
	var burst:=Sprite2D.new()
	burst.texture=MATCH_BURST_TEXTURE
	burst.position=p
	burst.scale=Vector2(.20,.20)
	burst.modulate=Color(c.r,c.g,c.b,.92)
	fx.add_child(burst)
	var bt:=burst.create_tween().set_parallel(true)
	bt.tween_property(burst,"scale",Vector2(.62,.62),.24).set_trans(Tween.TRANS_BACK)
	bt.tween_property(burst,"modulate:a",0.0,.28)
	bt.chain().tween_callback(burst.queue_free)

func _spawn_combo_fx(p:Vector2)->void:
	var ring:=Sprite2D.new()
	ring.texture=COMBO_RING_TEXTURE
	ring.position=p
	ring.scale=Vector2(.12,.12)
	fx.add_child(ring)
	var rt:=ring.create_tween().set_parallel(true)
	rt.tween_property(ring,"scale",Vector2(.68,.68),.34).set_trans(Tween.TRANS_BACK)
	rt.tween_property(ring,"rotation",TAU*.5,.45)
	rt.tween_property(ring,"modulate:a",0.0,.45)
	rt.chain().tween_callback(ring.queue_free)

func _spawn_special_flash(p:Vector2)->void:
	var ray:=Sprite2D.new()
	ray.texture=SPECIAL_RAY_TEXTURE
	ray.position=p
	ray.scale=Vector2(.15,.15)
	fx.add_child(ray)
	var rt:=ray.create_tween().set_parallel(true)
	rt.tween_property(ray,"scale",Vector2(.72,.72),.20).set_trans(Tween.TRANS_BACK)
	rt.tween_property(ray,"rotation",PI*.25,.26)
	rt.tween_property(ray,"modulate:a",0.0,.24)
	rt.chain().tween_callback(ray.queue_free)

func _spawn_fx(p:Vector2,c:Color)->void:
	_spawn_match_burst(p,c)
	for i in range(14):
		var d:=Polygon2D.new()
		d.polygon=PackedVector2Array([Vector2(-3,-3),Vector2(3,-3),Vector2(3,3),Vector2(-3,3)])
		d.color=c.lightened(.15)
		d.position=p
		fx.add_child(d)
		var a:=TAU*float(i)/14.0
		var t:=d.create_tween().set_parallel(true)
		t.tween_property(d,"position",p+Vector2(cos(a),sin(a))*rng.randf_range(30,58),.36)
		t.tween_property(d,"scale",Vector2.ZERO,.36)
		t.tween_property(d,"modulate:a",0,.36)
		t.chain().tween_callback(d.queue_free)

func _popup(p:Vector2,n:int)->void:
	var l:=Label.new()
	l.text="+%d"%n
	l.position=p-Vector2(18,15)
	l.add_theme_font_size_override("font_size",20)
	fx.add_child(l)
	var t:=l.create_tween()
	t.tween_property(l,"position",l.position-Vector2(0,40),.45)
	t.parallel().tween_property(l,"modulate:a",0,.45)
	t.tween_callback(l.queue_free)

func _build_sounds()->void:
	for n in ["select","swap","match","combo","error"]:
		var p:=AudioStreamPlayer.new()
		p.stream=_tone(n)
		p.volume_db=-10
		add_child(p)
		sounds[n]=p

func _tone(k:String)->AudioStreamWAV:
	var freq:float={"select":520.0,"swap":320.0,"match":680.0,"combo":900.0,"error":180.0}[k]
	var dur:float={"select":.06,"swap":.09,"match":.14,"combo":.22,"error":.13}[k]
	var rate:=22050
	var count:=int(rate*dur)
	var data:=PackedByteArray()
	data.resize(count*2)
	for i in range(count):
		var t:=float(i)/rate
		var env:=1.0-float(i)/count
		data.encode_s16(i*2,int(sin(TAU*freq*t)*env*.3*32767))
	var s:=AudioStreamWAV.new()
	s.format=AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate=rate
	s.data=data
	return s

func _play(n:String)->void:
	if sounds.has(n):
		(sounds[n] as AudioStreamPlayer).play()