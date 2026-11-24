extends Control

const State = preload("res://scripts/camp/state.gd")
const DayTwo = preload("res://scripts/camp/day_two.gd")
const World = preload("res://scripts/camp/world.gd")
const LICENSES = preload("res://scripts/manus/open_source_licenses.gd")
const COVER = preload("res://assets/acampada/cover.png")
const BODY = preload("res://assets/template/fonts/ui_regular.tres")
const BOLD = preload("res://assets/template/fonts/ui_bold.tres")
const TITLE = preload("res://assets/template/fonts/display/generic_title.tres")

var s: CampState = State.new()
var map_open := false
var world: CampWorld = World.new()
var screen := "title"
var paused := false
var confirm_new := false
var dialogue := false
var dialogue_speaker := ""
var dialogue_text := ""
var dialogue_next := ""
var choosing := false
var commission_open := false
var day_two_activity := DayTwo.new()
var day_two_open := false
var activity := preload("res://scripts/camp/activities.gd").new()
const COMMISSION_GAME := ["organization", "puzzle", "communication"]
var mini := false
var mini_piece := Vector2(240, 235)
var mini_success := 0
const LIFT_GOAL := 10.0
var mini_lift := 0.0
var mini_pegs := [false, false, false, false]
var mini_selected := 0
var dragging := false
var joystick_pointer := -2
var joystick_center := Vector2.ZERO
var joystick_radius := 1.0
var joystick_vector := Vector2.ZERO
var elapsed := 0.0
const CUE = preload("res://scripts/manus/procedural_sfx.gd")
var activity_sound := AudioStreamPlayer.new()
var activity_sounds: Dictionary = {}
var rest_time := -1.0
var test_build := false
var evening_shade := 0.0
var save_timer := 0.0
var walking := false
var arrivals: Array = []
var toast := ""
var toast_time := 0.0
var clickables: Array = []
var world_rect := Rect2(0,0,1280,720)
var mini_rect := Rect2()
var mini_scale := 1.0
var drawing_mini := false
var portrait := false
var touch_layout := false
var mobile_layout := false
var hud_expanded := false
var size_v := Vector2(1280, 720)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	test_build = OS.has_feature("camp_practice")
	if test_build: screen = "selector"
	touch_layout = DisplayServer.is_touchscreen_available()
	if OS.has_feature("web"):
		touch_layout = touch_layout or JavaScriptBridge.eval("matchMedia('(any-pointer: coarse)').matches") == true
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	activity_sounds = {
		"asamblea": CUE.tone(430, 0.15, 0.12, 580),
		"accesibilidad": CUE.tone(360, 0.09, 0.12, 520),
		"redes": CUE.tone(1080, 0.07, 0.10, 410),
		"seguridad": CUE.tone(690, 0.11, 0.11, 620),
		"convivencia": CUE.tone(330, 0.20, 0.10, 445),
		"sanitario": CUE.tone(570, 0.13, 0.11, 815),
	}
	add_child(activity_sound)
	set_process(true)
	set_process_input(true)
	queue_redraw()

func _process(delta: float) -> void:
	elapsed += delta
	evening_shade = move_toward(evening_shade, s.light_level(), delta * 0.16)
	if toast_time > 0: toast_time -= delta
	if paused or dialogue or mini or map_open or commission_open or screen != "play":
		reset_joystick()
	if rest_time >= 0:
		rest_time += delta
		if rest_time >= 2.8:
			rest_time = -1
			announce("Ha amanecido. Pulsa Acción o E para salir.")
		elif rest_time >= 1.2 and s.phase != "wake":
			s.phase = "wake"
			s.energy = 100
			s.player = World.tent_door(s)
			evening_shade = 0
			s.save_game()
		queue_redraw()
		return
	if screen != "play" or paused or map_open:
		queue_redraw()
		return
	if mini:
		if s.build_stage == 0:
			var d := movement()
			mini_piece += d * delta * 250.0
			mini_piece.x = clampf(mini_piece.x, 105, 715)
			mini_piece.y = clampf(mini_piece.y, 125, 345)
		elif s.build_stage == 2:
			mini_lift = maxf(0.0, mini_lift - delta * 1.5)
	elif commission_open:
		if day_two_open:
			day_two_activity.tick(delta)
			if day_two_activity.cue:
				activity_sound.stream = activity_sounds[day_two_activity.mode]
				activity_sound.play()
				day_two_activity.cue = false
			if day_two_activity.done:
				complete_day_two_activity()
		else:
			activity.tick(delta)
			if activity.done: complete_activity()
	elif not dialogue and s.phase != "wake":
		var dir := movement()
		walking = dir.length() > 0.05
		if walking:
			var movement_delta := dir * 88.0 * delta
			var steps := maxi(1, ceili(movement_delta.length() / 2.0))
			var step := movement_delta / steps
			for i in range(steps):
				var nx := s.player + Vector2(step.x, 0)
				if walkable(nx): s.player.x = nx.x
				var ny := s.player + Vector2(0, step.y)
				if walkable(ny): s.player.y = ny.y
		s.minutes += delta
		update_deliveries(delta)
		save_timer += delta
		if save_timer > 5:
			s.save_game()
			save_timer = 0
	queue_redraw()

func movement() -> Vector2:
	var d := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	d += joystick_vector
	return d.normalized() if d.length() > 1.0 else d

func walkable(p: Vector2) -> bool:
	return World.walkable(p, s)

func update_deliveries(delta: float) -> void:
	if s.day == 2 and s.phase == "expansion" and s.delivery == "delegated":
		s.delivery_progress += delta / 6.0
		if s.delivery_progress >= 1.0:
			install_tent(false)
			announce("Accesibilidad ha instalado una tienda y acompañado a sus ocupantes.")
		return
	if dialogue or mini or s.phase != "expansion":
		return
	if s.delivery not in ["leaving", "returning", "placing", "resident"]:
		return
	s.delivery_progress = minf(1.0, s.delivery_progress + delta / 1.6)
	if s.delivery == "resident":
		arrivals = [world.delivery_point(s, World.ENTRY_APPROACH, World.pitch_at(s, s.tents - 2) + Vector2(0, 8))]
	if s.delivery_progress < 1.0:
		return
	s.delivery_progress = 0.0
	match s.delivery:
		"leaving": s.delivery = "returning"
		"returning":
			s.delivery = "offer"
			announce("Ha vuelto una persona de la asamblea con su tienda.")
		"placing": install_tent(false)
		"resident": advance_expansion()
	s.save_game()

func install_tent(donated: bool) -> void:
	s.tents += 1
	s.capacity += 2
	keep_clear_of_new_shelters()
	if donated:
		s.people += 1
		s.phase = "expansion"
		s.delivery = "resident"
		s.delivery_progress = 0.0
		announce("La tienda donada está lista. Se acerca una persona para alojarse.")
	else:
		if s.tents > 6:
			s.people += 1
		advance_expansion()
	s.save_game()

func advance_expansion() -> void:
	arrivals.clear()
	s.phase = "expansion"
	s.delivery_progress = 0.0
	if s.day == 2:
		if s.day_two_commissions < 5 and s.tents >= 25 + 5 * s.day_two_commissions:
			s.phase = "commissions_two"
			s.delivery = ""
			announce("Siguiente comisión: " + DayTwo.NAMES[s.next_day_two_commission()] + ".")
		elif s.tents >= World.DAY_TWO_TENTS:
			s.delivery = "close"
		elif s.has_day_two_commission(State.ACCESSIBILITY):
			s.delivery = "delegated"
		else:
			s.delivery = "offer"
		return
	if s.tents < 6:
		s.delivery = "leaving"
		return
	if s.tents == 6 and s.material_boxes == 0:
		s.delivery = "unload"
		announce("Han traído cajas, mantas, agua y herramientas. Guárdalas en la primera tienda.")
		return
	if (s.commissions == 1 and s.tents >= World.KITCHEN_TENTS) or (s.commissions == 2 and s.tents >= World.COMMUNICATION_TENTS):
		s.phase = "commissions"
		s.delivery = ""
		announce("Ahora toca formar " + World.COMMISSION_NAMES[s.commissions] + ".")
		return
	s.delivery = "close" if s.tents >= World.DAY_ONE_TENTS else "offer"

