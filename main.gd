extends Node2D

const SIZE := 8
const TYPES := 6
const CELL := 78.0
const ORIGIN := Vector2(138, 202)
const COLORS := [Color("#ff5b67"), Color("#4d9cff"), Color("#43d98b"), Color("#ffd34e"), Color("#b978ff"), Color("#ff9b4a")]
const SYMBOLS := ["●", "◆", "■", "★", "⬟", "▲"]
const TYPE_NAMES := ["красных кругов", "синих ромбов", "зелёных квадратов", "звёзд", "фиолетовых кристаллов", "оранжевых треугольников"]
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
var destroyed_counts: Array = [0, 0, 0, 0, 0, 0]
var specials: Dictionary = {} # 1 horizontal, 2 vertical, 3 bomb, 4 rainbow
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

class Gem extends Node2D:
	var kind := 0
	var color := Color.WHITE
	var symbol := "●"
	var chosen := false
	var special_type := 0
	func setup(k: int, c: Color, s: String, sp: int = 0) -> void:
		kind = k
		color = c
		symbol = s
		special_type = sp
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
		if special_type == 1:
			draw_line(Vector2(-s*.72, 0), Vector2(s*.72, 0), Color.WHITE, 4.0)
		elif special_type == 2:
			draw_line(Vector2(0, -s*.72), Vector2(0, s*.72), Color.WHITE, 4.0)
		elif special_type == 3:
			draw_circle(Vector2.ZERO, s*.48, Color(1,1,1,.22))
			draw_arc(Vector2.ZERO, s*.48, 0, TAU, 16, Color.WHITE, 3.0)
		elif special_type == 4:
			draw_circle(Vector2.ZERO, s*.38, Color.WHITE)
			draw_arc(Vector2.ZERO, s*.62, 0, TAU, 18, Color.WHITE, 3.0)

class BoardFrame extends Node2D:
	func _draw() -> void:
		var o := StyleBoxFlat.new()
		o.bg_color=Color("#0e172b")
		o.border_color=Color("#344e7c")
		o.set_border_width_all(2)
		o.set_corner_radius_all(18)
		draw_style_box(o,Rect2(-314,-314,628,628))
		var c := StyleBoxFlat.new()
		c.bg_color=Color("#0b1426")
		c.border_color=Color("#172846")
		c.set_border_width_all(1)
		c.set_corner_radius_all(10)
		for y in SIZE:
			for x in SIZE:
				draw_style_box(c,Rect2(-312+x*CELL+4,-312+y*CELL+4,CELL-8,CELL-8))

func _ready() -> void:
	rng.randomize()
	_build_levels()
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
		LEVELS.append({"moves":moves,"score":target_score,"type":target_type,"count":target_count,"mechanic":tier})
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
	var bg:=ColorRect.new(); bg.size=Vector2(900,900); bg.color=Color("#071525"); menu_layer.add_child(bg)
	var sky:=ColorRect.new(); sky.size=Vector2(900,170); sky.color=Color("#103553"); menu_layer.add_child(sky)
	var title:=Label.new(); title.text="МИРЫ"; title.position=Vector2(70,35); title.add_theme_font_size_override("font_size",42); title.add_theme_color_override("font_color",Color("#f4f7ff")); menu_layer.add_child(title)
	var sub:=Label.new(); sub.text="Выбери остров и отправляйся в путешествие"; sub.position=Vector2(73,90); sub.add_theme_font_size_override("font_size",16); sub.add_theme_color_override("font_color",Color("#91abc9")); menu_layer.add_child(sub)
	_create_island_card(0,Vector2(100,220),true,"ЗАБЫТЫЕ ТРОПИКИ","Остров-обучение","Джунгли • пляж • древние тотемы • пираты")
	_create_island_card(1,Vector2(470,220),false,"???","Следующий остров","Откроется в будущей главе")
	_create_island_card(2,Vector2(285,520),false,"???","Следующий остров","Новые приключения впереди")
	var foot:=Label.new(); foot.text="Пока доступен только первый остров. Здесь будет развиваться вся система миров."; foot.position=Vector2(100,820); foot.size=Vector2(700,35); foot.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; foot.add_theme_font_size_override("font_size",13); foot.add_theme_color_override("font_color",Color("#7188aa")); menu_layer.add_child(foot)
	busy=false

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

