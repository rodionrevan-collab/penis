extends Node2D

const SIZE := 8
const TYPES := 6
const CELL := 78.0
const ORIGIN := Vector2(138, 178)
const COLORS := [Color("#ff5b67"),Color("#4d9cff"),Color("#43d98b"),Color("#ffd34e"),Color("#b978ff"),Color("#ff9b4a")]
const SYMBOLS := ["●","◆","■","★","⬟","▲"]

var board:Array = []
var gems:Dictionary = {}
var selected := Vector2i(-1,-1)
var busy := false
var score := 0
var best := 0
var combo := 0
var rng := RandomNumberGenerator.new()
var root:Node2D
var fx:Node2D
var score_label:Label
var best_label:Label
var combo_label:Label
var status:Label
var sounds:Dictionary = {}

class Gem extends Node2D:
	var kind := 0
	var color := Color.WHITE
	var symbol := "●"
	var chosen := false
	func setup(k:int,c:Color,s:String)->void:
		kind=k;color=c;symbol=s;queue_redraw()
	func select(v:bool)->void:
		chosen=v
		var t=create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		t.tween_property(self,"scale",Vector2.ONE*(1.12 if v else 1.0),0.12)
		queue_redraw()
	func _draw()->void:
		var s:=28.0
		draw_circle(Vector2(2,4),s+3,Color(0,0,0,0.28))
		if chosen: draw_circle(Vector2.ZERO,s+8,Color(color.r,color.g,color.b,0.18))
		match kind:
			0: draw_circle(Vector2.ZERO,s,color);draw_circle(Vector2.ZERO,s-5,color.darkened(0.08))
			1: draw_colored_polygon(PackedVector2Array([Vector2(0,-s),Vector2(s,0),Vector2(0,s),Vector2(-s,0)]),color)
			2: draw_style_box(box(),Rect2(-s,-s,s*2,s*2))
			3:
				var a:=PackedVector2Array()
				for i in 10:
					var ang:float=-PI/2+i*PI/5
					a.append(Vector2(cos(ang),sin(ang))*(s if i%2==0 else s*.43))
				draw_colored_polygon(a,color)
			4:
				var h:=PackedVector2Array()
				for i in 6:
					var ang:float=-PI/2+i*PI/3
					h.append(Vector2(cos(ang),sin(ang))*s)
				draw_colored_polygon(h,color)
			5: draw_colored_polygon(PackedVector2Array([Vector2(0,-s),Vector2(s,s),Vector2(-s,s)]),color)
		draw_circle(Vector2(-s*.32,-s*.34),s*.19,Color(1,1,1,.5))
		draw_circle(Vector2(-s*.23,-s*.22),s*.08,Color.WHITE)
		draw_string(ThemeDB.fallback_font,Vector2(-7,6),symbol,HORIZONTAL_ALIGNMENT_LEFT,-1,13,Color(1,1,1,.25))
	func box()->StyleBoxFlat:
		var b:=StyleBoxFlat.new();b.bg_color=color;b.border_color=color.lightened(.22);b.set_border_width_all(3);b.set_corner_radius_all(9);return b

class BoardFrame extends Node2D:
	func _draw()->void:
		var o:=StyleBoxFlat.new();o.bg_color=Color("#0e172b");o.border_color=Color("#2b3e61");o.set_border_width_all(2);o.set_corner_radius_all(18)
		draw_style_box(o,Rect2(-314,-314,628,628))
		var c:=StyleBoxFlat.new();c.bg_color=Color("#0b1426");c.border_color=Color("#172846");c.set_border_width_all(1);c.set_corner_radius_all(10)
		for y in SIZE:
			for x in SIZE: draw_style_box(c,Rect2(-312+x*CELL+4,-312+y*CELL+4,CELL-8,CELL-8))

func _ready()->void:
	rng.randomize()
	best=int(FileAccess.get_file_as_string("user://best_score.txt")) if FileAccess.file_exists("user://best_score.txt") else 0
	_build_ui();_build_sounds();_new_game()

func _build_ui()->void:
	var bg:=ColorRect.new();bg.size=Vector2(900,900);bg.color=Color("#090e1b");add_child(bg);move_child(bg,0)
	var head:=ColorRect.new();head.size=Vector2(900,150);head.color=Color("#111a30");add_child(head);move_child(head,1)
	var title:=Label.new();title.text="ТРИ В РЯД";title.position=Vector2(138,20);title.add_theme_font_size_override("font_size",38);add_child(title)
	var sub:=Label.new();sub.text="Собирай 3+ одинаковых фишки и набирай очки";sub.position=Vector2(140,68);sub.add_theme_font_size_override("font_size",14);sub.add_theme_color_override("font_color",Color("#8998b9"));add_child(sub)
	score_label=_stat("ОЧКИ",Vector2(138,103));best_label=_stat("РЕКОРД",Vector2(300,103));combo_label=_stat("КОМБО",Vector2(462,103))
	var b:=Button.new();b.text="↻  НОВАЯ ИГРА";b.position=Vector2(670,31);b.size=Vector2(120,48);b.add_theme_font_size_override("font_size",13);b.add_theme_stylebox_override("normal",style(Color("#1b2a4a"),Color("#334a75")));b.add_theme_stylebox_override("hover",style(Color("#263a62"),Color("#6684c4")));b.pressed.connect(_new_game);add_child(b)
	var frame:=BoardFrame.new();frame.position=ORIGIN+Vector2(312,312);add_child(frame)
	root=Node2D.new();add_child(root);fx=Node2D.new();add_child(fx)
	status=Label.new();status.position=Vector2(138,810);status.size=Vector2(624,38);status.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;status.add_theme_font_size_override("font_size",15);status.add_theme_color_override("font_color",Color("#9baad0"));add_child(status)

