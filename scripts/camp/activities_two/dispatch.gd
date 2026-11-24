extends "res://scripts/camp/activities_two/session.gd"

const TYPES := [
	["Cruce saturado","Flujo",0,1],
	["Persona desorientada","Acogida",1,1],
	["Discusión junto al acceso","Escucha",1,2],
	["Fila junto a la salida","Flujo",0,2],
	["Petición de acompañamiento","Acogida",2,1],
	["Reunión tranquila","Sin actuación",3,0]
]
const ZONES := [Vector2(108,154),Vector2(310,154),Vector2(117,323),Vector2(316,320)]
const ZONE_NAMES := ["Portal","Bancos","Refugio","Cocina"]
const ROLES := ["Flujo","Escucha","Enlace"]
var workers: Array[Dictionary] = []
var visitors: Array[Dictionary] = []
var incidents: Array[Dictionary] = []
var patrols := [0.0,0.0,0.0,0.0]
var selector := 0
var focus := 0
var next_event := 0.0
var roster := 1
var resolved := 0
var missed := 0
var unfair := 0
var prevented := 0
var generated := 0
var drag_worker := -1

func initialize(seed_value: int, plan: String) -> void:
	super.initialize(seed_value,plan)
	title = "Seguridad · coordinación"
	help = "Selecciona un chaleco y mándalo a un cuadrante vacío para practicar una ronda preventiva. También puedes arrastrarlo."
	roster += 1 if plan == "Cuidados" else 0
	for i in range(3): workers.append({"pos":Vector2(161+58*i,234),"zone":-1,"assignment":-1,"fatigue":0.0,"targeted":false})
	for i in range(4): incidents.append({})
	for i in range(14):
		var zone := rng.randi_range(0,3)
		visitors.append({
			"pos": Vector2(39+i*27,195+(i%3)*39),
			"zone": zone,
			"goal": visitor_target(zone),
			"speed": rng.randf_range(12,27),
			"linger": 0.0,
			"case": -1,
		})

func zone_at(point: Vector2) -> int:
	if not VIEW.has_point(point): return -1
	return int(point.x>215)+2*int(point.y>239)

func begin_drag(point: Vector2) -> bool:
	for i in range(3):
		if Vector2(workers[i].pos).distance_to(point)<24:
			drag_worker = i
			return true
	return false

func end_drag(point: Vector2) -> void:
	var zone := zone_at(point)
	selector = drag_worker
	if zone>=0 and Vector2(workers[selector].pos).distance_to(point)>12:
		order(zone)
	drag_worker = -1

func order(zone: int) -> void:
	var worker := workers[selector]
	worker.zone = zone
	worker.assignment = -1
	worker.targeted = not incidents[zone].is_empty()
	focus = zone
	trained()
	feedback("%s en camino a %s."%[ROLES[selector],ZONE_NAMES[zone]],ZONES[zone])

func perform(value: String) -> void:
	var parts := value.split(":")
	match parts[0]:
		"worker":
			selector = int(parts[1])
		"observe":
			focus = int(parts[1])
			if not incidents[focus].is_empty():
				incidents[focus].observed = true
				feedback("%s · %s."%[TYPES[incidents[focus].type][0],TYPES[incidents[focus].type][1]],ZONES[focus])
		"send":
			order(focus)
		"radio":
			var case := incidents[focus]
			if case.is_empty() or not case.observed or case.type==5:
				feedback("Observa y confirma una necesidad antes de activar apoyo.")
			elif roster>0 and not case.support:
				roster -= 1
				case.support = true
				feedback("Apoyo de otra comisión confirmado.",ZONES[focus])
		"rest":
			workers[selector].zone = -1
			workers[selector].assignment = -1

func visitor_target(zone: int) -> Vector2:
	return ZONES[zone] + Vector2(rng.randf_range(-44,44),rng.randf_range(-27,45))

func move_visitors(delta: float) -> void:
	for visitor in visitors:
		if visitor.case >= 0: continue
		visitor.pos = Vector2(visitor.pos).move_toward(visitor.goal,delta*visitor.speed)
		if Vector2(visitor.pos).distance_to(visitor.goal)>1: continue
		visitor.linger += delta
		if visitor.linger < 1.2: continue
		visitor.linger = 0
		visitor.zone = (visitor.zone+rng.randi_range(1,3))%4
		visitor.goal = visitor_target(visitor.zone)

func crowd_at(zone: int) -> int:
	var density := 0
	for visitor in visitors:
		if zone_at(visitor.pos)==zone: density += 1
	return density