func complete_activity() -> void:
	commission_open = false
	if activity.mode == "storage":
		s.material_boxes = 4
		s.phase = "commissions"
		s.delivery = ""
		keep_clear_of_new_shelters()
		s.save_game()
		open_dialog("MATERIAL COMÚN", "Almacén organizado. Vamos al punto de reunión para formar Organización.")
	else:
		form_commission()

func form_commission() -> void:
	const NOTES := [
		"Los seis referentes nos reunimos aquí para coordinar turnos y recoger acuerdos. Este será nuestro punto fijo. La carpa la montaremos más adelante.",
		"Ya tenemos mesa y comida en Cocina. Sigamos recibiendo tiendas antes de preparar el primer comunicado.",
		"Publicamos el acuerdo de la asamblea desde este punto. Quedan las últimas tiendas antes de cerrar el día."
	]
	var index := s.commissions
	s.commissions += 1
	if s.commissions == 2:
		keep_clear_of_new_shelters()
	advance_expansion()
	s.save_game()
	open_dialog(World.COMMISSION_NAMES[index].to_upper(), NOTES[index])

func start_day_two() -> void:
	if s.day != 1 or s.phase != "wake" or rest_time >= 0 or s.player.distance_to(World.tent_door(s)) > 16:
		return
	s.day = 2
	s.phase = "meeting_two"
	screen = "play"
	s.save_game()
	announce("Vuelve al círculo central para la segunda asamblea.")

func interact_day_two() -> bool:
	if s.phase == "meeting_two" and s.player.distance_to(World.MEETING) < 75:
		open_day_two_activity("asamblea")
		return true
	if s.phase != "commissions_two":
		return false
	var index := s.next_day_two_commission()
	if index < 0 or s.player.distance_to(DayTwo.POINTS[index]) > 42:
		return false
	open_day_two_activity(DayTwo.KINDS[index])
	return true

func open_day_two_activity(kind: String) -> void:
	commission_open = true
	day_two_open = true
	day_two_activity.start(kind, s.assembly_plan)

func complete_day_two_activity() -> void:
	commission_open = false
	day_two_open = false
	if day_two_activity.mode == "asamblea":
		s.assembly_plan = str(day_two_activity.session.result.get("plan", ""))
		s.phase = "commissions_two"
		s.save_game()
		announce("Acuerdo aprobado. Abre Accesibilidad para recibir a quienes lleguen.")
		return
	var index := s.next_day_two_commission()
	if index < 0: return
	if index == State.NETWORKS:
		s.media_count = DayTwo.MEDIA.size()
		s.posts = day_two_activity.published.duplicate(true)
	s.respect += day_two_activity.session.score / 10
	if index == 2: s.wellbeing = clampi(s.wellbeing + (day_two_activity.session.score - 50) / 5, 0, 100)
	s.finish_day_two_commission(index)
	advance_expansion()
	s.save_game()
	var messages := [
		"Las tres publicaciones están en el perfil simulado. Ya puedes abrir el teléfono junto al mapa.",
		"El equipo recibe avisos y mantiene libres las zonas de paso.",
		"Ya hay un punto para hablar y resolver problemas internos.",
		"El Punto sanitario queda abierto para atender a quien lo necesite.",
		"Desde ahora, Accesibilidad monta las tiendas que llegan y acompaña a las personas hasta su parcela."
	]
	open_dialog(DayTwo.NAMES[index].to_upper(), messages[index])

func open_phone() -> void:
	if not s.has_day_two_commission(State.NETWORKS) or dialogue:
		return
	commission_open = true
	day_two_open = true
	day_two_activity.open_profile(s.posts)

func keep_clear_of_new_shelters() -> void:
	if walkable(s.player):
		return
	for direction in [Vector2.DOWN, Vector2.UP, Vector2.LEFT, Vector2.RIGHT]:
		var nearby: Vector2 = s.player + direction * 36.0
		if walkable(nearby):
			s.player = nearby
			return
	s.player = World.ENTRANCE

func start_game(resume: bool) -> void:
	s = State.new()
	s.practice = test_build
	rest_time = -1
	if resume and s.load_game():
		if s.phase == "wake": s.player = World.tent_door(s)
		elif not walkable(s.player): s.player = World.ENTRANCE
		arrivals = []
	else:
		s.reset_save()
		s.save_game()
		arrivals = []
	evening_shade = s.light_level()
	screen = "play"
	map_open = false
	paused = false
	mini = false
	commission_open = false
	day_two_open = false
	dialogue = false
	if not resume:
		open_dialog("LA PLAZA, DÍA 1", "Hay unas veinte personas en la plaza. Acércate a Patricia, Alejandro y Marina para preparar la primera asamblea.", "")
	else:
		announce("Partida recuperada. La plaza te estaba esperando.")

func announce(text: String) -> void:
	toast = text
	toast_time = 4.0

func open_dialog(speaker: String, text: String, next: String = "") -> void:
	dialogue = true
	dialogue_speaker = speaker
	dialogue_text = text
	dialogue_next = next
	choosing = next == "assembly_choice"
	walking = false

func close_dialog() -> void:
	if choosing: return
	var next := dialogue_next
	dialogue = false
	dialogue_next = ""
	if next == "show_end": screen = "result"

func choose_assembly(option: int) -> void:
	if not choosing: return
	choosing = false
	s.choice = "cuidados" if option == 0 else "materiales"
	if option == 0:
		s.wellbeing += 10
		s.respect += 20
	else:
		s.cash += 8
		s.respect += 15
	s.phase = "materials"
	s.save_game()
	open_dialog("ASAMBLEA", "Acordamos quedarnos y acampar. La primera tienda será común y servirá para guardar material. Busquemos lona, varillas y piquetas.", "")

func interact() -> void:
	if screen != "play" or rest_time >= 0: return
	if paused or commission_open: return
	if dialogue:
		if not choosing: close_dialog()
		return
	if mini:
		mini_action()
		return
	if s.phase == "wake":
		start_day_two()
		return
	if s.phase == "return_tent" and s.player.distance_to(World.tent_door(s)) <= 16:
		rest_time = 0
		reset_joystick()
		walking = false
		return
	if s.day == 2 and interact_day_two(): return
	if s.phase == "meeting" and s.player.distance_to(World.MEETING) < 100:
		open_dialog("PRIMERA ASAMBLEA", "Patricia: Nos hemos juntado espontáneamente. ¿Y si nos quedamos a acampar? Empezamos con una tienda común. ¿Qué priorizamos al arrancar?", "assembly_choice")
		return
	if s.phase == "materials":
		var nearest := ""
		var dist := 75.0
		for key in World.MATERIALS:
			var d: float = s.player.distance_to(World.MATERIALS[key])
			if not s.collected[key] and d < dist:
				dist = d
				nearest = str(key)
		if nearest != "":
			s.collected[nearest] = true
			s.respect += 5
			s.energy = maxi(0, s.energy - 2)
			announce("Recogido: " + nearest + ".")
			if s.all_collected():
				s.phase = "build"
				open_dialog("ALEJANDRO", "¡Todo listo! Ven al espacio marcado en la zona B y montemos la tienda paso a paso.", "")
			s.save_game()
			return
	if s.phase == "build" and s.player.distance_to(World.camp_build_point(s)) < (100.0 if s.tents == 0 else 26.0):
		mini = true
		mini_piece = Vector2(240, 235)
		mini_success = 0
		mini_lift = 0.0
		mini_pegs = [false, false, false, false]
		mini_selected = 0
		return
	if s.phase == "commissions" and s.player.distance_to(World.COMMISSION_POINTS[s.commissions]) < 38:
		commission_open = true
		activity.start(COMMISSION_GAME[s.commissions])
		return
	if s.phase == "expansion" and interact_with_delivery():
		return
	var nearest_npc := ""
	var distance := 88.0
	for n in ["Patricia", "Alejandro", "Marina"]:
		var d := s.player.distance_to(world.npc_pos(n, s, elapsed))
		if d < distance:
			distance = d
			nearest_npc = n
	if nearest_npc != "":
		talk_to(nearest_npc)
	else:
		announce("Acércate a una persona o a un objeto marcado para interactuar.")

