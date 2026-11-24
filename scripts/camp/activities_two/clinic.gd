extends "res://scripts/camp/activities_two/session.gd"

const TRAY := Rect2(325,133,89,224)
const SENSOR := 4.0
const PATHS := [
	[Vector2(84,236),Vector2(186,236),Vector2(324,236),Vector2(367,236)],
	[Vector2(82,301),Vector2(143,301),Vector2(143,205),Vector2(250,205),Vector2(250,245),Vector2(367,245)],
	[Vector2(87,175),Vector2(162,175),Vector2(204,258),Vector2(274,258),Vector2(291,190),Vector2(367,190)],
	[Vector2(82,306),Vector2(160,306),Vector2(215,229),Vector2(189,166),Vector2(282,166),Vector2(300,283),Vector2(367,283)],
	[Vector2(100,255),Vector2(129,333),Vector2(229,333),Vector2(263,245),Vector2(229,163),Vector2(304,163),Vector2(367,215)]
]
const HALF_WIDTH := [26.0,22.0,20.0,18.0,17.0]
const PIECES := [10.0,12.0,9.0,11.0,8.0]
var path: Array = []
var stage := 0
var errors := 0
var grabbed := false
var closed := false
var tip := Vector2(255,302)
var piece := Vector2.ZERO
var grip := Vector2.ZERO
var mirror := false
var shifts: Array[float] = []
var collision_until := 0.0

func initialize(seed_value: int, plan: String) -> void:
	super.initialize(seed_value,plan)
	title = "Punto sanitario · Operación"
	help = "Mantén pulsada la pieza de ensayo. Recorre la ranura sin rozar las paredes y suelta sobre la bandeja."
	mirror = rng.randi_range(0,1)==0
	for i in range(PATHS.size()): shifts.append(0.0 if i==0 else rng.randf_range(-5,5))
	setup_piece()

func setup_piece() -> void:
	path = PATHS[stage].duplicate()
	for i in range(path.size()):
		if mirror and stage>0: path[i].y = 489-path[i].y
		path[i].y += shifts[stage]
	piece = path[0]
	grabbed = false

func contains_clearance(at: Vector2, radius: float) -> bool:
	if TRAY.grow(-radius).has_point(at): return true
	for i in range(1,path.size()):
		var nearest := Geometry2D.get_closest_point_to_segment(at,path[i-1],path[i])
		if nearest.distance_to(at)+radius <= HALF_WIDTH[stage]: return true
	return false

func begin_drag(point: Vector2) -> bool:
	if not VIEW.has_point(point): return false
	tip = point
	closed = true
	if point.distance_to(piece) <= PIECES[stage]-1:
		grip = piece-point
		grabbed = true
	return true

func hover(point: Vector2) -> void:
	if not closed and VIEW.has_point(point): tip = point

func move_drag(_delta: Vector2) -> void:
	var next := drag_cursor.clamp(VIEW.position,VIEW.end)
	if grabbed:
		var steps := maxi(1,ceili(tip.distance_to(next)/1.6))
		for i in range(1,steps+1):
			var p := tip.lerp(next,float(i)/steps)
			if not contains_clearance(p,SENSOR) or not contains_clearance(p+grip,PIECES[stage]):
				fault(p,"Has rozado la cavidad. Suelta para volver a intentarlo.")
				break
		if grabbed: piece = next+grip
	tip = next

func fault(point: Vector2, message: String) -> void:
	if not tutorial: errors += 1
	collision_until = clock+0.26
	feedback(message,point,true)
	setup_piece()

func cancel_drag() -> void:
	closed = false
	if grabbed: setup_piece()

