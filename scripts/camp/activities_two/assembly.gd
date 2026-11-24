extends "res://scripts/camp/activities_two/session.gd"

const AXES := ["Acceso", "Cuidados", "Difusión", "Descanso"]
const NAMES := ["Patricia", "Alejandro", "Marina", "Núria"]
const PACKAGES := [
	["Corredor libre", [2,0,0,1], [1,0,0]],
	["Puesto de acogida", [1,2,0,0], [1,1,0]],
	["Carteles y boletín", [1,0,2,0], [0,1,0]],
	["Zona tranquila", [0,1,0,2], [1,0,0]],
	["Rondas de apoyo", [0,2,1,0], [0,1,1]],
	["Turnos de relevo", [0,1,0,2], [0,0,1]],
	["Ruta señalizada", [2,0,1,0], [1,0,1]],
	["Mesa informativa", [0,0,2,1], [0,1,1]],
]
const EVENTS := ["Redes · información", "Seguridad · avisos", "Convivencia · material", "Punto sanitario · apoyo", "Accesibilidad · recorridos", "Acuerdo final"]
var participants: Array[Dictionary] = []
var options: Array = []
var selected: Array[int] = []
var budget := [3,2,2]
var remaining := [3,2,2]
var needs: Array = []
var chapter := 0
var heard := 0
var chair := 0
var compromise := -1
var tally := [0,0,0,0]
var consensus := 0
var revisions := 0
var voting := false
var vote_timer := 0.0

func initialize(seed_value: int, plan: String) -> void:
	super.initialize(seed_value,plan)
	title = "Segunda asamblea"
	help = "Redes, Seguridad, Convivencia, Punto sanitario y Accesibilidad. Escucha a dos delegados y prepara las prioridades."
	for i in range(4):
		participants.append({"first":i,"second":(i+1+rng.randi_range(0,2))%4,"trust":1})
	setup_agenda()

func setup_agenda() -> void:
	options = range(PACKAGES.size())
	for i in range(options.size()-1,0,-1):
		var j := rng.randi_range(0,i)
		var previous: int = options[j]
		options[j] = options[i]
		options[i] = previous
	options.resize(6)
	budget = [3 if chapter < 3 else 2, 2, 2 if chapter < 4 else 1]
	remaining = budget.duplicate()
	selected.clear()
	heard = 0
	compromise = -1
	voting = false
	needs = [chapter%4, (chapter+1)%4]

func effects() -> Array:
	var coverage := [0,0,0,0]
	for option in selected:
		for i in range(4): coverage[i] += PACKAGES[option][1][i]
	if 0 in selected and 6 in selected: coverage[0] -= 1
	if 2 in selected and 7 in selected: coverage[2] -= 1
	if 1 in selected and 5 in selected: coverage[1] += 1
	if compromise >= 0: coverage[participants[compromise].first] += 1
	return coverage

func support(i: int, coverage: Array) -> bool:
	var person := participants[i]
	var threshold := 4 + int(chapter >= 3) - int(person.trust >= 3)
	return 2 * mini(coverage[person.first], 2) + mini(coverage[person.second], 2) >= threshold

