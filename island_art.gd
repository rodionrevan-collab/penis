extends Node2D

const MAP_BACKGROUND = preload("res://art/backgrounds/island_map_background.svg")

# Временный процедурный слой теперь используется как интерактивный overlay
# поверх основной 2D-картины острова.

class IslandBackdrop extends Node2D:
	var unlocked: Array[bool] = []
	func setup(states:Array[bool]) -> void:
		unlocked = states
		queue_redraw()
	func _draw() -> void:
		draw_texture_rect(MAP_BACKGROUND,Rect2(0,0,770,655),false)
		# лёгкий водный overlay
		for y in range(15,650,34):
			for x in range((int(y/34)%2)*22,770,44):
				draw_arc(Vector2(x,y),9,PI,TAU,12,Color(1,1,1,.09),2.0)
		var zone_polys := [
			PackedVector2Array([Vector2(45,95),Vector2(145,55),Vector2(235,95),Vector2(215,220),Vector2(85,250)]),
			PackedVector2Array([Vector2(205,70),Vector2(330,45),Vector2(400,105),Vector2(345,240),Vector2(225,205)]),
			PackedVector2Array([Vector2(345,105),Vector2(480,70),Vector2(585,125),Vector2(560,245),Vector2(400,250)]),
			PackedVector2Array([Vector2(490,220),Vector2(635,185),Vector2(735,250),Vector2(690,390),Vector2(535,380)]),
			PackedVector2Array([Vector2(500,350),Vector2(655,330),Vector2(715,440),Vector2(635,575),Vector2(490,525)]),
			PackedVector2Array([Vector2(180,380),Vector2(330,350),Vector2(490,420),Vector2(470,570),Vector2(270,600),Vector2(140,500)])
		]
		var names := ["Пляж","Джунгли","Пристань","Пиратская бухта","Тайная пещера","Старая деревня"]
		for i in range(zone_polys.size()):
			var open := i < unlocked.size() and unlocked[i]
			var fill := Color("#5b995a") if open else Color("#32474b")
			var alpha:=0.20 if open else 0.12
			draw_colored_polygon(zone_polys[i],Color(fill.r,fill.g,fill.b,alpha))
			draw_polyline(zone_polys[i],Color("#c5e88b") if open else Color("#849397"),2.5)
			var center := _centroid(zone_polys[i])
			draw_string(ThemeDB.fallback_font,center-Vector2(45,-60),names[i],HORIZONTAL_ALIGNMENT_CENTER,90,12,Color("#eaf6dd") if open else Color("#9eafb2"))
		# дорога
		var road := PackedVector2Array([Vector2(118,270),Vector2(255,265),Vector2(395,300),Vector2(565,255),Vector2(620,405),Vector2(400,495)])
		draw_polyline(road,Color("#7a5a37"),13.0)
		draw_polyline(road,Color("#d1ad6b"),7.0)
		# пальмы/деревья
		for p in [Vector2(70,125),Vector2(110,165),Vector2(285,125),Vector2(365,145),Vector2(545,145),Vector2(655,240),Vector2(565,455),Vector2(620,500),Vector2(220,470),Vector2(300,535)]:
			_draw_palm(p,Color("#2e6a39") if unlocked.size()==0 else Color("#387a43"))
	func _draw_palm(p:Vector2,leaf:Color) -> void:
		draw_line(p,p+Vector2(-3,-30),Color("#7b5c38"),5)
		var top:=p+Vector2(-3,-34)
		for a in [-0.9,-0.45,0,0.45,0.9]:
			draw_line(top,top+Vector2(cos(a)*22,-abs(sin(a))*16-6),leaf,5)
	func _centroid(poly:PackedVector2Array)->Vector2:
		var s:=Vector2.ZERO
		for p in poly: s+=p
		return s/poly.size()

