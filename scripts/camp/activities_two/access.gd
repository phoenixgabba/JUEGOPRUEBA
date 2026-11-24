extends "res://scripts/camp/activities_two/session.gd"

const PAVING := preload("res://assets/visual/paving.png")
const BLOCKED_ART := preload("res://assets/visual/blocked.png")
const CRATE_ART := preload("res://assets/visual/crate.png")

const BOARD := Rect2(20,90,400,310)
const JOY := Vector2(91,552)
const DIRS := [Vector2i(1,0),Vector2i(0,1),Vector2i(-1,0),Vector2i(0,-1)]
var field := Rect2i()
var open_cells := {}
var narrow := {}
var player := Vector2i.ZERO
var guest := Vector2i.ZERO
var destination := Vector2i.ZERO
var from_player := Vector2i.ZERO
var from_guest := Vector2i.ZERO
var player_motion := 0.0
var guest_motion := 0.0
var joystick := Vector2.ZERO
var direction_buffer := Vector2i.ZERO
var stage := 0
var steps := 0
var optimal := 0
var separated := 0
var waiting := false
var guest_delay := 0.0

func initialize(seed_value: int, plan: String) -> void:
	super.initialize(seed_value,plan)
	title = "Accesibilidad · hacia tu tienda"
	help = "Mueve el joystick o usa WASD y las flechas. Guía a la persona hasta la tienda dorada. Las cajas estrechas solo te dejan pasar a ti."
	generate()
	optimal = 0

func generate() -> void:
	var width: int = [9,13,15][stage]
	var height: int = [7,9,11][stage]
	field = Rect2i(0,0,width,height)
	open_cells.clear()
	narrow.clear()
	player = Vector2i(1,1)
	guest = player
	destination = Vector2i(width-2,height-2)
	var stack: Array[Vector2i] = [player]
	open_cells[player] = true
	while not stack.is_empty():
		var here: Vector2i = stack.back()
		var options: Array[Vector2i] = []
		for dir: Vector2i in DIRS:
			var there := here+dir*2
			if field.grow(-1).has_point(there) and not open_cells.has(there): options.append(there)
		if options.is_empty():
			stack.pop_back()
		else:
			var next: Vector2i = options[rng.randi_range(0,options.size()-1)]
			open_cells[(here+next)/2] = true
			open_cells[next] = true
			stack.append(next)
	var crossings: Array[Vector2i] = []
	for y in range(1,height-1):
		for x in range(1,width-1):
			var cell := Vector2i(x,y)
			if open_cells.has(cell): continue
			if (open_cells.has(cell+Vector2i.LEFT) and open_cells.has(cell+Vector2i.RIGHT)) or (open_cells.has(cell+Vector2i.UP) and open_cells.has(cell+Vector2i.DOWN)):
				crossings.append(cell)
	for i in range(mini(crossings.size(),3+stage*2)):
		var cell: Vector2i = crossings.pop_at(rng.randi_range(0,crossings.size()-1))
		if i%3==0: narrow[cell] = true
		else: open_cells[cell] = true
	from_player = player
	from_guest = guest
	player_motion = 0
	guest_motion = 0
	guest_delay = 0
	waiting = false
	optimal += find_route(guest,destination,false).size()-1

func walkable(tile: Vector2i, player_only: bool) -> bool:
	return open_cells.has(tile) or (player_only and narrow.has(tile))

func find_route(origin: Vector2i, target: Vector2i, player_only: bool) -> Array[Vector2i]:
	var route: Array[Vector2i] = []
	if not walkable(target,player_only): return route
	var queue: Array[Vector2i] = [origin]
	var previous := {origin:origin}
	var i := 0
	while i<queue.size():
		var tile := queue[i]
		i += 1
		if tile==target:
			route.append(tile)
			while tile!=origin:
				tile = previous[tile]
				route.push_front(tile)
			return route
		for dir: Vector2i in DIRS:
			var neighbor := tile+dir
			if walkable(neighbor,player_only) and not previous.has(neighbor):
				previous[neighbor] = tile
				queue.append(neighbor)
	return route

func begin_drag(point: Vector2) -> bool:
	if point.distance_to(JOY+controls_offset)>70: return false
	set_joystick(point)
	return true

func move_drag(_delta: Vector2) -> void:
	set_joystick(drag_cursor)

func end_drag(_point: Vector2) -> void:
	joystick = Vector2.ZERO

func set_joystick(point: Vector2) -> void:
	joystick = ((point-JOY-controls_offset)/43).limit_length(1)

func key(code: int) -> void:
	super.key(code)
	var keys := {KEY_LEFT:Vector2i.LEFT,KEY_RIGHT:Vector2i.RIGHT,KEY_UP:Vector2i.UP,KEY_DOWN:Vector2i.DOWN,
		KEY_A:Vector2i.LEFT,KEY_D:Vector2i.RIGHT,KEY_W:Vector2i.UP,KEY_S:Vector2i.DOWN}
	if keys.has(code): direction_buffer = keys[code]

