extends "res://scripts/camp/activities_two/session.gd"

const AXES := ["Acceso", "Cuidados", "Difusión", "Descanso"]
const DELEGATES := ["Patricia", "Alejandro", "Marina", "Núria"]
const CARD_LIBRARY := [
	{"name":"Puesto de acogida", "effect":[2,1,0,0]},
	{"name":"Carteles visibles", "effect":[1,0,2,0]},
	{"name":"Turnos de relevo", "effect":[0,1,0,2]},
	{"name":"Corredor libre", "effect":[2,0,0,1]},
	{"name":"Zona tranquila", "effect":[0,2,0,2]},
	{"name":"Mesa informativa", "effect":[1,0,2,1]},
	{"name":"Grupo de apoyo", "effect":[0,2,1,0]},
	{"name":"Ruta señalizada", "effect":[2,0,1,0]},
]
const ACTS := [
	"Abrir Redes",
	"Abrir Seguridad",
	"Abrir Convivencia",
	"Abrir Punto sanitario",
	"Abrir Accesibilidad",
	"Paquete final",
]

var cards: Array = []
var delegates: Array = []
var focus: Array[int] = []
var chosen_delegates: Array[int] = []
var chosen_cards: Array[int] = []
var act := 0
var consensus := 0
var tension := 0
var rounds_won := 0

func initialize(seed_value: int, plan: String) -> void:
	super.initialize(seed_value,plan)
	title = "Segunda asamblea"
	help = "Escucha a dos delegadas, elige dos acuerdos y cierra el acta. Debes sumar apoyos sin disparar la tensión de la plaza."
	setup_round()