func interact_with_delivery() -> bool:
	match s.delivery:
		"offer":
			if s.player.distance_to(World.ENTRANCE) > 42: return false
			if s.tents < 6 or s.tents % 3 != 0:
				s.delivery = "assign"
				open_dialog("LLEGADA", "He traído mi propia tienda. Acércate a uno de los huecos marcados y usa Acción para indicarme dónde montarla.")
			else:
				s.delivery = "donation"
				s.build_stage = 0
				s.phase = "build"
				open_dialog("DONACIÓN", "Traemos una tienda para quien la necesite. Móntala en el sitio marcado.")
		"assign":
			if not World.assign_pitch(s): return false
			s.delivery = "placing"
			s.delivery_progress = 0.0
		"unload":
			if s.player.distance_to(World.SITE) > 30: return false
			activity.start("storage")
			commission_open = true
		"close":
			if s.player.distance_to(World.ORGANIZATION) > 38: return false
			s.phase = "return_tent" if s.day == 1 else "finished"
			s.delivery = ""
			var summary := "Terminamos el día con 25 tiendas nuevas y cinco comisiones más."
			open_dialog("CIERRE DEL DÍA", summary if s.day == 2 else "La plaza queda abierta. Cuando quieras descansar, busca tu tienda con la marca azul y pulsa Acción o E en la entrada.", "show_end" if s.day == 2 else "")
		_: return false
	s.save_game()
	return true

func talk_to(n: String) -> void:
	if s.phase == "talk" and not s.talked[n]:
		s.talked[n] = true
		s.respect += 10
		var lines := {
			"Patricia": "Soy Patricia. Una plaza no se ocupa solo con tiendas: se llena de escucha. ¿Te quedas para la primera asamblea?",
			"Alejandro": "Soy Alejandro. Hay materiales por aquí y sé montar tiendas. Primero decidamos cómo hacerlo entre todas.",
			"Marina": "Soy Marina. Podemos construir un lugar donde cada persona tenga voz. Nos reunimos en el centro cuando estemos listas."
		}
		if s.all_talked(): s.phase = "meeting"
		s.save_game()
		open_dialog(n.to_upper(), lines[n], "")
	else:
		var line := "La plaza es de quienes la cuidan. Seguimos juntas."
		if s.phase == "meeting": line = "Nos vemos en el círculo del centro para decidir juntas."
		if s.phase == "materials": line = "Busca los materiales brillantes. Cada pieza cuenta."
		if s.phase == "build": line = "Te ayudamos desde aquí. La lona, las varillas y las piquetas van por turnos."
		if s.phase == "expansion": line = "La primera tienda es para el material común. Las demás darán cobijo."
		if s.phase in ["commissions", "finished"]: line = "Nos reunimos en Organización, delante del Ayuntamiento."
		open_dialog(n.to_upper(), line, "")

func mini_action() -> void:
	match s.build_stage:
		0:
			if mini_piece.distance_to(Vector2(560,235)) < 55: complete_build_stage()
			else: announce("Mueve la lona hasta el círculo dorado.")
		1:
			var needle := (sin(elapsed * 2.9) + 1.0) / 2.0
			if needle >= 0.30 and needle <= 0.70:
				mini_success += 1
				if mini_success >= 2: complete_build_stage()
				else: announce("¡Una varilla encajada! Falta otra.")
			else: announce("Casi: espera a que el indicador entre en la franja verde.")
		2:
			mini_lift += 1.0
			if mini_lift >= LIFT_GOAL: complete_build_stage()
		3:
			mini_pegs[mini_selected] = true
			if not mini_pegs.has(false): complete_build_stage()
			else:
				for i in range(4):
					if not mini_pegs[i]:
						mini_selected = i
						break

func complete_build_stage() -> void:
	if not mini: return
	s.build_stage += 1
	s.energy = maxi(0, s.energy - 5)
	s.respect += 12
	mini = false
	dragging = false
	if s.build_stage == 4:
		if s.tents == 0:
			s.tents = 1
			advance_expansion()
			if s.player.distance_to(World.SITE) < 9:
				s.player = World.clear_spot(World.SITE + Vector2(0, 15), s)
			open_dialog("ALEJANDRO", "Ya tenemos un sitio para guardar material. Cinco personas de la asamblea van a buscar sus tiendas.")
		else:
			install_tent(true)
	else:
		var lines := ["La lona ya está extendida sobre el suelo.", "Las varillas quedan ensambladas sobre la lona.", "La estructura está levantada; solo falta asegurarla."]
		open_dialog("MONTAJE", lines[s.build_stage - 1] + " Acércate de nuevo para continuar.", "")
	s.save_game()

func objective() -> String:
	match s.phase:
		"meeting_two": return "Ve al círculo central para la segunda asamblea."
		"commissions_two":
			return "Abre la comisión de " + DayTwo.NAMES[s.next_day_two_commission()]
		"talk": return "Conoce a Patricia, Alejandro y Marina  ·  %d/3" % [int(s.talked.Patricia) + int(s.talked.Alejandro) + int(s.talked.Marina)]
		"meeting": return "Ve al círculo central y participa en la primera asamblea."
		"materials": return "Recoge lona, varillas y piquetas  ·  %d/3" % s.resources()
		"build": return "Monta la tienda marcada · paso %d/4 · %d/25 tiendas" % [s.build_stage + 1, s.tents]
		"commissions": return "Forma %s (%d/3)" % [World.COMMISSION_NAMES[s.commissions], s.commissions]
		"expansion":
			var instruction: String = {
				"leaving":"Deja que vaya a buscar su tienda", "returning":"Espera a que vuelva con su tienda",
				"offer":"Habla con quien acaba de llegar", "assign":"Indica dónde montar la tienda",
				"placing":"La persona está montando su tienda", "resident":"Recibe a la persona que ocupará la tienda",
				"unload":"Guarda el material en la primera tienda", "close":"Cierra el día en Organización", "delegated":"Accesibilidad está recibiendo y alojando a las personas",
			}.get(s.delivery, "")
			return "%s · %d/%d tiendas" % [instruction, s.tents, World.tent_goal(s)]
		"finished": return "Día 2 cerrado · 50 tiendas y 8 comisiones" if s.day == 2 else "Día 1 cerrado"
		"return_tent": return "Vuelve a tu tienda para descansar."
		"wake": return "Ha amanecido. Sal de tu tienda con Acción o E."
	return "Explora la plaza."

func _draw() -> void:
	size_v = get_viewport_rect().size
	portrait = size_v.y > size_v.x * 1.15
	mobile_layout = touch_layout or portrait
	clickables.clear()
	draw_rect(Rect2(Vector2.ZERO,size_v), Color("e5dcc3"), true)
	if screen == "selector":
		draw_selector()
		return
	if screen == "title":
		draw_title()
		return
	world_rect = camera_world_rect()
	world.draw(self, s, world_rect, elapsed, walking, arrivals)
	draw_rect(world_rect, Color(0.12, 0.16, 0.34, evening_shade))
	if rest_time >= 0:
		var alpha := clampf(minf(rest_time / 0.7, (2.8 - rest_time) / 0.7), 0, 1)
		draw_rect(Rect2(Vector2.ZERO, size_v), Color(0.03, 0.05, 0.09, alpha))
		if alpha > 0.9:
			text(Vector2(0, size_v.y * 0.5), "Dentro de tu tienda" if s.phase != "wake" else "Amanece en la plaza", mobile_text_size(), Color("fff5df"), true, size_v.x, HORIZONTAL_ALIGNMENT_CENTER)
		return
	if map_open:
		draw_camp_map()
		return
	if not mobile_layout or (not mini and not dialogue and not paused and not commission_open and screen == "play"):
		draw_hud()
	if screen == "play":
		if not mini and not dialogue and not paused and not commission_open: draw_touch_controls()
		if toast_time > 0 and not dialogue and not mini and not paused and not commission_open: draw_toast()
		if commission_open:
			clickables.clear()
			if day_two_open:
				day_two_activity.draw(self)
			else:
				activity.draw(self)
		if mini:
			clickables.clear()
			draw_minigame()
		if dialogue:
			clickables.clear()
			draw_dialog()
		if paused:
			clickables.clear()
			draw_pause()
	elif screen == "result":
		clickables.clear()
		draw_result()

