extends "res://scripts/camp/activities_two/session.gd"

const STATIONS := ["Recepción","Agua","Mantas","Enlace","Almacén"]
const POINTS := [Vector2(89,142),Vector2(222,142),Vector2(353,142),Vector2(352,249),Vector2(351,354)]
const REQUESTS := [
	["Espera sentada", [1]],
	["Abrigo", [2]],
	["Turno de espera", [1,2]],
	["Pide ver al equipo", [3]],
	["Busca a su acompañante", [1,3]]
]
var queue: Array[Dictionary] = []
var tasks: Array[Dictionary] = []
var workers: Array[Dictionary] = []
var boxes := [2,2,2]
var capacity := 4
var selected_person := 0
var selected_worker := 0
var next_arrival := 0.0
var received := 0
var served := 0
var assisted := 0
var lost := 0
var waiting := 0.0
var bottlenecks := 0
var drag_person := -1

func initialize(seed_value: int,plan: String) -> void:
	super.initialize(seed_value,plan)
	title = "Punto sanitario · logística"
	help = "Arrastra a la primera persona a Recepción o tócala y elige la estación. Recepción identifica qué solicita."
	if plan=="Cuidados": boxes[2] += 1
	for i in range(5): tasks.append({})
	for i in range(2): workers.append({"pos":Vector2(84+i*67,214),"station":-1})
	add_person(0)

func add_person(stage: int) -> void:
	var kind := rng.randi_range(0,mini(4,1+stage))
	if stage>=2 and received%4==0: kind = 3
	received += 1
	if queue.size()>=capacity:
		lost += 1
		feedback("La sala de espera se llenó. Conviene liberar turnos.")
		return
	queue.append({"id":received,"kind":kind,"entered":active_time,"deadline":active_time+35.0-stage*2.5,"step":-1,"assigned":false})

func queue_pos(index: int) -> Vector2:
	return Vector2(74+59*(index%4),316)

func find_person(id: int) -> int:
	for i in range(queue.size()):
		if queue[i].id==id: return i
	return -1

func begin_drag(point: Vector2) -> bool:
	for i in range(queue.size()):
		if Rect2(queue_pos(i)-Vector2(26,50),Vector2(52,67)).has_point(point):
			selected_person = i
			drag_person = queue[i].id
			return true
	return false

func end_drag(point: Vector2) -> void:
	var index := find_person(drag_person)
	drag_person = -1
	if index<0: return
	selected_person = index
	for station in range(5):
		if Vector2(POINTS[station]).distance_to(point)<=56:
			assign_station(station)
			return

func assign_station(station: int) -> void:
	if not tasks[station].is_empty():
		feedback("La estación está ocupada.",POINTS[station])
		return
	if workers[selected_worker].station>=0:
		var other := 1-selected_worker
		if workers[other].station<0: selected_worker = other
		else:
			feedback("Los dos voluntarios están atendiendo. Espera a que se libere uno.")
			return
	if station==4:
		if tutorial: return
		launch(station,-1,5.5)
		return
	if queue.is_empty(): return
	var person := queue[clampi(selected_person,0,queue.size()-1)]
	if person.assigned: return
	var needs: Array = REQUESTS[person.kind][1]
	var expected: int = 0 if person.step<0 else needs[person.step]
	if expected!=station:
		bottlenecks += 1
		feedback("Consulta la ficha. Necesita pasar por "+STATIONS[expected]+".")
		return
	if station>0 and boxes[station-1]<=0:
		feedback("Sin reserva en "+STATIONS[station]+". Envía un voluntario al almacén.")
		return
	person.assigned = true
	if station>0: boxes[station-1] -= 1
	launch(station,person.id,[3.1,3.8,4.2,6.0][station])
	trained()

func launch(station: int,id: int,time: float) -> void:
	workers[selected_worker].station = station
	tasks[station] = {"worker":selected_worker,"id":id,"left":time,"total":time}
	feedback("Tarea asignada a "+STATIONS[station]+".",POINTS[station])

func release_task(station: int) -> void:
	var task := tasks[station]
	workers[task.worker].station = -1
	tasks[station] = {}
	if station==4:
		for i in range(boxes.size()): boxes[i] = mini(4,boxes[i]+(1 if i==2 else 2))
		feedback("Reposición entregada.",POINTS[station])
		return
	var index := find_person(task.id)
	if index<0: return
	var person := queue[index]
	person.step += 1
	person.assigned = false
	if station==3: assisted += 1
	if person.step >= REQUESTS[person.kind][1].size():
		served += 1
		waiting += active_time-person.entered
		queue.remove_at(index)
		selected_person = clampi(selected_person,0,queue.size()-1)
		feedback("Turno completado.",POINTS[station])
	else:
		feedback(str(REQUESTS[person.kind][0])+" · sigue en "+STATIONS[REQUESTS[person.kind][1][person.step]]+".",POINTS[station])

