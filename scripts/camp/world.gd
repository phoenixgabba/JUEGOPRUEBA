extends RefCounted
class_name CampWorld

const MAP = preload("res://scripts/camp/plaza_geometry.gd")
const PLAZA = preload("res://assets/acampada/plaza.png")
const PLAYER = preload("res://assets/acampada/player.png")
const PATRICIA = preload("res://assets/acampada/alba.png")
const ALEJANDRO = preload("res://assets/acampada/joan.png")
const MARINA = preload("res://assets/acampada/mar.png")
const TARP = preload("res://assets/acampada/tarp.png")
const POLES = preload("res://assets/acampada/poles.png")
const PEGS = preload("res://assets/acampada/pegs.png")
const TABLE = preload("res://assets/acampada/table.png")
const TENT = preload("res://assets/acampada/tent.png")
const LAID = preload("res://assets/acampada/tent_laid.png")
const FRAMED = preload("res://assets/acampada/tent_poles.png")
const RAISED = preload("res://assets/acampada/tent_raised.png")

const MEETING := Vector2(615, 428)
const SITE := Vector2(410, 392)
const ORGANIZATION := Vector2(625, 261)
const MATERIALS := {"lona": Vector2(235, 423), "varillas": Vector2(540, 435), "piquetas": Vector2(824, 391)}

# The illustrated plaza puts the fountain on the right. Rotate the satellite
# reference into that view, then compress depth to match the paving.
const CAMP_ORIGIN := Vector2(1025, 218)
const CAMP_EAST := Vector2(0, 0.93)
const CAMP_SOUTH := Vector2(-2.25, 0.19)
const DAY_ONE_TENTS := 25
const DAY_TWO_TENTS := 50
const Networks = preload("res://scripts/camp/activities_two/photo.gd")
const DayTwo = preload("res://scripts/camp/day_two.gd")
const KITCHEN_TENTS := 12
const COMMUNICATION_TENTS := 19
const ENTRANCE := Vector2(650, 454)
const ENTRY_APPROACH := Vector2(650, 475)
const COMMUNICATION := Vector2(307, 407)
const KITCHEN := Vector2(540, 402)
const COMMISSION_POINTS := [ORGANIZATION, KITCHEN, COMMUNICATION]
const COMMISSION_NAMES := ["Organización", "Cocina", "Comunicación"]
const CROWD_TEXTURES := [PATRICIA, ALEJANDRO, MARINA, PLAYER]
const VARIANT_BASES := [1,1,0,1,2,1,0,1,1,1,2,0,1,2,1,1,1]
const SKIN_TINTS := [Color("f0c6a3"),Color("deb398"),Color("a97554"),Color("f5d2b4"),Color("e6b391"),Color("b98b68"),Color("f2c9ac"),Color("d5a17d"),Color("edc19d"),Color("c79471"),Color("f1c9ad"),Color("e4b28f"),Color("bf8b65"),Color("eac4a7"),Color("986a4c"),Color("e0ae8a"),Color("d2a17d")]
const HAIR_TINTS := [Color("49352c"),Color("a8a39b"),Color("302529"),Color("8d5835"),Color("ac653c"),Color("272226"),Color("c2b9ad"),Color("6d4934"),Color("54392c"),Color("372a25"),Color("75513b"),Color("bd8950"),Color("282329"),Color("92735b"),Color("392d28"),Color("9a683c"),Color("514039")]
const CLOTH_TINTS := [Color("b56b60"),Color("7e966d"),Color("b58a54"),Color("6688b2"),Color("ba79a0"),Color("6a9b90"),Color("ae8791"),Color("c0a75f"),Color("658e86"),Color("bf7557"),Color("8695bb"),Color("d2a66c"),Color("889e67"),Color("a58cc2"),Color("557a95"),Color("b98b62"),Color("8884aa")]
var crowd_variants: Array[Texture2D] = []

