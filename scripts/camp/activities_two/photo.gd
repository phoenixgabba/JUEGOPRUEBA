extends "res://scripts/camp/activities_two/session.gd"

const SUBJECTS := ["Acogida","Cocina","Relevos"]
const SUBJECT_NAMES := ["Patricia en la plaza","Turno de Cocina","Llegada a la plaza"]
const POINTS := [Vector2(575,410),Vector2(540,402),Vector2(650,454)]
const BRIEFS := [
	"Patricia acepta salir en el retrato. Encuádrela con el móvil.",
	"Cocina abre el turno. Encuadra la mesa con el móvil.",
	"Una visitante acaba de llegar. Encuádrela junto a la entrada."
]
# The descriptors below keep photos from older saves visible.
const TARGETS := [Vector2(104,164),Vector2(205,232),Vector2(302,153)]
const CAMERA := Rect2(29,106,382,258)
const SITES := [Vector2(650,454),Vector2(540,402),Vector2(625,261)]

static func start(phone) -> void:
	if phone.data.network.get("started",false): return
	phone.data.network = {"started":true,"prepared":-1,"misses":0}
	phone.unlock("phone")
	phone.notify("social","","Encargo de Redes","Crea el perfil y documenta tres momentos de la plaza.")

static func next_subject(phone) -> int:
	for i in range(SUBJECT_NAMES.size()):
		if not phone.data.photos.any(func(photo): return int(photo.get("subject",-1)) == i): return i
	return -1

static func published_subjects(phone) -> Dictionary:
	var subjects := {}
	for post in phone.data.social:
		for photo in phone.data.photos:
			if photo.id==post.photo and photo.has("subject"):
				subjects[int(photo.subject)] = int(photo.quality)
				break
	return subjects

static func publish_score(phone) -> int:
	var total := 0
	for points in published_subjects(phone).values(): total += int(points)
	return clampi(roundi(total/3.0)-int(phone.data.network.get("misses",0))*2,0,100)

func subject_position(subject: int, time: float) -> Vector2:
	var rhythm := 0.63 + 0.15*subject + minf(time/170,1)*0.18
	return TARGETS[subject] + Vector2(sin(time*rhythm)*46,cos(time*rhythm*0.55)*32)

func draw_photo(game: Control, shot: Dictionary, crop: Vector2) -> void:
	var subject := clampi(int(shot.subject),0,2)
	var focal := clampi(int(shot.zoom),0,2)
	var framing := Vector2(float(shot.x),float(shot.y))-crop
	var magnification := 1+focal*0.22
	backdrop(game,SITES[subject]+framing*0.34,Color(0,0.08,0.08,0.08),Vector2(224,165)/magnification)
	game.draw_rect(CAMERA,Color("20232b"),false,3)
	for corner in [CAMERA.position,CAMERA.position+Vector2(CAMERA.size.x,0),CAMERA.end,CAMERA.position+Vector2(0,CAMERA.size.y)]:
		var sx := 1.0 if corner.x==CAMERA.position.x else -1.0
		var sy := 1.0 if corner.y==CAMERA.position.y else -1.0
		game.draw_line(corner,corner+Vector2(sx*15,0),Color.WHITE,2,true)
		game.draw_line(corner,corner+Vector2(0,sy*15),Color.WHITE,2,true)
	var p := Vector2(220,232)+(subject_position(subject,float(shot.time))-Vector2(220,232)-framing)*magnification
	for i in range(3):
		var at := p + Vector2(22*i-20,15*(i%2))
		if not CAMERA.grow(-44).has_point(at): continue
		if i == 0:
			item(game,game.World.TABLE if subject==1 else game.World.TENT,at+Vector2(-29,4),Vector2(56,45))
		var saved_clock := clock
		clock = float(shot.time)
		actor(game,at,(subject+i)%4,0.85+magnification*0.22,true)
		clock = saved_clock
