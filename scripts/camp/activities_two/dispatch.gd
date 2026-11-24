extends "res://scripts/camp/activities_two/session.gd"

const CABINET := preload("res://assets/visual/arcade_board.png")
const HOLE_BACK := preload("res://assets/visual/hole_back.png")
const HOLE_FRONT := preload("res://assets/visual/hole_front.png")

const SLOTS := [Vector2(76,172),Vector2(219,172),Vector2(362,172),Vector2(76,273),Vector2(219,273),Vector2(362,273),Vector2(76,373),Vector2(219,373),Vector2(362,373)]
const LABELS := ["AVISO NEONAZI", "VECINA MAYOR", "MENOR", "VISITANTE"]
var slots: Dictionary = {}
var correct := 0
var mistakes := 0
var misses := 0
var next_wave := 0.0
var previous := -1
var flash := {}
var spawned := 0

func initialize(seed_value: int, plan: String) -> void:
	super.initialize(seed_value,plan)
	title = "Seguridad · alerta en la plaza"
	help = "Toca el aviso de práctica. En la partida, marca solo «Aviso neonazi»: identifica el aviso por su texto, nunca por el aspecto del personaje."
	slots[4] = make_actor(0,20.0)

func make_actor(role: int, span: float) -> Dictionary:
	return {"role":role,"sprite":rng.randi_range(0,3),"born":clock,"until":clock+span}

func advance(_delta: float) -> void:
	for slot in slots.keys():
		if clock >= slots[slot].until:
			if slots[slot].role == 0: misses += 1
			slots.erase(slot)
	if clock < next_wave: return
	var stage := mini(4,correct/3)
	next_wave = clock+rng.randf_range(0.48,0.88)-stage*0.055
	var free: Array[int] = []
	for i in range(SLOTS.size()):
		if not slots.has(i): free.append(i)
	if free.is_empty(): return
	var has_target := slots.values().any(func(entry): return entry.role==0)
	if not has_target and (spawned%3==0 or rng.randf()<0.48):
		if free.size()>1: free.erase(previous)
		var slot := free.pop_at(rng.randi_range(0,free.size()-1)) as int
		slots[slot] = make_actor(0,rng.randf_range(1.55,2.05)-stage*0.18)
		previous = slot
	var additional := mini(free.size(),1+stage/2)
	for i in range(additional):
		var slot := free.pop_at(rng.randi_range(0,free.size()-1)) as int
		slots[slot] = make_actor(rng.randi_range(1,3),rng.randf_range(0.85,1.85))
	spawned += 1

func perform(value: String) -> void:
	if not value.begins_with("spot:"): return
	var slot := int(value.get_slice(":",1))
	if not slots.has(slot): return
	var role: int = slots[slot].role
	slots.erase(slot)
	if tutorial:
		trained()
		next_wave = clock+0.45
		feedback("Marca 15 avisos. Los errores y avisos perdidos reducen la puntuación.", SLOTS[slot])
		return
	flash[slot] = {"until":clock+0.34,"good":role==0}
	if role==0:
		correct += 1
		feedback("Alerta enviada · %d/15"%correct,SLOTS[slot])
	else:
		mistakes += 1
		feedback("Era " + LABELS[role].to_lower() + ". Selecciona solo el aviso explícito.",SLOTS[slot],true)
	score = clampi(100-mistakes*8-misses*3-maxi(0,roundi(active_time)-43),0,100)
	if correct==15:
		finish(score,"15 avisos correctos · %d errores · %d avisos perdidos · %.1f s."%[mistakes,misses,active_time])

func key(code: int) -> void:
	super.key(code)
	if code in range(KEY_1,KEY_9+1): action("spot:%d"%(code-KEY_1))

func status() -> String:
	return "%d/15 alertas    •    %d errores    •    %.1f s"%[correct,mistakes,active_time]

func scene(game: Control) -> void:
	game.draw_texture_rect(CABINET,VIEW,false)
	for i in range(SLOTS.size()):
		var p: Vector2 = SLOTS[i]
		var bay := Rect2(p-Vector2(57,71),Vector2(114,94))
		var hole := Rect2(p-Vector2(57,30),Vector2(114,54))
		game.draw_texture_rect(HOLE_BACK,hole,false)
		if flash.has(i) and clock<flash[i].until:
			game.draw_arc(p-Vector2(0,5),43,0,TAU,32,Color(GREEN if flash[i].good else RED,0.85),3)
		if not slots.has(i):
			game.draw_texture_rect(HOLE_FRONT,hole,false)
			game.text(p+Vector2(-52,12),str(i+1),13,CREAM)
			continue
		var entry: Dictionary = slots[i]
		var reveal := clampf(minf(clock-entry.born,entry.until-clock)*7,0,1)
		var stature := 0.8 if entry.role==2 else 1.0
		actor(game,p+Vector2(0,12-20*reveal),entry.sprite,(0.58+0.30*reveal)*stature,true)
		game.draw_texture_rect(HOLE_FRONT,hole,false)
		if entry.role==1:
			game.draw_line(p+Vector2(11,-24),p+Vector2(14,-10),Color("c5a46a"),2)
		var tag := Rect2(p-Vector2(55,1),Vector2(110,22))
		game.draw_rect(tag,Color("743848") if entry.role==0 else Color("405759"))
		game.text(tag.position+Vector2(0,15),LABELS[entry.role],12,CREAM,true,tag.size.x,HORIZONTAL_ALIGNMENT_CENTER)
		meter(game,p+Vector2(-44,24),88,(entry.until-clock)/1.6,RED if entry.role==0 else GREEN)
		hit(game,bay,"spot:%d"%i)