func _create_level_node(parent:Control,index:int,pos:Vector2)->void:
	var unlocked:=index<=unlocked_level
	var done:=completed[index]
	var c:=Color("#39cf78") if done else (Color("#328dff") if unlocked else Color("#c94253"))
	var b:=Button.new(); b.position=pos-Vector2(28,28); b.size=Vector2(56,56); b.text=("✓" if done else (str(index+1) if unlocked else "🔒")); b.disabled=not unlocked; b.add_theme_font_size_override("font_size",18); b.add_theme_color_override("font_color",Color.WHITE); b.add_theme_stylebox_override("normal",_style(c,c.lightened(.25),28)); b.add_theme_stylebox_override("hover",_style(c.lightened(.12),Color.WHITE,28)); b.add_theme_stylebox_override("pressed",_style(c.darkened(.08),Color.WHITE,28)); b.tooltip_text="Уровень %d"%(index+1); b.pressed.connect(_start_level.bind(index)); parent.add_child(b)
	var l:=Label.new(); l.text=str(index+1); l.position=pos+Vector2(-30,31); l.size=Vector2(60,22); l.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; l.add_theme_font_size_override("font_size",10); l.add_theme_color_override("font_color",Color("#b8d2d9")); parent.add_child(l)
	if index%10==0:
		var chapter:=Label.new(); chapter.text="ГЛАВА %d"%(int(index/10)+1); chapter.position=pos+Vector2(-65,-55); chapter.size=Vector2(130,24); chapter.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; chapter.add_theme_font_size_override("font_size",11); chapter.add_theme_color_override("font_color",c.lightened(.25)); parent.add_child(chapter)

func _start_level(index:int)->void:
	if index>unlocked_level: return
	current_level=index
	var data:Dictionary=LEVELS[index]
	moves_left=int(data["moves"])
	score=0
	combo=0
	destroyed_counts=[0,0,0,0,0,0]
	specials.clear()
	selected=Vector2i(-1,-1)
	busy=true
	if map_layer: map_layer.visible=false
	if menu_layer: menu_layer.visible=false
	game_layer.visible=true
	_generate_board()
	_clear_visuals()
	_create_visuals()
	_update_labels()
	status.text="Уровень %d • %s"%[index+1,MECHANICS[int(data["mechanic"])]]
	busy=false

func _build_game_layer()->void:
	game_layer=Control.new(); game_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); add_child(game_layer)
	var bg:=ColorRect.new(); bg.size=Vector2(900,900); bg.color=Color("#080e1c"); game_layer.add_child(bg)
	var head:=ColorRect.new(); head.size=Vector2(900,176); head.color=Color("#111b33"); game_layer.add_child(head)
	var title:=Label.new(); title.text="ТРИ В РЯД"; title.position=Vector2(138,12); title.add_theme_font_size_override("font_size",36); title.add_theme_color_override("font_color",Color("#f2f5ff")); game_layer.add_child(title)
	var hint:=Label.new(); hint.text="Выполни две цели уровня до окончания ходов"; hint.position=Vector2(140,53); hint.add_theme_font_size_override("font_size",13); hint.add_theme_color_override("font_color",Color("#8495bb")); game_layer.add_child(hint)
	level_label=_stat("УРОВЕНЬ",Vector2(138,88)); moves_label=_stat("ХОДЫ",Vector2(255,88)); score_label=_stat("ОЧКИ",Vector2(372,88)); best_label=_stat("РЕКОРД",Vector2(489,88)); combo_label=_stat("КОМБО",Vector2(606,88))
	goal_label=Label.new(); goal_label.position=Vector2(138,138); goal_label.size=Vector2(620,28); goal_label.add_theme_font_size_override("font_size",13); goal_label.add_theme_color_override("font_color",Color("#dce5ff")); game_layer.add_child(goal_label)
	var restart:=Button.new(); restart.text="↻"; restart.position=Vector2(780,24); restart.size=Vector2(48,42); restart.add_theme_font_size_override("font_size",20); restart.add_theme_stylebox_override("normal",_style(Color("#1a2a4b"),Color("#3b5787"))); restart.pressed.connect(_restart_level); game_layer.add_child(restart)
	var mapb:=Button.new(); mapb.text="КАРТА"; mapb.position=Vector2(670,86); mapb.size=Vector2(98,34); mapb.add_theme_font_size_override("font_size",12); mapb.add_theme_stylebox_override("normal",_style(Color("#16243f"),Color("#30486f"))); mapb.pressed.connect(_show_map); game_layer.add_child(mapb)
	var hint:=Button.new(); hint.text="ПОДСКАЗКА"; hint.position=Vector2(670,126); hint.size=Vector2(98,34); hint.add_theme_font_size_override("font_size",10); hint.add_theme_stylebox_override("normal",_style(Color("#18324b"),Color("#3f7292"))); hint.pressed.connect(_show_hint); game_layer.add_child(hint)
	var frame:=BoardFrame.new(); frame.position=ORIGIN+Vector2(312,312); game_layer.add_child(frame)
	root=Node2D.new(); game_layer.add_child(root); fx=Node2D.new(); game_layer.add_child(fx)
	status=Label.new(); status.position=Vector2(138,832); status.size=Vector2(624,34); status.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; status.add_theme_font_size_override("font_size",14); status.add_theme_color_override("font_color",Color("#9baad0")); game_layer.add_child(status)

