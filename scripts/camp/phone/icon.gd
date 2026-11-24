extends Button

const PAPER := Color("f5edd5")
var app := ""
var caption := ""
var tint := Color("509873")

func _ready() -> void:
	resized.connect(queue_redraw)

func _draw() -> void:
	var origin := Vector2(size.x/2-24,4)
	draw_set_transform(origin)
	var box := StyleBoxFlat.new()
	box.bg_color = tint
	box.set_corner_radius_all(12)
	box.shadow_color = Color(0.04,0.13,0.11,0.6)
	box.shadow_size = 3
	box.shadow_offset = Vector2(0,3)
	draw_style_box(box,Rect2(0,0,48,48))
	var center := Vector2(24,24)
	match app:
		"contacts":
			draw_circle(Vector2(24,18),7,PAPER)
			draw_rect(Rect2(13,27,22,10),PAPER)
		"social","camera":
			draw_rect(Rect2(11,13,26,23),PAPER,false,3)
			if app=="camera": draw_rect(Rect2(19,9,11,6),PAPER)
			draw_arc(center,7,0,TAU,22,PAPER,3)
			if app=="social": draw_circle(Vector2(32,17),1.5,PAPER)
		"messages":
			draw_circle(Vector2(24,23),14,PAPER)
			draw_colored_polygon(PackedVector2Array([Vector2(14,28),Vector2(12,37),Vector2(24,30)]),PAPER)
			for x in [18,24,30]: draw_circle(Vector2(x,23),1.5,tint)
		"mail":
			draw_rect(Rect2(10,14,28,21),PAPER,false,2)
			draw_polyline(PackedVector2Array([Vector2(11,15),Vector2(24,26),Vector2(37,15)]),PAPER,2)
		"gallery":
			draw_rect(Rect2(10,11,28,26),PAPER)
			draw_colored_polygon(PackedVector2Array([Vector2(11,36),Vector2(21,20),Vector2(27,26),Vector2(31,22),Vector2(37,36)]),tint)
			draw_circle(Vector2(31,17),3,tint)
		"map":
			draw_polyline(PackedVector2Array([Vector2(10,15),Vector2(20,11),Vector2(30,15),Vector2(38,11),Vector2(38,33),Vector2(30,37),Vector2(20,33),Vector2(10,37),Vector2(10,15)]),PAPER,2)
			draw_circle(Vector2(25,23),5,PAPER)
		"agenda","notes":
			draw_rect(Rect2(13,11,22,27),PAPER)
			for y in [19,25,31]: draw_rect(Rect2(17,y,14,2),tint)
		"files":
			draw_rect(Rect2(10,16,28,20),PAPER)
			draw_rect(Rect2(11,12,12,6),PAPER)
		"settings":
			for i in range(8):
				var angle := Vector2.from_angle(i*TAU/8)
				draw_line(center+angle*9,center+angle*15,PAPER,4)
			draw_arc(center,10,0,TAU,24,PAPER,3)
		"clock":
			draw_circle(center,15,PAPER)
			draw_polyline(PackedVector2Array([Vector2(24,13),center,Vector2(31,28)]),tint,3)
	draw_set_transform(Vector2.ZERO)
	var font := get_theme_default_font()
	draw_string(font,Vector2(0,72),caption,HORIZONTAL_ALIGNMENT_CENTER,size.x,16,PAPER)