func setup_round() -> void:
	cards.clear()
	delegates.clear()
	chosen_delegates.clear()
	chosen_cards.clear()
	focus = [act % 4, (act + 1 + rng.randi_range(0,1)) % 4]
	var pool: Array = []
	for entry in CARD_LIBRARY:
		pool.append(entry.duplicate(true))
	for i in range(pool.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var swap = pool[j]
		pool[j] = pool[i]
		pool[i] = swap
	for i in range(5):
		cards.append(pool[i])
	for i in range(4):
		var first := (act + i + rng.randi_range(0, 1)) % 4
		var second := (first + 1 + rng.randi_range(0, 2)) % 4
		if second == first:
			second = (second + 1) % 4
		delegates.append({"first": first, "second": second, "mood": clampi(2 + (consensus / 4) - (tension / 3), 0, 4)})

func coverage() -> Array:
	var values := [0, 0, 0, 0]
	for index in chosen_cards:
		var effect: Array = cards[index]["effect"]
		for i in range(4):
			values[i] += effect[i]
	return values

func support_for_delegate(index: int, values: Array) -> int:
	var entry: Dictionary = delegates[index]
	var total := 0
	if values[entry["first"]] > 0:
		total += 1
	if values[entry["second"]] > 0:
		total += 1
	if entry["first"] in focus and values[entry["first"]] >= 2:
		total += 1
	return total

func perform(value: String) -> void:
	var parts := value.split(":")
	match parts[0]:
		"clear":
			if tutorial:
				return
			chosen_cards.clear()
			chosen_delegates.clear()
		"delegate":
			var index := int(parts[1])
			if index in chosen_delegates:
				chosen_delegates.erase(index)
			elif chosen_delegates.size() < 2:
				chosen_delegates.append(index)
				if tutorial and chosen_delegates.size() == 2:
					trained()
					feedback("Ahora elige dos acuerdos y cierra el acta.")
		"card":
			if tutorial:
				return
			var index := int(parts[1])
			if index in chosen_cards:
				chosen_cards.erase(index)
			elif chosen_cards.size() < 2:
				chosen_cards.append(index)
		"resolve":
			if tutorial:
				return
			resolve_act()

func resolve_act() -> void:
	if chosen_delegates.size() != 2 or chosen_cards.size() != 2:
		feedback("Selecciona dos delegadas y dos acuerdos antes de cerrar el acta.", Vector2(322, 238), true)
		return
	var values := coverage()
	var gained := 0
	for index in chosen_delegates:
		gained += support_for_delegate(index, values)
	if values[focus[0]] == 0 or values[focus[1]] == 0:
		tension += 2
		feedback("Falta cubrir una prioridad del acta. La plaza se impacienta.", Vector2(322, 238), true)
	else:
		consensus += gained
		if gained >= 4:
			rounds_won += 1
			feedback("Buen cierre de acta. Se suman %d apoyos." % gained, Vector2(322, 238))
		else:
			tension += 1
			feedback("Acuerdo suficiente, pero con dudas. Solo %d apoyos." % gained, Vector2(322, 238), true)
	score = clampi(45 + consensus * 4 + rounds_won * 6 - tension * 5, 0, 100)
	act += 1
	if act >= ACTS.size():
		var best := 0
		var values := coverage()
		for i in range(1, 4):
			if values[i] > values[best]:
				best = i
		result.plan = AXES[best]
		finish(score, "%d apoyos · %d cierres sólidos · tensión %d. La asamblea prioriza %s." % [consensus, rounds_won, tension, AXES[best]])
		return
	setup_round()

func status() -> String:
	return "Acta %d/6  •  %d apoyos  •  tensión %d" % [mini(act + 1, 6), consensus, tension]

func scene(game: Control) -> void:
	backdrop(game, Vector2(620, 420), Color(0.17, 0.15, 0.11, 0.18))
	game.draw_circle(Vector2(142, 176), 81, Color("6d6749"))
	game.draw_arc(Vector2(142, 176), 79, 0, TAU, 36, GOLD, 3)
	game.text(Vector2(18, 101), ACTS[act], 21, GOLD, true)
	game.text(Vector2(18, 124), "Prioridades: %s y %s" % [AXES[focus[0]], AXES[focus[1]]], 15, GREEN, true)
	var positions := [Vector2(56, 112), Vector2(226, 112), Vector2(56, 239), Vector2(226, 239)]
	var values := coverage()
	for i in range(4):
		var p: Vector2 = positions[i]
		actor(game, p + Vector2(23, 18), i, 1.08)
		var rect := Rect2(p, Vector2(113, 74))
		game.draw_rect(rect, Color("20393a") if i in chosen_delegates else Color("1b2d2d"))
		game.draw_rect(rect, GOLD if i in chosen_delegates else CREAM, false, 2)
		game.text(rect.position + Vector2(45, 16), DELEGATES[i], 15, GOLD if i in chosen_delegates else CREAM, true, 62)
		var entry: Dictionary = delegates[i]
		game.text(rect.position + Vector2(46, 36), "%s + %s" % [AXES[entry["first"]], AXES[entry["second"]]], 12, GREEN, false, 62)
		meter(game, rect.position + Vector2(46, 52), 58, entry["mood"] / 4.0, GREEN)
		game.text(rect.position + Vector2(0, 68), "%d apoyos" % support_for_delegate(i, values), 11, CREAM, true, rect.size.x, HORIZONTAL_ALIGNMENT_CENTER)
		hit(game, rect, "delegate:%d" % i)
	game.draw_rect(Rect2(18, 324, 404, 73), INK)
	for i in range(4):
		var x := 28 + i * 96
		game.text(Vector2(x, 347), AXES[i], 14, GOLD if i in focus else CREAM, true)
		meter(game, Vector2(x, 356), 80, float(values[i]) / 4.0, GREEN if i in focus else GOLD)
		game.text(Vector2(x, 375), str(values[i]), 14, CREAM, true)

func controls(game: Control) -> void:
	for i in range(cards.size()):
		var rect := Rect2(20 + (i % 2) * 202, 431 + (i / 2) * 57, 194, 50)
		var selected := i in chosen_cards
		button(game, rect, cards[i]["name"], "card:%d" % i, selected, 16)
		var effect: Array = cards[i]["effect"]
		game.text(rect.position + Vector2(0, 42), "+%d %s  +%d %s" % [effect[focus[0]], AXES[focus[0]], effect[focus[1]], AXES[focus[1]]], 12, INK if selected else CREAM, false, rect.size.x, HORIZONTAL_ALIGNMENT_CENTER)
	button(game, Rect2(20, 612, 194, 54), "Rehacer selección", "clear", false, 16)
	button(game, Rect2(226, 612, 194, 54), "Cerrar acta", "resolve", true, 18)
