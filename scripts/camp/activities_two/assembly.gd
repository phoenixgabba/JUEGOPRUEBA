extends "res://scripts/camp/activities_two/session.gd"

const MAT_ART := preload("res://assets/visual/assembly_mat.png")
const AXES := ["Acceso", "Cuidados", "Difusión", "Descanso"]
const NAMES := ["Patricia", "Alejandro", "Marina", "Núria"]
const EVENTS := ["Redes", "Seguridad", "Convivencia", "Punto sanitario", "Accesibilidad", "Acuerdo final"]
const TOPICS := [
	["Hace falta señalizar la entrada.", "Organicemos un punto de apoyo.", "Compartamos el boletín.", "Necesitamos turnos de descanso."],
	["Dejemos un corredor libre.", "Acompañemos a quien lo necesite.", "Expliquemos cómo pedir ayuda.", "Repartamos las guardias."],
	["No bloqueemos los pasos.", "Repartamos agua y materiales.", "Informemos de los cambios.", "Reservemos una zona tranquila."],
	["Despejemos la ruta sanitaria.", "Preparemos un puesto de cuidados.", "Avisemos dónde pedir asistencia.", "Hagamos relevos en el puesto."],
	["Revisemos los recorridos.", "Acompañemos a quien pida apoyo.", "Pongamos información accesible.", "Incluyamos zonas de reposo."],
	["Mantengamos los accesos libres.", "Garanticemos apoyo mutuo.", "Compartamos los acuerdos.", "Organicemos descansos."]
]
const CHOICES := [
	["Ruta libre y señalizada", "Puesto de apoyo mutuo", "Boletín e información", "Turnos y zona tranquila"],
	["Corredor de seguridad", "Equipo de acompañamiento", "Punto de información", "Relevo de guardias"],
	["Paso entre tiendas", "Reparto de material", "Panel de avisos", "Espacio de descanso"],
	["Ruta sanitaria libre", "Puesto de cuidados", "Mapa de asistencia", "Relevos sanitarios"],
	["Recorrido accesible", "Equipo de apoyo", "Señalización accesible", "Zona de reposo"],
	["Accesos despejados", "Apoyo mutuo", "Acta abierta", "Turnos sostenibles"]
]
const SEATS := [Vector2(105,185),Vector2(335,185),Vector2(105,292),Vector2(335,292)]
var chapter := 0
var phase := "queue"
var queue: Array[int] = []
var heard: Array[int] = []
var speaker := -1
var speech := 0.0
var duration := 3.2
var patience := 1.0
var interruption := -1
var interruption_time := 0.0
var interruption_pending := false
var round_good := 0
var round_errors := 0
var total_good := 0
var total_errors := 0
var round_support := 0
var consensus := 0
var tally := [0,0,0,0]
var votes: Array[int] = []
var vote_timer := 0.0
var chosen := -1

func initialize(seed_value: int, plan: String) -> void:
	super.initialize(seed_value,plan)
	title = "Asamblea · toma la palabra"
	help = "Pulsa a quien levanta la mano para darle turno. Cierra el turno en la zona verde y media si alguien interrumpe."
	setup_round()

func setup_round() -> void:
	phase = "queue"
	queue.clear()
	heard.clear()
	votes.clear()
	speaker = -1
	interruption = -1
	interruption_pending = false
	interruption_time = 0.0
	patience = 1.0
	round_good = 0
	round_errors = 0
	chosen = -1
	var order: Array[int] = [0,1,2,3]
	for i in range(3,0,-1):
		var j := rng.randi_range(0,i)
		var saved := order[i]
		order[i] = order[j]
		order[j] = saved
	for i in range(3):
		queue.append(order[i])
	notice = "Da paso a la primera mano levantada."

func start_speech(person: int) -> void:
	queue.erase(person)
	speaker = person
	phase = "speech"
	speech = 0.0
	duration = maxf(2.7,3.8-float(chapter)*0.15)
	interruption = -1
	interruption_time = 0.0
	interruption_pending = chapter > 0 or heard.size() == 1
	notice = TOPICS[chapter][speaker]

func close_speech(good: bool) -> void:
	if good:
		round_good += 1
		total_good += 1
	else:
		round_errors += 1
		total_errors += 1
	heard.append(speaker)
	speaker = -1
	interruption = -1
	interruption_pending = false
	if queue.is_empty():
		phase = "vote"
		votes.assign(heard)
		notice = "¡A votar! Elige una propuesta que recoja las intervenciones."
	else:
		phase = "queue"
		patience = 1.0
		notice = "Buen turno. Da paso a la siguiente mano." if good else "Turno cerrado. Recupera el orden."

