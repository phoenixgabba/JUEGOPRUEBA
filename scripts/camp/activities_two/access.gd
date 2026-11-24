extends "res://scripts/camp/activities_two/session.gd"

const GRID := Vector2i(8,6)
const TILE := Vector2(49,48)
const START := Vector2(24,103)
const ENTRIES := [Vector2i(0,1),Vector2i(0,4)]
const GOALS := [Vector2i(7,1),Vector2i(7,4)]
const STEPS := [Vector2i.UP,Vector2i.DOWN,Vector2i.LEFT,Vector2i.RIGHT]
var furniture: Dictionary = {}
var lanes: Dictionary = {}
var benches: Array[Vector2i] = []
var guests: Array[Dictionary] = []
var routes: Dictionary = {}
var selected := Vector2i(-1,-1)
var moved_from := Vector2i(-1,-1)
var tool := "move"
var lane_supply := 12
var served := 0
var left := 0
var accessible := 0
var waiting_total := 0.0
var next_arrival := 0.0
var next_step := 0.0
var entry := 0
var destination := 0
var bench_selected := Vector2i(-1,-1)

func initialize(seed_value: int, plan: String) -> void:
	super.initialize(seed_value,plan)
	title = "Accesibilidad"
	help = "Desplaza una tienda, mesa o caja a una casilla libre. También puedes tocar origen y destino."
	lane_supply += 3 if plan == "Acceso" else 0
	furniture = {Vector2i(3,0):0,Vector2i(3,2):1,Vector2i(3,4):0,Vector2i(3,5):2,Vector2i(5,3):1,
		Vector2i(5+rng.randi_range(-1,1),2):2,Vector2i(1+rng.randi_range(0,1),3):1}
	benches = [Vector2i(7,0),Vector2i(7,3)]

func inside(cell: Vector2i) -> bool:
	return Rect2i(Vector2i.ZERO,GRID).has_point(cell)

func width_at(cell: Vector2i) -> bool:
	if lanes.has(cell): return true
	var adjacent := 0
	for step in STEPS:
		var neighbor: Vector2i = cell + step
		if inside(neighbor) and not furniture.has(neighbor): adjacent += 1
	return adjacent >= 3 or cell in ENTRIES or cell in GOALS

func route(origin: Vector2i, goal: Vector2i, mobility: int) -> Array:
	var cache_key := [origin,goal,mobility]
	if routes.has(cache_key): return routes[cache_key]
	var line := [origin]
	var parent := {origin:origin}
	var cursor := 0
	while cursor < line.size():
		var current: Vector2i = line[cursor]
		if current == goal:
			var path := [goal]
			while path[0] != origin: path.push_front(parent[path[0]])
			routes[cache_key] = path
			return path
		cursor += 1
		for step in STEPS:
			var neighbor: Vector2i = current + step
			if not inside(neighbor) or furniture.has(neighbor) or parent.has(neighbor): continue
			if mobility == 1 and not width_at(neighbor): continue
			parent[neighbor] = current
			line.append(neighbor)
	routes[cache_key] = []
	return []

func center(cell: Vector2i) -> Vector2:
	return START + (Vector2(cell)+Vector2(0.5,0.5))*TILE

func cell_at(point: Vector2) -> Vector2i:
	return Vector2i(((point - START)/TILE).floor())

func begin_drag(point: Vector2) -> bool:
	moved_from = cell_at(point)
	return tool == "move" and furniture.has(moved_from)

func end_drag(point: Vector2) -> void:
	var target := cell_at(point)
	if target == moved_from:
		selected = moved_from
		return
	relocate(moved_from,target)

func relocate(source: Vector2i, target: Vector2i) -> void:
	if not inside(target) or target.x in [0,7] or furniture.has(target) or lanes.has(target): return
	if guests.any(func(guest): return guest.cell == target or guest.next == target):
		feedback("Espera a que quede libre esa casilla.",center(target))
		return
	furniture[target] = furniture[source]
	furniture.erase(source)
	selected = Vector2i(-1,-1)
	routes.clear()
	trained()
	feedback("Mobiliario movido. Las visitas recalculan su ruta.",center(target))

func perform(value: String) -> void:
	var parts := value.split(":")
	if parts[0] == "tool":
		tool = parts[1]
		return
	if parts[0] != "cell": return
	var cell := Vector2i(int(parts[1]),int(parts[2]))
	if tool == "rest":
		if cell in benches:
			bench_selected = cell
		elif bench_selected in benches and inside(cell) and cell.x not in [0,7] and not furniture.has(cell):
			benches[benches.find(bench_selected)] = cell
			bench_selected = Vector2i(-1,-1)
			feedback("Zona de descanso reubicada.",center(cell))
		return
	if tool == "lane":
		if furniture.has(cell) or cell.x in [0,7]: return
		if lanes.has(cell):
			lanes.erase(cell)
			lane_supply += 1
		elif lane_supply > 0:
			lanes[cell] = true
			lane_supply -= 1
		routes.clear()
	elif furniture.has(cell):
		selected = cell
	elif furniture.has(selected):
		relocate(selected,cell)