const CROWD_NAMES := ["Tomi","Vicent","Amina","Pau","Cleo","Julian","Rosa","Marc","Carles","Hugo","Anna","Irene","Óscar","Lulu","Dan","David","Àlex"]
const CORE_NAMES := ["Patricia","Alejandro","Marina"]
const MAX_TENTS := 800
const TENT_GROUND := Vector2(9, 5)
const TENT_SIZE := Vector2(23, 21)
const TENT_OFFSET := Vector2(11.5, 17)
const CAMP_TINTS := [Color("e0c2a0"), Color("cad8bd"), Color("e1bfae"), Color.WHITE]
# Red boundary, traced in the supplied satellite crop.
const OCCUPIED_AREA := [
	Vector2(148,126), Vector2(150,117), Vector2(160,97), Vector2(177,91),
	Vector2(224,87), Vector2(245,81), Vector2(260,77), Vector2(270,81),
	Vector2(276,95), Vector2(282,126), Vector2(291,164), Vector2(301,195),
	Vector2(313,231), Vector2(322,259), Vector2(330,291), Vector2(325,307),
	Vector2(321,324), Vector2(295,337), Vector2(263,349), Vector2(231,362),
	Vector2(213,364), Vector2(201,359), Vector2(188,347), Vector2(179,333),
	Vector2(174,321), Vector2(172,309), Vector2(166,294), Vector2(165,269),
	Vector2(166,233), Vector2(160,208), Vector2(159,181), Vector2(160,149),
]

# Four lines drawn on the annotated plaza, from the northern pavement south.
const DAY_ONE_ROWS := [
	[Vector2(435, 323), Vector2(410, 392)],
	[Vector2(476, 318), Vector2(455, 392)],
	[Vector2(515, 318), Vector2(495, 392)],
	[Vector2(554, 318), Vector2(545, 385)],
]
static var day_one_pitches := make_day_one_pitches()

static func make_day_one_pitches() -> PackedVector2Array:
	var pitches := PackedVector2Array()
	for i in range(6):
		var fraction := float(i) / 5.0
		for row_index in range(DAY_ONE_ROWS.size()):
			var row: Array = DAY_ONE_ROWS[row_index]
			var end: Vector2 = SITE.lerp(row[0], 1.0 / 6.0) if row_index == 0 else row[1]
			pitches.append(row[0].lerp(end, fraction))
	return pitches

static var camp_pitches := make_pitches()

static func make_pitches() -> PackedVector2Array:
	var boundary := PackedVector2Array()
	for point in OCCUPIED_AREA:
		boundary.append(CAMP_ORIGIN + CAMP_EAST * point.x + CAMP_SOUTH * point.y)
	var blocks: Array[Vector2] = []
	# Leave crossing routes between blocks and a clearing at the first tent
	# and at the Organization table.
	for row in range(36):
		for column in range(65):
			if row % 8 == 7 or column % 10 == 9:
				continue
			var position := Vector2(210 + 10 * column, 365 + 6 * row)
			if position.distance_to(SITE) < 36 or position.distance_to(MEETING) < 28 or position.distance_to(ENTRANCE) < 20:
				continue
			if position.distance_to(ORGANIZATION) < 30 or position.distance_to(COMMUNICATION) < 30 or position.distance_to(KITCHEN) < 34:
				continue
			var fits := true
			for corner in [Vector2(-5,-3), Vector2(5,-3), Vector2(5,3), Vector2(-5,3)]:
				if not Geometry2D.is_point_in_polygon(position + corner, boundary) or not MAP.walkable(position + corner):
					fits = false
					break
			if fits:
				blocks.append(position)
	# Spread occupied pitches across the available area while preserving
	# the cross aisles, then expand outward from the original site.
	var selected: Array[Vector2] = []
	for i in range(mini(MAX_TENTS - 1, blocks.size())):
		selected.append(blocks[floori(float(i) * blocks.size() / (MAX_TENTS - 1))])
	selected.sort_custom(func(a: Vector2, b: Vector2): return a.distance_squared_to(SITE) < b.distance_squared_to(SITE))
	return PackedVector2Array(selected)

