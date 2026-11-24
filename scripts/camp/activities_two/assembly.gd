extends "res://scripts/camp/activities_two/session.gd"

const AXES := ["Acceso", "Cuidados", "Difusión", "Descanso"]
const PALETTE := [Color("75b8cf"),Color("ec9084"),Color("e8bf68"),Color("b49bd4")]
const SIDE := 6
const GOAL := 30
const ORIGIN := Vector2(79,112)
const STEP := 47.0
var board: Array[int] = []
var selected := -1
var cursor := 0
var cleared := 0
var moves := 0
var errors := 0
var chain := 0
var best_chain := 0
var tally := [0,0,0,0]
var pending: Array[int] = []
var resolve_timer := 0.0
var hint := Vector2i(-1,-1)

func initialize(seed_value: int, plan: String) -> void:
	super.initialize(seed_value,plan)
	title = "Asamblea · construye acuerdos"
	help = "Intercambia dos fichas vecinas y junta 3 o más iguales. Completa 30 propuestas."
	make_board()

func make_board() -> void:
	while true:
		board.clear()
		for i in range(SIDE*SIDE):
			var allowed: Array[int] = [0,1,2,3]
			if i%SIDE >= 2 and board[i-1] == board[i-2]: allowed.erase(board[i-1])
			if i >= SIDE*2 and board[i-SIDE] == board[i-SIDE*2]: allowed.erase(board[i-SIDE])
			board.append(allowed[rng.randi_range(0,allowed.size()-1)])
		if find_move().x >= 0: break
	selected = -1
	hint = Vector2i(-1,-1)

func matches() -> Array[int]:
	var found: Array[int] = []
	for i in range(SIDE*SIDE):
		if i%SIDE <= SIDE-3 and board[i] == board[i+1] and board[i] == board[i+2]:
			for k in range(3):
				if not found.has(i+k): found.append(i+k)
		if i < SIDE*(SIDE-2) and board[i] == board[i+SIDE] and board[i] == board[i+2*SIDE]:
			for k in range(3):
				if not found.has(i+k*SIDE): found.append(i+k*SIDE)
	return found

func exchange(a: int,b: int) -> void:
	var temp := board[a]
	board[a] = board[b]
	board[b] = temp

func find_move() -> Vector2i:
	for i in range(SIDE*SIDE):
		for shift in [1,SIDE]:
			if shift == 1 and i%SIDE == SIDE-1: continue
			var j: int = i+shift
			if j >= board.size(): continue
			exchange(i,j)
			var valid := not matches().is_empty()
			exchange(i,j)
			if valid: return Vector2i(i,j)
	return Vector2i(-1,-1)

func adjacent(a: int,b: int) -> bool:
	return (absi(a-b)==1 and floori(float(a)/SIDE)==floori(float(b)/SIDE)) or absi(a-b)==SIDE

func perform(value: String) -> void:
	if not pending.is_empty(): return
	if value == "hint":
		hint = find_move()
		notice = "Intercambia las dos fichas marcadas."
		return
	if not value.begins_with("tile:"): return
	var i := int(value.get_slice(":",1))
	if i < 0 or i >= board.size(): return
	cursor = i
	if selected == i:
		selected = -1
		return
	if selected < 0 or not adjacent(selected,i):
		selected = i
		return
	var previous := selected
	selected = -1
	hint = Vector2i(-1,-1)
	exchange(previous,i)
	pending = matches()
	if pending.is_empty():
		exchange(previous,i)
		errors += 1
		feedback("Necesitas una línea de tres. Prueba otra combinación.",tile_center(i),true)
		return
	if tutorial: trained()
	moves += 1
	chain = 1
	resolve_timer = 0.25
	notice = "¡Acuerdo! Las propuestas se combinan."

func tile_center(i: int) -> Vector2:
	return ORIGIN+Vector2(i%SIDE,floori(float(i)/SIDE))*STEP+Vector2.ONE*STEP/2

func advance(delta: float) -> void:
	if pending.is_empty(): return
	resolve_timer -= delta
	if resolve_timer > 0: return
	for i in pending:
		tally[board[i]] += 1
		cleared += 1
		board[i] = -1
	best_chain = maxi(best_chain,chain)
	feedback("¡%d propuestas! %s" % [pending.size(),"Combo x%d" % chain if chain > 1 else "Acuerdo colectivo"],tile_center(pending[0]))
	for x in range(SIDE):
		var dest := SIDE-1
		for y in range(SIDE-1,-1,-1):
			var i := y*SIDE+x
			if board[i] < 0: continue
			board[dest*SIDE+x] = board[i]
			dest -= 1
		for y in range(dest,-1,-1):
			board[y*SIDE+x] = rng.randi_range(0,3)
	pending = matches()
	if not pending.is_empty():
		chain += 1
		resolve_timer = 0.28
		return
	if cleared >= GOAL:
		var best: int = tally.find(tally.max())
		result.plan = AXES[best]
		finish(clampi(100-errors*3-maxi(0,moves-10)*2,0,100),"Prioridad acordada: %s. %d propuestas · combo máximo x%d. Redes abre la primera ronda de llegadas." % [AXES[best],cleared,best_chain])
		return
	if find_move().x < 0:
		make_board()
		notice = "Nuevas propuestas sobre la mesa."

