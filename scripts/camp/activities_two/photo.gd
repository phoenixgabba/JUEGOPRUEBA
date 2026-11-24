extends "res://scripts/camp/activities_two/session.gd"

const SUBJECTS := ["Acogida","Cocina","Relevos"]
const FORMATS := ["Crónica","Aviso","Díptico"]
const BRIEFS := ["Acogida · panorama general", "Servicio · información útil", "Cierre · contraste de escenas"]
const UNLOCK := [0,54,152]
const TARGETS := [Vector2(104,164),Vector2(205,232),Vector2(302,153)]
const CAMERA := Rect2(29,106,382,258)
const SITES := [Vector2(650,454),Vector2(540,402),Vector2(625,261)]
var posts: Array = []
var gallery: Array[Dictionary] = []
var offset := Vector2(40,-28)
var zoom := 0
var battery := 12
var used: Dictionary = {}
var selected := -1
var pair := -1
var event_index := 0
var format := 0
var caption := 0
var grade := 0
var simulated_time := 0.0
var editing := false
var reviewing := false
var view_index := 0
var flash := 0.0
var sequence := [0,1,2]
var correction := Vector2.ZERO
var view_pair := false

func initialize(seed_value: int, plan: String) -> void:
	super.initialize(seed_value,plan)
	title = "Redes · visor"
	help = "Arrastra el visor y toma una foto de ensayo. El marco guía el motivo. La batería se activa al terminar el ensayo."
	battery += 3 if plan == "Difusión" else 0
	var initial := rng.randi_range(0,2)
	sequence = [initial, (initial+1)%3, (initial+2)%3]

func event_at(time: float) -> int:
	return sequence[mini(floori(time/19.0), 10000)%3]

func subject_position(subject: int, time: float) -> Vector2:
	var rhythm := 0.63 + 0.15*subject + minf(time / 170, 1) * 0.18
	return TARGETS[subject] + Vector2(sin(time*rhythm)*46,cos(time*rhythm*0.55)*32)

func event_phase(time: float) -> float:
	return fposmod(time,19.0)

func sharpness(subject: int,time: float, framing: Vector2, focal: int) -> int:
	var p := Vector2(220,232) + (subject_position(subject,time) - Vector2(220,232) - framing) * (1 + focal*0.22)
	var distance := minf(p.distance_to(Vector2(220,224)),p.distance_to(Vector2(165,221)))
	var phase := event_phase(time)
	var light := (phase >= 4 and phase <= 14)
	return clampi(62-roundi(distance*0.54)+int(light)*19+focal*5,0,100)

func begin_drag(point: Vector2) -> bool:
	return not reviewing and CAMERA.has_point(point)

func move_drag(delta: Vector2) -> void:
	if editing:
		correction = (correction + delta*0.45).clamp(Vector2(-66,-54),Vector2(66,54))
	else:
		offset = (offset - delta/(1+zoom*0.22)).clamp(Vector2(-145,-104),Vector2(145,104))

func advance(delta: float) -> void:
	simulated_time += delta
	flash = maxf(0,flash-delta)
	event_index = event_at(simulated_time)
	if battery == 0 and float(fmod(simulated_time,35.0)) < delta:
		battery = 3
		feedback("Llegó una batería de recambio.")
	if active_time >= 185 and posts.size() == 3:
		finish(score,"Tres publicaciones · %d de 3 temas cubiertos · %d puntos de composición y claridad." % [used.size(),score])
	elif active_time >= 185 and active_time < 186:
		notice = "Última ventana: faltan publicaciones. Sigue observando y edita las fotos."