class IslandObjectArt extends Node2D:
	var object_id := ""
	var repaired := false
	var glow := 0.0
	var rng:=RandomNumberGenerator.new()
	func setup(id:String,done:bool)->void:
		object_id=id
		repaired=done
		queue_redraw()
	func play_repair()->void:
		repaired=true
		glow=1.0
		queue_redraw()
		var t:=create_tween()
		t.tween_property(self,"scale",Vector2.ONE*1.15,.12)
		t.tween_property(self,"scale",Vector2.ONE,.28)
		t.parallel().tween_property(self,"glow",0.0,.42)
		for i in range(12):
			var piece:=Polygon2D.new()
			piece.polygon=PackedVector2Array([Vector2(-3,-3),Vector2(3,-3),Vector2(3,3),Vector2(-3,3)])
			piece.color=Color("#d8b15f") if i%2==0 else Color("#70dca3")
			piece.position=Vector2.ZERO
			add_child(piece)
			var angle:=TAU*float(i)/12.0
			var target:=Vector2(cos(angle),sin(angle))*rng.randf_range(28.0,52.0)
			var pt:=create_tween().set_parallel(true)
			pt.tween_property(piece,"position",target,.42)
			pt.tween_property(piece,"rotation",rng.randf_range(-2.5,2.5),.42)
			pt.tween_property(piece,"scale",Vector2.ZERO,.42)
			pt.tween_property(piece,"modulate:a",0.0,.42)
			pt.chain().tween_callback(piece.queue_free)
	func _process(_delta:float)->void:
		if glow>0.0: queue_redraw()
	func _draw()->void:
		if not repaired:
			_draw_ruined()
		else:
			match object_id:
				"bridge": _draw_bridge()
				"hut": _draw_hut()
				"jungle_path": _draw_path()
				"dock": _draw_dock()
				"pirate_cove": _draw_cove()
				"lighthouse": _draw_lighthouse()
				"secret_cave": _draw_cave()
				"old_village": _draw_village()
		if glow>0: draw_circle(Vector2.ZERO,34+glow*10,Color(1,.85,.35,.18*glow))
	func _draw_ruined()->void:
		draw_circle(Vector2.ZERO,25,Color(0,0,0,.22))
		for i in range(4):
			draw_line(Vector2(-20+i*11,12),Vector2(-15+i*10,-15),Color("#65584a"),5)
		draw_arc(Vector2.ZERO,25,-2.7,-.3,18,Color("#c99354"),3)
	func _draw_bridge()->void:
		for x in range(-28,29,11): draw_rect(Rect2(x-4,-14,8,28),Color("#98673b"))
		draw_line(Vector2(-30,-13),Vector2(30,-13),Color("#5d3f28"),4)
		draw_line(Vector2(-30,13),Vector2(30,13),Color("#5d3f28"),4)
	func _draw_hut()->void:
		draw_rect(Rect2(-25,-5,50,31),Color("#a9784c")); draw_colored_polygon(PackedVector2Array([Vector2(-32,-5),Vector2(0,-28),Vector2(32,-5)]),Color("#7d4d35")); draw_rect(Rect2(-6,10,12,16),Color("#3f2d22")); draw_rect(Rect2(10,2,10,8),Color("#96c9c2"))
	func _draw_path()->void:
		draw_circle(Vector2.ZERO,24,Color("#6b923d")); draw_circle(Vector2(-11,3),7,Color("#7da94a")); draw_circle(Vector2(11,1),7,Color("#7da94a")); draw_line(Vector2(-14,-18),Vector2(-8,-30),Color("#725535"),4)
	func _draw_dock()->void:
		for x in range(-26,30,12): draw_rect(Rect2(x,-15,8,35),Color("#9a693f")); draw_line(Vector2(-30,-15),Vector2(30,-15),Color("#62442d"),5); draw_line(Vector2(23,-18),Vector2(34,-35),Color("#d3c29c"),4); draw_line(Vector2(34,-35),Vector2(24,-35),Color("#d3c29c"),3)
	func _draw_cove()->void:
		draw_arc(Vector2(0,8),26,PI,TAU,20,Color("#2e5664"),12); draw_colored_polygon(PackedVector2Array([Vector2(-12,-6),Vector2(5,-20),Vector2(22,-7)]),Color("#6d4734")); draw_line(Vector2(5,-20),Vector2(5,10),Color("#4d3426"),4)
	func _draw_lighthouse()->void:
		draw_colored_polygon(PackedVector2Array([Vector2(-15,25),Vector2(15,25),Vector2(9,-24),Vector2(-9,-24)]),Color("#cbd8d2")); draw_rect(Rect2(-12,-31,24,9),Color("#b24e3e")); draw_circle(Vector2(0,-34),7,Color("#ffe37b")); draw_circle(Vector2(0,-34),15,Color(1,.87,.4,.18))
	func _draw_cave()->void:
		draw_colored_polygon(PackedVector2Array([Vector2(-28,24),Vector2(-20,-7),Vector2(-6,-27),Vector2(16,-17),Vector2(29,7),Vector2(22,25)]),Color("#66656a")); draw_colored_polygon(PackedVector2Array([Vector2(-12,24),Vector2(-9,4),Vector2(2,-9),Vector2(14,3),Vector2(10,24)]),Color("#172029")); draw_circle(Vector2(16,-5),5,Color("#7de5a9"))
	func _draw_village()->void:
		_draw_hut(); draw_rect(Rect2(-38,4,12,18),Color("#b8d092")); draw_colored_polygon(PackedVector2Array([Vector2(-43,4),Vector2(-32,-8),Vector2(-21,4)]),Color("#6d5136")); draw_circle(Vector2(25,0),12,Color("#74a458")); draw_line(Vector2(25,12),Vector2(25,28),Color("#6a4d33"),4)

