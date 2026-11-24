extends Control

var game: Control
var aim := Vector2.ZERO
var zoom := 0

func plaza_frame() -> Rect2:
	var span := 236.0 / (1.0 + zoom * 0.38)
	var scale := size.x / span
	var focus: Vector2 = game.s.player + aim * Vector2(132,94)
	var half_view := size/(2*scale)
	focus = focus.clamp(half_view,Vector2(1280,720)-half_view)
	return Rect2(focus-half_view,2*half_view)

func _draw() -> void:
	var frame := plaza_frame()
	var scale := size.x/frame.size.x
	game.world.draw(self,game.s,Rect2(-frame.position*scale,Vector2(1280,720)*scale),game.elapsed,false,game.arrivals)
	draw_rect(Rect2(Vector2.ZERO,size),Color(0.12,0.16,0.34,game.evening_shade))