func _stat(n:String,p:Vector2)->Label:
	var l:=Label.new();l.position=p;l.size=Vector2(130,44);l.text=n+"\n0";l.add_theme_font_size_override("font_size",12);l.add_theme_color_override("font_color",Color("#8494b9"));add_child(l);return l
func style(bg:Color,border:Color)->StyleBoxFlat:
	var s:=StyleBoxFlat.new();s.bg_color=bg;s.border_color=border;s.set_border_width_all(1);s.set_corner_radius_all(12);return s

func _build_sounds()->void:
	for n in ["select","swap","match","combo","error"]:
		var p:=AudioStreamPlayer.new();p.stream=_tone(n);p.volume_db=-10;add_child(p);sounds[n]=p
func _tone(k:String)->AudioStreamWAV:
	var f:float={"select":520.0,"swap":320.0,"match":680.0,"combo":900.0,"error":180.0}[k];var d:float={"select":.06,"swap":.09,"match":.14,"combo":.22,"error":.13}[k];var rate:=22050;var count:=int(rate*d);var data:=PackedByteArray();data.resize(count*2)
	for i in count:
		var t:=float(i)/rate;var env:=1.0-float(i)/count;var freq:=f+(t*220 if k=="match" else 0.0);if k=="combo":freq+=sin(t*25)*120
		data.encode_s16(i*2,int(sin(TAU*freq*t)*env*.30*32767))
	var s:=AudioStreamWAV.new();s.format=AudioStreamWAV.FORMAT_16_BITS;s.mix_rate=rate;s.data=data;return s
func _play(n:String)->void:
	if sounds.has(n):sounds[n].play()

func _new_game()->void:
	busy=true;selected=Vector2i(-1,-1);score=0;combo=0;_generate_board();_clear();_create(true);_labels();status.text="Выберите фишку, затем соседнюю";busy=false
func _generate_board()->void:
	board.clear()
	for y in SIZE:
		var row:Array=[]
		for x in SIZE:
			var opts:Array[int]=[]
			for t in TYPES:
				if x>=2 and row[x-1]==t and row[x-2]==t:continue
				if y>=2 and board[y-1][x]==t and board[y-2][x]==t:continue
				opts.append(t)
			row.append(opts[rng.randi_range(0,opts.size()-1)])
		board.append(row)
func _clear()->void:
	for n in root.get_children():n.queue_free()
	for n in fx.get_children():n.queue_free()
	gems.clear()
func _pos(p:Vector2i)->Vector2:return ORIGIN+Vector2(p.x*CELL+CELL/2,p.y*CELL+CELL/2)
func _create(intro:=false)->void:
	for y in SIZE:
		for x in SIZE:
			var p:=Vector2i(x,y);var g:=Gem.new();g.setup(board[y][x],COLORS[board[y][x]],SYMBOLS[board[y][x]]);g.position=_pos(p);g.scale=Vector2.ZERO if intro else Vector2.ONE;root.add_child(g);gems[p]=g
			if intro:
				var tw:=create_tween();tw.tween_interval((x+y)*.012);tw.tween_property(g,"scale",Vector2.ONE,.20).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _input(e:InputEvent)->void:
	if busy or not e is InputEventMouseButton:return
	var m:=e as InputEventMouseButton
	if not m.pressed or m.button_index!=MOUSE_BUTTON_LEFT:return
	var q:=m.position-ORIGIN;var p:=Vector2i(floor(q.x/CELL),floor(q.y/CELL))
	if p.x>=0 and p.y>=0 and p.x<SIZE and p.y<SIZE:_click(p)
func _click(p:Vector2i)->void:
	if selected.x<0:selected=p;gems[p].select(true);status.text="Теперь выберите соседнюю фишку";_play("select");return
	if p==selected:gems[p].select(false);selected=Vector2i(-1,-1);return
	if abs(p.x-selected.x)+abs(p.y-selected.y)!=1:status.text="Можно менять только соседние фишки";_play("error");return
	var a:=selected;gems[a].select(false);selected=Vector2i(-1,-1);_resolve(a,p)