func perform(value: String) -> void:
	if phase == "queue" and value.begins_with("delegate:"):
		var person := int(value.get_slice(":",1))
		if person not in queue: return
		if person != queue[0]:
			round_errors += 1
			total_errors += 1
			feedback("Respeta el orden de las manos.",SEATS[person],true)
			return
		if tutorial: trained()
		start_speech(person)
	elif phase == "speech":
		if value == "mediate" and interruption >= 0:
			interruption = -1
			interruption_time = 0.0
			feedback("¡Turno protegido!")
		elif value == "close":
			var ratio := speech/duration
			var good := ratio >= 0.68 and ratio <= 0.93 and interruption < 0
			close_speech(good)
			feedback("¡Buen cierre!" if good else "Fuera de tiempo.",Vector2(220,340),not good)
	elif phase == "vote" and value.begins_with("vote:"):
		var axis := int(value.get_slice(":",1))
		if axis < 0 or axis >= 4: return
		chosen = axis
		round_support = clampi(1+round_good-int(round_errors>0)+int(axis in heard),1,4)
		consensus += round_support
		tally[axis] += round_support+1
		for person in heard:
			tally[person] += 1
		score = clampi(roundi(float(consensus)*100.0/24.0)-total_errors,0,100)
		phase = "result"
		vote_timer = 1.8
		feedback("%d de 4 apoyos. Acuerdo en el acta." % round_support)
	elif phase == "result" and value == "next":
		next_round()

func next_round() -> void:
	chapter += 1
	if chapter >= EVENTS.size():
		var best := tally.find(tally.max())
		result.plan = AXES[best]
		finish(score,"Prioridad acordada: %s. %d/24 apoyos · %d turnos bien moderados. Redes abre la primera ronda de llegadas." % [AXES[best],consensus,total_good])
	else:
		setup_round()

func advance(delta: float) -> void:
	match phase:
		"queue":
			patience -= delta/(5.2-float(chapter)*0.3)
			if patience <= 0.0:
				round_errors += 1
				total_errors += 1
				patience = 1.0
				feedback("La asamblea espera. Da paso al siguiente turno.",Vector2(220,320),true)
		"speech":
			if interruption >= 0:
				interruption_time -= delta
				if interruption_time <= 0.0:
					interruption = -1
					round_errors += 1
					total_errors += 1
					feedback("Se han solapado dos voces.",Vector2(220,245),true)
				return
			speech += delta
			if interruption_pending and speech >= duration*0.35:
				interruption_pending = false
				interruption = queue[0] if not queue.is_empty() else (speaker+1)%4
				interruption_time = maxf(0.85,1.6-float(chapter)*0.10)
				notice = "¡Dos voces a la vez! Pulsa Mediar."
				return
			if speech >= duration:
				close_speech(false)
				feedback("El turno se ha alargado demasiado.",Vector2(220,340),true)
		"result":
			vote_timer -= delta
			if vote_timer <= 0.0: next_round()

func key(code: int) -> void:
	super.key(code)
	if report: return
	if code >= KEY_1 and code <= KEY_4:
		var index := code-KEY_1
		if phase == "queue": action("delegate:%d"%index)
		elif phase == "vote": action("vote:%d"%index)
	elif code == KEY_SPACE: action("close")
	elif code == KEY_M: action("mediate")
	elif code == KEY_ENTER and phase == "result": action("next")

func status() -> String:
	return "Ronda %d/6 · %d apoyos · %d errores" % [mini(chapter+1,6),consensus,total_errors]