func key(code: int) -> void:
	super.key(code)
	if report: return
	match code:
		KEY_LEFT: cursor = maxi(0,cursor-1)
		KEY_RIGHT: cursor = mini(SIDE*SIDE-1,cursor+1)
		KEY_UP: cursor = maxi(0,cursor-SIDE)
		KEY_DOWN: cursor = mini(SIDE*SIDE-1,cursor+SIDE)
		KEY_SPACE,KEY_ENTER: action("tile:%d"%cursor)
		KEY_H: action("hint")

func status() -> String:
	return "%d/%d propuestas · %d movimientos · combo x%d" % [mini(cleared,GOAL),GOAL,moves,best_chain]

func draw_symbol(game: Control,p: Vector2,kind: int,r: float) -> void:
	var color: Color = PALETTE[kind]
	match kind:
		0:
			game.draw_line(p+Vector2(-r,0),p+Vector2(r,0),color,4)
			game.draw_line(p+Vector2(r*0.2,-r*0.65),p+Vector2(r,0),color,4)
			game.draw_line(p+Vector2(r,0),p+Vector2(r*0.2,r*0.65),color,4)
		1:
			game.draw_circle(p+Vector2(-r*0.45,-r*0.22),r*0.58,color)
			game.draw_circle(p+Vector2(r*0.45,-r*0.22),r*0.58,color)
			game.draw_colored_polygon(PackedVector2Array([p+Vector2(-r,-r*0.1),p+Vector2(r,-r*0.1),p+Vector2(0,r)]),color)
		2:
			game.draw_colored_polygon(PackedVector2Array([p+Vector2(-r,-r*0.3),p+Vector2(r*0.65,-r),p+Vector2(r*0.65,r),p+Vector2(-r,r*0.3)]),color)
			game.draw_line(p+Vector2(-r*0.6,r*0.2),p+Vector2(-r*0.3,r),color,4)
			game.draw_line(p+Vector2(r*0.85,-r*0.4),p+Vector2(r*1.25,-r*0.7),color,2)
		3:
			game.draw_circle(p,r,color)
			game.draw_circle(p+Vector2(r*0.45,-r*0.35),r*0.85,INK)

func scene(game: Control) -> void:
	game.draw_rect(VIEW,Color("4d5146"))
	game.draw_rect(Rect2(65,99,310,303),Color("896c4d"))
	game.draw_rect(Rect2(72,105,296,292),INK)
	for i in range(board.size()):
		var p := tile_center(i)
		var r := Rect2(p-Vector2.ONE*21,Vector2.ONE*42)
		var color: Color = PALETTE[board[i]]
		game.draw_rect(Rect2(r.position+Vector2(0,3),r.size),Color("101e20"))
		game.draw_rect(r,Color("304448"))
		game.draw_rect(r,Color(color,0.18))
		draw_symbol(game,p,board[i],12)
		if i in pending:
			game.draw_rect(r,Color(color,0.6))
			game.draw_rect(r,CREAM,false,3)
		elif selected == i or hint.x == i or hint.y == i:
			game.draw_rect(r,GOLD,false,3)
		elif cursor == i:
			game.draw_rect(r,Color(CREAM,0.5),false,1)
		hit(game,r,"tile:%d"%i)
	if chain > 1 and not pending.is_empty():
		game.text(Vector2(0,105),"COMBO x%d"%chain,21,GOLD,true,440,HORIZONTAL_ALIGNMENT_CENTER)

func controls(game: Control) -> void:
	game.text(Vector2(20,482),"Acta de propuestas",21,GOLD,true)
	for i in range(4):
		var p := Vector2(40+(i%2)*202,517+floori(float(i)/2)*51)
		draw_symbol(game,p,i,10)
		game.text(p+Vector2(22,5),"%s · %d" % [AXES[i],tally[i]],17,CREAM,true)
	game.text(Vector2(20,613),"Acuerdos: %d / %d" % [mini(cleared,GOAL),GOAL],17,GREEN,true)
	meter(game,Vector2(20,622),400,float(cleared)/GOAL,GREEN)
	button(game,Rect2(20,641,400,48),"Mostrar combinación · H","hint",false,18)
