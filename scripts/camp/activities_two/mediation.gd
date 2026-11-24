extends "res://scripts/camp/activities_two/session.gd"

const ITEMS := ["Tienda","Mesa","Lona","Piquetas","Varillas","Manta","Cantimplora","Mochila","Megáfono","Linterna"]
const GRID := Vector2(20,88)
const AREA := Vector2(400,311)
var deck: Array[int] = []
var matched: Dictionary = {}
var opened: Array[int] = []
var turnover: Dictionary = {}
var flip_back := 0.0
var stage := 0
var next_board := 0.0
var attempts := 0
var errors := 0
var pairs := 0

func initialize(seed_value: int, plan: String) -> void:
	super.initialize(seed_value,plan)
	title = "Convivencia · parejas de la plaza"
	help = "Encuentra una pareja de prueba y después completa los tableros con iconos de la acampada."
	deal(2)

func deal(count: int) -> void:
	deck.clear()
	matched.clear()
	opened.clear()
	turnover.clear()
	flip_back = 0
	for i in range(count):
		var item := (i+stage*2)%ITEMS.size()
		deck.append_array([item,item])
	for i in range(deck.size()-1,0,-1):
		var j := rng.randi_range(0,i)
		var value := deck[j]
		deck[j] = deck[i]
		deck[i] = value

func tick(delta: float) -> void:
	super.tick(delta)
	if report: return
	if flip_back>0 and clock>=flip_back:
		for index in opened: turnover[index] = {"at":clock,"face":false}
		opened.clear()
		flip_back = 0
	if next_board>0 and clock>=next_board:
		next_board = 0
		if tutorial:
			trained()
			deal(4)
			feedback("Encuentra todas las parejas. Cada tablero añade cartas.")
		else:
			stage += 1
			if stage==3:
				finish(clampi(100-errors*3-maxi(0,roundi(active_time)-50),0,100), "%d parejas · %d intentos · %d fallos · %.1f s."%[pairs,attempts,errors,active_time])
			else: deal([4,6,10][stage])

func perform(value: String) -> void:
	if not value.begins_with("card:") or next_board>0 or opened.size()==2: return
	var index := int(value.get_slice(":",1))
	if index not in range(deck.size()) or matched.has(index) or index in opened: return
	opened.append(index)
	turnover[index] = {"at":clock,"face":true}
	if opened.size()!=2: return
	if not tutorial: attempts += 1
	if deck[opened[0]]==deck[opened[1]]:
		for card in opened: matched[card] = true
		opened.clear()
		if not tutorial: pairs += 1
		feedback("Pareja encontrada", card_rect(index).get_center())
		if matched.size()==deck.size() or tutorial: next_board = clock+0.65
	else:
		if not tutorial: errors += 1
		flip_back = clock+0.82
		feedback("Prueba con otra pareja.", card_rect(index).get_center(),true)

func card_rect(index: int) -> Rect2:
	var columns := 5 if deck.size()>12 else 4
	var rows := ceili(float(deck.size())/columns)
	var tile := AREA/Vector2(columns,rows)
	return Rect2(GRID+Vector2(index%columns,index/columns)*tile+Vector2(3,4),tile-Vector2(6,8))

func status() -> String:
	return "Tablero %d/3  •  %d parejas  •  %d intentos  •  %.1fs"%[mini(stage+1,3),pairs,attempts,active_time]