static func pitch_count(s: CampState) -> int:
	return maxi(0, s.tents - 1)

static func personal_tent(s: CampState) -> Vector2:
	return pitch_at(s, 0)

static func tent_door(s: CampState) -> Vector2:
	return clear_spot(personal_tent(s) + Vector2(0, 6), s)

static func next_pitch(s: CampState) -> Vector2:
	return pitch_at(s, s.tents - 1)

static func pitch_at(s: CampState, index: int) -> Vector2:
	var slot := int(s.pitch_swaps.get(str(index), index))
	if slot < day_one_pitches.size():
		return day_one_pitches[slot]
	var new_slot := slot - day_one_pitches.size()
	return Vector2(590 + (new_slot % 5) * 30, 306 + floori(new_slot / 5.0) * 19)

static func tent_goal(s: CampState) -> int:
	return DAY_TWO_TENTS if s.day >= 2 else DAY_ONE_TENTS

static func assign_pitch(s: CampState) -> bool:
	var first := s.tents - 1
	var best := -1
	var distance := 16.0
	for i in range(first, mini(first + 3, tent_goal(s) - 1)):
		var d := s.player.distance_to(pitch_at(s, i))
		if d < distance:
			best = i
			distance = d
	if best < 0:
		return false
	var previous := int(s.pitch_swaps.get(str(first), first))
	s.pitch_swaps[str(first)] = int(s.pitch_swaps.get(str(best), best))
	s.pitch_swaps[str(best)] = previous
	return true

var route_key := ""
var route := Curve2D.new()

func delivery_point(s: CampState, start: Vector2, end: Vector2) -> Vector2:
	var key := "%s:%s:%s:%s" % [s.delivery, s.tents, start, end]
	if route_key != key:
		route_key = key
		route.clear_points()
		var grid := AStarGrid2D.new()
		grid.region = Rect2i(36, 60, 190, 84)
		grid.cell_size = Vector2(4, 4)
		grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
		grid.update()
		for y in range(grid.region.position.y, grid.region.end.y):
			for x in range(grid.region.position.x, grid.region.end.x):
				var id := Vector2i(x, y)
				grid.set_point_solid(id, not walkable(Vector2(id) * 4.0, s))
		var origin := nearby_grid_point(grid, start)
		var to := nearby_grid_point(grid, end)
		if grid.is_in_boundsv(origin) and grid.is_in_boundsv(to):
			for point in grid.get_point_path(origin, to):
				route.add_point(point)
	return route.sample_baked(route.get_baked_length() * s.delivery_progress) if route.point_count > 0 else start

func nearby_grid_point(grid: AStarGrid2D, point: Vector2) -> Vector2i:
	var cell := Vector2i((point / 4.0).round())
	for radius in range(7):
		for y in range(-radius, radius + 1):
			for x in range(-radius, radius + 1):
				var id := cell + Vector2i(x,y)
				if grid.is_in_boundsv(id) and not grid.is_point_solid(id):
					return id
	return Vector2i(-1,-1)

static func walkable(p: Vector2, s: CampState) -> bool:
	if not MAP.walkable(p) or pitch_blocks(p, s):
		return false
	if s.tents > 0 and Rect2(SITE - TENT_GROUND, TENT_GROUND * 2).has_point(p):
		return false
	if s.commissions >= 2:
		if Rect2(KITCHEN - Vector2(7,4), Vector2(16,7)).has_point(p):
			return false
		if Rect2(KITCHEN + Vector2(8,-1), Vector2(20,7)).has_point(p):
			return false
	if s.material_boxes > 0 and Rect2(SITE + Vector2(6,-3), Vector2(27,7)).has_point(p):
		return false
	return true

static func clear_spot(p: Vector2, s: CampState) -> Vector2:
	if walkable(p, s):
		return p
	for distance in range(4, 45, 4):
		for direction in [Vector2.DOWN, Vector2.UP, Vector2.LEFT, Vector2.RIGHT]:
			var nearby: Vector2 = p + direction * distance
			if walkable(nearby, s):
				return nearby
	return ENTRANCE

