extends "res://scripts/camp/activities_two/session.gd"

const CASES := [
	[["Ana","Pau"],["El grupo necesita ensayar.","El ruido atraviesa la tienda."],["El local se cierra al anochecer.","Su turno empieza a las seis."],["Lugar","Horario"],["Junto al círculo","Patio lateral","Fuera de la plaza"],["Por la tarde","Al atardecer","Por la noche"]],
	[["Omar","Berta"],["Hay que repartir agua a toda la fila.","No puede esperar mucho de pie."],["La entrada se atasca si la fila se duplica.","Puede recoger también para su compañera."],["Recogida","Turno"],["Ventanilla","Dos puntos","Reparto móvil"],["Fila única","Franjas","Con acompañante"]],
	[["Lola","Iker"],["Necesita las cajas a mano.","Hay que liberar la salida de la tienda."],["Las cajas salen una a una durante el día.","Pasa con un carro más ancho por la tarde."],["Almacén","Carga"],["En la esquina","En los bancos","En el refugio"],["Todo el día","Ventanas cortas","Por turnos"]],
	[["Sira","Teo"],["Su grupo usa las mantas para el relevo.","Las personas nuevas esperan material."],["Parte del turno acaba antes de la cena.","Solo algunas llegadas requieren espera."],["Reserva","Entrega"],["Por grupos","Individual","En depósito"],["Al llegar","Tras el relevo","Con cita"]],
	[["Aina","Bilal"],["El tablero debe ser visible.","Quieren conservar la entrada despejada."],["Los avisos deben cambiar cada hora.","La entrada alternativa es más ancha."],["Ubicación","Carteles"],["Puerta","Banco","Pasillo ancho"],["Solo urgentes","Dos paneles","Rotativos"]],
]
var order: Array = []
var chapter := 0
var person := 0
var trust := [0,0]
var tension := 2
var seen := [0,0]
var interests := [[0,0],[0,0]]
var style := [0,0]
var terms := [0,0]
var offer_history: Array = []
var turn_cost := 0
var agreements := 0
var reached := 0
var listening := true
var last_outcome := ""
var transcript: Array[String] = []

func initialize(seed_value: int,plan: String) -> void:
	super.initialize(seed_value,plan)
	title = "Convivencia · mesa de diálogo"
	help = "Habla con cada persona. Pregunta por el límite o refleja lo que has oído para abrir una segunda rama."
	order = range(CASES.size())
	for i in range(order.size()-1,0,-1):
		var j := rng.randi_range(0,i)
		var previous: int = order[j]
		order[j] = order[i]
		order[i] = previous
	if plan == "Descanso": turn_cost = -1
	setup_case()

func case_data() -> Array:
	return CASES[order[mini(chapter,order.size()-1)]]

func setup_case() -> void:
	tension = 2+int(chapter>=2)
	trust = [0,0]
	seen = [0,0]
	terms = [0,0]
	person = 0
	listening = true
	offer_history.clear()
	transcript.assign([case_data()[1][0],case_data()[1][1]])
	for i in range(2):
		interests[i] = [rng.randi_range(0,2),rng.randi_range(0,2)]
		style[i] = (i+chapter)%2

func add_line(line: String) -> void:
	transcript.append(line)
	while transcript.size()>2: transcript.pop_front()

func speak(topic: int) -> void:
	var side := person
	var flag := 1 << topic
	if seen[side] & flag:
		add_line("«Ya lo hemos hablado. Puedes reformular o volver a la propuesta.»")
		return
	seen[side] |= flag
	turn_cost += 1
	var data := case_data()
	match topic:
		0:
			trust[side] += 1
			add_line("«Gracias por escuchar. "+data[1][side]+"»")
		1:
			var axis: int = style[side]
			if trust[side]==0 and tension>=3:
				seen[side] &= ~flag
				add_line("«Prefiero explicar primero qué me preocupa.»")
				tension = mini(6,tension+1)
			else:
				var choice: String = data[4+axis][interests[side][axis]]
				add_line("«"+data[2][side]+" Me importa mantener: "+choice+".»")
		2:
			var axis: int = 1-style[side]
			if trust[side] == 0:
				add_line("«Si acordamos un ensayo, podemos revisar cómo funciona.»")
			else:
				trust[side] += 1
				tension = maxi(0,tension-1)
				add_line("«Puedo ceder si el primer ensayo incluye: "+str(data[4+axis][interests[side][axis]])+".»")
	if seen[0]>0 and seen[1]>0: trained()

