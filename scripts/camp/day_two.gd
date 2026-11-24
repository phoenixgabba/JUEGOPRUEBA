extends RefCounted

const NAMES := ["Redes", "Seguridad", "Convivencia", "Punto sanitario", "Accesibilidad"]
const POINTS := [Vector2(575,410), Vector2(710,450), Vector2(795,429), Vector2(375,455), Vector2(810,395)]
const MEDIA_POINTS := [Vector2(575,410), Vector2(540,402), Vector2(650,454)]
const MEDIA := ["Retrato de Patricia", "Turno de Cocina", "Llegadas a la plaza"]
const KINDS := ["redes", "seguridad", "convivencia", "sanitario", "accesibilidad"]
const PEOPLE := ["Patricia", "Alejandro", "Marina"]
const TRADEOFFS := [
	["«Con la entrada libre puedo acompañar a quien llegue.»", "Abrir un paso", "Cerrar la entrada"],
	["«Para cubrir el paso, necesito relevo y material cerca.»", "Organizar relevos", "Un turno para todo el día"],
	["«Puedo avisar del acceso si acordamos un punto de encuentro.»", "Señalar el punto", "Publicar sin ubicación"],
]
# Each case has two accounts, a proposal that serves both, and a partial proposal.
const CONFLICTS := [
	["«No puedo dormir cuando suenan los altavoces.»", "«Necesitamos ensayar para la asamblea.»", "Acordar horario y lugar", "Prohibir el ensayo"],
	["«Quiero agua, pero no puedo esperar de pie.»", "«La fila necesita mantener su turno.»", "Turnos y zona de espera", "Adelantar a todo el mundo"],
	["«Puse mis cajas junto a la lona.»", "«Las cajas impiden abrir la tienda.»", "Acordar zona de carga", "Moverlas a otra puerta"],
	["«Me falta una manta en mi turno.»", "«No sé cuántas quedan en el almacén.»", "Registrar y repartir mantas", "Reservarlas todas"],
]
const INCIDENTS := [
	["Un carro se detiene en el paso.", "El paso se estrecha al acumularse la gente.", "Despejar el paso"],
	["Una visitante se separa de su grupo.", "Busca el punto de encuentro y pide orientación.", "Guiar al encuentro"],
	["Dos personas levantan la voz junto a una salida.", "La salida sigue libre. Piden ayuda para conversar.", "Pedir mediación"],
	["Una persona se sienta en el suelo y pide ayuda.", "Se encuentra mal y pide que llamemos al sanitario.", "Avisar a sanitario"],
]
# Situations are fictional. The station handles supplies, waiting and escalation.
const CARE := [
	["Agua para la espera", "La persona pide agua y puede esperar sentada.", 0],
	["Manta para la espera", "La persona pide una manta mientras espera.", 1],
	["Orientación", "La persona busca a su acompañante y pide orientación.", 2],
	["Ayuda profesional", "La persona pide valoración del equipo profesional.", 3],
]
const SUPPLIES := ["Dar agua", "Dar manta", "Orientar", "Avisar al equipo"]
const CAPTIONS := ["Punto de encuentro", "Comida y turnos", "Entrada y acogida"]
const AUDIENCES := ["Comunidad", "Voluntariado", "Nuevas llegadas"]
const CAMERA_FRAME := Rect2(22, 82, 376, 254)
const FLOOR := Color("d1bd9a")
const GREEN := Color("95d29c")
const AMBER := Color("ffcc7b")
const GRID_ORIGIN := Vector2(26, 123)
const CELL := Vector2(46, 40)
const GRID := Vector2i(8, 5)
const DIRECTIONS := {"up": Vector2i.UP, "down": Vector2i.DOWN, "left": Vector2i.LEFT, "right": Vector2i.RIGHT}

var mode := ""
var done := false
var round_index := 0
var clock := 0.0
var notice := ""
var cases: Array = []
var listened := 0
var tension := 3
var swap_options := false
var stage := 0
var selected := -1
var stock := [1, 1]
var camera := Vector2.ZERO
var zoom := 0
var caption := 0
var audience := 0
var published: Array[Dictionary] = []
var subjects := []
var furniture: Dictionary = {}
var route: Array[Vector2i] = []
var route_time := 0.0
var care_queue: Array = []
var cue := false
var captured_at := 0.0
var flash := 0.0
var media_view := 0
var camera_pointer := -2
var incident_groups := []