func advance(delta: float) -> void:
	move_visitors(delta)
	if active_time >= next_event and active_time < 179:
		var stage := mini(3,floori(active_time/52))
		next_event = active_time+12-stage*2.15
		var available: Array[int] = []
		for i in range(4):
			if incidents[i].is_empty(): available.append(i)
		if not available.is_empty():
			var weights := []
			for zone in available:
				for person in range(maxi(1,crowd_at(zone))): weights.append(zone)
			create_incident(weights[rng.randi_range(0,weights.size()-1)],stage)
	for i in range(workers.size()):
		var worker := workers[i]
		var zone: int = worker.zone
		var target: Vector2 = Vector2(161+58*i,234) if zone<0 else ZONES[zone]+Vector2(12*i-12,31)
		worker.pos = Vector2(worker.pos).move_toward(target,delta*(33-worker.fatigue*13))
		if zone<0:
			worker.fatigue = maxf(0,worker.fatigue-delta*0.18)
			continue
		if worker.pos.distance_to(target)>2: continue
		patrols[zone] = active_time
		var incident := incidents[zone]
		if incident.is_empty():
			worker.fatigue = minf(1,worker.fatigue+delta*0.013)
			continue
		var type: int = incident.type
		if worker.assignment != int(incident.id):
			worker.assignment = incident.id
			if not worker.targeted:
				incident.observed = true
			elif type==5 or not incident.observed:
				unfair += 1
				worker.zone = -1
				feedback("Intervención sin confirmar en "+ZONE_NAMES[zone]+". Revisa antes de enviar.",ZONES[zone])
				continue
		if type==5: continue
		var required: int = TYPES[type][2]
		incident.progress += delta*(1.0 if i==required else 0.56)*(1.0-worker.fatigue*0.43)
		worker.fatigue = minf(1,worker.fatigue+delta*0.045)
	for z in range(4):
		var case := incidents[z]
		if case.is_empty(): continue
		if case.support: case.progress += delta*0.6
		if case.type != 5 and case.progress >= 3.1+TYPES[case.type][3]*1.9:
			resolved += 1
			release_visitors(case.id)
			incidents[z] = {}
			feedback("Incidencia resuelta en "+ZONE_NAMES[z]+".",ZONES[z])
		elif active_time >= case.deadline:
			if case.type != 5: missed += 1
			release_visitors(case.id)
			incidents[z] = {}
	score = clampi(resolved*7+prevented*5-missed*4-unfair*6,0,100)
	if active_time >= 193:
		finish(score,"%d resueltas · %d prevenidas · %d sin atender · %d intervenciones sin justificar."%[resolved,prevented,missed,unfair])

func release_visitors(case_id: int) -> void:
	for visitor in visitors:
		if visitor.case == case_id: visitor.case = -1

func create_incident(zone: int, stage: int) -> void:
	var type := rng.randi_range(0,1+stage)
	if crowd_at(zone)>=6 and generated%3==0: type = 0
	if generated%5==4: type = 5
	generated += 1
	if type==0 and patrols[zone]>0 and active_time-patrols[zone]<8:
		prevented += 1
		feedback("La ronda mantuvo libre "+ZONE_NAMES[zone]+".",ZONES[zone])
		return
	var participants := 0
	for visitor in visitors:
		if visitor.case >= 0 or zone_at(visitor.pos)!=zone: continue
		visitor.case = generated
		participants += 1
		if participants >= (2 if type in [0,2,3,5] else 1): break
	incidents[zone] = {"id":generated,"type":type,"observed":false,"deadline":active_time+26-stage*2.6,"progress":0.0,"support":false}

func status() -> String:
	return "%ds    •    %d resueltas    •    %d apoyos externos"%[ceili(maxf(0,193-active_time)),resolved,roster]

func scene(game: Control) -> void:
	backdrop(game,Vector2(710,450),Color(0.09,0.18,0.16,0.22))
	for i in range(visitors.size()):
		var visitor := visitors[i]
		actor(game,visitor.pos+Vector2(0,19),i,0.56,visitor.case<0)
		if visitor.case>=0:
			game.draw_rect(Rect2(visitor.pos+Vector2(-4,-8),Vector2(8,4)),GOLD)
	for zone in range(4):
		var p: Vector2 = ZONES[zone]
		var case := incidents[zone]
		var r := Rect2(p-Vector2(69,33),Vector2(138,66))
		game.draw_rect(r,Color(INK,0.81))
		game.draw_rect(r,GOLD if zone==focus else Color("889a79"),false,2)
		game.text(p+Vector2(-65,-10),ZONE_NAMES[zone],17,CREAM,true,130,HORIZONTAL_ALIGNMENT_CENTER)
		if not case.is_empty():
			var marker := "Incidencia" if not case.observed else TYPES[case.type][1] as String
			game.text(p+Vector2(-65,13),marker,15,RED if not case.observed else GOLD,false,130,HORIZONTAL_ALIGNMENT_CENTER)
			meter(game,p+Vector2(-56,20),112,(case.deadline-active_time)/26,RED)
		else:
			game.text(p+Vector2(-65,13),"Ronda reciente" if patrols[zone]>0 and active_time-patrols[zone]<8 else "En calma",15,GREEN,false,130,HORIZONTAL_ALIGNMENT_CENTER)
		hit(game,r,"observe:%d"%zone)
	for i in range(workers.size()):
		var p: Vector2 = workers[i].pos
		if i==drag_worker: p = drag_cursor
		game.draw_circle(p,13,GOLD if i==selector else GREEN)
		actor(game,p,i,0.87,workers[i].zone>=0)
		meter(game,p+Vector2(-15,11),30,1-workers[i].fatigue,GREEN)

func controls(game: Control) -> void:
	for i in range(3):
		button(game,Rect2(20+i*135,481,130,59),ROLES[i],"worker:%d"%i,i==selector)
	button(game,Rect2(20,554,194,61),"Enviar a "+ZONE_NAMES[focus],"send",true,16)
	button(game,Rect2(225,554,194,61),"Pedir apoyo","radio")
	button(game,Rect2(20,627,399,56),"Dar relevo al voluntario","rest")