func scene(game: Control) -> void:
	backdrop(game,Vector2(615,428),Color(0.15,0.17,0.12,0.25))
	item(game,MAT_ART,Vector2(220,236),Vector2(250,240))
	item(game,game.World.TABLE,Vector2(220,239),Vector2(92,75))
	game.draw_rect(Rect2(27,91,386,36),INK)
	game.text(Vector2(35,115),EVENTS[mini(chapter,5)],21,GOLD,true,370,HORIZONTAL_ALIGNMENT_CENTER)
	for i in range(4):
		var p: Vector2 = SEATS[i]
		var current := i == speaker
		var waiting := i in queue and phase in ["queue","speech"]
		if current:
			game.draw_circle(p-Vector2(0,28),43,Color(GREEN,0.23))
			game.draw_arc(p-Vector2(0,28),43,0,TAU,40,GREEN,3)
		elif waiting:
			game.draw_circle(p-Vector2(0,28),39,Color(GOLD,0.20))
		actor(game,p,i,1.65,current)
		game.draw_rect(Rect2(p+Vector2(-58,4),Vector2(116,24)),INK)
		game.text(p+Vector2(-58,21),NAMES[i],15,CREAM,true,116,HORIZONTAL_ALIGNMENT_CENTER)
		if waiting:
			var position := queue.find(i)+1
			var bob := sin(clock*7.0)*3.0
			var badge := p+Vector2(29,-67+bob)
			game.draw_circle(badge,16,GOLD)
			game.text(badge+Vector2(-16,6),str(position),19,INK,true,32,HORIZONTAL_ALIGNMENT_CENTER)
			if phase == "queue": hit(game,Rect2(p-Vector2(61,84),Vector2(122,112)),"delegate:%d"%i)
		if i in heard:
			game.draw_circle(p+Vector2(-31,-57),10,GREEN)
			game.text(p+Vector2(-41,-52),"✓",14,INK,true,20,HORIZONTAL_ALIGNMENT_CENTER)
		if i == interruption:
			game.draw_circle(p+Vector2(30,-64),17,RED)
			game.text(p+Vector2(13,-58),"!",24,INK,true,34,HORIZONTAL_ALIGNMENT_CENTER)
	game.draw_rect(Rect2(25,328,390,66),INK)
	match phase:
		"queue":
			game.text(Vector2(37,350),"TURNO DE PALABRA",16,GOLD,true)
			meter(game,Vector2(37,364),366,patience,GOLD)
			game.text(Vector2(37,387),"Escoge la mano número 1",16,CREAM)
		"speech":
			game.text(Vector2(37,350),"ESCUCHA · CIERRA EN VERDE",16,GREEN,true)
			var bar := Rect2(37,361,366,17)
			game.draw_rect(bar,Color("55504c"))
			game.draw_rect(Rect2(bar.position+Vector2(bar.size.x*0.68,0),Vector2(bar.size.x*0.25,17)),GREEN)
			var cursor := bar.position.x+bar.size.x*clampf(speech/duration,0,1)
			game.draw_rect(Rect2(cursor-3,bar.position.y-4,6,25),CREAM)
			if interruption >= 0:
				game.draw_rect(bar,Color(RED,0.65))
				game.text(Vector2(37,391),"¡MEDIA AHORA!",15,RED,true)
		"vote":
			game.text(Vector2(37,353),"BUSCA UN ACUERDO",18,GOLD,true)
			game.text(Vector2(37,378),"%d intervenciones · %d bien moderadas" % [heard.size(),round_good],16,CREAM)
		"result":
			game.text(Vector2(37,353),"ACUERDO · %d/4 APOYOS"%round_support,19,GREEN,true)
			game.text(Vector2(37,379),AXES[chosen],18,CREAM)

func controls(game: Control) -> void:
	match phase:
		"queue":
			game.text(Vector2(20,484),"¿Quién tiene el siguiente turno?",20,GOLD,true)
			for i in range(4):
				var rect := Rect2(20+(i%2)*202,504+floori(float(i)/2)*65,194,58)
				var caption: String = NAMES[i]
				if i in queue: caption = "%d · %s"%[queue.find(i)+1,NAMES[i]]
				button(game,rect,caption,"delegate:%d"%i,i in queue,17)
		"speech":
			game.text(Vector2(20,486),"Habla: "+NAMES[speaker],22,GOLD,true)
			button(game,Rect2(20,510,400,68),"Cerrar turno · Espacio","close",interruption<0,22)
			button(game,Rect2(20,590,400,76),"Mediar · M","mediate",interruption>=0,23)
			if interruption >= 0:
				meter(game,Vector2(28,673),384,interruption_time/1.6,RED)
		"vote":
			game.text(Vector2(20,483),"¿Qué acordamos?",20,GOLD,true)
			for i in range(4):
				var caption: String = CHOICES[chapter][i]
				if i in heard: caption += " · ✓"
				button(game,Rect2(20,495+i*47,400,43),caption,"vote:%d"%i,i in heard,17)
		"result":
			game.text(Vector2(20,493),"Acuerdo incorporado al acta",21,GREEN,true)
			button(game,Rect2(20,550,400,70),"Siguiente punto","next",true,23)