func evaluate(temporary: bool) -> void:
	if tutorial: return
	var key := "%s:%s" % [terms,temporary]
	if key in offer_history:
		feedback("Ese acuerdo ya se discutió. Cambia alguna condición o plantea un piloto.")
		return
	offer_history.append(key)
	var votes := 0
	var data := case_data()
	for i in range(2):
		var axis: int = style[i]
		var principal := int(terms[axis] == interests[i][axis])
		var extra := int(terms[1-axis] == interests[i][1-axis])
		var accept: bool = principal*3 + extra*2 + trust[i] + (2 if temporary else 0) >= 4+int(tension>=4)
		if accept: votes += 1
		else: add_line("«%s: me falta una garantía sobre %s.»"%[data[0][i],data[3][axis].to_lower()])
	if votes == 2:
		agreements += 1
		reached += 11 if temporary else 17
		resolve_case("Piloto con revisión" if temporary else "Pacto estable")
	else:
		tension = mini(6,tension+1)
		reached += votes
		feedback("%d de 2 apoyos. Puedes retomar la conversación o pausar."%votes)

func resolve_case(outcome: String) -> void:
	last_outcome = outcome
	chapter += 1
	score = clampi(reached + agreements*3-maxi(0,turn_cost-25),0,100)
	feedback(outcome,Vector2(215,260))
	if chapter>=order.size():
		finish(score,"%d acuerdos de 5. Último desenlace: %s. El clima de la plaza refleja los acuerdos alcanzados."%[agreements,last_outcome])
	else:
		setup_case()

func perform(value: String) -> void:
	var parts := value.split(":")
	match parts[0]:
		"person": person = int(parts[1])
		"topic": speak(int(parts[1]))
		"talk": listening = not listening
		"term":
			var i := int(parts[1])
			terms[i] = (terms[i]+1)%3
		"pilot": evaluate(true)
		"commit": evaluate(false)
		"break":
			if tension>1 and trust[0]+trust[1]>=1:
				tension = maxi(0,tension-2)
				turn_cost += 2
				feedback("Pausa compartida. Baja la tensión sin perder el turno.")
			else:
				resolve_case("Derivado a seguimiento")

func status() -> String:
	return "Mesa %d/5    •    %d acuerdos    •    %d puntos"%[mini(chapter+1,5),agreements,score]

func scene(game: Control) -> void:
	var data := case_data()
	backdrop(game,Vector2(795,429),Color(0.24,0.12,0.09,0.32))
	item(game,game.World.TABLE,Vector2(220,237),Vector2(132,95))
	for i in range(2):
		var p := Vector2(101+236*i,230)
		actor(game,p,i+chapter,1.25)
		game.draw_rect(Rect2(p+Vector2(-57,3),Vector2(114,31)),INK)
		game.text(p+Vector2(-53,25),data[0][i],18,GOLD if person==i else CREAM,true,106,HORIZONTAL_ALIGNMENT_CENTER)
		hit(game,Rect2(p+Vector2(-66,-67),Vector2(131,104)),"person:%d"%i)
	game.draw_rect(Rect2(24,275,392,121),Color(INK,0.94))
	for i in range(transcript.size()):
		label(game,Vector2(34,298+42*i),transcript[i],369,GOLD if i==1 else CREAM)
	game.text(Vector2(34,385),"Tensión",14,CREAM)
	meter(game,Vector2(100,378),120,tension/6.0,RED)
	game.text(Vector2(235,385),"Confianza %d / %d"%trust,14,GREEN)

func controls(game: Control) -> void:
	var data := case_data()
	if listening:
		button(game,Rect2(20,477,197,55),"Escuchar versión","topic:0")
		button(game,Rect2(223,477,197,55),"Precisar límite","topic:1")
		button(game,Rect2(20,541,197,55),"Explorar cesión","topic:2")
		button(game,Rect2(223,541,197,55),"Abrir el acuerdo","talk",true)
		button(game,Rect2(20,610,400,54),"Pausa / derivación","break")
	else:
		button(game,Rect2(20,471,400,48),"%s · %s"%[data[3][0],data[4][terms[0]]],"term:0")
		button(game,Rect2(20,526,400,48),"%s · %s"%[data[3][1],data[5][terms[1]]],"term:1")
		button(game,Rect2(20,583,197,50),"Ensayar como piloto","pilot",false,16)
		button(game,Rect2(223,583,197,50),"Proponer pacto","commit",true,16)
		button(game,Rect2(20,641,400,48),"Volver a escuchar","talk")
