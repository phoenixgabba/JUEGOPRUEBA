extends Control

const World = preload("res://scripts/camp/world.gd")
const Photo = preload("res://scripts/camp/activities_two/photo.gd")
var shot: Dictionary
var renderer := Photo.new()

func _draw() -> void:
	if shot.is_empty(): return
	var scale := minf(size.x/404,size.y/318)
	draw_set_transform((size-Vector2(404,318)*scale)/2.0-Photo.VIEW.position*scale,0,Vector2.ONE*scale)
	renderer.draw_photo(self,shot,Vector2.ZERO)