func start(kind: String) -> void:
	mode = kind
	done = false
	round_index = 0
	clock = 0
	stage = 0
	notice = ""
	listened = 0
	tension = 3
	swap_options = bool(randi() % 2)
	selected = -1
	stock = [1, 1]
	published.clear()
	cases = range(4)
	cases.shuffle()
	incident_groups = range(4)
	incident_groups.shuffle()
	flash = 0
	care_queue = [cases.filter(func(i): return i != 3)[0], 3, 0]
	subjects = range(3)
	subjects.shuffle()
	prepare_camera()
	setup_route()
	cue = false

func tick(delta: float) -> void:
	clock += delta
	flash = maxf(0, flash - delta)
	if not route.is_empty():
		route_time += delta
		if route_time >= (route.size() - 1) * 0.23:
			next_round(3)
			if not done: setup_route()

func key(code: int) -> void:
	var bindings := {KEY_UP:"up", KEY_DOWN:"down", KEY_LEFT:"left", KEY_RIGHT:"right",
		KEY_W:"up", KEY_S:"down", KEY_A:"left", KEY_D:"right", KEY_ENTER:"confirm", KEY_SPACE:"confirm"}
	if bindings.has(code): action(bindings[code])
	if mode in ["asamblea", "seguridad", "convivencia", "sanitario"] and code >= KEY_1 and code <= KEY_4:
		action(str(code - KEY_1))

func action(value: String) -> void:
	if done: return
	match mode:
		"asamblea": assembly(value)
		"accesibilidad": accessibility(value)
		"redes": phone(value)
		"perfil":
			if value in ["left", "right"]: show_photo(posmod(media_view + (1 if value == "right" else -1), 3))
		"seguridad": security(value)
		"convivencia": mediation(value)
		"sanitario": clinic(value)

func next_round(goal: int) -> void:
	round_index += 1
	done = round_index >= goal
	stage = 0
	listened = 0
	tension = 3
	selected = -1
	clock = 0.0
	route.clear()
	swap_options = bool(randi() % 2)
	cue = true

func assembly(value: String) -> void:
	if value in ["0", "1", "2"]:
		var speaker := int(value)
		listened |= 1 << speaker
		notice = ["«Mantengamos el paso libre.»", "«Repartamos las tareas por turnos.»", "«Indiquemos dónde recibir a la gente.»"][speaker]
		return
	if value not in ["good", "bad"]: return
	var required := (1 << (round_index + 1)) - 1
	if (listened & required) != required:
		notice = "Da la palabra a los turnos pendientes antes de votar."
	elif value == "bad":
		notice = "La propuesta no consigue consenso. Escucha la prioridad de la ronda."
	else:
		next_round(3)
		notice = "Acuerdo incorporado al acta."

func setup_route() -> void:
	var lane := 1 + randi() % 3
	furniture = {Vector2i(2, lane): "table", Vector2i(4, 2): "box", Vector2i(6, lane): "tent"}
	if round_index >= 1:
		furniture[Vector2i(4, 0)] = "tent"
		furniture[Vector2i(4, 4)] = "box"
	if round_index >= 2:
		furniture[Vector2i(3, 0)] = "box"
		furniture[Vector2i(3, 4)] = "table"

func starts() -> Array[Vector2i]:
	var row := 2 if round_index == 0 else 1
	var result: Array[Vector2i] = []
	for i in range(round_index + 1): result.append(Vector2i(0, row + i))
	return result

func valid_lane(cell: Vector2i) -> bool:
	for offset in range(round_index + 1):
		var occupied := cell + Vector2i(0, offset)
		if not Rect2i(Vector2i.ZERO, GRID).has_point(occupied) or furniture.has(occupied):
			return false
	return true

func find_route() -> Array[Vector2i]:
	var origin: Vector2i = starts()[0]
	var goal := Vector2i(GRID.x - 1, origin.y)
	var queue: Array[Vector2i] = [origin]
	var previous := {origin: origin}
	var cursor := 0
	while cursor < queue.size():
		var cell := queue[cursor]
		cursor += 1
		if cell == goal:
			var path: Array[Vector2i] = [goal]
			while path[0] != origin: path.push_front(previous[path[0]])
			if round_index == 0 and path.size() > 8: return []
			return path
		for direction: Vector2i in DIRECTIONS.values():
			var neighbor := cell + direction
			if not previous.has(neighbor) and valid_lane(neighbor):
				previous[neighbor] = cell
				queue.append(neighbor)
	return []

