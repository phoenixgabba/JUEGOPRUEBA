extends Control

var game: Control
var aim := Vector2.ZERO
var zoom := 0

func _draw() -> void:
	var plaza_size := Vector2(1280,720)
	var span := 236.0 / (1.0 + zoom * 0.38)
	var scale := size.x / span
	var focus: Vector2 = game.s.player + aim * Vector2(132,94)
	var half_view := size/(2*scale)
	focus = focus.clamp(half_view,plaza_size-half_view)
	var rect := Rect2(size/2-focus*scale,plaza_size*scale)
	game.world.draw(self,game.s,rect,game.elapsed,false,game.arrivals)
	draw_rect(Rect2(Vector2.ZERO,size),Color(0.12,0.16,0.34,game.evening_shade))