static func pitch_blocks(p: Vector2, s: CampState) -> bool:
	for i in range(pitch_count(s)):
		if Rect2(pitch_at(s, i) - TENT_GROUND, TENT_GROUND * 2.0).has_point(p):
			return true
	return false

func draw_pitch(c: Control, p: Vector2, index: int) -> void:
	c.draw_texture_rect(TENT, Rect2(p - TENT_OFFSET, TENT_SIZE), false, CAMP_TINTS[index % CAMP_TINTS.size()])

func npc_pos(n: String, s: CampState, t: float) -> Vector2:
	if n == "Patricia" and s.day == 2 and s.phase == "commissions_two" and s.next_day_two_commission() == CampState.NETWORKS:
		return Networks.POINTS[0]
	if s.phase in ["commissions", "expansion", "finished"]:
		return clear_spot(ORGANIZATION + Vector2(-22 + ["Patricia", "Alejandro", "Marina"].find(n) * 22, -14), s)
	var p := Vector2.ZERO
	match n:
		"Patricia": p = Vector2(585, 480)
		"Alejandro": p = Vector2(435, 398)
		"Marina": p = Vector2(755, 407)
	if s.phase == "meeting":
		match n:
			"Patricia": p = Vector2(575, 423)
			"Alejandro": p = Vector2(628, 394)
			"Marina": p = Vector2(687, 423)
	elif s.phase == "build":
		match n:
			"Patricia": p = Vector2(480, 438)
			"Alejandro": p = Vector2(300, 427)
			"Marina": p = Vector2(690, 470)
	# Small walking routines keep the plaza alive without changing logical navigation.
	if s.phase == "materials":
		var shift := 0.0
		match n:
			"Patricia": shift = 0.4
			"Alejandro": shift = 2.1
			"Marina": shift = 4.0
		p += Vector2(sin(t * 0.42 + shift) * 18.0, cos(t * 0.35 + shift) * 7.0)
	return clear_spot(p,s)

func crowd_carrier(i: int,s: CampState) -> bool:
	return s.phase == "expansion" and s.delivery in ["leaving","returning","offer","assign","placing"] and s.tents <= 5 and i == s.tents-1

func crowd_npc_pos(i: int,s: CampState,t: float) -> Vector2:
	var base := crowd_position(i,s)
	var offset := Vector2(sin(t*0.38+i*1.7)*9.0,cos(t*0.31+i*2.1)*5.0)
	return clear_spot(base+offset,s)

func nearest_npc(s: CampState,t: float) -> String:
	var name := ""
	var best := 88.0
	for n in CORE_NAMES:
		var distance := s.player.distance_to(npc_pos(n,s,t))
		if distance < best:
			best = distance
			name = n
	for i in range(CROWD_NAMES.size()):
		if crowd_carrier(i,s): continue
		var distance := s.player.distance_to(crowd_npc_pos(i,s,t))
		if distance < minf(best,30.0):
			best = distance
			name = CROWD_NAMES[i]
	return name

func crowd_position(i: int, s: CampState) -> Vector2:
	var center := MEETING if s.phase == "meeting" else Vector2(440 + (i % 5) * 67, 390 + floori(i / 5.0) * 36)
	var pos := center + Vector2.from_angle(i * TAU / 17.0) * (32.0 + float(i % 3) * 9.0)
	if s.phase in ["commissions", "expansion", "finished", "build"]:
		if i < 3: pos = ORGANIZATION + Vector2(-20 + i * 20, 15)
		elif i < 7: pos = COMMUNICATION + Vector2(-27 + (i - 3) * 18, 12)
		elif i < 10: pos = KITCHEN + Vector2(-21 + (i - 7) * 18, 17)
	return clear_spot(pos, s)