func accessibility(value: String) -> void:
	if not route.is_empty(): return
	if value == "confirm":
		route = find_route()
		route_time = 0.0
		notice = "Probando el recorrido con visitantes…" if not route.is_empty() else "El paso sigue bloqueado. Reubica el mobiliario."
		return
	if not value.is_valid_int(): return
	var index := int(value)
	if index < 0 or index >= GRID.x * GRID.y: return
	var cell := Vector2i(index % GRID.x, index / GRID.x)
	if furniture.has(cell):
		selected = -1 if selected == index else index
	elif selected >= 0 and cell.x > 0 and cell.x < GRID.x - 1:
		var old := Vector2i(selected % GRID.x, selected / GRID.x)
		furniture[cell] = furniture[old]
		furniture.erase(old)
		selected = -1
		notice = "Objeto reubicado. Prueba el recorrido cuando esté libre."
		cue = true

func prepare_camera() -> void:
	camera_pointer = -2
	camera = Vector2([28, 42, 56][mini(round_index, 2)], -28)
	zoom = 0
	caption = 0
	audience = 0

func begin_aim(point: Vector2, index: int) -> bool:
	if mode != "redes" or stage != 0 or not CAMERA_FRAME.has_point(point):
		return false
	if camera_pointer == -2: camera_pointer = index
	return true

func aim(delta: Vector2, index: int) -> void:
	if camera_pointer == index and stage == 0:
		camera = (camera - delta / (2.0 + zoom * 0.7)).clamp(Vector2(-84,-70), Vector2(84,70))

func release_aim(index: int) -> void:
	if camera_pointer == index: camera_pointer = -2

func phone(value: String) -> void:
	if stage == 0:
		if DIRECTIONS.has(value):
			camera = (camera + Vector2(DIRECTIONS[value]) * 14).clamp(Vector2(-84,-70), Vector2(84,70))
		elif value == "zoom":
			zoom = (zoom + 1) % 3
		elif value == "confirm":
			if camera.length() > 22 - round_index * 5 or zoom != round_index:
				notice = "Centra el motivo en las guías y ajusta el zoom a %d×." % (round_index + 1)
				return
			stage = 1
			captured_at = clock
			flash = 0.22
			notice = "Foto capturada. Edita el pie y elige a quién va dirigida."
			cue = true
	elif stage == 1:
		match value:
			"caption": caption = (caption + 1) % CAPTIONS.size()
			"audience": audience = (audience + 1) % AUDIENCES.size()
			"retake":
				stage = 0
				notice = ""
			"confirm":
				if caption != subjects[round_index] or audience != subjects[round_index]:
					notice = "Relaciona el pie y el público con el motivo de la foto."
					return
				published.append({"subject":subjects[round_index], "x":camera.x, "y":camera.y, "zoom":zoom, "caption":caption, "time":captured_at})
				stage = 2
				notice = "Comentario recibido: «¿Dónde puedo encontrarlo?»"
				cue = true
	elif value == "confirm":
		next_round(3)
		prepare_camera()
		notice = "Ubicación compartida en el perfil simulado."

func security(value: String) -> void:
	if stage == 0:
		if not value.is_valid_int(): return
		if int(value) != incident_groups[round_index]:
			notice = "Ese grupo sigue con su actividad. Busca el aviso ámbar."
			return
		stage = 1
		notice = INCIDENTS[cases[round_index]][1]
	elif stage == 1:
		if value == "good":
			stage = 2
			notice = "Decisión registrada. Confirma con el equipo por radio."
		elif value == "bad":
			notice = "La situación sigue abierta. Elige una respuesta adecuada."
	elif value == "confirm":
		next_round(3)
		notice = "Radio: apoyo confirmado."