func _stat(n:String,p:Vector2)->Label:
	var l:=Label.new(); l.position=p; l.size=Vector2(105,45); l.text=n+"\n0"; l.add_theme_font_size_override("font_size",12); l.add_theme_color_override("font_color",Color("#8395bd")); game_layer.add_child(l); return l

func _generate_board()->void:
	board.clear()
	for y in range(SIZE):
		var row:Array=[]
		for x in range(SIZE):
			var opts:Array[int]=[]
			for t in range(TYPES):
				if x>=2 and row[x-1]==t and row[x-2]==t: continue
				if y>=2 and board[y-1][x]==t and board[y-2][x]==t: continue
				opts.append(t)
			row.append(opts[rng.randi_range(0,opts.size()-1)])
		board.append(row)

func _clear_visuals()->void:
	for n in root.get_children(): n.free()
	for n in fx.get_children(): n.free()
	gems.clear()
	specials.clear()
func _cell_pos(p:Vector2i)->Vector2: return ORIGIN+Vector2(p.x*CELL+CELL/2,p.y*CELL+CELL/2)
func _make_gem(k:int, sp:int = 0)->Gem:
	var g:=Gem.new()
	g.setup(k,COLORS[k],SYMBOLS[k],sp)
	root.add_child(g)
	return g

func _create_visuals()->void:
	for y in range(SIZE):
		for x in range(SIZE):
			var p:=Vector2i(x,y)
			var sp:int=int(specials.get(p,0))
			var g:=_make_gem(board[y][x],sp)
			g.position=_cell_pos(p)
			g.scale=Vector2.ONE
			g.modulate=Color.WHITE
			g.rotation=0.0
			gems[p]=g

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
				if _valid_cell(from) and _valid_cell(to):
					_swipe_move(from,to)
			elif _valid_cell(_board_cell_from_position(touch.position)):
				_click(_board_cell_from_position(touch.position))
		return
	if event is InputEventMouseButton:
		var m:=event as InputEventMouseButton
		if not m.pressed or m.button_index!=MOUSE_BUTTON_LEFT: return
		var p:=_board_cell_from_position(m.position)
		if _valid_cell(p): _click(p)

func _board_cell_from_position(pos:Vector2)->Vector2i:
	var local:=pos-ORIGIN
	return Vector2i(floor(local.x/CELL),floor(local.y/CELL))

