extends RefCounted

const NAMES := ["Redes", "Seguridad", "Convivencia", "Punto sanitario", "Accesibilidad"]
const POINTS := [Vector2(575,410), Vector2(710,450), Vector2(795,429), Vector2(375,455), Vector2(810,395)]
const KINDS := ["redes", "seguridad", "convivencia", "sanitario", "accesibilidad"]
const SESSIONS := {
	"asamblea": preload("res://scripts/camp/activities_two/assembly.gd"),
	"accesibilidad": preload("res://scripts/camp/activities_two/access.gd"),
	"seguridad": preload("res://scripts/camp/activities_two/dispatch.gd"),
	"convivencia": preload("res://scripts/camp/activities_two/mediation.gd"),
	"sanitario": preload("res://scripts/camp/activities_two/clinic.gd"),
}
var mode := ""
var active_plan := ""
var session: RefCounted
var done: bool:
	get: return session != null and session.done
var cue: bool:
	get: return session != null and session.cue
	set(value):
		if session != null: session.cue = value

func start(kind: String, plan: String = "", seed_value: int = -1) -> void:
	mode = kind
	active_plan = plan
	session = SESSIONS[kind].new()
	session.initialize(randi() if seed_value < 0 else seed_value, plan)

func tick(delta: float) -> void:
	session.tick(delta)

func action(value: String) -> void:
	if value == "retry" and session.report:
		start(mode, active_plan)
	else:
		session.action(value)

func key(code: int) -> void:
	session.key(code)

func draw(game: Control) -> void:
	session.draw(game)

func begin_aim(point: Vector2, index: int) -> bool:
	return session.press(point, index)

func aim(delta: Vector2, index: int) -> void:
	session.move(delta,index)

func hover(point: Vector2) -> void:
	if session.has_method("hover"): session.hover(point)

func release_aim(index: int) -> void:
	session.release(index)