func mediation(value: String) -> void:
	if value in ["0", "1"]:
		var bit := 1 << int(value)
		if (listened & bit) == 0: tension = maxi(1, tension - 1)
		listened |= bit
		notice = CONFLICTS[cases[round_index]][int(value)]
	elif value in ["good", "bad"]:
		if listened != 3:
			notice = "Escucha las dos versiones antes de proponer un acuerdo."
		elif value == "bad" and stage == 0:
			tension = mini(4, tension + 1)
			notice = "Una parte sigue sin solución. Prueba un acuerdo compartido."
		elif stage == 0:
			tension = 0
			stage = 1
			notice = "Ambas partes aceptan. Confirma el acuerdo."
	elif stage == 1 and value == "confirm":
		next_round(3)
		notice = "Acuerdo confirmado."

func clinic(value: String) -> void:
	if value == "restock":
		stock = [1, 1]
		notice = "Suministros repuestos."
		return
	if value == "listen":
		stage = 1
		notice = CARE[care_queue[round_index]][1]
	elif value.is_valid_int() and stage == 1:
		var supply := int(value)
		if supply != CARE[care_queue[round_index]][2]:
			notice = "Revisa la petición de la persona en turno."
			return
		if supply < stock.size():
			if stock[supply] == 0:
				notice = "Repón suministros en el armario."
				return
			stock[supply] -= 1
		next_round(3)
		notice = "Turno atendido. La persona pasa a la zona de espera."

func open_profile(posts: Array) -> void:
	start("perfil")
	if posts.size() == 3:
		published.assign(posts.duplicate(true))
	else:
		for i in range(3):
			published.append({"subject": i, "x": 0, "y": 0, "zoom": 0, "caption": i, "time": 0})
	show_photo(0)

func show_photo(index: int) -> void:
	media_view = index
	var photo := published[index]
	subjects[0] = int(photo.subject)
	camera = Vector2(float(photo.x), float(photo.y))
	zoom = int(photo.zoom)
	caption = int(photo.caption)
	captured_at = float(photo.time)

func draw(game: Control) -> void:
	var size: Vector2 = game.size_v
	var wide := size.x > size.y * 1.25
	var layout := Vector2(850, 410) if wide else Vector2(420, 638)
	var scale := minf((size.x - 24) / layout.x, (size.y - 24) / layout.y)
	if not game.mobile_layout: scale = minf(scale, 1.25)
	var origin := (size - layout * scale) * 0.5
	game.draw_rect(Rect2(Vector2.ZERO, size), Color(0.04, 0.10, 0.08, 0.76))
	game.mini_scale = scale
	game.mini_rect = Rect2(origin, layout * scale)
	game.draw_set_transform(origin, 0, Vector2.ONE * scale)
	game.drawing_mini = true
	var titles := {"asamblea":"Segunda asamblea", "redes":"Teléfono · Redes", "seguridad":"Puesto de Seguridad",
		"convivencia":"Mesa de mediación", "sanitario":"Punto sanitario", "accesibilidad":"Accesibilidad", "perfil":"Teléfono · Publicaciones"}
	game.panel(Rect2(Vector2.ZERO, layout), Color("182f2c"), Color("bda578"))
	game.text(Vector2(22, 42), titles[mode], 26, AMBER, true)
	game.button(Rect2(layout.x - 68, 12, 54, 46), "Ⅱ" if game.test_build else "×", "pause" if game.test_build else "commission_close", false, 22)
	game.text(Vector2(24, 68), "@acampadavalencia" if mode == "perfil" else "Ronda %d de 3" % (round_index + 1), 17, GREEN, true)
	draw_scene(game)
	var controls_origin := origin + (Vector2(424, -266) if wide else Vector2.ZERO) * scale
	game.mini_rect.position = controls_origin
	game.draw_set_transform(controls_origin, 0, Vector2.ONE * scale)
	draw_controls(game)
	if not notice.is_empty():
		game.paragraph(Vector2(22, 576), notice, 376, 18, AMBER, 1.15)
	game.drawing_mini = false
	game.mini_rect.position = origin
	game.draw_set_transform(Vector2.ZERO)