func camera_world_rect() -> Rect2:
	var plaza_size := Vector2(1280, 720)
	var fit_width := size_v.x / plaza_size.x
	var fit_height := size_v.y / plaza_size.y
	var scale := fit_width * 2.25
	if mobile_layout:
		var zoom := 3.8 if portrait else 3.4
		scale = maxf(fit_width * zoom, fit_height * 1.2)

	var world_size := plaza_size * scale
	var focus := size_v * Vector2(0.5, 0.49 if mobile_layout else 0.55)
	var offset := focus - s.player * scale
	offset.x = clampf(offset.x, size_v.x - world_size.x, 0.0)
	if world_size.y > size_v.y:
		offset.y = clampf(offset.y, size_v.y - world_size.y, 0.0)
	else:
		offset.y = maxf(0.0, (size_v.y - size_v.x * 0.5625) * 0.30)
	return Rect2(offset, world_size)

func panel(r: Rect2, fill: Color = Color("203d35"), border: Color = Color("eed29b")) -> void:
	draw_rect(r.grow(4), Color(0.11,0.17,0.15,0.32), true)
	draw_rect(r, fill, true)
	draw_rect(r, border, false, 2)

func text(pos: Vector2, value: String, font_size: int, color: Color = Color("fff5df"), bold: bool = false, width: float = -1, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> void:
	draw_string(BOLD if bold else BODY, pos, value, align, width, font_size, color)

func wrap_lines(value: String, font: Font, font_size: int, width: float) -> Array:
	var lines: Array = []
	var line := ""
	for word in value.split(" "):
		var candidate := word if line == "" else line + " " + word
		if font.get_string_size(candidate, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > width and line != "":
			lines.append(line)
			line = word
		else: line = candidate
	if line != "": lines.append(line)
	return lines

func paragraph(p: Vector2, value: String, width: float, font_size: int, color: Color = Color("fff5df"), line_height: float = 1.35) -> void:
	var y := p.y
	for line in wrap_lines(value, BODY, font_size, width):
		text(Vector2(p.x,y), line, font_size, color)
		y += font_size * line_height

func button(r: Rect2, label: String, id: String, highlight: bool = false, font_size: int = 0) -> void:
	var col := Color("f0bc66") if highlight else Color("36594b")
	draw_rect(r, col, true)
	draw_rect(r, Color("f7daa0"), false, 2)
	var fs := font_size if font_size > 0 else (22 if drawing_mini or not portrait else 36)
	text(Vector2(r.position.x, r.position.y + r.size.y * 0.63), label, fs, Color("27392f") if highlight else Color("fff5df"), true, r.size.x, HORIZONTAL_ALIGNMENT_CENTER)
	clickables.append({"rect":mini_hit(r) if drawing_mini else r, "id":id})

func mini_hit(r: Rect2) -> Rect2:
	return Rect2(mini_rect.position + r.position * mini_scale, r.size * mini_scale)

func draw_title() -> void:
	draw_texture_rect(COVER, Rect2(Vector2.ZERO,size_v), false)
	draw_rect(Rect2(Vector2.ZERO,size_v), Color(0.10,0.18,0.15,0.30), true)
	var w := minf(1130 if portrait else 590, size_v.x - 56)
	var x := 42.0 if not portrait else (size_v.x - w) / 2
	var y := 72.0 if not portrait else size_v.y * 0.16
	if portrait:
		draw_portrait_title(x, y, w)
		return
	panel(Rect2(x,y,w,520), Color(0.10,0.20,0.17,0.92))
	text(Vector2(x+30,y+45), "UN JUEGO DE PLAZA Y COMUNIDAD", 15, Color("f1c873"), true)
	draw_string(TITLE, Vector2(x+27,y+120), "ACAMPADA", HORIZONTAL_ALIGNMENT_LEFT, w-40, 53, Color("fff2d7"))
	draw_string(TITLE, Vector2(x+27,y+177), "VALÈNCIA", HORIZONTAL_ALIGNMENT_LEFT, w-40, 53, Color("f5bf6d"))
	paragraph(Vector2(x+32,y+220), "Un primer día para escucharnos, levantar refugio y hacer sitio a quienes llegan.", w-64, 22)
	var has_save := FileAccess.file_exists(State.SAVE_PATH)
	button(Rect2(x+32,y+300,w-64,54), "CONTINUAR PARTIDA" if has_save else "EMPEZAR EL DÍA 1", "continue" if has_save else "start", true)
	if has_save: button(Rect2(x+32,y+366,w-64,45), "NUEVA PARTIDA", "new")
	text(Vector2(x+34,y+448), "WASD / flechas para caminar   ·   E para interactuar", 16, Color("d4e0cb"))
	text(Vector2(x+34,y+476), "En móvil: joystick y botón de acción", 16, Color("d4e0cb"))
	text(Vector2(x+34,y+503), "Licencias de código abierto", 14, Color("eecb89"))
	clickables.append({"rect":Rect2(x+30,y+482,240,32),"id":"licenses"})
	if confirm_new:
		draw_rect(Rect2(Vector2.ZERO,size_v), Color(0.04,0.10,0.08,0.75), true)
		var r := Rect2(size_v.x/2-260,size_v.y/2-135,520,270)
		panel(r, Color("f8edce"), Color("29453a"))
		text(r.position+Vector2(25,48), "¿Empezar de nuevo?", 27, Color("29453a"), true)
		paragraph(r.position+Vector2(25,88), "Se borrará la partida guardada en este dispositivo.", 470, 18, Color("405446"))
		clickables.clear()
		button(Rect2(r.position+Vector2(25,140),Vector2(470,45)), "SÍ, NUEVA PARTIDA", "confirm_new", true)
		button(Rect2(r.position+Vector2(25,200),Vector2(470,45)), "CANCELAR", "cancel_new")

func draw_portrait_title(x: float, y: float, w: float) -> void:
	var has_save := FileAccess.file_exists(State.SAVE_PATH)
	panel(Rect2(x, y, w, 760), Color(0.10,0.20,0.17,0.92))
	draw_string(TITLE, Vector2(x + 45, y + 125), "ACAMPADA", HORIZONTAL_ALIGNMENT_LEFT, w - 90, 96, Color("fff2d7"))
	draw_string(TITLE, Vector2(x + 45, y + 230), "VALÈNCIA", HORIZONTAL_ALIGNMENT_LEFT, w - 90, 96, Color("f5bf6d"))
	paragraph(Vector2(x + 48, y + 318), "Un primer día para escucharnos, levantar refugio y hacer sitio a quienes llegan.", w - 96, 49)
	if confirm_new:
		paragraph(Vector2(x + 48, y + 470), "¿Borrar la partida guardada y empezar de nuevo?", w - 96, 48)
		button(Rect2(x + 48, y + 560, (w - 120) * 0.5, 140), "Sí, empezar", "confirm_new", true, 46)
		button(Rect2(x + 60 + (w - 120) * 0.5, y + 560, (w - 120) * 0.5, 140), "Cancelar", "cancel_new", false, 46)
		return
	button(Rect2(x + 48, y + 440, w - 96, 140), "Continuar partida" if has_save else "Empezar el día 1", "continue" if has_save else "start", true, 52)
	if has_save:
		button(Rect2(x + 48, y + 600, (w - 120) * 0.5, 136), "Nueva partida", "new", false, 46)
	var license_x := x + 72 + (w - 120) * 0.5 if has_save else x + 48
	var license_width := (w - 120) * 0.5 if has_save else w - 96
	button(Rect2(license_x, y + 600, license_width, 136), "Licencias", "licenses", false, 46)

func draw_hud() -> void:
	if mobile_layout:
		draw_mobile_hud()
	else:
		panel(Rect2(14,14,size_v.x-28,62), Color(0.10,0.20,0.17,0.95))
		text(Vector2(32,40), "ACAMPADA", 19, Color("f6ce80"), true)
		text(Vector2(32,62), "DÍA %d · %s · %02d:00" % [s.day, s.daylight(), s.clock_hour()], 13, Color("fff3d9"), true)
		text(Vector2(225,51), "VIDA %d    ENERGÍA %d    RESPETO %d    CAJA %d €    RECURSOS %d    BIENESTAR %d    PERSONAS %d" % [s.health,s.energy,s.respect,s.cash,s.resources(),s.wellbeing,s.people], 16, Color("fff6e2"), true)
		button(Rect2(size_v.x-105,23,76,42), "Ⅱ", "pause")
		if s.has_day_two_commission(State.NETWORKS): button(Rect2(20,88,130,50), "Teléfono", "phone")
		panel(Rect2(size_v.x-327,94,305,94), Color(0.12,0.23,0.19,0.91))
		text(Vector2(size_v.x-309,121), "AHORA EN LA PLAZA", 13, Color("eac379"), true)
		paragraph(Vector2(size_v.x-309,145), objective(), 268, 16)

func mobile_text_size() -> int:
	return 52 if portrait else 36

func draw_mobile_hud() -> void:
	var fs := mobile_text_size()
	var margin := fs * 0.55
	var width := minf(size_v.x - margin * 2, fs * 24.0)
	if not hud_expanded:
		return
	var y := margin
	var step := fs * 1.28
	var content_width := width - margin * 2
	var status := "Día %d · %s · %02d:00   |   Vida %d · Energía %d · Respeto %d · Caja %d € · Recursos %d · Bienestar %d · Personas %d" % [
		s.day, s.daylight(), s.clock_hour(), s.health, s.energy, s.respect, s.cash, s.resources(), s.wellbeing, s.people
	]
	var goal_lines := wrap_lines(objective(), BOLD, fs, content_width)
	var status_size := roundi(fs * 0.9)
	var status_lines := wrap_lines(status, BODY, status_size, content_width)
	panel(Rect2(margin, y, width, margin * 2 + step * (goal_lines.size() + status_lines.size()) + 12), Color("203d35"))
	var baseline := y + margin + fs
	for line in goal_lines:
		text(Vector2(margin * 2, baseline), line, fs, Color("fff2d7"), true)
		baseline += step
	baseline += 12
	for line in status_lines:
		text(Vector2(margin * 2, baseline), line, status_size, Color("f3ce89"))
		baseline += step

func toggle_map() -> void:
	map_open = not map_open
	reset_joystick()
	clickables.clear()
	queue_redraw()

func draw_camp_map() -> void:
	draw_rect(Rect2(Vector2.ZERO, size_v), Color(0.04,0.09,0.07,0.94))
	var fs := mobile_text_size() if mobile_layout else 20
	var points := world.map_locations(s, elapsed)
	var columns := 2 if portrait else 3
	var rows := ceili(float(points.size()) / columns)
	var margin := fs * 0.65
	var step := fs * 1.65
	var top := fs * 3
	var width := minf(size_v.x - margin * 2, (size_v.y - top - (rows + 1) * step) * 16.0 / 9.0)
	var start := Vector2((size_v.x - width) / 2.0, top)
	var scale := width / 1280.0
	var map_rect := Rect2(start, Vector2(width,720 * scale))
	text(Vector2(margin, fs * 1.65), "Mapa · %d/%d tiendas" % [s.tents, World.tent_goal(s)], fs)
	button(Rect2(size_v.x - margin - fs * 5, margin, fs * 5, fs * 1.9), "Cerrar", "map", false, fs)
	draw_texture_rect(World.PLAZA, map_rect, false)
	for i in range(World.pitch_count(s)):
		var point := start + World.pitch_at(s,i) * scale
		draw_circle(point, 3.0 * scale, Color("b0db96"))
	var offset_counts := {}
	var marker_font := maxi(13, roundi(fs * 0.52))
	var radius := marker_font * 0.8
	var legend_width := (size_v.x - 2 * margin) / columns
	for i in range(points.size()):
		var item := points[i]
		var point: Vector2 = start + item.pos * scale
		var count: int = offset_counts.get(point,0)
		offset_counts[point] = count + 1
		if count > 0: point.x += count * radius * 2
		var color := Color("f5c172") if item.kind == "goal" else (Color("a3d58b") if item.kind == "built" else Color("8bd5ed"))
		draw_circle(point, radius, Color("172723"))
		draw_arc(point, radius, 0, TAU, 26, color, 2)
		text(point + Vector2(-radius, marker_font * 0.37), str(i+1), marker_font, color, true, radius * 2, HORIZONTAL_ALIGNMENT_CENTER)
		var label_pos := Vector2(margin + (i % columns) * legend_width, map_rect.end.y + (i / columns + 1) * step)
		text(label_pos, "%d  %s" % [i+1,item.label], roundi(fs * 0.85), color, true, legend_width - 8)

func mobile_button_row() -> Rect2:
	var fs := mobile_text_size()
	var margin := fs * 0.55
	var height := fs * 3.5
	return Rect2(margin, size_v.y - margin - height, size_v.x - margin * 2, height)

func draw_touch_controls() -> void:
	if not mobile_layout:
		text(Vector2(24,size_v.y-21), "CAMINAR: WASD / FLECHAS    ·    INTERACTUAR: E   ·   MAPA: M", 13, Color("fff5df"), true)
		return
	var fs := mobile_text_size()
	var row := mobile_button_row()
	draw_mobile_controls(row, not dialogue)
	if dialogue:
		return
	var gap := fs * 0.35
	var pause_width := fs * 4.3
	button(Rect2(row.position, Vector2(row.size.x - gap - pause_width, row.size.y)), "Ocultar información" if hud_expanded else "Ver objetivo y estado", "hud_toggle", false, fs)
	button(Rect2(row.end.x - pause_width, row.position.y, pause_width, row.size.y), "Pausa", "pause", false, fs)

func draw_mobile_controls(row: Rect2, enabled: bool) -> void:
	var fs := mobile_text_size()
	var gap := fs * 0.45
	joystick_radius = fs * 2.55
	var right_width := fs * 5.35
	var top := row.position.y - gap - joystick_radius * 2
	joystick_center = Vector2(row.position.x + joystick_radius, top + joystick_radius)
	var base := Color(0.10,0.21,0.18,0.83 if enabled else 0.45)
	draw_circle(joystick_center, joystick_radius, base)
	draw_arc(joystick_center, joystick_radius, 0, TAU, 48, Color("eed29b"), 3)
	draw_circle(joystick_center + joystick_vector * joystick_radius * 0.55, joystick_radius * 0.39, Color("d4bf91") if enabled else Color("968c72"))
	if enabled:
		clickables.append({"rect":Rect2(joystick_center - Vector2.ONE * joystick_radius, Vector2.ONE * joystick_radius * 2), "id":"joystick"})
	var h := joystick_radius - gap * 0.5
	var x := row.end.x - right_width
	button(Rect2(x,top,right_width,h), "Mapa", "map", false, fs)
	if s.has_day_two_commission(State.NETWORKS) and enabled:
		button(Rect2(x-right_width-gap,top,right_width,h), "Teléfono", "phone", false, roundi(fs * 0.9))
	button(Rect2(x,top+h+gap,right_width,h), "Acción", "action", enabled, fs)
	if not enabled:
		draw_rect(Rect2(x,top,right_width,joystick_radius * 2), Color(0.05,0.11,0.09,0.45))
		clickables.pop_back()
		clickables.pop_back()

func reset_joystick() -> void:
	joystick_pointer = -2
	joystick_vector = Vector2.ZERO

func update_joystick(pos: Vector2) -> void:
	var motion := (pos - joystick_center) / (joystick_radius * 0.65)
	var strength := clampf((motion.length() - 0.15) / 0.85, 0.0, 1.0)
	joystick_vector = motion.normalized() * strength

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		reset_joystick()

func draw_toast() -> void:
	if mobile_layout:
		if hud_expanded:
			return
		var fs := mobile_text_size()
		var margin := fs * 0.55
		var width := minf(size_v.x - margin * 2, fs * 24.0)
		var y_top := margin
		var lines := wrap_lines(toast, BOLD, fs, width - margin * 2)
		panel(Rect2(margin, y_top, width, margin * 2 + lines.size() * fs * 1.25))
		for i in range(lines.size()):
			text(Vector2(margin * 2, y_top + margin + fs * (1.0 + i * 1.25)), lines[i], fs, Color("fff4d7"), true)
		return
	var y := minf(world_rect.end.y - 68, size_v.y - 95) if not portrait else size_v.y * 0.72
	var w := 690.0 if not portrait else 1100.0
	panel(Rect2((size_v.x-w)/2,y,w,44 if not portrait else 65), Color(0.12,0.24,0.19,0.94))
	text(Vector2((size_v.x-w)/2+12,y+(29 if not portrait else 43)), toast, 16 if not portrait else 24, Color("fff4d7"), true, w-24, HORIZONTAL_ALIGNMENT_CENTER)

func draw_dialog() -> void:
	if mobile_layout:
		draw_mobile_dialog()
		return
	draw_rect(Rect2(Vector2.ZERO,size_v), Color(0.05,0.11,0.09,0.42), true)
	var w := 890.0
	var h := 196.0
	var x := (size_v.x-w)/2
	var y := size_v.y-h-45
	var r := Rect2(x,y,w,h)
	panel(r, Color("f8edce"), Color("243d33"))
	text(Vector2(x+25,y+37), dialogue_speaker, 18 if not portrait else 34, Color("b65c3e"), true)
	paragraph(Vector2(x+25,y+72), dialogue_text, w-50, 20 if not portrait else 35, Color("273f35"))
	if choosing:
		if portrait:
			button(Rect2(x+24,y+h-225,w-48,90), "1 · Cuidar a las personas", "choice0", true)
			button(Rect2(x+24,y+h-115,w-48,90), "2 · Reunir recursos", "choice1")
		else:
			var by := y+h-62
			button(Rect2(x+24,by,(w-60)/2,45), "1 · Cuidar a las personas", "choice0", true)
			button(Rect2(x+36+(w-60)/2,by,(w-60)/2,45), "2 · Reunir recursos", "choice1")

	else:
		text(Vector2(x+25,y+h-22), "E / ESPACIO  ·  CONTINUAR", 14 if not portrait else 29, Color("6b7d69"), true)
		clickables.append({"rect":r,"id":"dialog"})

func draw_mobile_dialog() -> void:
	var fs := mobile_text_size()
	var margin := fs * 0.55
	var width := minf(size_v.x - margin * 2.0, fs * 25.0)
	var x := (size_v.x - width) * 0.5
	var content_width := width - margin * 2
	var line_height := fs * 1.3
	var lines := wrap_lines(dialogue_text, BODY, fs, content_width)
	panel(Rect2(x, margin, width, margin * 2 + line_height * (lines.size() + 1)), Color("f8edce"), Color("243d33"))
	text(Vector2(x + margin, margin * 2 + fs), dialogue_speaker, fs, Color("a14b33"), true)
	for i in range(lines.size()):
		text(Vector2(x + margin, margin * 2 + fs + line_height * (i + 1)), lines[i], fs, Color("273f35"))
	var row := mobile_button_row()
	draw_touch_controls()
	if choosing:
		var gap := fs * 0.35
		var choice_width := (row.size.x - gap) * 0.5
		button(Rect2(row.position, Vector2(choice_width, row.size.y)), "Cuidar a las personas", "choice0", true, roundi(fs * 0.83))
		button(Rect2(row.position + Vector2(choice_width + gap, 0), Vector2(choice_width, row.size.y)), "Reunir recursos", "choice1", false, roundi(fs * 0.83))
	else:
		button(row, "Continuar", "dialog", true, fs)

func draw_pause() -> void:
	draw_rect(Rect2(Vector2.ZERO,size_v), Color(0.04,0.10,0.08,0.75), true)
	var layout := Vector2(470, 386)
	mini_scale = minf((size_v.x - 32) / layout.x, (size_v.y - 32) / layout.y)
	if not mobile_layout: mini_scale = minf(1.0, mini_scale)
	mini_rect = Rect2((size_v - layout * mini_scale) * 0.5, layout * mini_scale)
	draw_set_transform(mini_rect.position, 0, Vector2.ONE * mini_scale)
	drawing_mini = true
	panel(Rect2(Vector2.ZERO, layout))
	text(Vector2(26,54), "EN PAUSA", 32, Color("f1c578"), true)
	paragraph(Vector2(26,95), "El progreso de prueba se pierde al volver al selector." if test_build else "Tu progreso se guarda automáticamente en este dispositivo.", 418, 22)
	button(Rect2(26,140,418,62), "CONTINUAR", "unpause", true)
	button(Rect2(26,215,418,62), "PUNTOS DE PRUEBA" if test_build else "VOLVER AL INICIO", "title")
	button(Rect2(26,290,418,62), "LICENCIAS", "licenses")
	drawing_mini = false
	draw_set_transform(Vector2.ZERO)

func draw_result() -> void:
	draw_rect(Rect2(Vector2.ZERO,size_v), Color(0.04,0.11,0.08,0.78), true)
	var r := Rect2(size_v.x/2-355, size_v.y/2-235, 710, 470)
	panel(r, Color("f8edce"), Color("233f34"))
	text(r.position+Vector2(36,50), "LA PLAZA YA NO ESTÁ VACÍA", 17, Color("b45f40"), true)
	text(r.position+Vector2(36,102), "Día %d completado" % s.day, 38, Color("263e32"), true)
	paragraph(r.position+Vector2(36,153), "La plaza tiene 50 tiendas y ocho comisiones. Accesibilidad se encarga de recibir y alojar a las personas." if s.day == 2 else "Hay 25 tiendas, incluida la de material común. Organización y Comunicación tienen puntos de reunión y Cocina ya cuenta con una mesa y cajas de comida.", 635, 21, Color("314a3c"))
	text(r.position+Vector2(36,264), "RESPETO %d    ·    PERSONAS %d    ·    ALOJAMIENTO %d" % [s.respect,s.people,s.capacity], 18, Color("63745b"), true)
	button(Rect2(r.position+Vector2(36,302),Vector2(638,55)), "SEGUIR EXPLORANDO", "explore", true)
	button(Rect2(r.position+Vector2(36,375),Vector2(638,45)), "VOLVER AL INICIO", "title")

func draw_minigame() -> void:
	draw_rect(Rect2(Vector2.ZERO,size_v), Color(0.04,0.10,0.08,0.75), true)
	var vertical := mobile_layout and portrait
	var panel_size := Vector2(440, 690) if vertical else Vector2(820, 500)
	mini_scale = minf((size_v.x - 24) / panel_size.x, (size_v.y - 24) / panel_size.y)
	if not mobile_layout:
		mini_scale = minf(1.0, mini_scale)
	mini_rect = Rect2((size_v - panel_size * mini_scale) * 0.5, panel_size * mini_scale)
	draw_set_transform(mini_rect.position, 0.0, Vector2.ONE * mini_scale)
	drawing_mini = true
	if vertical:
		draw_portrait_tent()
	else:
		draw_landscape_tent()
	drawing_mini = false
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func draw_landscape_tent() -> void:
	var p := Vector2.ZERO
	panel(Rect2(0,0,820,500), Color("f8edce"), Color("29453a"))
	var names := ["1. EXTIENDE LA LONA", "2. ENSAMBLA LAS VARILLAS", "3. LEVANTA LA ESTRUCTURA", "4. ASEGURA LAS PIQUETAS"]
	text(p+Vector2(28,42), names[s.build_stage], 25, Color("2a4839"), true)
	button(Rect2(p+Vector2(720,12),Vector2(75,44)), "X", "mini_close")
	if s.build_stage == 0:
		paragraph(p+Vector2(28,76), "Arrastra la lona al círculo. En PC: flechas y E.", 750, 22, Color("405446"))
		draw_circle(p+Vector2(560,235), 75, Color(0.91,0.73,0.36,0.24))
		draw_arc(p+Vector2(560,235), 70, 0, TAU, 40, Color("be8e3e"), 4)
		draw_texture_rect(World.TARP, Rect2(p+mini_piece-Vector2(55,55),Vector2(110,110)), false)
		text(p+Vector2(450,355), "DESTINO", 15, Color("927339"), true, 220, HORIZONTAL_ALIGNMENT_CENTER)
		button(Rect2(p+Vector2(290,406),Vector2(240,50)), "COLOCAR · E", "mini_action", true)
	elif s.build_stage == 1:
		paragraph(p+Vector2(28,76), "Dos varillas: pulsa cuando el indicador esté en verde.", 750, 22, Color("405446"))
		draw_texture_rect(World.FRAMED, Rect2(p+Vector2(320,105),Vector2(180,150)), false)
		draw_rect(Rect2(p+Vector2(130,285),Vector2(560,30)), Color("cdbf9e"), true)
		draw_rect(Rect2(p+Vector2(298,285),Vector2(224,30)), Color("77a878"), true)
		var needle := (sin(elapsed*2.9)+1.0)/2.0
		draw_rect(Rect2(p+Vector2(130+needle*560-5,275),Vector2(10,50)), Color("be5d40"), true)
		text(p+Vector2(0,355), "ENCAJADAS %d / 2" % mini_success, 18, Color("345445"), true, 820, HORIZONTAL_ALIGNMENT_CENTER)
		button(Rect2(p+Vector2(290,406),Vector2(240,50)), "ENCAJAR · E", "mini_action", true)
	elif s.build_stage == 2:
		paragraph(p+Vector2(28,76), "Pulsa E o el botón repetidamente para levantar la tienda. La barra baja si paras.", 750, 22, Color("405446"))
		draw_texture_rect(World.RAISED, Rect2(p+Vector2(310,100),Vector2(200,180)), false)
		draw_rect(Rect2(p+Vector2(145,305),Vector2(530,24)), Color("cabd9c"), true)
		draw_rect(Rect2(p+Vector2(145,305),Vector2(530*clampf(mini_lift/LIFT_GOAL,0,1),24)), Color("64a276"), true)
		button(Rect2(p+Vector2(265,386),Vector2(290,65)), "PULSA RÁPIDO · E", "mini_action", true)
	else:
		paragraph(p+Vector2(28,76), "Toca las cuatro piquetas. En PC: flechas y E.", 750, 22, Color("405446"))
		draw_texture_rect(World.RAISED, Rect2(p+Vector2(292,112),Vector2(236,220)), false)
		var pts := [Vector2(250,160),Vector2(570,160),Vector2(250,327),Vector2(570,327)]
		for i in range(4):
			var pt: Vector2 = p+pts[i]
			draw_circle(pt, 25, Color("68a577") if mini_pegs[i] else Color("e9b15f"))
			draw_arc(pt, 29 if i == mini_selected else 25, 0, TAU, 28, Color("354f3d"), 3)
			text(pt+Vector2(-20,7), "OK" if mini_pegs[i] else str(i+1), 20, Color("263e32"), true, 40, HORIZONTAL_ALIGNMENT_CENTER)
			clickables.append({"rect":mini_hit(Rect2(pt-Vector2(35,35),Vector2(70,70))),"id":"peg%d" % i})
		button(Rect2(p+Vector2(290,406),Vector2(240,50)), "ASEGURAR · E", "mini_action", true)
	if toast_time > 0: text(p+Vector2(28,390), toast, 15, Color("a05739"), true)
	text(p+Vector2(28,478), "ESC: CERRAR Y CONTINUAR DESPUÉS", 13, Color("657b69"), true)
func draw_portrait_tent() -> void:
	var ink := Color("29453a")
	panel(Rect2(0,0,440,690), Color("f8edce"), ink)
	var headings := ["Extiende la lona", "Ensambla las varillas", "Levanta la tienda", "Asegura las piquetas"]
	var instructions := ["Arrastra la lona al círculo.", "Pulsa cuando el indicador esté en verde.", "Pulsa rápido varias veces. La barra baja si paras.", "Toca las cuatro piquetas."]
	text(Vector2(24,48), headings[s.build_stage], 28, ink, true)
	button(Rect2(365,12,55,55), "×", "mini_close")
	paragraph(Vector2(24,98), instructions[s.build_stage], 392, 24, ink)
	var labels := ["Colocar", "Encajar", "Pulsa rápido", "Asegurar"]
	match s.build_stage:
		0:
			var destination := tarp_panel_point(Vector2(560,235))
			draw_circle(destination, 54, Color("efdfbb"))
			draw_arc(destination, 53, 0, TAU, 36, Color("be8e3e"), 4)
			draw_texture_rect(World.TARP, Rect2(tarp_panel_point(mini_piece) - Vector2(55,55), Vector2(110,110)), false)
		1, 2:
			var aligning := s.build_stage == 1
			draw_texture_rect(World.FRAMED if aligning else World.RAISED, Rect2(110,168,220,220), false)
			draw_rect(Rect2(32,433,376,32), Color("cdbf9e"))
			if aligning:
				draw_rect(Rect2(145,433,150,32), Color("77a878"))
				var needle := (sin(elapsed * 2.9) + 1.0) * 0.5
				draw_rect(Rect2(32 + needle * 376 - 4,425,8,48), Color("be5d40"))
				text(Vector2(32,518), "Varillas encajadas: %d/2" % mini_success, 24, ink)
			else:
				draw_rect(Rect2(32,433,376 * clampf(mini_lift / LIFT_GOAL,0,1),32), Color("64a276"))
		3:
			draw_texture_rect(World.RAISED, Rect2(120,196,200,200), false)
			var points := [Vector2(85,220), Vector2(355,220), Vector2(85,430), Vector2(355,430)]
			for i in range(points.size()):
				var point: Vector2 = points[i]
				draw_circle(point, 32, Color("68a577") if mini_pegs[i] else Color("e9b15f"))
				draw_arc(point, 34, 0, TAU, 28, ink, 3)
				text(point + Vector2(-32,9), "OK" if mini_pegs[i] else str(i + 1), 26, ink, true, 64, HORIZONTAL_ALIGNMENT_CENTER)
				clickables.append({"rect":mini_hit(Rect2(point - Vector2(37,37), Vector2(74,74))), "id":"peg%d" % i})
	if toast_time > 0:
		paragraph(Vector2(24,541), toast, 392, 19, Color("a05739"))
	button(Rect2(24,594,392,70), labels[s.build_stage], "mini_action", true, 29)

func tarp_panel_point(point: Vector2) -> Vector2:
	if mobile_layout and portrait:
		return Vector2((point.x - 410.0) * 0.52 + 220.0, point.y + 70.0)
	return point

func tarp_drag_point(pos: Vector2) -> Vector2:
	var point := (pos - mini_rect.position) / mini_scale
	if mobile_layout and portrait:
		return Vector2((point.x - 220.0) / 0.52 + 410.0, point.y - 70.0)
	return point

func _input(event: InputEvent) -> void:
	if rest_time >= 0: return
	if event is InputEventKey and event.pressed and not event.echo:
		if commission_open and not paused:
			if event.keycode == KEY_ESCAPE:
				if test_build: paused = true
				else: commission_open = false
			else:
				if day_two_open: day_two_activity.key(event.keycode)
				else: activity.key(event.keycode)
			return
		if event.keycode == KEY_M and screen == "play" and not mini and not dialogue and not paused:
			toggle_map()
			return
		if map_open:
			if event.keycode == KEY_ESCAPE: toggle_map()
			return
		if event.keycode == KEY_ESCAPE:
			if paused: paused = false
			elif test_build and screen == "play" and not dialogue: paused = true
			elif mini: mini = false
			elif dialogue: pass
			elif screen == "play": paused = not paused
			return
		if choosing and event.keycode in [KEY_1,KEY_KP_1]: choose_assembly(0); return
		if choosing and event.keycode in [KEY_2,KEY_KP_2]: choose_assembly(1); return
		if mini and s.build_stage == 3 and event.keycode in [KEY_LEFT,KEY_RIGHT,KEY_UP,KEY_DOWN,KEY_A,KEY_D,KEY_W,KEY_S]:
			mini_selected = (mini_selected + 1) % 4
			return
		if event.keycode in [KEY_E,KEY_SPACE,KEY_ENTER,KEY_KP_ENTER]:
			if screen == "title" and not confirm_new: start_game(FileAccess.file_exists(State.SAVE_PATH))
			elif screen == "result":
				screen = "play"
			else: interact()
			return
	if event is InputEventScreenTouch:
		if event.pressed and not event.canceled: pointer_down(event.position, event.index)
		else: pointer_up(event.position, event.index)
	elif event is InputEventScreenDrag:
		if commission_open and day_two_open and not paused:
			day_two_activity.aim(event.relative / mini_scale, event.index)
		if event.index == joystick_pointer: update_joystick(event.position)
		elif dragging and mini and s.build_stage == 0: mini_piece = tarp_drag_point(event.position)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed: pointer_down(event.position, -1)
		else: pointer_up(event.position, -1)
	elif event is InputEventMouseMotion:
		if commission_open and day_two_open and not paused:
			day_two_activity.aim(event.relative / mini_scale, -1)
		if joystick_pointer == -1: update_joystick(event.position)
		elif dragging and mini and s.build_stage == 0: mini_piece = tarp_drag_point(event.position)

func pointer_down(pos: Vector2, index: int) -> void:
	if commission_open and day_two_open and not paused and mini_scale > 0:
		if day_two_activity.begin_aim((pos - mini_rect.position) / mini_scale, index): return
	if mini and not paused and s.build_stage == 0 and pos.distance_to(mini_rect.position + tarp_panel_point(mini_piece) * mini_scale) < 75*mini_scale:
		dragging = true
		return
	for entry in clickables:
		if entry.rect.has_point(pos):
			var id: String = entry.id
			if commission_open and not paused:
				if id == "commission_close": commission_open = false
				elif id == "pause": paused = true
				elif id.begins_with("activity:"):
					if day_two_open: day_two_activity.action(id.trim_prefix("activity:"))
					else: activity.action(id.trim_prefix("activity:"))
				return
			match id:
				"start": start_game(false)
				"continue": start_game(true)
				"new": confirm_new = true
				"confirm_new": confirm_new = false; start_game(false)
				"cancel_new": confirm_new = false
				"licenses": LICENSES.open(self)
				"hud_toggle": hud_expanded = not hud_expanded; queue_redraw()
				"pause": paused = true; s.save_game()
				"unpause": paused = false
				"title":
					paused = false
					commission_open = false
					day_two_open = false
					mini = false
					clickables.clear()
					screen = "selector" if test_build else "title"
					s.save_game()
				"explore": screen = "play"
				"dialog": close_dialog()
				"choice0": choose_assembly(0)
				"choice1": choose_assembly(1)
				"joystick":
					if joystick_pointer == -2 and pos.distance_to(joystick_center) <= joystick_radius:
						joystick_pointer = index
						update_joystick(pos)
				"action": interact()
				"map": toggle_map()
				"phone": open_phone()
				"mini_action": mini_action()
				"mini_close": mini = false
				_:
					if id.begins_with("checkpoint:") and test_build:
						load_checkpoint(int(id.get_slice(":", 1)))
					elif id.begins_with("peg"):
						mini_selected = int(id.substr(3))
						mini_action()
			return

func pointer_up(_pos: Vector2, index: int) -> void:
	if commission_open and day_two_open: day_two_activity.release_aim(index)
	if index == joystick_pointer:
		reset_joystick()
	if dragging:
		dragging = false
		if mini and s.build_stage == 0 and mini_piece.distance_to(Vector2(560,235)) < 65: complete_build_stage()


func draw_selector() -> void:
	draw_texture_rect(COVER, Rect2(Vector2.ZERO, size_v), false)
	var labels := ["Cierre del Día 1", "Regreso a tu tienda", "Entrar y descansar", "Amanecer", "Segunda asamblea"] + DayTwo.NAMES + ["Montaje de tienda", "Almacén", "Cocina"]
	var cols := 2 if size_v.x > size_v.y else 1
	var layout := Vector2(430 * cols + 20, 78 + ceili(float(labels.size()) / cols) * 58)
	mini_scale = minf((size_v.x - 20) / layout.x, (size_v.y - 20) / layout.y)
	mini_rect = Rect2((size_v - layout * mini_scale) / 2, layout * mini_scale)
	draw_set_transform(mini_rect.position, 0, Vector2.ONE * mini_scale)
	drawing_mini = true
	panel(Rect2(Vector2.ZERO, layout))
	text(Vector2(24, 44), "Saltar a un punto de prueba", 29, Color("fff5df"), true)
	for i in range(labels.size()):
		button(Rect2(20 + (i % cols) * 430, 64 + (i / cols) * 58, 410, 51), labels[i], "checkpoint:%d" % i, false, 22)
	drawing_mini = false
	draw_set_transform(Vector2.ZERO)

func load_checkpoint(index: int) -> void:
	if not test_build or index < 0 or index > 12: return
	s = State.new()
	s.practice = true
	s.tents = 25
	s.commissions = 3
	s.material_boxes = 4
	s.capacity = 48
	s.phase = "return_tent"
	s.player = World.clear_spot(World.ORGANIZATION, s)
	paused = false
	map_open = false
	mini = false
	dialogue = false
	choosing = false
	commission_open = false
	day_two_open = false
	rest_time = -1
	screen = "play"
	if index == 0:
		s.phase = "expansion"
		s.delivery = "close"
	elif index == 2 or index == 3:
		s.player = World.tent_door(s)
		if index == 3: s.phase = "wake"
	elif index >= 10:
		s.tents = [0, 6, 12][index - 10]
		s.commissions = 1 if index == 12 else 0
		s.material_boxes = 4 if index == 12 else 0
		s.capacity = maxi(0, s.tents - 1) * 2
		if index == 10:
			s.phase = "build"
			s.player = World.SITE
			interact()
		elif index == 11:
			s.phase = "expansion"
			s.delivery = "unload"
			s.player = World.clear_spot(World.SITE, s)
			interact()
		else:
			s.phase = "commissions"
			s.player = World.KITCHEN
			interact()
	elif index >= 4:
		s.day = 2
		s.phase = "meeting_two" if index == 4 else "commissions_two"
		if index == 4:
			s.player = World.clear_spot(World.MEETING, s)
		else:
			var target := index - 5
			for previous in State.DAY_TWO_ORDER:
				if previous == target: break
				s.finish_day_two_commission(previous)
				s.tents += 5
				s.capacity += 10
			s.player = World.clear_spot(DayTwo.POINTS[target], s)
			open_day_two_activity(DayTwo.KINDS[target])
	evening_shade = s.light_level()