func draw(c: Control, s: CampState, rect: Rect2, t: float, walking: bool, arrival_positions: Array) -> void:
	var v := rect.size / Vector2(1280, 720)
	c.draw_set_transform(rect.position, 0.0, v)
	c.draw_texture_rect(PLAZA, Rect2(0, 0, 1280, 720), false)
	for item in objective_locations(s, t):
		marker(c, item.pos, t)
	if s.phase == "materials":
		for k in MATERIALS:
			if not s.collected[k]:
				var texture: Texture2D = TARP if k == "lona" else (POLES if k == "varillas" else PEGS)
				var p: Vector2 = MATERIALS[k]
				c.draw_circle(p, 8, Color(1.0, 0.85, 0.43, 0.25))
				c.draw_texture_rect(texture, Rect2(p - Vector2(6, 10), Vector2(12, 12)), false)
	if s.phase == "build" and s.build_stage > 0:
		var tex: Texture2D = LAID
		if s.build_stage == 2: tex = FRAMED
		if s.build_stage == 3: tex = RAISED
		if s.build_stage >= 4: tex = TENT
		c.draw_texture_rect(tex, Rect2(camp_build_point(s) - TENT_OFFSET, TENT_SIZE), false)
	if s.phase == "expansion" and s.delivery == "assign":
		for i in range(s.tents - 1, mini(s.tents + 2, tent_goal(s) - 1)):
			var pitch := pitch_at(s, i)
			c.draw_rect(Rect2(pitch - TENT_GROUND, TENT_GROUND * 2.0), Color("ffed9c"), false, 1.0)
	# Characters are ordered by their feet, so overlapping still feels spatial.
	for i in range(DayTwo.NAMES.size()):
		if not s.has_day_two_commission(i): continue
		var point: Vector2 = DayTwo.POINTS[i]
		c.draw_circle(point, 8, Color("36594b"))
		c.draw_arc(point, 8, 0, TAU, 20, Color("eed29b"), 1.5)
	var actors: Array = MAP.scenery.duplicate()
	actors.append_array([
		{"pos":npc_pos("Patricia", s, t), "tex":PATRICIA},
		{"pos":npc_pos("Alejandro", s, t), "tex":ALEJANDRO},
		{"pos":npc_pos("Marina", s, t), "tex":MARINA},
		{"pos":s.player, "tex":PLAYER, "walking":walking}
	])
	if s.phase=="commissions_two" and s.next_day_two_commission()==CampState.NETWORKS and s.phone.data.network.get("started",false):
		actors.append({"pos":Networks.POINTS[2]+Vector2(sin(t*1.5)*8,4),"tex":MARINA,"walking":true})
		actors.append({"pos":KITCHEN+Vector2(-7+sin(t*1.8)*17,13),"tex":ALEJANDRO,"walking":true})
	if s.tents > 0:
		actors.append({"pos":SITE,"pitch":0})
	if s.commissions >= 2:
		actors.append({"pos":KITCHEN, "table":true})
		for i in range(3):
			actors.append({"pos":KITCHEN + Vector2(11 + i * 7, 2), "box":true})
	for i in range(mini(s.material_boxes, 4)):
		actors.append({"pos":SITE + Vector2(8 + i * 7, 0), "box":true})
	var carriers := s.phase == "expansion" and s.delivery in ["leaving", "returning", "offer", "assign", "placing"]
	for i in range(CROWD_NAMES.size()):
		if crowd_carrier(i,s): continue
		actors.append({"pos":crowd_npc_pos(i,s,t),"crowd":i,"name":CROWD_NAMES[i]})
	if carriers:
		var pos := ENTRANCE
		match s.delivery:
			"leaving": pos = delivery_point(s, crowd_position(s.tents - 1, s), ENTRANCE)
			"returning": pos = delivery_point(s, ENTRY_APPROACH, ENTRANCE)
			"placing": pos = delivery_point(s, ENTRANCE, next_pitch(s))
		actors.append({"pos":pos, "crowd":posmod(s.tents - 1,CROWD_NAMES.size()), "walking":s.delivery in ["leaving", "returning", "placing"]})
	if s.day == 2 and s.delivery == "delegated":
		var guest := delivery_point(s, ENTRY_APPROACH, next_pitch(s))
		actors.append({"pos":guest, "crowd":posmod(s.tents,CROWD_NAMES.size()), "walking":true})
		actors.append({"pos":clear_spot(guest + Vector2(-12, 4), s), "tex":MARINA, "walking":true})
	for i in range(arrival_positions.size()):
		actors.append({"pos":arrival_positions[i], "crowd":posmod(s.tents+i,CROWD_NAMES.size())})
	for i in range(pitch_count(s)):
		actors.append({"pos": pitch_at(s, i), "pitch": i})
	actors.sort_custom(func(a, b): return a.pos.y < b.pos.y)
	for a in actors:
		if a.has("cutout"):
			MAP.draw_cutout(c, PLAZA, a.cutout)
			continue
		if a.has("box"):
			box(c, a.pos)
			continue
		if a.has("table"):
			c.draw_texture_rect(TABLE, Rect2(a.pos - Vector2(8, 13), Vector2(16, 16)), false)
			continue
		if a.has("pitch"):
			draw_pitch(c, a.pos, a.pitch)
			if s.tents >= 2 and a.pos == personal_tent(s):
				c.draw_rect(Rect2(a.pos + Vector2(-4, -13), Vector2(8, 4)), Color("84d5de"))
			continue
		if a.has("crowd"):
			draw_crowd_actor(c,a.pos,int(a.crowd),t,bool(a.get("walking",true)))
		else:
			actor(c, a.tex, a.pos, t, bool(a.get("walking", s.phase not in ["talk", "meeting"])))
	c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