func _resolve(a:Vector2i,b:Vector2i)->void:
	busy=true;_swap_data(a,b);_play("swap");await _swap_anim(a,b);var m:=_matches()
	if m.is_empty():
		_swap_data(a,b);await _swap_anim(a,b);status.text="Нет комбинации — обмен отменён";_play("error");busy=false;return
	combo=0
	while not m.is_empty():
		combo+=1;var gained:=m.size()*10*combo;score+=gained;_labels();_play("combo" if combo>1 else "match");_popup(_pos(m[0]),gained);await _destroy(m)
		for p in m:board[p.y][p.x]=-1
		await _fall()
		m=_matches()
	_update_best();_labels();status.text=("🔥 КАСКАД x%d!"%combo) if combo>1 else "✨ Отлично!";busy=false
func _swap_data(a:Vector2i,b:Vector2i)->void:
	var t=board[a.y][a.x];board[a.y][a.x]=board[b.y][b.x];board[b.y][b.x]=t
	var g=gems[a];gems[a]=gems[b];gems[b]=g
func _swap_anim(a:Vector2i,b:Vector2i)->void:
	var t:=create_tween().set_parallel(true);t.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT);t.tween_property(gems[a],"position",_pos(a),.18);t.tween_property(gems[b],"position",_pos(b),.18);await t.finished
func _destroy(m:Array[Vector2i])->void:
	for p in m:
		_spawn_fx(_pos(p),COLORS[board[p.y][p.x]])
		var g:Gem=gems[p];var t:=create_tween().set_parallel(true);t.tween_property(g,"scale",Vector2.ZERO,.20).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN);t.tween_property(g,"rotation",rng.randf_range(-.5,.5),.20);t.tween_property(g,"modulate:a",0,.16)
	await get_tree().create_timer(.21).timeout

func _fall()->void:
	for x in SIZE:
		var w:=SIZE-1
		for y in range(SIZE-1,-1,-1):
			if board[y][x]>=0:board[w][x]=board[y][x];w-=1
		while w>=0:board[w][x]=rng.randi_range(0,TYPES-1);w-=1
	for n in root.get_children():n.queue_free()
	gems.clear()
	for y in SIZE:
		for x in SIZE:
			var p:=Vector2i(x,y);var g:=Gem.new();g.setup(board[y][x],COLORS[board[y][x]],SYMBOLS[board[y][x]]);g.position=_pos(p)-Vector2(0,CELL*rng.randi_range(1,3));g.scale=Vector2.ONE*.82;root.add_child(g);gems[p]=g
	for p in gems:
		var t:=create_tween();t.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT);t.tween_property(gems[p],"position",_pos(p),.30+p.y*.015);t.parallel().tween_property(gems[p],"scale",Vector2.ONE,.20)
	await get_tree().create_timer(.43).timeout

func _spawn_fx(p:Vector2,c:Color)->void:
	for i in 14:
		var d:=Polygon2D.new();d.polygon=PackedVector2Array([Vector2(-3,-3),Vector2(3,-3),Vector2(3,3),Vector2(-3,3)]);d.color=c.lightened(.15);d.position=p;fx.add_child(d);var a:=TAU*i/14.0;var tw:=create_tween().set_parallel(true);tw.tween_property(d,"position",p+Vector2(cos(a),sin(a))*rng.randf_range(30,58),.36);tw.tween_property(d,"scale",Vector2.ZERO,.36);tw.tween_property(d,"modulate:a",0,.36);tw.chain().tween_callback(d.queue_free)
	var flash:=Polygon2D.new();flash.polygon=PackedVector2Array([Vector2(-20,-20),Vector2(20,-20),Vector2(20,20),Vector2(-20,20)]);flash.color=Color(1,1,1,.55);flash.position=p;fx.add_child(flash);var ft:=create_tween();ft.tween_property(flash,"scale",Vector2(1.7,1.7),.07);ft.parallel().tween_property(flash,"modulate:a",0,.14);ft.tween_callback(flash.queue_free)
func _popup(p:Vector2,n:int)->void:
	var l:=Label.new();l.text="+%d"%n;l.position=p-Vector2(18,15);l.add_theme_font_size_override("font_size",20);fx.add_child(l);var t:=create_tween();t.tween_property(l,"position",l.position-Vector2(0,40),.45);t.parallel().tween_property(l,"modulate:a",0,.45);t.tween_callback(l.queue_free)

func _matches()->Array[Vector2i]:
	var f:Dictionary={}
	for y in SIZE:
		var s:=0
		while s<SIZE:
			var t=board[y][s];var e:=s+1
			while e<SIZE and board[y][e]==t:e+=1
			if t>=0 and e-s>=3:for x in range(s,e):f[Vector2i(x,y)]=true
			s=e
	for x in SIZE:
		var s:=0
		while s<SIZE:
			var t=board[s][x];var e:=s+1
			while e<SIZE and board[e][x]==t:e+=1
			if t>=0 and e-s>=3:for y in range(s,e):f[Vector2i(x,y)]=true
			s=e
	var r:Array[Vector2i]=[];for p in f.keys():r.append(p);return r
func _update_best()->void:
	if score>best:
		best=score;var f:=FileAccess.open("user://best_score.txt",FileAccess.WRITE);if f:f.store_string(str(best))
func _labels()->void:
	score_label.text="ОЧКИ\n%d"%score;best_label.text="РЕКОРД\n%d"%best;combo_label.text="КОМБО\n%s"%("x%d"%combo if combo>0 else "—")