func perform(value: String) -> void:
	if reviewing:
		if value == "pair":
			view_pair = not view_pair
		elif value in ["previous","next"]:
			view_index = posmod(view_index+(1 if value=="next" else -1),posts.size())
			view_pair = false
		return
	match value:
		"capture":
			if editing: return
			if tutorial:
				trained()
				flash = 0.25
				feedback("Ensayo completo. Los momentos decisivos llegan entre el segundo 4 y el 14 de cada escena.")
				return
			if battery == 0:
				feedback("Sin carga. Hay recambios junto a Organización.")
				return
			battery -= 1
			var snap := {"subject":event_index,"x":offset.x,"y":offset.y,"zoom":zoom,"caption":event_index,"time":simulated_time}
			if gallery.size()==8: gallery.pop_front()
			gallery.append(snap)
			flash = 0.28
			feedback("Captura guardada · nitidez %d/100." % sharpness(event_index,simulated_time,offset,zoom))
		"zoom":
			zoom = (zoom+1)%3
		"gallery":
			if gallery.is_empty(): return
			editing = not editing
			correction = Vector2.ZERO
			selected = gallery.size()-1
			pair = -1
		"previous":
			selected = posmod(selected-1,gallery.size())
			correction = Vector2.ZERO
		"next":
			selected = posmod(selected+1,gallery.size())
			correction = Vector2.ZERO
		"pair":
			pair = selected if pair != selected else -1
		"format":
			format = (format+1)%FORMATS.size()
		"caption":
			caption = (caption+1)%SUBJECTS.size()
		"publish":
			if editing and posts.size()<3: publish()

func publish() -> void:
	var photo := gallery[selected].duplicate()
	var subject := int(photo.subject)
	var slot := posts.size()
	if photo.time < UNLOCK[slot]:
		feedback("El encargo %d requiere una captura a partir del segundo %d." % [slot+1,UNLOCK[slot]])
		return
	if used.has(subject) and active_time < 210:
		feedback("Este tema ya tiene cobertura. Reserva los espacios para otros acontecimientos.")
		return
	var framing := Vector2(photo.x,photo.y)
	var base := sharpness(subject,photo.time,framing,int(photo.zoom))
	var edited := sharpness(subject,photo.time,framing-correction,int(photo.zoom))
	var clarity := mini(edited,base+20)
	var relevance := 26 if caption == subject else 6
	var choice := 8
	if format == 1 and event_phase(photo.time) < 10: choice += 8
	if format == 0 and clarity >= 53: choice += 10
	if format == slot: choice += 7
	if format == 2:
		if pair < 0 or pair == selected:
			feedback("Marca una segunda imagen para el díptico y selecciona la portada.")
			return
		photo.second = gallery[pair].duplicate()
		if int(gallery[pair].subject) != subject: choice += 15
	var freshness := 14 if not used.has(subject) else 0
	grade += clampi(roundi(clarity*0.43) + relevance + choice + freshness,0,100)
	photo.x -= correction.x
	photo.y -= correction.y
	photo.caption = caption
	photo.grade = clampi(roundi(clarity*0.43) + relevance + choice + freshness,0,100)
	photo.format = format
	posts.append(photo)
	used[subject] = true
	score = roundi(grade/float(posts.size()))
	editing = false
	feedback("Publicación %d/3. Claridad %d · coherencia %d."%[posts.size(),clarity,relevance])
	if active_time>=185 and posts.size()==3:
		finish(score,"Tres publicaciones · %d temas · índice de claridad, relevancia y composición %d."%[used.size(),score])

func profile(saved: Array) -> void:
	reviewing = true
	tutorial = false
	title = "Teléfono · publicaciones"
	posts = saved.duplicate()
	if posts.is_empty():
		for i in range(3): posts.append({"subject":i,"x":0,"y":0,"zoom":0,"caption":i,"time":0})

func key(code: int) -> void:
	super.key(code)
	if report or editing or reviewing: return
	if code == KEY_SPACE: action("capture")
	var keys := {KEY_LEFT:Vector2.LEFT,KEY_RIGHT:Vector2.RIGHT,KEY_UP:Vector2.UP,KEY_DOWN:Vector2.DOWN}
	if keys.has(code): offset = (offset + keys[code]*12).clamp(Vector2(-145,-104),Vector2(145,104))

func status() -> String:
	if reviewing: return "@acampadavalencia    •    %d/%d"% [view_index+1,posts.size()]
	return "%s    •    %d fotos de batería    •    %d/3 publicaciones"%[SUBJECTS[event_index],battery,posts.size()]

