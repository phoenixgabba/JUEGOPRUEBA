extends "res://scripts/camp/activities_two/session.gd"

const PAVING := preload("res://assets/visual/paving.png")
const BLOCKED_ART := preload("res://assets/visual/blocked.png")
const CRATE_ART := preload("res://assets/visual/crate.png")

const BOARD := Rect2(20,90,400,310)
const WINDOW := Vector2i(9,7)
const TILE_SIZE := 40.0
const VISION := [4.6,4.1,3.6]
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
var explored := {}
var camera_origin := Vector2i.ZERO
var visited_steps := 0

func initialize(seed_value: int, plan: String) -> void:
	super.initialize(seed_value,plan)
	title = "Accesibilidad · hacia tu tienda"
	help = "Explora con joystick o flechas. Solo ves tu entorno. La brújula señala la tienda; evita los pasos estrechos y no pierdas a tu acompañante."
	generate()
	optimal = 0

func generate() -> void:
	var width: int = [13,17,21][stage]
	var height: int = [11,13,15][stage]
	field = Rect2i(0,0,width,height)
	open_cells.clear()
	narrow.clear()
	explored.clear()
	visited_steps = 0
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
	for i in range(mini(crossings.size(),5+stage*3)):
		var cell: Vector2i = crossings.pop_at(rng.randi_range(0,crossings.size()-1))
		if i%2==0: narrow[cell] = true
		else: open_cells[cell] = true
	# Elige una meta distante por recorrido accesible, no por distancia recta.
	var farthest := -1
	for candidate in open_cells.keys():
		var tile: Vector2i = candidate
		if tile.x%2==0 or tile.y%2==0: continue
		if tile.x < width/2 and tile.y < height/2: continue
		var distance := find_route(player,tile,false).size()-1
		if distance > farthest:
			farthest = distance
			destination = tile
	from_player = player
	from_guest = guest
	player_motion = 0
	guest_motion = 0
	guest_delay = 0
	waiting = false
	optimal += find_route(guest,destination,false).size()-1
	update_camera()
	reveal_nearby()

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
				update_camera()
				reveal_nearby()
				if tutorial:
					trained()
					optimal = find_route(guest,destination,false).size()-1
					feedback("Ve despacio. Tu acompañante necesita un paso ancho.")
	if guest_motion>0 or guest_delay>0: return
	var route := find_route(guest,player,false)
	var stopped := route.is_empty() or route.size()>7
	if stopped and not waiting:
		separated += 1
		feedback("Tu acompañante se ha quedado atrás. Regresa por un camino ancho.")
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
		feedback("Llegasteis juntos. El siguiente tramo es mayor y tendrás menos visibilidad.")

func update_camera() -> void:
	camera_origin = Vector2i(clampi(player.x-WINDOW.x/2,0,field.size.x-WINDOW.x),clampi(player.y-WINDOW.y/2,0,field.size.y-WINDOW.y))

func reveal_nearby() -> void:
	var radius: float = VISION[stage]
	for y in range(maxi(0,player.y-5),mini(field.size.y,player.y+6)):
		for x in range(maxi(0,player.x-5),mini(field.size.x,player.x+6)):
			var tile := Vector2i(x,y)
			if Vector2(tile-player).length()<=radius:
				if not explored.has(tile): visited_steps += 1
				explored[tile] = true

func on_camera(tile: Vector2i) -> bool:
	return Rect2i(camera_origin,WINDOW).has_point(tile)

func center(tile: Vector2i) -> Vector2:
	return BOARD.get_center()+(Vector2(tile-camera_origin)+Vector2(0.5,0.5)-Vector2(WINDOW)/2)*TILE_SIZE

func status() -> String:
	return "Tramo %d/3 · %d pasos · %d separaciones"%[mini(stage+1,3),steps,separated]

func scene(game: Control) -> void:
	game.draw_rect(BOARD,Color("17282a"))
	var radius: float = VISION[mini(stage,2)]
	for y in range(camera_origin.y,camera_origin.y+WINDOW.y):
		for x in range(camera_origin.x,camera_origin.x+WINDOW.x):
			var tile := Vector2i(x,y)
			var p := center(tile)
			var r := Rect2(p-Vector2.ONE*TILE_SIZE/2,Vector2.ONE*TILE_SIZE)
			var visible := Vector2(tile-player).length()<=radius
			if not explored.has(tile):
				game.draw_rect(r,Color("18282c"))
				game.draw_rect(r,Color("26383a"),false,1)
				continue
			if open_cells.has(tile):
				game.draw_texture_rect(PAVING,r,false)
			elif narrow.has(tile):
				game.draw_texture_rect(PAVING,r,false)
				for side in [-1,1]: item(game,CRATE_ART,p+Vector2(side*TILE_SIZE*0.41,0),Vector2(TILE_SIZE*0.24,TILE_SIZE*0.68))
				game.draw_rect(r,Color("d19b55"),false,2)
			else:
				game.draw_texture_rect(BLOCKED_ART,r,false)
				if (x+2*y)%4==0: item(game,game.World.TENT,p,Vector2(TILE_SIZE*1.04,TILE_SIZE))
				elif (2*x+y)%3==0: item(game,game.World.TABLE,p,Vector2(TILE_SIZE*0.84,TILE_SIZE*0.72))
				else: item(game,CRATE_ART,p,Vector2(TILE_SIZE*0.85,TILE_SIZE*0.85))
			if tile == destination:
				item(game,game.World.TENT,p,Vector2(TILE_SIZE*1.03,TILE_SIZE))
				game.draw_arc(p,TILE_SIZE*0.46,0,TAU,24,GOLD,3)
			if not visible: game.draw_rect(r,Color(0.04,0.09,0.11,0.68))
	if report: return
	var p := center(from_player).lerp(center(player),1-player_motion/0.14)
	var g := center(from_guest).lerp(center(guest),1-guest_motion/0.18)
	if on_camera(guest):
		game.draw_circle(g,TILE_SIZE*0.37,RED if waiting else GREEN)
		actor(game,g+Vector2(0,TILE_SIZE*0.18),1,TILE_SIZE/45,guest_motion>0)
	actor(game,p+Vector2(0,TILE_SIZE*0.20),3,TILE_SIZE/42,player_motion>0)

func compass(game: Control,at: Vector2,target: Vector2i,color: Color) -> void:
	var direction := Vector2(target-player).normalized()
	game.draw_circle(at,24,Color("192f30"))
	game.draw_arc(at,24,0,TAU,32,color,2)
	if direction.length()<0.1:
		game.draw_circle(at,7,color)
		return
	var tip := at+direction*17
	var side := direction.orthogonal()*7
	game.draw_colored_polygon(PackedVector2Array([tip,at-direction*8+side,at-direction*8-side]),color)

func controls(game: Control) -> void:
	game.draw_circle(JOY,63,Color("284e48"))
	game.draw_arc(JOY,63,0,TAU,36,CREAM,2)
	game.draw_circle(JOY+joystick*39,23,GOLD)
	label(game,Vector2(169,495),"Joystick o flechas",239,GOLD)
	compass(game,Vector2(192,555),destination,GOLD)
	label(game,Vector2(225,550),"Tienda",180,GOLD)
	compass(game,Vector2(192,615),guest,RED if waiting else GREEN)
	label(game,Vector2(225,607),"Espera: vuelve" if waiting else "Te acompaña",180,RED if waiting else GREEN)
	label(game,Vector2(20,674),"La brújula no muestra el camino. Las cajas estrechas no son accesibles.",400)