func draw_scene(game: Control) -> void:
	var scene := CAMERA_FRAME
	if mode == "accesibilidad":
		draw_route(game, scene)
		return
	if mode in ["redes", "perfil"]:
		draw_camera(game, scene)
		return
	var site: Vector2
	match mode:
		"asamblea": site = game.World.MEETING
		"seguridad": site = POINTS[1]
		"convivencia": site = POINTS[2]
		_: site = POINTS[3]
	plaza_crop(game, scene, site, 1.0)
	match mode:
		"asamblea":
			game.draw_circle(Vector2(210,213), 91, Color(0.11,0.24,0.21,0.87))
			game.draw_arc(Vector2(210,213), 87, 0, TAU, 42, AMBER, 2)
			for i in range(3):
				var p := Vector2(96 + 112 * i, 222 + 58 * (i % 2))
				person(game, p, i)
				if listened & (1 << i): game.draw_circle(p + Vector2(0,-55), 5, GREEN)
			game.text(Vector2(34, 113), "Prioridad · " + ["Paso accesible","Relevos","Información"][round_index], 19, Color("182f2c"), true)
		"seguridad":
			for i in range(4):
				var p := Vector2(75 + (i % 2) * 186, 178 + (i / 2) * 103)
				p.x += sin(clock * (1.0 + round_index * 0.35) + i * 2.0) * (24 + 7 * round_index)
				person(game, p, i, true)
				var signal_color := AMBER if incident_groups[round_index] == i else GREEN
				game.draw_rect(Rect2(p + Vector2(-18, -69), Vector2(36, 22)), Color("182f2c"))
				game.text(p + Vector2(-17, -52), str(i + 1), 17, signal_color, true, 34, HORIZONTAL_ALIGNMENT_CENTER)
				if stage == 0:
					game.clickables.append({"rect":game.mini_hit(Rect2(p + Vector2(-42,-76), Vector2(84,91))), "id":"activity:%d" % i})
		"convivencia":
			game.draw_texture_rect(game.World.TABLE, Rect2(151,182,118,95), false)
			person(game, Vector2(92, 253), cases[round_index])
			person(game, Vector2(326, 253), cases[round_index] + 1)
			meter(game, Vector2(103, 285), "Tensión", tension, 4)
		"sanitario":
			game.draw_rect(Rect2(37, 120, 346, 192), Color("d7e4d3"))
			game.draw_rect(Rect2(37, 120, 346, 22), Color("6b9387"))
			game.draw_rect(Rect2(320, 154, 48, 57), Color("3f776c"))
			game.draw_rect(Rect2(339, 164, 9, 36), Color.WHITE)
			game.draw_rect(Rect2(327, 178, 33, 9), Color.WHITE)
			game.draw_texture_rect(game.World.TABLE, Rect2(190,184,105,86), false)
			person(game, Vector2(268,213), 2)
			for i in range(mini(round_index, 2)):
				person(game, Vector2(317 + i * 36, 272), care_queue[i], false, 0.7)
			for i in range(round_index, care_queue.size()):
				var distance := i - round_index
				person(game, Vector2(182 - distance * 47, 273 + distance * 10), care_queue[i], distance > 0)
			game.text(Vector2(52, 168), "Recepción · turno %d" % (round_index + 1), 19, Color("21473e"), true)
			game.text(Vector2(52, 303), "Reserva · agua %d / mantas %d" % stock, 17, Color("21473e"), true)