func scene(game: Control) -> void:
	backdrop(game,Vector2(795,429),Color(0.15,0.18,0.12,0.25))
	for i in range(deck.size()):
		var r := card_rect(i)
		var facing := matched.has(i) or i in opened
		var flip := 1.0
		if turnover.has(i):
			var progress := clampf((clock-turnover[i].at)/0.22,0,1)
			flip = maxf(0.05,absf(1-2*progress))
			if progress<0.5: facing = not turnover[i].face
		var display := Rect2(r.get_center()-Vector2(r.size.x*flip,r.size.y)/2,Vector2(r.size.x*flip,r.size.y))
		var front := Color("efe2bc")
		var back := Color("254640")
		game.draw_rect(display,front if facing else back)
		game.draw_rect(display,GOLD if matched.has(i) else CREAM,false,2)
		if flip>0.63:
			if facing:
				game.draw_rect(display.grow(-8),Color("f7edd0"))
				draw_item(game,deck[i],display.get_center()-Vector2(0,10))
				game.text(display.position+Vector2(0,display.size.y-8),ITEMS[deck[i]],11,INK,true,display.size.x,HORIZONTAL_ALIGNMENT_CENTER)
			else:
				var center := display.get_center()
				game.draw_rect(display.grow(-6),Color("2f5a52"),false,1)
				game.draw_circle(center,18,GOLD)
				game.draw_circle(center,12,back)
				game.draw_line(center+Vector2(-9,0),center+Vector2(9,0),GOLD,2)
				game.draw_line(center+Vector2(0,-9),center+Vector2(0,9),GOLD,2)
		hit(game,r,"card:%d"%i)

func draw_item(game: Control, id: int, p: Vector2) -> void:
	game.draw_circle(p,22,Color("d7c793"))
	match id:
		0:
			game.draw_colored_polygon(PackedVector2Array([p+Vector2(0,-16),p+Vector2(14,10),p+Vector2(-14,10)]),Color("5b7f65"))
			game.draw_rect(Rect2(p+Vector2(-12,10),Vector2(24,5)),Color("355440"))
		1:
			game.draw_rect(Rect2(p+Vector2(-16,-10),Vector2(32,8)),Color("a36d45"))
			game.draw_line(p+Vector2(-12,-2),p+Vector2(-15,13),INK,2)
			game.draw_line(p+Vector2(12,-2),p+Vector2(15,13),INK,2)
		2:
			game.draw_rect(Rect2(p+Vector2(-15,-11),Vector2(30,22)),Color("6289a3"))
			game.draw_line(p+Vector2(-13,-11),p+Vector2(0,-18),Color("d8e4ef"),2)
			game.draw_line(p+Vector2(13,-11),p+Vector2(0,-18),Color("d8e4ef"),2)
		3:
			for offset in [-8,0,8]:
				game.draw_line(p+Vector2(offset,-12),p+Vector2(offset-3,11),Color("d0a76f"),3)
			game.draw_line(p+Vector2(-12,11),p+Vector2(12,11),Color("d0a76f"),3)
		4:
			for offset in [-10,-3,4,11]:
				game.draw_line(p+Vector2(offset,-12),p+Vector2(offset,12),Color("8f7f63"),3)
			game.draw_line(p+Vector2(-12,12),p+Vector2(12,12),INK,2)
		5:
			game.draw_rect(Rect2(p+Vector2(-16,-12),Vector2(32,24)),Color("b65d59"))
			for i in range(3): game.draw_line(p+Vector2(-13,-6+i*7),p+Vector2(13,-6+i*7),Color("f0dcb1"),2)
		6:
			game.draw_rect(Rect2(p+Vector2(-9,-12),Vector2(18,26)),Color("477b9b"))
			game.draw_rect(Rect2(p+Vector2(-5,-17),Vector2(10,6)),INK)
			game.draw_rect(Rect2(p+Vector2(-7,0),Vector2(14,8)),Color("d1edf8"))
		7:
			game.draw_rect(Rect2(p+Vector2(-15,-11),Vector2(30,23)),Color("a36d45"))
			game.draw_rect(Rect2(p+Vector2(-9,-17),Vector2(18,8)),INK)
			game.draw_rect(Rect2(p+Vector2(-11,-1),Vector2(22,9)),Color("f3d383"))
		8:
			game.draw_colored_polygon(PackedVector2Array([p+Vector2(-15,-6),p+Vector2(13,-15),p+Vector2(13,9),p+Vector2(-15,2)]),Color("7865a0"))
			game.draw_rect(Rect2(p+Vector2(-8,-2),Vector2(8,10)),INK)
		9:
			game.draw_rect(Rect2(p+Vector2(-8,-10),Vector2(16,24)),Color("514d64"))
			game.draw_rect(Rect2(p+Vector2(-11,13),Vector2(22,7)),GOLD)
