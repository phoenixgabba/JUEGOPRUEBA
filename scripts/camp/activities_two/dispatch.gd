extends "res://scripts/camp/activities_two/session.gd"

const CABINET := preload("res://assets/visual/arcade_board.png")
const HOLE_BACK := preload("res://assets/visual/hole_back.png")
const HOLE_FRONT := preload("res://assets/visual/hole_front.png")

const SLOTS := [Vector2(76,172),Vector2(219,172),Vector2(362,172),Vector2(76,273),Vector2(219,273),Vector2(362,273),Vector2(76,373),Vector2(219,373),Vector2(362,373)]
const CHARACTERS := preload("res://assets/seguridad/personajes.svg")
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
	help = "Identifica a los agitadores neonazis por la esvástica de su uniforme. Toca para avisar a Seguridad. No marques a niños ni a personas mayores."
	slots[4] = make_actor(0,20.0)

func make_actor(role: int, span: float) -> Dictionary:
	return {"role":role,"sprite":role*2+rng.randi_range(0,1),"born":clock,"until":clock+span}

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
		slots[slot] = make_actor(rng.randi_range(1,2),rng.randf_range(0.85,1.85))
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
		feedback("Identifica a 15 agitadores. Evita marcar a los civiles.", SLOTS[slot])
		return
	flash[slot] = {"until":clock+0.34,"good":role==0}
	if role==0:
		correct += 1
		feedback("Alerta enviada · %d/15"%correct,SLOTS[slot])
	else:
		mistakes += 1
		feedback("¡Cuidado! Era una persona civil.",SLOTS[slot],true)
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
		var frame: int = entry.sprite
		var height := 94.0 if entry.role == 0 else 81.0
		var width := height*96.0/112.0
		var bottom := p.y+16.0 if entry.role == 0 else p.y+23.0
		var visible := maxf(1.0,112.0*reveal)
		var drawn_height := height*visible/112.0
		var source := Rect2(frame*96,0,96,visible)
		var destination := Rect2(p.x-width/2,bottom-drawn_height,width,drawn_height)
		game.draw_texture_rect_region(CHARACTERS,destination,source)
		game.draw_texture_rect(HOLE_FRONT,hole,false)
		hit(game,bay,"spot:%d"%i)
