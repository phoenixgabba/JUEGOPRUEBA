extends RefCounted

const GREEN := Color("a7d594")
const GOLD := Color("f6cb81")
const RED := Color("eb947d")
const INK := Color("182d2d")
const CREAM := Color("fff1d4")
const VIEW := Rect2(18, 85, 404, 318)
var rng := RandomNumberGenerator.new()
var clock := 0.0
var active_time := 0.0
var score := 0
var done := false
var cue := false
var tutorial := true
var report := false
var notice := ""
var bursts: Array[Dictionary] = []
var drag_id := -2
var drag_cursor := Vector2.ZERO
var result: Dictionary = {}
var wide := false
var controls_offset := Vector2.ZERO
var title := ""
var help := ""
var summary := ""

func initialize(seed_value: int, _plan: String) -> void:
	rng.seed = seed_value

func tick(delta: float) -> void:
	clock += delta
	for i in range(bursts.size() - 1, -1, -1):
		if clock - bursts[i].time > 0.6: bursts.remove_at(i)
	if not tutorial and not report:
		active_time += delta
		advance(delta)

func advance(_delta: float) -> void:
	pass

func action(value: String) -> void:
	if report:
		if value == "finish": done = true
		return
	perform(value)

func perform(_value: String) -> void:
	pass

func trained() -> void:
	if tutorial:
		tutorial = false
		notice = ""

func finish(points: int, details: String) -> void:
	score = clampi(points, 0, 100)
	summary = details
	report = true
	cue = true

func feedback(message: String, point: Vector2 = Vector2(220, 230)) -> void:
	notice = message
	cue = true
	bursts.append({"p":point, "time":clock})

func key(code: int) -> void:
	if code == KEY_ENTER and report: action("finish")

func press(point: Vector2, index: int) -> bool:
	if drag_id != -2 or report or not begin_drag(point): return false
	drag_id = index
	drag_cursor = point
	return true

func move(delta: Vector2, index: int) -> void:
	if index != drag_id: return
	drag_cursor += delta
	move_drag(delta)

func release(index: int) -> void:
	if index != drag_id: return
	drag_id = -2
	end_drag(drag_cursor)

func begin_drag(_point: Vector2) -> bool:
	return false

func move_drag(_delta: Vector2) -> void:
	pass

func end_drag(_point: Vector2) -> void:
	pass

func draw(game: Control) -> void:
	var size: Vector2 = game.size_v
	wide = size.x > size.y * 1.25
	var layout := Vector2(875, 453) if wide else Vector2(440, 715)
	var scale := minf((size.x - 20) / layout.x, (size.y - 20) / layout.y)
	if not game.mobile_layout: scale = minf(scale, 1.25)
	var origin := (size - layout * scale) / 2
	game.draw_rect(Rect2(Vector2.ZERO, size), Color(0.04, 0.09, 0.09, 0.78))
	game.mini_scale = scale
	game.mini_rect = Rect2(origin, layout * scale)
	game.draw_set_transform(origin, 0, Vector2.ONE * scale)
	game.drawing_mini = true
	game.panel(Rect2(Vector2.ZERO, layout), INK, Color("b79b67"))
	game.text(Vector2(18, 35), title, 25, GOLD, true)
	game.button(Rect2(layout.x - 64, 9, 54, 49), "Ⅱ" if game.test_build else "×", "pause" if game.test_build else "commission_close", false, 22)
	game.text(Vector2(18, 65), status(), 16, GREEN, true, 405)
	scene(game)
	for burst in bursts:
		var age: float = clock - burst.time
		for i in range(8):
			var offset := Vector2.from_angle(i * TAU / 8) * (10 + age * 52)
			game.draw_rect(Rect2(burst.p + offset, Vector2(3, 3)), Color(GOLD, 1.0-age/0.6))
	controls_offset = Vector2(430, -342) if wide else Vector2.ZERO
	game.mini_rect.position = origin + controls_offset * scale
	game.draw_set_transform(game.mini_rect.position, 0, Vector2.ONE * scale)
	label(game, Vector2(20, 425), help if tutorial else notice, 398, GOLD)
	if report:
		label(game, Vector2(20, 492), summary, 396)
		game.text(Vector2(20, 575), "%d / 100 puntos" % score, 28, GREEN, true)
		button(game, Rect2(20, 607, 194, 58), "Repetir actividad", "retry")
		button(game, Rect2(226, 607, 194, 58), "Volver a la plaza", "finish", true)
	else:
		controls(game)
	game.drawing_mini = false
	game.mini_rect.position = origin
	game.draw_set_transform(Vector2.ZERO)

func status() -> String:
	return "Prueba los controles" if tutorial else "%d puntos" % score

func scene(_game: Control) -> void:
	pass

func controls(_game: Control) -> void:
	pass

func button(game: Control, rect: Rect2, caption: String, id: String, selected: bool = false, font_size: int = 18) -> void:
	game.button(rect, caption, "activity:" + id, selected, font_size)

func label(game: Control, point: Vector2, caption: String, width: float = 345, color: Color = CREAM) -> void:
	game.paragraph(point, caption, width, 17, color, 1.13)

func backdrop(game: Control, site: Vector2, tint: Color, span: Vector2 = Vector2(206,162)) -> void:
	var ratio := Vector2(game.World.PLAZA.get_size()) / Vector2(1280,720)
	game.draw_texture_rect_region(game.World.PLAZA, VIEW, Rect2((site-span/2)*ratio, span*ratio))
	game.draw_rect(VIEW, tint)

func actor(game: Control, p: Vector2, id: int, size: float = 1.0, walking: bool = false) -> void:
	var bounce := roundf(sin(clock * (13.0 if walking else 4.0) + id) * 2) * size
	game.draw_circle(p, 9 * size, Color(0.1,0.12,0.16,0.38))
	game.draw_texture_rect(game.World.CROWD_TEXTURES[posmod(id,4)], Rect2(p+Vector2(-13,-39)*size+Vector2(0,bounce),Vector2(26,40)*size), false)

func item(game: Control, tex: Texture2D, center: Vector2, size: Vector2) -> void:
	game.draw_texture_rect(tex, Rect2(center-size/2,size), false)

func meter(game: Control, pos: Vector2, width: float, value: float, color: Color) -> void:
	game.draw_rect(Rect2(pos,Vector2(width,7)), INK)
	game.draw_rect(Rect2(pos,Vector2(width*clampf(value,0,1),7)), color)

func hit(game: Control, rect: Rect2, id: String) -> void:
	if not report: game.clickables.append({"rect":game.mini_hit(rect),"id":"activity:"+id})