func draw_controls(game: Control) -> void:
	match mode:
		"asamblea":
			game.paragraph(Vector2(23, 362), TRADEOFFS[round_index][0], 374, 19)
			for i in range(3):
				control(game, Rect2(22 + 128 * i, 405, 120, 50), PEOPLE[i], str(i), bool(listened & (1 << i)))
			choices(game, TRADEOFFS[round_index][2], TRADEOFFS[round_index][1], 466)
		"accesibilidad":
			game.paragraph(Vector2(23, 370), "Toca un objeto y una parcela libre. " + ["Abre un paso.","Deja dos filas libres.","Deja tres filas libres."][round_index], 374, 20)
			control(game, Rect2(22, 466, 376, 65), "Probar recorrido", "confirm", true)
		"redes":
			draw_phone_controls(game)
		"perfil":
			game.text(Vector2(22, 368), CAPTIONS[caption], 22, GREEN, true)
			game.paragraph(Vector2(22, 407), "Ubicación compartida · %d reacciones" % (6 + media_view * 3), 376, 20)
			control(game, Rect2(22, 468, 182, 62), "Anterior", "left")
			control(game, Rect2(216, 468, 182, 62), "Siguiente", "right")
		"seguridad":
			if stage == 0:
				game.paragraph(Vector2(23, 369), INCIDENTS[cases[round_index]][0] + " Toca el grupo que necesita apoyo.", 374, 20)
				for i in range(4):
					control(game, Rect2(22 + 95 * i, 470, 86, 60), str(i + 1), str(i))
			elif stage == 1:
				game.paragraph(Vector2(23, 368), "Elige una respuesta para el grupo y mantén operativa la plaza.", 374, 20)
				var alternate: String = INCIDENTS[(cases[round_index] + round_index + 1) % INCIDENTS.size()][2]
				choices(game, alternate, INCIDENTS[cases[round_index]][2], 456)
			else:
				control(game, Rect2(22, 449, 376, 64), "Enviar por radio", "confirm", true)
		"convivencia":
			game.paragraph(Vector2(23, 364), "Escucha a quienes discrepan y busca un acuerdo.", 374, 20)
			control(game, Rect2(22, 410, 182, 50), "Escuchar a Ana", "0", bool(listened & 1))
			control(game, Rect2(216, 410, 182, 50), "Escuchar a Pau", "1", bool(listened & 2))
			if stage == 0:
				choices(game, CONFLICTS[cases[round_index]][3], CONFLICTS[cases[round_index]][2], 466)
			else:
				control(game, Rect2(22, 474, 376, 56), "Confirmar el acuerdo", "confirm", true)
		"sanitario":
			control(game, Rect2(22, 354, 182, 54), "Escuchar turno", "listen", stage == 0)
			control(game, Rect2(216, 354, 182, 54), "Reponer reserva", "restock")
			for i in range(SUPPLIES.size()):
				control(game, Rect2(22 + 194 * (i % 2), 417 + 62 * (i / 2), 182, 54), SUPPLIES[i], str(i))

func draw_route(game: Control, scene: Rect2) -> void:
	plaza_crop(game, scene, POINTS[4], 1.0)
	for y in range(GRID.y):
		for x in range(GRID.x):
			var cell := Vector2i(x,y)
			var r := Rect2(GRID_ORIGIN + Vector2(cell) * CELL, CELL - Vector2.ONE * 2)
			game.draw_rect(r, Color(FLOOR, 0.78))
			var index := y * GRID.x + x
			if selected == index: game.draw_rect(r, AMBER, false, 3)
			if furniture.has(cell):
				match furniture[cell]:
					"table": game.draw_texture_rect(game.World.TABLE, r.grow(-3), false)
					"tent": game.draw_texture_rect(game.World.TENT, r.grow(-3), false)
					"box":
						game.draw_rect(r.grow(-8), Color("916348"))
						game.draw_rect(Rect2(r.get_center() - Vector2(3,11), Vector2(6,22)), AMBER)
			if cell in route: game.draw_rect(r.grow(-12), GREEN)
			if route.is_empty():
				game.clickables.append({"rect":game.mini_hit(r), "id":"activity:%d" % index})
	for i in range(starts().size()):
		var point := Vector2(starts()[i])
		if not route.is_empty():
			var at := route_time / 0.23
			var index := mini(floori(at), route.size() - 1)
			point = Vector2(route[index]).lerp(Vector2(route[mini(index+1,route.size()-1)]), fposmod(at,1))
			point.y += i
		var feet := GRID_ORIGIN + point * CELL + Vector2(22,36)
		if i == 1:
			game.draw_circle(feet - Vector2(0,6), 8, Color("345b70"))
			game.draw_arc(feet - Vector2(0,6), 7, 0, TAU, 18, GREEN, 2)
		person(game, feet, i, not route.is_empty(), 0.65)
	game.text(Vector2(29,111), "Entrada", 17, Color("182f2c"), true)
	game.text(Vector2(329,111), "Refugio", 17, Color("182f2c"), true)