func perform(value: String) -> void:
	var parts := value.split(":")
	match parts[0]:
		"station": assign_station(int(parts[1]))
		"person": selected_person = int(parts[1])
		"worker": selected_worker = int(parts[1])
		"prioritize":
			if queue.size()<2: return
			var index := clampi(selected_person,0,queue.size()-1)
			var person := queue[index]
			if person.assigned: return
			queue.remove_at(index)
			queue.push_front(person)
			selected_person = 0
			feedback("Turno adelantado. Revisa el margen de las otras personas.")

func advance(delta: float) -> void:
	if active_time>=next_arrival and active_time<174:
		var stage := mini(3,floori(active_time/48))
		next_arrival = active_time + 10-stage*1.2+rng.randf_range(-1.2,1.4)
		add_person(stage)
		if stage>=2 and received%7==0: add_person(stage)
	for i in range(workers.size()):
		var worker := workers[i]
		var station: int = worker.station
		var target: Vector2 = Vector2(84+i*67,214) if station<0 else POINTS[station]+Vector2(0,29)
		var stride := 79 if i==1 else 62
		worker.pos = Vector2(worker.pos).move_toward(target,delta*stride)
		if station<0: continue
		if worker.pos.distance_to(target)>2: continue
		var task := tasks[station]
		var specialist := (i==0 and station in [0,3]) or (i==1 and station in [1,2,4])
		task.left -= delta*(1.30 if specialist else 1.0)
		if task.left<=0: release_task(station)
	for i in range(queue.size()-1,-1,-1):
		if queue[i].deadline<active_time and not queue[i].assigned:
			queue.remove_at(i)
			selected_person = clampi(selected_person,0,queue.size()-1)
			lost += 1
	score = clampi(served*7 + assisted*3 - lost*3 - bottlenecks - roundi(waiting/65),0,100)
	if active_time>=195:
		finish(score,"%d turnos completos · %d enlaces profesionales · %d abandonos · %ds de espera media."%[served,assisted,lost,roundi(waiting/maxi(1,served))])

func status() -> String:
	return "%ds    •    %d atendidas    •    %d en espera"%[ceili(maxf(0,195-active_time)),served,queue.size()]

func scene(game: Control) -> void:
	backdrop(game,Vector2(375,455),Color(0.06,0.22,0.17,0.24))
	game.draw_rect(Rect2(25,93,390,88),Color("62938a"))
	game.draw_rect(Rect2(22,262,278,103),Color("55574b"))
	game.draw_rect(Rect2(311,191,104,195),Color("486453"))
	for station in range(5):
		var p: Vector2 = POINTS[station]
		var r := Rect2(p-Vector2(53,27),Vector2(106,54))
		game.draw_rect(r,INK)
		game.draw_rect(r,CREAM,false,2)
		game.text(p+Vector2(-51,2),STATIONS[station],15,CREAM,true,102,HORIZONTAL_ALIGNMENT_CENTER)
		if not tasks[station].is_empty(): meter(game,p+Vector2(-46,12),93,1-tasks[station].left/tasks[station].total,GREEN)
		hit(game,r,"station:%d"%station)
	for i in range(workers.size()):
		var p: Vector2 = workers[i].pos
		game.draw_circle(p,13,GOLD if i==selected_worker else GREEN)
		actor(game,p,i+1,0.88,workers[i].station>=0)
		game.text(p + Vector2(-35,20), "Acogida" if i==0 else "Material", 12, CREAM, true, 70, HORIZONTAL_ALIGNMENT_CENTER)
		if workers[i].station < 0: hit(game,Rect2(p-Vector2(27,45),Vector2(54,64)),"worker:%d"%i)
	for i in range(queue.size()):
		var person := queue[i]
		var p := drag_cursor if person.id==drag_person else queue_pos(i)
		if i==selected_person: game.draw_rect(Rect2(p-Vector2(21,45),Vector2(42,62)),GOLD,false,2)
		actor(game,p,person.kind,0.87)
		var next := "?" if person.step<0 else str(STATIONS[REQUESTS[person.kind][1][person.step]]).left(3)
		game.text(p+Vector2(-21,22),next,14,GOLD,true,43,HORIZONTAL_ALIGNMENT_CENTER)
		meter(game,p+Vector2(-21,29),42,(person.deadline-active_time)/35,RED)
		hit(game,Rect2(p-Vector2(25,47),Vector2(50,78)),"person:%d"%i)

func controls(game: Control) -> void:
	game.text(Vector2(20,481),"Agua %d    Mantas %d    Enlaces %d"%boxes,18,GREEN,true)
	var choices := ["Recepción","Agua","Mantas","Enlace","Almacén","Adelantar turno"]
	for i in range(choices.size()):
		button(game,Rect2(20+(i%2)*203,497+(i/2)*58,195,53),choices[i],"station:%d"%i if i<5 else "prioritize")
	label(game,Vector2(20,694),"Toca o arrastra fichas. Cada tarea ocupa un voluntario.",398,GOLD)