func advance(_delta: float) -> void:
	if active_time >= next_arrival and active_time < 177.0:
		var stage := mini(floori(active_time/55),3)
		var mobility := (entry+stage)%3
		destination = rng.randi_range(0,1) if stage > 0 else entry%2
		next_arrival = active_time + 8.2-stage*1.25
		guests.append({"cell":ENTRIES[entry%2],"next":ENTRIES[entry%2],"target":GOALS[destination],"mobility":mobility,"born":active_time,"step":active_time,"stamina":5})
		entry += 1
	if active_time >= next_step:
		next_step = active_time + 0.48
		walk()
	score = clampi(served*3+accessible*2-left*4-roundi(waiting_total/7),0,100)
	if active_time >= 190 and (served >= 10 or active_time >= 240):
		finish(score,"%d llegadas · %d con movilidad asistida · %d abandonos. Tiempo acumulado en el recorrido: %ds." % [served,accessible,left,roundi(waiting_total)])
	elif active_time >= 190 and active_time >= next_arrival:
		next_arrival = active_time+6
		guests.append({"cell":ENTRIES[entry%2],"next":ENTRIES[entry%2],"target":GOALS[entry%2],"mobility":1,"born":active_time,"step":active_time,"stamina":5})
		entry += 1

func walk() -> void:
	var capacity := {}
	for guest in guests:
		capacity[guest.cell] = int(capacity.get(guest.cell,0))+1
	for i in range(guests.size()-1,-1,-1):
		var guest := guests[i]
		if guest.next != guest.cell and active_time >= guest.step:
			guest.cell = guest.next
			if guest.mobility == 2:
				var near_bench := benches.any(func(bench): return Vector2i(bench).distance_to(guest.cell) <= 1)
				guest.stamina = 5 if near_bench else maxi(0,int(guest.stamina)-1)
		if guest.cell == guest.target:
			served += 1
			if guest.mobility > 0: accessible += 1
			waiting_total += maxf(0,active_time-guest.born-7)
			bursts.append({"p":center(guest.cell),"time":clock})
			guests.remove_at(i)
			continue
		if active_time - guest.born > 30:
			left += 1
			guests.remove_at(i)
			continue
		if active_time < guest.step: continue
		var path := route(guest.cell,guest.target,guest.mobility)
		if path.size() <= 1: continue
		var next: Vector2i = path[1]
		if capacity.get(next,0) >= (2 if lanes.has(next) else 1): continue
		capacity[next] = int(capacity.get(next,0))+1
		guest.next = next
		guest.step = active_time + (0.55 if guest.mobility == 0 else 0.9)
		if guest.mobility == 2 and guest.stamina == 0: guest.step += 0.65

func status() -> String:
	return "%ds    •    %d llegadas    •    %d en tránsito" % [ceili(maxf(0,190-active_time)),served,guests.size()]

func scene(game: Control) -> void:
	backdrop(game,Vector2(810,395),Color(0.25,0.20,0.1,0.35))
	for y in range(GRID.y):
		for x in range(GRID.x):
			var cell := Vector2i(x,y)
			var r := Rect2(START+Vector2(cell)*TILE,TILE-Vector2.ONE*2)
			game.draw_rect(r,Color("b0bc86") if lanes.has(cell) else Color("c6b388") if (x+y)%2 else Color("d9c79d"))
			if cell in ENTRIES or cell in GOALS:
				game.text(r.position+Vector2(0,29),"→" if cell in ENTRIES else "⚑",21,INK,true,r.size.x,HORIZONTAL_ALIGNMENT_CENTER)
			if cell in benches: game.draw_rect(Rect2(r.position+Vector2(8,15),Vector2(31,13)),Color("88634b"))
			if cell == selected or cell == bench_selected: game.draw_rect(r,GOLD,false,3)
			if furniture.has(cell):
				var kind: int = furniture[cell]
				if kind == 2: game.draw_rect(r.grow(-11),Color("976349"))
				else: item(game,game.World.TENT if kind == 0 else game.World.TABLE,center(cell),Vector2(48,43))
			hit(game,r,"cell:%d:%d"%[x,y])
	for guest in guests:
		var duration := 0.55 if guest.mobility == 0 else 0.9
		var p := center(guest.cell).lerp(center(guest.next),clampf(1-(guest.step-active_time)/duration,0,1))
		if guest.mobility != 0: game.draw_circle(p+Vector2(0,9),8,Color("3e6f78") if guest.mobility == 1 else Color("937331"))
		actor(game,p+Vector2(0,10),guest.mobility,0.65,guest.cell!=guest.next)
	if drag_id != -2: game.draw_rect(Rect2(drag_cursor-Vector2(12,12),Vector2(24,24)),GOLD,false,3)

func controls(game: Control) -> void:
	button(game,Rect2(20,485,196,58),"Mover mobiliario","tool:move",tool=="move")
	button(game,Rect2(223,485,197,58),"Carril ancho · %d"%lane_supply,"tool:lane",tool=="lane")
	button(game,Rect2(20,551,400,51),"Trasladar bancos de descanso","tool:rest",tool=="rest")
	label(game,Vector2(20,625),"Carril ancho: dos visitas a la vez. Los bancos recuperan la resistencia de quienes van despacio.",398)
	label(game,Vector2(20,680),"Llegadas asistidas %d  ·  Abandonos %d  ·  Puntos %d"%[accessible,left,score],398,GREEN)
