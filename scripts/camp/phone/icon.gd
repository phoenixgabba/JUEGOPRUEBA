extends Button

const ART := {
	"contacts": preload("res://assets/visual/app_contacts.png"),
	"social": preload("res://assets/visual/app_social.png"),
	"messages": preload("res://assets/visual/app_messages.png"),
	"mail": preload("res://assets/visual/app_mail.png"),
	"camera": preload("res://assets/visual/app_camera.png"),
	"gallery": preload("res://assets/visual/app_gallery.png"),
	"map": preload("res://assets/visual/app_map.png"),
	"agenda": preload("res://assets/visual/app_agenda.png"),
	"notes": preload("res://assets/visual/app_notes.png"),
	"files": preload("res://assets/visual/app_files.png"),
	"settings": preload("res://assets/visual/app_settings.png"),
	"clock": preload("res://assets/visual/app_clock.png"),
	"calls": preload("res://assets/visual/app_calls.png"),
	"notices": preload("res://assets/visual/app_notices.png"),
}
var app := ""
var caption := ""
var tint := Color("509873")
var icon_size := 57.0

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	resized.connect(queue_redraw)

func _draw() -> void:
	var extent := minf(icon_size,size.x-8)
	var origin := Vector2((size.x-extent)/2,4)
	var artwork: Texture2D = ART.get(app)
	if artwork != null:
		draw_texture_rect(artwork,Rect2(origin,Vector2.ONE*extent),false)
	if not caption.is_empty():
		var font := get_theme_default_font()
		draw_string(font,Vector2(0,extent+20),caption,HORIZONTAL_ALIGNMENT_CENTER,size.x,14,Color.WHITE)