func end_drag(point: Vector2) -> void:
	if grabbed and not tip.is_equal_approx(point.clamp(VIEW.position,VIEW.end)):
		move_drag(Vector2.ZERO)
	closed = false
	if not grabbed: return
	if not TRAY.grow(-PIECES[stage]).has_point(piece):
		fault(piece,"Pieza devuelta. Abre las pinzas dentro de la bandeja.")
		return
	if tutorial:
		trained()
		feedback("Ensayo completo. Ahora extrae las cinco piezas.",piece)
		setup_piece()
		return
	var deposit := piece
	stage += 1
	if stage==PATHS.size():
		finish(clampi(100-errors*6-maxi(0,roundi(active_time)-50),0,100),"Cinco piezas a salvo · %d roces o caídas · %.1f s."%[errors,active_time])
		path = []
		grabbed = false
	else:
		feedback("Pieza depositada · %d/5"%stage,deposit)
		setup_piece()

func status() -> String:
	return "%d/5 piezas  •  %d roces  •  %.1f s"%[stage,errors,active_time]

func scene(game: Control) -> void:
	backdrop(game,Vector2(375,455),Color(0.22,0.3,0.22,0.5))
	game.draw_rect(Rect2(25,103,296,285),Color("a87953"))
	game.draw_rect(Rect2(31,110,282,273),Color("c99b67"),false,3)
	# Stylised felt patient on a wooden operation board, with abstract tokens.
	game.draw_rect(Rect2(32,113,282,265),Color("8f6547"),false,2)
	for p in [Vector2(38,118),Vector2(304,118),Vector2(38,372),Vector2(304,372)]:
		game.draw_rect(Rect2(p-Vector2(3,3),Vector2(6,6)),Color("dbbb8a"))
		game.draw_line(p-Vector2(2,0),p+Vector2(2,0),INK,1)
	game.draw_circle(Vector2(71,238),34,Color("88b2a4"))
	game.draw_rect(Rect2(93,169,153,140),Color("6c9f91"))
	game.draw_rect(Rect2(129,137,78,204),Color("6c9f91"))
	for y in [179,261]:
		game.draw_rect(Rect2(233,y,63,39),Color("6c9f91"))
		game.draw_rect(Rect2(277,y+4,16,31),Color("8bb4a4"))
	for p in [Vector2(120,180),Vector2(208,180),Vector2(120,298),Vector2(208,298)]:
		game.draw_rect(Rect2(p,Vector2(6,6)),Color("9ec4af"))
	game.draw_rect(Rect2(43,228,7,5),INK)
	game.draw_rect(Rect2(43,245,7,5),INK)
	game.draw_rect(TRAY,Color("779396"))
	game.draw_rect(TRAY.grow(-5),Color("334f51"),false,3)
	for i in range(7):
		game.draw_line(Vector2(340,177+i*22),Vector2(400,177+i*22),Color("658387"),1)
	game.text(TRAY.position+Vector2(0,19),"BANDEJA",12,CREAM,true,TRAY.size.x,HORIZONTAL_ALIGNMENT_CENTER)
	for i in range(stage):
		game.draw_rect(Rect2(340+(i%2)*24,317+i/2*10,12,8),GOLD)
	if not path.is_empty():
		var c := RED if clock<collision_until else Color("394451")
		for i in range(1,path.size()):
			game.draw_line(path[i-1],path[i],c,HALF_WIDTH[stage]*2)
			game.draw_circle(path[i-1],HALF_WIDTH[stage],c)
		game.draw_circle(path[-1],HALF_WIDTH[stage],c)
		var radius: float = PIECES[stage]
		var corners := 3+stage%4
		var outline := PackedVector2Array()
		for i in range(corners): outline.append(piece+Vector2.from_angle(i*TAU/corners-PI/2)*radius)
		game.draw_colored_polygon(outline,GOLD)
		game.draw_circle(piece,3,CREAM)
	if not report:
		var pinch := 2.0 if closed else 8.0
		game.draw_line(tip+Vector2(-26,-42),tip+Vector2(-pinch,1),Color("cfdbda"),4)
		game.draw_line(tip+Vector2(26,-42),tip+Vector2(pinch,1),Color("a3bdc3"),4)