func perform(value: String) -> void:
	if value in ["right","down","left","up"]: direction_buffer = DIRS[["right","down","left","up"].find(value)]

func tick(delta: float) -> void:
	super.tick(delta)
	if report: return
	player_motion = maxf(0,player_motion-delta)
	guest_motion = maxf(0,guest_motion-delta)
	guest_delay = maxf(0,guest_delay-delta)
	var speed := 0.14
	if player_motion==0:
		var input := joystick
		if input.length()<0.23:
			input = Input.get_vector("move_left","move_right","move_up","move_down")
		var direction := direction_buffer
		direction_buffer = Vector2i.ZERO
		if input.length()>=0.23:
			direction = Vector2i(int(signf(input.x)),0) if absf(input.x)>absf(input.y) else Vector2i(0,int(signf(input.y)))
		if direction!=Vector2i.ZERO:
			var next := player+direction
			if walkable(next,true):
				from_player = player
				player = next
				player_motion = speed
				steps += int(not tutorial)
				if tutorial:
					trained()
					optimal = find_route(guest,destination,false).size()-1
					feedback("Ve despacio. Tu acompañante necesita un paso ancho.")
	if guest_motion>0 or guest_delay>0: return
	var route := find_route(guest,player,false)
	var stopped := route.is_empty() or route.size()>9
	if stopped and not waiting:
		separated += 1
		feedback("Tu acompañante espera. Vuelve por un paso ancho.")
	waiting = stopped
	if not waiting and (route.size()>2 or (player==destination and route.size()>1)):
		from_guest = guest
		guest = route[1]
		guest_motion = 0.18
		guest_delay = 0.20
	elif guest==destination and player==destination:
		advance_board()

func advance_board() -> void:
	stage += 1
	if stage==3:
		finish(clampi(100-maxi(0,steps-optimal)-roundi(active_time/5)-separated*4,0,100),
			"Tres acompañamientos · %d pasos · %d separaciones · %.1f s."%[steps,separated,active_time])
	else:
		generate()
		feedback("Llegasteis juntos. La siguiente zona tiene más cruces.")

func center(tile: Vector2i) -> Vector2:
	var unit := minf(BOARD.size.x/field.size.x,BOARD.size.y/field.size.y)
	return BOARD.get_center()+(Vector2(tile)+Vector2(0.5,0.5)-Vector2(field.size)/2)*unit

func status() -> String:
	return "Tramo %d/3  •  %d pasos  •  %.1f s"%[mini(stage+1,3),steps,active_time]

func scene(game: Control) -> void:
	backdrop(game,Vector2(810,395),Color(0.19,0.23,0.11,0.34))
	var unit := minf(BOARD.size.x/field.size.x,BOARD.size.y/field.size.y)
	for y in range(field.size.y):
		for x in range(field.size.x):
			var tile := Vector2i(x,y)
			var p := center(tile)
			var r := Rect2(p-Vector2.ONE*unit/2,Vector2.ONE*unit)
			if open_cells.has(tile):
				game.draw_texture_rect(PAVING,r,false)
			elif narrow.has(tile):
				game.draw_texture_rect(PAVING,r,false)
				for side in [-1,1]: item(game,CRATE_ART,p+Vector2(side*unit*0.41,0),Vector2(unit*0.24,unit*0.53))
			else:
				game.draw_texture_rect(BLOCKED_ART,r,false)
				if (x+2*y)%4==0: item(game,game.World.TENT,p,Vector2(unit*1.04,unit))
				elif (2*x+y)%3==0: item(game,game.World.TABLE,p,Vector2(unit*0.84,unit*0.72))
				else: item(game,CRATE_ART,p,Vector2(unit*0.85,unit*0.85))
	var goal := center(destination)
	item(game,game.World.TENT,goal,Vector2(unit*1.03,unit))
	game.draw_arc(goal,unit*0.46,0,TAU,20,GOLD,3)
	if report: return
	var p := center(from_player).lerp(center(player),1-player_motion/0.14)
	var g := center(from_guest).lerp(center(guest),1-guest_motion/0.18)
	game.draw_circle(g,unit*0.37,RED if waiting else GREEN)
	actor(game,g+Vector2(0,unit*0.18),1,unit/45,guest_motion>0)
	actor(game,p+Vector2(0,unit*0.20),3,unit/42,player_motion>0)

func controls(game: Control) -> void:
	game.draw_circle(JOY,63,Color("284e48"))
	game.draw_arc(JOY,63,0,TAU,36,CREAM,2)
	game.draw_circle(JOY+joystick*39,23,GOLD)
	label(game,Vector2(169,517),"Joystick o flechas",239,GOLD)
	label(game,Vector2(169,558),"Verde: te sigue. Rojo: espera. La tienda dorada es la meta.",232)