func draw_camera(game: Control, scene: Rect2) -> void:
	var subject: int = subjects[round_index]
	var magnification := 1.0 + zoom * 0.35
	plaza_crop(game, scene, MEDIA_POINTS[subject] + camera, magnification)
	var center := scene.get_center()
	var p := center - camera * 2.0 * magnification
	if scene.grow(-30).has_point(p):
		if subject == 1:
			game.draw_texture_rect(game.World.TABLE, Rect2(p - Vector2(32,31), Vector2(64,47)), false)
		person(game, p, subject)
		if subject != 0 and p.x + 34 < scene.end.x - 20:
			person(game, p + Vector2(34,6), subject + 1, false)
	if stage == 0 and mode != "perfil":
		for x in [1,2]:
			var offset: float = scene.size.x * x / 3
			game.draw_line(scene.position + Vector2(offset, 0), scene.position + Vector2(offset, scene.size.y), Color(1,1,1,0.5))
		for y in [1,2]:
			var offset: float = scene.size.y * y / 3
			game.draw_line(scene.position + Vector2(0,offset), scene.position + Vector2(scene.size.x,offset), Color(1,1,1,0.5))
		game.draw_rect(Rect2(center - Vector2(33,31), Vector2(66,62)), GREEN if camera.length() <= 22 - round_index * 5 else AMBER, false, 2)
	if flash > 0: game.draw_rect(scene, Color(1,1,1,flash * 3))
	game.text(Vector2(31, 108), MEDIA[subject], 20, Color("182f2c"), true)

func draw_phone_controls(game: Control) -> void:
	if stage == 0:
		game.text(Vector2(22, 369), "Encuadra el motivo · objetivo %d×" % (round_index + 1), 20, GREEN)
		for i in range(4):
			control(game, Rect2(22 + 95 * i, 394, 86, 60), ["←","↑","↓","→"][i], ["left","up","down","right"][i])
		control(game, Rect2(22, 468, 182, 62), "Zoom %d×" % (zoom+1), "zoom")
		control(game, Rect2(216, 468, 182, 62), "Tomar foto", "confirm", true)
	elif stage == 1:
		control(game, Rect2(22, 353, 376, 55), "Pie · " + CAPTIONS[caption], "caption")
		control(game, Rect2(22, 415, 376, 55), "Público · " + AUDIENCES[audience], "audience")
		control(game, Rect2(22, 480, 182, 55), "Repetir foto", "retake")
		control(game, Rect2(216, 480, 182, 55), "Publicar", "confirm", true)
	else:
		game.paragraph(Vector2(22, 370), "Publicación visible · %d reacciones · 1 pregunta" % (6 + round_index * 3), 376, 21)
		control(game, Rect2(22, 467, 376, 62), "Responder con la ubicación", "confirm", true)

func plaza_crop(game: Control, dest: Rect2, site: Vector2, magnification: float) -> void:
	var span := dest.size / (2.0 * magnification)
	var ratio := Vector2(game.World.PLAZA.get_size()) / Vector2(1280,720)
	game.draw_texture_rect_region(game.World.PLAZA, dest, Rect2((site - span / 2) * ratio, span * ratio))
	game.draw_rect(dest, Color("e6cb9e"), false, 2)

func person(game: Control, p: Vector2, actor: int, moving: bool = false, scale: float = 1.0) -> void:
	var animation_time := captured_at if mode == "perfil" or (mode == "redes" and stage > 0) else clock
	var bob := roundf(sin(animation_time * (11 if moving else 3) + actor) * (3 if moving else 1))
	game.draw_circle(p, 16 * scale, Color(0.12,0.19,0.15,0.38))
	var sprite: Texture2D = game.World.CROWD_TEXTURES[actor % 4]
	game.draw_texture_rect(sprite, Rect2(p + Vector2(-17,-52 + bob) * scale, Vector2(34,53) * scale), false)

func meter(game: Control, pos: Vector2, label: String, amount: int, total: int) -> void:
	game.draw_rect(Rect2(pos - Vector2(8,8), Vector2(213,42)), Color("203d35"))
	game.text(pos + Vector2(0,19), label, 17, Color("fff5df"))
	for i in range(total):
		game.draw_rect(Rect2(pos + Vector2(72 + i*29,5), Vector2(24,17)), AMBER if i < amount else GREEN.darkened(0.2))

func choices(game: Control, partial: String, best: String, y: float) -> void:
	var actions := ["bad","good"] if swap_options else ["good","bad"]
	for i in range(2):
		control(game, Rect2(22, y + i * 47, 376, 43), best if actions[i] == "good" else partial, actions[i])

func control(game: Control, rect: Rect2, label: String, value: String, highlight: bool = false) -> void:
	game.button(rect, label, "activity:" + value, highlight, 19)