static func camp_build_point(s: CampState) -> Vector2:
	return SITE if s.tents == 0 else next_pitch(s)

func box(c: Control, pos: Vector2) -> void:
	c.draw_rect(Rect2(pos - Vector2(3, 4), Vector2(6, 5)), Color("9a7244"))
	c.draw_line(pos - Vector2(3, 3), pos + Vector2(3, -3), Color("d0aa71"))

func map_locations(s: CampState, t: float) -> Array[Dictionary]:
	var locations: Array[Dictionary] = [{"label":"Tú", "pos":s.player, "kind":"player"}]
	if s.tents >= 2 and s.phase not in ["return_tent", "wake"]:
		locations.append({"label":"Tu tienda", "pos":personal_tent(s), "kind":"built"})
	if s.tents > 0:
		locations.append({"label":"Almacén", "pos":SITE, "kind":"built"})
	for i in range(s.commissions):
		locations.append({"label":COMMISSION_NAMES[i], "pos":COMMISSION_POINTS[i], "kind":"built"})
	for i in range(DayTwo.NAMES.size()):
		if not s.has_day_two_commission(i): continue
		locations.append({"label":DayTwo.NAMES[i], "pos":DayTwo.POINTS[i], "kind":"built"})
	locations.append_array(objective_locations(s, t))
	return locations

func objective_locations(s: CampState, t: float) -> Array[Dictionary]:
	var items: Array[Dictionary] = []
	match s.phase:
		"return_tent", "wake":
			items.append({"label":"Tu tienda", "pos":personal_tent(s), "kind":"goal"})
		"meeting_two": items.append({"label":"Segunda asamblea", "pos":MEETING, "kind":"goal"})
		"commissions_two":
			var index := s.next_day_two_commission()
			if index==CampState.NETWORKS and s.phone.data.profile.get("configured",false) and s.phone.data.network.get("started",false):
				var subject := Networks.next_subject(s.phone)
				if subject>=0: items.append({"label":Networks.SUBJECT_NAMES[subject],"pos":Networks.POINTS[subject],"kind":"goal"})
			elif index >= 0:
				items.append({"label":DayTwo.NAMES[index], "pos":DayTwo.POINTS[index], "kind":"goal"})
		"talk":
			for name in ["Patricia", "Alejandro", "Marina"]:
				if not s.talked[name]:
					items.append({"label":name, "pos":npc_pos(name,s,t), "kind":"goal"})
		"meeting": items.append({"label":"Asamblea", "pos":MEETING, "kind":"goal"})
		"materials":
			for key in MATERIALS:
				if not s.collected[key]:
					items.append({"label":str(key).capitalize(), "pos":MATERIALS[key], "kind":"goal"})
		"build": items.append({"label":"Montar tienda", "pos":camp_build_point(s), "kind":"goal"})
		"commissions":
			items.append({"label":"Formar " + COMMISSION_NAMES[s.commissions], "pos":COMMISSION_POINTS[s.commissions], "kind":"goal"})
		"expansion":
			match s.delivery:
				"offer": items.append({"label":"Llegada", "pos":ENTRANCE, "kind":"goal"})
				"assign": items.append({"label":"Elegir parcela", "pos":next_pitch(s), "kind":"goal"})
				"unload": items.append({"label":"Guardar material", "pos":SITE, "kind":"goal"})
				"close": items.append({"label":"Cerrar el día", "pos":ORGANIZATION, "kind":"goal"})
	return items

