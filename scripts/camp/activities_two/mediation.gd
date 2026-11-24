extends "res://scripts/camp/activities_two/session.gd"

const ITEMS := ["Tienda","Mesa","Lona","Piquetas","Varillas","Manta","Cantimplora","Mochila","Megáfono","Linterna"]
const ICONS := [
	preload("res://assets/art_v2/tent.png"), preload("res://assets/art_v2/table.png"),
	preload("res://assets/art_v2/tarp.png"), preload("res://assets/art_v2/pegs.png"),
	preload("res://assets/art_v2/poles.png"), preload("res://assets/art_v2/blanket.png"),
	preload("res://assets/art_v2/canteen.png"), preload("res://assets/art_v2/backpack.png"),
	preload("res://assets/art_v2/megaphone.png"), preload("res://assets/art_v2/flashlight.png")
]
const FACE := preload("res://assets/art_v2/card_face.png")
const BACK := preload("res://assets/art_v2/card_back.png")
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
	help = "Voltea dos cartas de ensayo y encuentra una pareja. Luego comienza el tablero puntuado."
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
	var columns := 2 if deck.size()==4 else (5 if deck.size()>12 else 4)
	var rows := ceili(float(deck.size())/columns)
	var tile := AREA/Vector2(columns,rows)
	var card_size := Vector2(minf(tile.x-8,(tile.y-8)*0.76),tile.y-8)
	return Rect2(GRID+Vector2(index%columns,floori(float(index)/columns))*tile+(tile-card_size)/2,card_size)

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
		game.draw_rect(Rect2(display.position+Vector2(2,4),display.size),Color(0,0,0,0.40))
		game.draw_texture_rect(FACE if facing else BACK, display, false)
		if matched.has(i): game.draw_rect(display.grow(-2), GOLD, false, 2)
		if flip>0.63:
			if facing:
				draw_item(game,deck[i],display.get_center()-Vector2(0,7),display.size)
				game.text(display.position+Vector2(0,display.size.y-8),ITEMS[deck[i]],11,INK,true,display.size.x,HORIZONTAL_ALIGNMENT_CENTER)
		hit(game,r,"card:%d"%i)

func draw_item(game: Control, id: int, p: Vector2, card_size: Vector2) -> void:
	var tex: Texture2D = ICONS[id]
	var bounds := Vector2(card_size.x-12,card_size.y-23)
	var factor := minf(bounds.x/float(tex.get_width()),bounds.y/float(tex.get_height()))
	item(game,tex,p,Vector2(tex.get_size())*factor)