func _valid_cell(p:Vector2i)->bool:
	return p.x>=0 and p.y>=0 and p.x<SIZE and p.y<SIZE

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
	var special_triggered := special_a != 0 or special_b != 0
	var special_combo := special_a != 0 and special_b != 0
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
	while true:
		combo+=1
		var wave:Array[Vector2i]=matches.duplicate()
		if special_combo:
			wave.append_array(_special_combo_cells(a,b))
			special_combo=false
			special_triggered=false
		elif special_triggered:
			wave.append_array(_special_effect_cells(a,b))
			special_triggered=false
		wave=_unique_cells(wave)
		if wave.is_empty():
			break
		_create_special_from_match(wave)
		var gained:int=wave.size()*10*combo
		score+=gained
		_play("combo" if combo>1 else "match")
		_popup(_cell_pos(wave[0]),gained)
		await _destroy_matches(wave)
		await _collapse_and_refill()
		matches=_find_matches()
		if matches.is_empty():
			break
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
	for p in matches:
		var kind:int=board[p.y][p.x]
		if kind >= 0 and kind < destroyed_counts.size():
			destroyed_counts[kind]+=1
		_spawn_fx(_cell_pos(p),COLORS[kind])
		if gems.has(p):
			var g:Gem=gems[p]
			var t:=g.create_tween().set_parallel(true)
			t.tween_property(g,"scale",Vector2.ZERO,.20).set_trans(Tween.TRANS_BACK)
			t.tween_property(g,"rotation",rng.randf_range(-.5,.5),.20)
			t.tween_property(g,"modulate:a",0,.16)
	await get_tree().create_timer(.21).timeout
	for p in matches:
		board[p.y][p.x]=-1
		specials.erase(p)
		if gems.has(p):
			var g:Gem=gems[p]
			gems.erase(p)
			g.queue_free()

func _collapse_and_refill()->void:
	var max_time:=0.0
	for x in range(SIZE):
		var write_y:=SIZE-1
		for read_y in range(SIZE-1,-1,-1):
			if board[read_y][x]<0: continue
			if write_y!=read_y:
				var kind:int=board[read_y][x]
				var old_special:=int(specials.get(Vector2i(x,read_y),0))
				board[write_y][x]=kind
				if old_special != 0:
					specials.erase(Vector2i(x,read_y))
					specials[Vector2i(x,write_y)]=old_special
				board[read_y][x]=-1
				var old_p:=Vector2i(x,read_y)
				var new_p:=Vector2i(x,write_y)
				if not gems.has(old_p): continue
				var g:Gem=gems[old_p]
				gems.erase(old_p)
				gems[new_p]=g
				var d:=write_y-read_y
				var dur:=.18+d*.055
				max_time=max(max_time,dur)
				var tw:=g.create_tween()
				tw.tween_property(g,"position",_cell_pos(new_p),dur).set_trans(Tween.TRANS_QUAD)
			write_y-=1
		var spawn:=0
		for y in range(write_y,-1,-1):
			var kind:=rng.randi_range(0,TYPES-1)
			board[y][x]=kind
			var p:=Vector2i(x,y)
			var sp:=int(specials.get(p,0))
			var g:=_make_gem(kind,sp)
			specials.erase(p)
			g.position=_cell_pos(p)-Vector2(0,CELL*(spawn+2))
			g.scale=Vector2.ONE*.82
			gems[p]=g
			var dur:=.22+spawn*.05
			max_time=max(max_time,dur)
			var tw:=g.create_tween().set_parallel(true)
			tw.tween_property(g,"position",_cell_pos(p),dur).set_trans(Tween.TRANS_BOUNCE)
			tw.tween_property(g,"scale",Vector2.ONE,.18)
			spawn+=1
	if max_time>0: await get_tree().create_timer(max_time+.05).timeout

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
			var k:=board[y][x]
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
			var k:=board[y][x]
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
		var target:=board[normal_p.y][normal_p.x]
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
		if sp==1:
			for x in range(SIZE): result.append(Vector2i(x,p.y))
		elif sp==2:
			for y in range(SIZE): result.append(Vector2i(p.x,y))
		elif sp==3:
			for y in range(maxi(0,p.y-1),mini(SIZE,p.y+2)):
				for x in range(maxi(0,p.x-1),mini(SIZE,p.x+2)): result.append(Vector2i(x,y))
		elif sp==4:
			var target:=board[b.y][b.x] if p==a else board[a.y][a.x]
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
			if x+1<SIZE and _swap_creates_match(board,x,y,x+1,y): return [Vector2i(x,y),Vector2i(x+1,y)]
			if y+1<SIZE and _swap_creates_match(board,x,y,x,y+1): return [Vector2i(x,y),Vector2i(x,y+1)]
	return []