func scene(game: Control) -> void:
	var snapshot := {"subject":event_index,"x":offset.x,"y":offset.y,"zoom":zoom,"time":simulated_time}
	if editing: snapshot = gallery[selected]
	if reviewing:
		snapshot = posts[view_index]
		if view_pair: snapshot = snapshot.get("second",snapshot)
	draw_photo(game,snapshot,correction if editing else Vector2.ZERO)
	if not editing and not reviewing:
		for i in [1,2]:
			var x: float = CAMERA.position.x+CAMERA.size.x*i/3.0
			var y: float = CAMERA.position.y+CAMERA.size.y*i/3.0
			game.draw_line(Vector2(x,CAMERA.position.y),Vector2(x,CAMERA.end.y),Color(1,1,1,0.5))
			game.draw_line(Vector2(CAMERA.position.x,y),Vector2(CAMERA.end.x,y),Color(1,1,1,0.5))
		var phase := event_phase(simulated_time)
		meter(game,Vector2(36,379),359,phase/19,GREEN if phase>=4 and phase<=14 else GOLD)
		game.text(Vector2(35,397),"En acción" if phase>=4 and phase<=14 else "Preparativos",14,CREAM)
	if editing or reviewing:
		var layout: int = int(snapshot.get("format",format if editing else 0))
		var banner := Rect2(29,332,382,32)
		if layout == 1: banner.position.y = 107
		game.draw_rect(banner,Color(INK,0.89))
		game.text(banner.position+Vector2(11,22),FORMATS[layout]+" · "+SUBJECTS[int(caption if editing else snapshot.caption)],16,GOLD,true,354)
		if layout==2:
			game.draw_rect(Rect2(358,118,42,25),INK)
			game.text(Vector2(368,137),"1|2",16,CREAM,true)
	if flash>0: game.draw_rect(CAMERA,Color(1,1,1,clampf(flash*3,0,1)))

func draw_photo(game: Control, shot: Dictionary, crop: Vector2) -> void:
	var subject := clampi(int(shot.subject),0,2)
	var focal := clampi(int(shot.zoom),0,2)
	var framing := Vector2(float(shot.x),float(shot.y))-crop
	var magnification := 1+focal*0.22
	backdrop(game,SITES[subject]+framing*0.34,Color(0,0.08,0.08,0.08),Vector2(224,165)/magnification)
	game.draw_rect(CAMERA,GOLD,false,2)
	var p := Vector2(220,232)+(subject_position(subject,float(shot.time))-Vector2(220,232)-framing)*magnification
	for i in range(3):
		var at := p + Vector2(22*i-20,15*(i%2))
		if not CAMERA.grow(-44).has_point(at): continue
		if i == 0:
			item(game,game.World.TABLE if subject==1 else game.World.TENT,at+Vector2(-29,4),Vector2(56,45))
		var saved_clock := clock
		if editing or reviewing: clock = float(shot.time)
		actor(game,at,(subject+i)%4,0.85+magnification*0.22,true)
		clock = saved_clock

func controls(game: Control) -> void:
	if reviewing:
		label(game,Vector2(20,495),SUBJECTS[int(posts[view_index].caption)],395)
		button(game,Rect2(20,575,193,58),"Anterior","previous")
		button(game,Rect2(226,575,194,58),"Siguiente","next")
		if posts[view_index].has("second"): button(game,Rect2(20,641,400,51),"Cambiar imagen del díptico","pair")
	elif not editing:
		button(game,Rect2(20,493,193,65),"Zoom %s×"%[1.0+zoom*0.22],"zoom")
		button(game,Rect2(226,493,194,65),"Disparar","capture",true)
		button(game,Rect2(20,574,400,65),"Carrete · %d capturas"%gallery.size(),"gallery")
		if posts.size() < 3:
			var slot := posts.size()
			label(game,Vector2(20,664),BRIEFS[slot]+" · "+("abierto" if active_time>=UNLOCK[slot] else "en %ds"%ceili(UNLOCK[slot]-active_time)),398,GREEN)
	else:
		button(game,Rect2(20,475,99,53),"‹","previous")
		button(game,Rect2(123,475,193,53),"Foto %d/%d"%[selected+1,gallery.size()],"pair",selected==pair)
		button(game,Rect2(321,475,99,53),"›","next")
		button(game,Rect2(20,535,193,53),FORMATS[format],"format")
		button(game,Rect2(226,535,194,53),SUBJECTS[caption],"caption")
		button(game,Rect2(20,598,193,54),"Volver al visor","gallery")
		button(game,Rect2(226,598,194,54),"Publicar","publish",true)
		game.text(Vector2(20,680),"Arrastra para recortar. Toca el número para marcar el díptico.",14,GREEN,false,398)