func perform(value: String) -> void:
	if voting: return
	var parts := value.split(":")
	match parts[0]:
		"delegate":
			var i := int(parts[1])
			chair = i
			heard |= 1 << i
			var person := participants[i]
			feedback("%s defiende %s y pide %s." % [NAMES[i], AXES[person.first].to_lower(), AXES[person.second].to_lower()])
			if heard & (heard-1): trained()
		"card":
			if tutorial: return
			var i := int(parts[1])
			if i in selected:
				selected.erase(i)
				for j in range(3): remaining[j] += PACKAGES[i][2][j]
				return
			for j in range(3):
				if remaining[j] < PACKAGES[i][2][j]:
					feedback("Reserva agotada. Retira una propuesta o negocia un ajuste.")
					return
			selected.append(i)
			for j in range(3): remaining[j] -= PACKAGES[i][2][j]
		"amend":
			if tutorial or (heard & (1 << chair)) == 0: return
			if compromise >= 0:
				remaining[2] += 1
				if chair == compromise:
					compromise = -1
					return
			if remaining[2] > 0:
				remaining[2] -= 1
				compromise = chair
			else: feedback("El ajuste necesita un relevo disponible.")
		"vote":
			if tutorial or selected.is_empty(): return
			var coverage := effects()
			var yes := 0
			for i in range(4):
				if support(i,coverage): yes += 1
			if yes < 2 or coverage[needs[0]] == 0:
				revisions += 1
				feedback("Solo %d apoyos o una prioridad sin cubrir. Negocia y vuelve a votar." % yes)
				return
			consensus += yes
			score = clampi(roundi(consensus * 100.0/24) - revisions,0,100)
			for i in range(4):
				tally[i] += mini(coverage[i],4)
				participants[i].trust = clampi(participants[i].trust + (1 if support(i,coverage) else -1),0,4)
			voting = true
			vote_timer = 3.8
			feedback("%d de 4 apoyos. Se incorpora al acta." % yes)

func advance(delta: float) -> void:
	if not voting: return
	vote_timer -= delta
	if vote_timer > 0: return
	chapter += 1
	if chapter == EVENTS.size():
		var best := tally.find(tally.max())
		result.plan = AXES[best]
		finish(score, "Prioridad acordada: %s. Apoyos acumulados %d/24. Redes abre la primera ronda de llegadas." % [AXES[best],consensus])
	else:
		setup_agenda()

func status() -> String:
	return "Acta %d/6    •    %d apoyos acumulados" % [mini(chapter+1,6),consensus]

func scene(game: Control) -> void:
	backdrop(game,Vector2(615,428),Color(0.15,0.17,0.12,0.15))
	game.draw_circle(Vector2(219,214),99,Color("676449"))
	game.draw_arc(Vector2(219,214),95,0,TAU,48,GOLD,3)
	item(game,game.World.TABLE,Vector2(215,224),Vector2(99,78))
	var coverage := effects()
	for i in range(4):
		var p := Vector2(69+98*i,201+(i%2)*75)
		actor(game,p,i,1.15)
		var color := GREEN if support(i,coverage) else GOLD
		game.draw_rect(Rect2(p+Vector2(-42,4),Vector2(85,25)),INK)
		game.text(p+Vector2(-40,22),NAMES[i],15,color,true,80,HORIZONTAL_ALIGNMENT_CENTER)
		if (heard & (1 << i)) != 0:
			game.draw_rect(Rect2(p+Vector2(-9,-64),Vector2(18,12)),color)
		hit(game,Rect2(p+Vector2(-43,-68),Vector2(87,97)),"delegate:%d"%i)
	game.draw_rect(Rect2(18,302,404,101),INK)
	game.text(Vector2(29,326),EVENTS[mini(chapter,5)],18,GOLD,true)
	for i in range(4):
		var x := 29+i*97
		game.text(Vector2(x,356),AXES[i],15,CREAM,true)
		meter(game,Vector2(x,366),80,coverage[i]/4.0,GREEN if i in needs else GOLD)

func controls(game: Control) -> void:
	var budget_text := "Espacio %d   Material %d   Relevos %d" % remaining
	game.text(Vector2(21,476),budget_text,17,GREEN,true)
	for i in range(options.size()):
		var id: int = options[i]
		var p := Rect2(20+(i%2)*202,487+(i/2)*47,195,43)
		button(game,p,PACKAGES[id][0],"card:%d"%id,id in selected,16)
		var values: Array = PACKAGES[id][2]
		game.text(p.position+Vector2(0,38),"%d · %d · %d" % values,12,INK if id in selected else CREAM,false,p.size.x,HORIZONTAL_ALIGNMENT_CENTER)
	button(game,Rect2(20,635,194,53),"Ajuste para "+NAMES[chair],"amend",compromise>=0,15)
	button(game,Rect2(222,635,198,53),"Votar el paquete","vote",true,17)