class IslandNPCArt extends Node2D:
	var tint:=Color("#6db8d7")
	var role := ""
	func setup(npc_role:String)->void:
		role=npc_role
		match role:
			"Смотрительница пляжа": tint=Color("#f0b2a9")
			"Рыбак": tint=Color("#8fc1dd")
			"Хранитель маяка": tint=Color("#d5d0a1")
			_: tint=Color("#c79ee0")
		queue_redraw()
	func _draw()->void:
		draw_circle(Vector2(0,11),13,Color(0,0,0,.2)); draw_circle(Vector2(0,-10),10,Color("#f0c8a8")); draw_circle(Vector2(0,-12),12,Color("#3a2a25")); draw_rect(Rect2(-11,0,22,29),tint); draw_rect(Rect2(-9,29,7,12),Color("#3c4654")); draw_rect(Rect2(2,29,7,12),Color("#3c4654"))
		if role=="Рыбак": draw_line(Vector2(13,4),Vector2(25,-15),Color("#7b6248"),3)
		elif role=="Хранитель маяка": draw_circle(Vector2(0,18),5,Color("#ffe27a"))

class IslandChestArt extends Node2D:
	var claimed:=false
	func setup(done:bool)->void:
		claimed=done
		queue_redraw()
	func _draw()->void:
		var body:=Color("#586459") if claimed else Color("#b37a38")
		draw_rect(Rect2(-24,-15,48,32),body)
		draw_rect(Rect2(-24,-22,48,12),body.lightened(.15))
		draw_line(Vector2(0,-22),Vector2(0,17),Color("#e1bf62") if not claimed else Color("#879f8e"),4)
		draw_circle(Vector2(0,-1),5,Color("#e8cb76") if not claimed else Color("#93a69a"))


func create_backdrop(states:Array[bool])->Node2D:
	var n:=IslandBackdrop.new()
	n.setup(states)
	return n

func create_object(id:String,done:bool)->Node2D:
	var n:=IslandObjectArt.new()
	n.setup(id,done)
	return n

func create_npc(npc_role:String)->Node2D:
	var n:=IslandNPCArt.new()
	n.setup(npc_role)
	return n

func create_chest(done:bool)->Node2D:
	var n:=IslandChestArt.new()
	n.setup(done)
	return n