func _swap_creates_match(b:Array,x1:int,y1:int,x2:int,y2:int)->bool:
	var a=b[y1][x1]
	var c=b[y2][x2]
	if a==c: return false
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
	var data:Dictionary=LEVELS[current_level]
	var type:int=int(data["type"])
	var score_done:bool=score>=int(data["score"])
	var pieces_done:bool=destroyed_counts[type]>=int(data["count"])
	if score_done and pieces_done:
		_win()
		return
	if moves_left<=0:
		_lose()
		return
	status.text="Продолжайте! %s"%MECHANICS[int(data["mechanic")]]

func _win()->void:
	busy=true
	completed[current_level]=true
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
	var p:=Panel.new(); p.position=Vector2(145,245); p.size=Vector2(610,350); p.add_theme_stylebox_override("panel",_style(Color("#111c31"),Color("#38527d"),22)); modal.add_child(p)
	var t:=Label.new(); t.text="УРОВЕНЬ ПРОЙДЕН! 🎉" if won else "ХОДЫ ЗАКОНЧИЛИСЬ"; t.position=Vector2(40,35); t.size=Vector2(530,55); t.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; t.add_theme_font_size_override("font_size",29); t.add_theme_color_override("font_color",Color("#63e6a0") if won else Color("#ff8794")); p.add_child(t)
	var tx:=Label.new(); tx.text=("Поздравляем!\nВсе цели уровня %d выполнены.\n\nОчки: %d     Ходов осталось: %d"%[current_level+1,score,moves_left]) if won else ("Попробуй ещё раз!\nЦель не выполнена.\n\nОчки: %d"%score); tx.position=Vector2(55,105); tx.size=Vector2(500,105); tx.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; tx.add_theme_font_size_override("font_size",16); tx.add_theme_color_override("font_color",Color("#c5d1e8")); p.add_child(tx)
	var primary:=Button.new(); primary.position=Vector2(65,255); primary.size=Vector2(230,52); primary.add_theme_font_size_override("font_size",13); primary.add_theme_stylebox_override("normal",_style(Color("#237b50") if won else Color("#334d78"),Color("#62dfa1") if won else Color("#6484b8"))); primary.text=("СЛЕДУЮЩИЙ УРОВЕНЬ →" if current_level<99 else "ВЕРНУТЬСЯ НА КАРТУ") if won else "ПОПРОБОВАТЬ СНОВА"; primary.pressed.connect(_modal_primary.bind(won)); p.add_child(primary)
	var secondary:=Button.new(); secondary.position=Vector2(315,255); secondary.size=Vector2(230,52); secondary.text="ВЕРНУТЬСЯ В ЛОББИ"; secondary.add_theme_stylebox_override("normal",_style(Color("#182943"),Color("#466187"))); secondary.pressed.connect(_show_map); p.add_child(secondary); game_layer.add_child(modal)

func _modal_primary(won:bool)->void:
	if won and current_level<99: _start_level(current_level+1)
	elif won: _show_map()
	else: _start_level(current_level)

func _restart_level()->void:
	_start_level(current_level)

func _update_best()->void:
	if score>best:
		best=score
		var f:=FileAccess.open("user://best_score.txt",FileAccess.WRITE)
		if f: f.store_string(str(best))

func _update_labels()->void:
	var d:Dictionary=LEVELS[current_level]
	var type:int=int(d["type"])
	level_label.text="УРОВЕНЬ\n%d"%(current_level+1)
	moves_label.text="ХОДЫ\n%d"%moves_left
	score_label.text="ОЧКИ\n%d"%score
	best_label.text="РЕКОРД\n%d"%best
	combo_label.text="КОМБО\n%s"%("x%d"%combo if combo>0 else "—")
	goal_label.text="ЦЕЛЬ: %d / %d очков   •   %d / %d %s"%[score,int(d["score"]),destroyed_counts[type],int(d["count"]),TYPE_NAMES[type]]

func _spawn_fx(p:Vector2,c:Color)->void:
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