extends "res://scripts/camp/activities_two/session.gd"

const SLOTS := [Vector2(76,172),Vector2(219,172),Vector2(362,172),Vector2(76,273),Vector2(219,273),Vector2(362,273),Vector2(76,373),Vector2(219,373),Vector2(362,373)]
const LABELS := ["NAZI", "ANCIANA", "NIÑO", "VECINO"]
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
	help = "Golpea solo a los nazis. Esquiva a niños, ancianas y vecinas de la plaza."
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
	next_wave = clock+rng.randf_range(0.45,0.82)-stage*0.05
	var free: Array[int] = []
	for i in range(SLOTS.size()):
		if not slots.has(i): free.append(i)
	if free.is_empty(): return
	var has_target := slots.values().any(func(entry): return entry.role==0)
	if not has_target and (spawned%2==0 or rng.randf()<0.52):
		if free.size()>1: free.erase(previous)
		var slot := free.pop_at(rng.randi_range(0,free.size()-1)) as int
		slots[slot] = make_actor(0,rng.randf_range(1.40,1.92)-stage*0.15)
		previous = slot
	var additional := mini(free.size(),1+stage/2)
	for i in range(additional):
		var slot := free.pop_at(rng.randi_range(0,free.size()-1)) as int
		slots[slot] = make_actor(rng.randi_range(1,3),rng.randf_range(0.92,1.95))
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
		feedback("Tienes que encontrar 15 nazis. Tocar a un niño o a una anciana cuenta como error.", SLOTS[slot])
		return
	flash[slot] = {"until":clock+0.34,"good":role==0}
	if role==0:
		correct += 1
		feedback("Alerta resuelta · %d/15"%correct,SLOTS[slot])
	else:
		mistakes += 1
		feedback("Era %s. Solo debes golpear a los nazis." % LABELS[role].to_lower(),SLOTS[slot],true)
	score = clampi(100-mistakes*9-misses*3-maxi(0,roundi(active_time)-40),0,100)
	if correct==15:
		finish(score,"15 nazis detectados · %d errores · %d avisos perdidos · %.1f s."%[mistakes,misses,active_time])

func key(code: int) -> void:
	super.key(code)
	if code in range(KEY_1,KEY_9+1): action("spot:%d"%(code-KEY_1))

func status() -> String:
	return "%d/15 nazis    •    %d errores    •    %.1f s"%[correct,mistakes,active_time]

func scene(game: Control) -> void:
	backdrop(game,Vector2(710,450),Color(0.15,0.21,0.15,0.12))
	for i in range(SLOTS.size()):
		var p: Vector2 = SLOTS[i]
		var bay := Rect2(p-Vector2(57,71),Vector2(114,94))
		game.draw_rect(bay,Color("7d5a34"))
		game.draw_rect(bay.grow(-4),Color("b68855"),false,3)
		for ring in range(2):
			game.draw_circle(p+Vector2(0,11),34-ring*6,Color("261814"))
		if flash.has(i) and clock<flash[i].until:
			game.draw_rect(bay,Color(GREEN if flash[i].good else RED,0.58),false,4)
		if not slots.has(i):
			game.text(p+Vector2(-52,12),str(i+1),13,CREAM)
			continue
		var entry: Dictionary = slots[i]
		var reveal := clampf(minf(clock-entry.born,entry.until-clock)*7,0,1)
		draw_role(game, p-Vector2(0,8*reveal), entry.role, reveal)
		var tag := Rect2(p-Vector2(50,1),Vector2(100,22))
		game.draw_rect(tag,Color("7b2f33") if entry.role==0 else Color("405759"))
		game.text(tag.position+Vector2(0,15),LABELS[entry.role],12,CREAM,true,tag.size.x,HORIZONTAL_ALIGNMENT_CENTER)
		meter(game,p+Vector2(-44,24),88,(entry.until-clock)/1.5,RED if entry.role==0 else GREEN)
		hit(game,bay,"spot:%d"%i)

func draw_role(game: Control, p: Vector2, role: int, reveal: float) -> void:
	var bob := sin(clock * 8.0 + p.x * 0.03) * 1.5 * reveal
	match role:
		0:
			game.draw_rect(Rect2(p+Vector2(-10,-9+bob),Vector2(20,28)),Color("18161b"))
			game.draw_rect(Rect2(p+Vector2(-9,5+bob),Vector2(18,10)),Color("7c1f22"))
			game.draw_rect(Rect2(p+Vector2(-4,-18+bob),Vector2(8,9)),Color("e5c09b"))
			game.draw_rect(Rect2(p+Vector2(-11,-23+bob),Vector2(22,6)),Color("101015"))
			game.draw_line(p+Vector2(-4,0+bob),p+Vector2(-14,8+bob),Color("e5c09b"),3)
			game.draw_line(p+Vector2(4,0+bob),p+Vector2(12,11+bob),Color("e5c09b"),3)
		1:
			game.draw_rect(Rect2(p+Vector2(-10,-4+bob),Vector2(20,23)),Color("876aa3"))
			game.draw_circle(p+Vector2(0,-12+bob),8,Color("d6cec1"))
			game.draw_line(p+Vector2(10,-2+bob),p+Vector2(18,16+bob),Color("d1b07c"),2)
			game.draw_line(p+Vector2(-3,17+bob),p+Vector2(-7,27+bob),Color("d1b07c"),2)
			game.draw_line(p+Vector2(3,17+bob),p+Vector2(7,27+bob),Color("d1b07c"),2)
		2:
			game.draw_rect(Rect2(p+Vector2(-8,-2+bob),Vector2(16,18)),Color("3d8aac"))
			game.draw_circle(p+Vector2(0,-10+bob),7,Color("efc49d"))
			game.draw_line(p+Vector2(-3,15+bob),p+Vector2(-6,24+bob),Color("efc49d"),2)
			game.draw_line(p+Vector2(3,15+bob),p+Vector2(6,24+bob),Color("efc49d"),2)
		3:
			game.draw_rect(Rect2(p+Vector2(-10,-5+bob),Vector2(20,23)),Color("47705d"))
			game.draw_circle(p+Vector2(0,-13+bob),8,Color("f0c8a0"))
			game.draw_line(p+Vector2(-3,17+bob),p+Vector2(-7,27+bob),Color("f0c8a0"),2)
			game.draw_line(p+Vector2(3,17+bob),p+Vector2(7,27+bob),Color("f0c8a0"),2)