class IslandInteractiveArt extends Node2D:
	var object_id := ""
	var state := 0 # 0 locked, 1 available, 2 completed
	var pulse := 0.0
	func setup(id:String,visual_state:int)->void:
		object_id=id
		state=visual_state
		if state==1:
			pulse=1.0
		queue_redraw()
	func _process(delta:float)->void:
		if state==1:
			pulse=maxf(0.0,pulse-delta)
			queue_redraw()
	func _draw()->void:
		var base:=Color("#4c5963")
		var accent:=Color("#53606a")
		if state==1:
			base=Color("#287da0")
			accent=Color("#7de2ff")
		elif state==2:
			base=Color("#2f6658")
			accent=Color("#75d6aa")
		draw_circle(Vector2(2,4),24,Color(0,0,0,.24))
		draw_circle(Vector2.ZERO,22,base)
		draw_circle(Vector2.ZERO,14,Color(accent.r,accent.g,accent.b,.18))
		match object_id:
			"beach_watch_lantern":
				draw_rect(Rect2(-7,-13,14,24),Color("#dbbd70") if state!=0 else Color("#65717a"))
				draw_circle(Vector2(0,-17),9,accent)
				if state==2: draw_circle(Vector2(0,-17),13,Color(1,.83,.38,.18))
			"pirate_chart_table":
				draw_rect(Rect2(-24,4,48,8),Color("#8a5d36"))
				draw_rect(Rect2(-18,-13,36,17),Color("#dbc58f") if state!=0 else Color("#667079"))
				draw_line(Vector2(-13,-6),Vector2(12,-6),accent,2)
				draw_line(Vector2(-8,0),Vector2(9,0),accent,2)
			"cave_ancient_lock":
				draw_rect(Rect2(-16,-16,32,32),Color("#67717c") if state!=0 else Color("#49545d"))
				draw_circle(Vector2.ZERO,8,Color("#1c2630"))
				draw_arc(Vector2.ZERO,10,-PI/2,PI/2,10,accent,3)
			"village_trade_scale":
				draw_line(Vector2(0,-18),Vector2(0,15),accent,4)
				draw_line(Vector2(-17,-12),Vector2(17,-12),accent,4)
				draw_line(Vector2(-17,-12),Vector2(-24,4),accent,3)
				draw_line(Vector2(17,-12),Vector2(24,4),accent,3)
				draw_line(Vector2(-29,5),Vector2(-19,5),base.darkened(.2),4)
				draw_line(Vector2(19,5),Vector2(29,5),base.darkened(.2),4)
		if state==1 and pulse>0:
			draw_circle(Vector2.ZERO,28+pulse*3,Color(0.45,0.85,1.0,.14))

class IslandActivityArt extends Node2D:
	var icon := ""
	var state := 0 # 0 locked, 1 available, 2 completed
	var secret := false
	func setup(activity_icon:String,visual_state:int,is_secret:bool=false)->void:
		icon=activity_icon
		state=visual_state
		secret=is_secret
		queue_redraw()
	func _draw()->void:
		var outer:=Color("#4f4a43")
		var inner:=Color("#7b7062")
		if secret:
			outer=Color("#5d4677")
			inner=Color("#d19aff")
			if state==2:
				outer=Color("#365f5a")
				inner=Color("#8ee0cb")
		elif state==1:
			outer=Color("#8b6435")
			inner=Color("#ffd171")
		elif state==2:
			outer=Color("#3d6658")
			inner=Color("#79d1a7")
		draw_circle(Vector2(2,4),25,Color(0,0,0,.25))
		draw_circle(Vector2.ZERO,23,outer)
		draw_circle(Vector2.ZERO,17,inner)
		if secret:
			draw_dashed_line(Vector2(0,-28),Vector2(28,0),Color("#e7c5ff"),2.0,3.0)
			draw_dashed_line(Vector2(28,0),Vector2(0,28),Color("#e7c5ff"),2.0,3.0)
			draw_dashed_line(Vector2(0,28),Vector2(-28,0),Color("#e7c5ff"),2.0,3.0)
			draw_dashed_line(Vector2(-28,0),Vector2(0,-28),Color("#e7c5ff"),2.0,3.0)
		if state==0:
			draw_line(Vector2(-9,-9),Vector2(9,9),Color("#49545d"),4)
			draw_line(Vector2(9,-9),Vector2(-9,9),Color("#49545d"),4)
		else:
			draw_string(ThemeDB.fallback_font,Vector2(-13,8),icon,HORIZONTAL_ALIGNMENT_CENTER,26,18,Color("#16212b"))
			if state==2:
				draw_arc(Vector2.ZERO,25,-PI*0.8,PI*0.8,18,Color("#8ce0ba") if not secret else Color("#cfa6ff"),3)

func create_interactive(id:String,visual_state:int)->Node2D:
	var n:=IslandInteractiveArt.new()
	n.setup(id,visual_state)
	return n

func create_activity(icon:String,visual_state:int,is_secret:bool=false)->Node2D:
	var n:=IslandActivityArt.new()
	n.setup(icon,visual_state,is_secret)
	return n