func marker(c: Control, pos: Vector2, t: float) -> void:
	var r := 9.0 + sin(t * 3.0)
	c.draw_arc(pos, r, 0, TAU, 32, Color("ffed9c"), 1.0)

func actor(c: Control, tex: Texture2D, pos: Vector2, t: float, walking: bool) -> void:
	c.draw_circle(pos, 4, Color(0.16, 0.14, 0.10, 0.27))
	var bob := sin(t * 9.0 + pos.x) * 0.5 if walking else sin(t * 1.7 + pos.x) * 0.15
	c.draw_texture_rect(tex, Rect2(pos + Vector2(-5, -16 + bob), Vector2(10, 17)), false)

func recolor_variant(source: Texture2D,index: int,base: int) -> Texture2D:
	var pixels := source.get_image()
	if pixels.is_compressed(): pixels.decompress()
	pixels.convert(Image.FORMAT_RGBA8)
	var w := pixels.get_width()
	var h := pixels.get_height()
	for y in range(h):
		for x in range(w):
			var original := pixels.get_pixel(x,y)
			if original.a <= 0.0: continue
			var ny := float(y)/float(h)
			var hue := original.h
			var sat := original.s
			var light := original.v
			var target := Color.WHITE
			var strength := 0.0
			if light < 0.13: continue
			var warm := hue < 0.15 or hue > 0.96
			# Shirt palette first, before the overlapping warm skin palette.
			var shirt := (base == 0 and hue > 0.09 and hue < 0.18 and sat > 0.37) or (base == 1 and hue > 0.39 and hue < 0.65 and sat > 0.19) or (base == 2 and hue > 0.65 and hue < 0.91 and sat > 0.16)
			if ny > 0.36 and ny < 0.66 and shirt:
				target = CLOTH_TINTS[index]
				strength = 0.95
			elif warm and sat > 0.28 and light > 0.47 and (ny < 0.43 or (ny > 0.48 and ny < 0.73)):
				target = SKIN_TINTS[index]
				strength = 0.85
			elif ny < (0.36 if base == 1 else 0.49) and warm and sat > 0.12 and light < 0.54:
				target = HAIR_TINTS[index]
				strength = 0.90
			if strength > 0.0:
				var recolored := Color.from_hsv(target.h,lerpf(sat,target.s,strength),clampf(light*lerpf(1.0,target.v/0.85,strength*0.65),0,1),original.a)
				pixels.set_pixel(x,y,recolored)
	return ImageTexture.create_from_image(pixels)

func draw_crowd_actor(c: Control,pos: Vector2,index: int,t: float,walking: bool) -> void:
	if crowd_variants.is_empty():
		for i in range(CROWD_NAMES.size()):
			var base: int = VARIANT_BASES[i]
			crowd_variants.append(recolor_variant(CROWD_TEXTURES[base],i,base))
	actor(c,crowd_variants[posmod(index,crowd_variants.size())],pos,t,walking)
