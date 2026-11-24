extends Control

const Story = preload("res://scripts/camp/phone/story.gd")
const PhotoCard = preload("res://scripts/camp/phone/photo_card.gd")
const Icon = preload("res://scripts/camp/phone/icon.gd")
const Data = preload("res://scripts/camp/phone/data.gd")
const Photo = preload("res://scripts/camp/activities_two/photo.gd")
const APPS := [
	["contacts","Contactos","●","799b94"],["social","Instagram","◎","ab5475"],["messages","Mensajes","▰","509873"],
	["mail","Gmail","✉","557caa"],["camera","Cámara","◉","73838e"],["gallery","Galería","▧","bd9450"],
	["map","Mapa","◆","729265"],["agenda","Agenda","▦","a27158"],["notes","Notas","≡","bc964d"],
	["files","Archivos","■","558da3"],["settings","Ajustes","✦","76868b"],["clock","Reloj","◷","776b96"],
]
const NAMES := {"home":"Acampada València","contacts":"Contactos","social":"Instagram · simulación","messages":"Mensajes",
	"mail":"Gmail · simulación","camera":"Cámara","gallery":"Fotos","map":"Mapa","agenda":"Agenda","notes":"Notas",
	"files":"Archivos","settings":"Ajustes","clock":"Reloj","calls":"Teléfono","direct":"Mensajes directos",
	"notices":"Notificaciones","compose":"Redactar","attachment":"Adjunto"}
const FONTS := preload("res://assets/template/fonts/ui_regular.tres")
const INK := Color("171a20")
const PAPER := Color("202124")
const GOLD := Color("176bd1")
const WALLPAPER := preload("res://assets/visual/phone_wallpaper.png")
var game: Control
var phone: Data
var handset: Panel
var content: VBoxContainer
var scroll: ScrollContainer
var routes := preload("res://scripts/camp/phone/navigation.gd").new()
var at: String:
	get: return routes.app
var target: String:
	get: return routes.item
var status: Label
var signals: Control
var progress := 0.0
var shown := false
var switching := false
const Camera = preload("res://scripts/camp/phone/camera.gd")
var viewfinder: SubViewport
var camera_stage: Camera
var camera_clock := 0.0
var capturing := false
var zoom := 0
var aim := Vector2.ZERO
var view: TextureRect
var call_state := ""
var call_name := ""
var call_seconds := 0.0
var call_incoming := false
var textures := {}
var letter_tab := "in"
var social_tab := "feed"
var message_edit: LineEdit
var notify_sound := AudioStreamPlayer.new()
var vibration_time := 0.0
var notification_count := 0
var timer_labels: Dictionary = {}

func setup(owner_game: Control) -> void:
	game = owner_game
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	z_index = 10
	theme = make_theme()
	handset = Panel.new()
	handset.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(handset)
	handset.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var frame := style(Color("090b0e"),Color("9da6b1"),43,3)
	frame.shadow_color = Color(0,0,0,0.72)
	frame.shadow_size = 12
	frame.shadow_offset = Vector2(0,5)
	handset.add_theme_stylebox_override("panel",frame)
	handset.draw.connect(func():
		var screen := Rect2(Vector2(9,9),handset.size-Vector2(18,18))
		handset.draw_style_box(style(screen_color(),Color("101217"),34,1),screen)
		if at=="home": handset.draw_texture_rect(WALLPAPER,screen,false)
		var island := Rect2(Vector2(handset.size.x/2-57,18),Vector2(114,27))
		handset.draw_style_box(style(Color("08090b"),Color("171c24"),15,1),island)
		handset.draw_circle(island.position+Vector2(96,13),4,Color("192231"))
		handset.draw_circle(island.position+Vector2(95,12),1.5,Color("465a7f"))
		var bar := Rect2(Vector2(handset.size.x/2-62,handset.size.y-22),Vector2(124,5))
		handset.draw_style_box(style(foreground(),Color.TRANSPARENT,3),bar))
	viewfinder = SubViewport.new()
	viewfinder.size = Vector2i(480,316)
	viewfinder.disable_3d = true
	viewfinder.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(viewfinder)
	camera_stage = Camera.new()
	camera_stage.size = Vector2(viewfinder.size)
	camera_stage.game = game
	camera_stage.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	viewfinder.add_child(camera_stage)
	add_child(notify_sound)
	notify_sound.stream = game.CUE.tone(740,0.14,0.09,910)

func is_dark() -> bool:
	return at in ["home","camera","clock","notices"] or (at=="calls" and call_state in ["Entrante","Marcando","En llamada"])

func foreground() -> Color:
	return Color("f7f7fb") if is_dark() else PAPER

func accent() -> Color:
	if at=="notes" or at=="clock": return Color("f5b93b") if is_dark() else Color("936009")
	if at=="calls" or at=="messages": return Color("25a951")
	if at=="mail": return Color("1769c2")
	if at=="social": return Color("1679e8")
	if at=="agenda": return Color("d94b54")
	return Color("76b7ff") if is_dark() else GOLD

func screen_color() -> Color:
	if at=="home": return Color("151b36")
	if at=="camera": return Color("101116")
	if at=="calls" and is_dark(): return Color("202a3c")
	if at in ["clock","notices"]: return Color("171a24")
	if at in ["social","mail","messages","contacts","gallery","files"]: return Color("ffffff")
	if at=="notes": return Color("fffcf1")
	return Color("f2f2f7")

func make_theme() -> Theme:
	var result := Theme.new()
	result.default_font = FONTS
	result.default_font_size = 19
	var surface := Color("303747") if is_dark() else Color("f0f1f5")
	var pressed := Color("495366") if is_dark() else Color("e2e6ed")
	for state in ["normal","hover","pressed","focus","disabled"]:
		var fill := surface if state in ["normal","disabled"] else pressed
		result.set_stylebox(state,"Button",style(fill,Color.TRANSPARENT,12))
		result.set_stylebox(state,"OptionButton",style(fill,Color.TRANSPARENT,10))
	for kind in ["Label","Button","LineEdit","OptionButton","CheckButton"]:
		result.set_color("font_color",kind,foreground())
		result.set_color("font_hover_color",kind,foreground())
		result.set_color("font_pressed_color",kind,foreground())
	result.set_color("caret_color","LineEdit",foreground())
	result.set_color("font_placeholder_color","LineEdit",Color("9499a4") if is_dark() else Color("747985"))
	result.set_stylebox("normal","LineEdit",style(surface,Color.TRANSPARENT,10))
	result.set_stylebox("focus","LineEdit",style(surface,accent(),10,2))
	result.set_stylebox("scroll","VScrollBar",StyleBoxEmpty.new())
	result.set_stylebox("grabber","VScrollBar",style(Color(0.5,0.5,0.55,0.5),Color.TRANSPARENT,4))
	return result

func style(color: Color,border: Color, radius: int, width: int = 0) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.border_color = border
	box.set_border_width_all(width)
	box.set_corner_radius_all(radius)
	box.set_content_margin_all(8)
	return box

func reset(next: Data) -> void:
	Input.emulate_mouse_from_touch = false
	phone = next
	shown = false
	progress = 0
	visible = false
	var active: Dictionary = phone.data.active_call
	call_state = str(active.get("state",""))
	call_name = str(active.get("name",""))
	call_incoming = bool(active.get("incoming",false))
	call_seconds = float(active.get("seconds",0))
	notify_sound.stop()
	routes.reset()
	letter_tab = "in"
	social_tab = "feed"
	textures.clear()
	viewfinder.render_target_update_mode = SubViewport.UPDATE_DISABLED
	aim = Vector2.ZERO
	zoom = 0
	notification_count = phone.unread()

func open() -> void:
	if phone == null: reset(game.s.phone)
	shown = true
	Input.emulate_mouse_from_touch = true
	visible = true
	routes.reset()
	rebuild()

func close() -> void:
	shown = false
	viewfinder.render_target_update_mode = SubViewport.UPDATE_DISABLED
	Input.emulate_mouse_from_touch = false
	if is_instance_valid(message_edit): message_edit.release_focus()
	game.s.save_game()

func alt_size() -> Vector2:
	return Vector2(430,850)

func step(delta: float, allow_notice: bool) -> void:
	progress = move_toward(progress,1.0 if shown else 0.0,delta*6.5)
	visible = progress>0 or shown
	if visible:
		var shell := alt_size()
		if handset.size != shell and not switching: rebuild()
		var s := minf((size.x-20)/shell.x,(size.y-20)/shell.y)
		var eased := smoothstep(0.0,1.0,progress)
		handset.scale = Vector2.ONE*s*(0.93+0.07*eased)
		var shake := sin(vibration_time*96)*2 if vibration_time>0 else 0.0
		handset.position = (size-shell*handset.scale)*0.5 + Vector2(shake,(1-eased)*70*s)
		handset.modulate.a = eased
		if is_instance_valid(status):
			status.text = "%02d:00" % game.s.clock_hour()
		queue_redraw()
	if shown and at=="clock":
		for key in timer_labels:
			var item: Dictionary = phone.data.agenda[key]
			timer_labels[key].text = timer_caption(item)
	if shown and at=="camera":
		camera_clock += delta
		if camera_clock>=0.045:
			camera_clock = 0
			update_view()
	if phone == null: return
	vibration_time = maxf(0,vibration_time-delta)
	var unread := phone.unread()
	if unread>notification_count and allow_notice:
		if phone.data.settings.notifications:
			if phone.data.settings.sound: notify_sound.play()
			if phone.data.settings.vibration: vibration_time = 0.24
			game.announce("Móvil · "+str(phone.data.notices[0].title))
		notification_count = unread
	elif unread<notification_count: notification_count = unread
	if call_state.is_empty() or not allow_notice and not shown: return
	call_seconds += delta
	if not phone.data.active_call.is_empty(): phone.data.active_call.seconds = call_seconds
	if call_state=="Marcando" and call_seconds>=2:
		call_state = "En llamada"
		call_seconds = 0
		store_call()
		build_if("calls")
	elif call_state=="Entrante" and call_seconds>=18:
		finish_call("Perdida")
	elif call_state=="En llamada" and call_seconds>=18:
		finish_call("Completada")
	elif call_state=="Finalizada" and call_seconds>=2:
		call_state = ""
		build_if("calls")

func _draw() -> void:
	if progress>0: draw_rect(Rect2(Vector2.ZERO,size),Color(0.015,0.018,0.025,progress*0.66))

func navigate(app: String, item: String = "", remember: bool = true) -> void:
	routes.go(app,item,remember)
	if app=="mail" and item.begins_with("read:"):
		for entry in phone.data.mail:
			if entry.id==item.trim_prefix("read:"):
				entry.read = true
				phone.changed = true
	rebuild()

func back() -> void:
	if routes.back(): rebuild()
	else: close()

func home() -> void:
	routes.reset()
	rebuild()

func build_if(app: String) -> void:
	if shown and at==app: rebuild()

func button(parent: Control, caption: String, command: Callable, height: float = 48) -> Button:
	var node := Button.new()
	node.text = caption
	node.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	node.custom_minimum_size.y = height
	node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	node.pressed.connect(command)
	parent.add_child(node)
	var primary := caption.begins_with("Enviar") or caption.begins_with("Guardar") or caption in ["Redactar","Crear perfil","Compartir","Comentar","Responder","Colgar","Confirmar borrado"]
	if primary:
		var fill := Color("dc434b") if caption in ["Colgar","Confirmar borrado"] else accent()
		if caption=="Responder": fill = Color("24a452")
		for state in ["normal","hover","pressed","focus"]:
			node.add_theme_stylebox_override(state,style(fill if state=="normal" else fill.darkened(0.1),Color.TRANSPARENT,13))
		for state in ["font_color","font_hover_color","font_pressed_color","font_focus_color"]:
			node.add_theme_color_override(state,Color.WHITE)
	return node

func row(parent: Control) -> HBoxContainer:
	var node := HBoxContainer.new()
	node.add_theme_constant_override("separation",8)
	parent.add_child(node)
	return node

func label(parent: Control, copy: String, fs: int = 19, tint: Color = PAPER) -> Label:
	var node := Label.new()
	node.text = copy
	node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	node.add_theme_font_size_override("font_size",fs)
	node.add_theme_color_override("font_color",foreground() if tint==PAPER else (accent() if tint==GOLD else tint))
	parent.add_child(node)
	return node

func write(parent: Control, initial: String, prompt: String, submit: Callable, action: String = "Guardar", draft: Callable = Callable()) -> void:
	var editor := LineEdit.new()
	editor.text = initial
	editor.placeholder_text = prompt
	editor.max_length = 260
	editor.custom_minimum_size.y = 50
	editor.virtual_keyboard_enabled = true
	parent.add_child(editor)
	message_edit = editor
	if draft.is_valid(): editor.text_changed.connect(draft)
	button(parent,action,func():
		var value := editor.text.strip_edges()
		if not value.is_empty(): submit.call(value))

func rebuild() -> void:
	if not shown: return
	switching = true
	timer_labels.clear()
	if at!="camera": viewfinder.render_target_update_mode = SubViewport.UPDATE_DISABLED
	for child in handset.get_children():
		handset.remove_child(child)
		child.queue_free()
	handset.size = alt_size()
	theme = make_theme()
	handset.queue_redraw()
	var margin := MarginContainer.new()
	handset.add_child(margin)
	margin.position = Vector2(25,20)
	margin.size = handset.size - Vector2(50,52)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation",8)
	margin.add_child(column)
	var status_row := row(column)
	status = label(status_row,"%02d:00"%game.s.clock_hour(),17,foreground())
	status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status.custom_minimum_size.y = 29
	signals = Control.new()
	var indicator := signals
	indicator.custom_minimum_size = Vector2(79,29)
	status_row.add_child(indicator)
	indicator.draw.connect(func():
		var capacity: float = int(phone.data.settings.get("battery",100))/100.0
		var ink := foreground()
		for i in range(4):
			var height := 4+i*3
			indicator.draw_style_box(style(ink,Color.TRANSPARENT,1),Rect2(2+i*4,19-height,3,height))
		for radius in [9,6,3]: indicator.draw_arc(Vector2(30,19),radius,PI*1.17,PI*1.83,15,ink,1.5,true)
		indicator.draw_style_box(style(Color.TRANSPARENT,ink,4,1),Rect2(43,6,31,14))
		indicator.draw_rect(Rect2(75,10,2,6),ink)
		indicator.draw_style_box(style(ink,Color.TRANSPARENT,2),Rect2(46,9,25*capacity,8)))
	var nav := row(column)
	if at!="home":
		var previous := button(nav,"‹ Atrás",back,38)
		previous.add_theme_color_override("font_color",accent())
		previous.add_theme_stylebox_override("normal",StyleBoxEmpty.new())
		var go_home := button(nav,"⌂",home,38)
		go_home.tooltip_text = "Pantalla de inicio"
		go_home.add_theme_stylebox_override("normal",StyleBoxEmpty.new())
	else:
		var breathing_space := Control.new()
		breathing_space.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		nav.add_child(breathing_space)
	var dismiss := button(nav,"×",close,38)
	dismiss.size_flags_horizontal = Control.SIZE_SHRINK_END
	dismiss.custom_minimum_size.x = 42
	dismiss.tooltip_text = "Cerrar teléfono"
	dismiss.add_theme_stylebox_override("normal",style(Color(0.5,0.5,0.55,0.16),Color.TRANSPARENT,19))
	if at!="home":
		var heading := label(column,NAMES.get(at,at),30,foreground())
		heading.add_theme_constant_override("line_spacing",1)
	scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.scroll_deadzone = 8
	column.add_child(scroll)
	content = VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation",8)
	scroll.add_child(content)
	match at:
		"home": draw_home(column)
		"contacts": draw_contacts()
		"messages","direct": draw_messages()
		"mail": draw_mail()
		"camera": draw_camera()
		"gallery": draw_gallery()
		"social":
			draw_social()
			if target.is_empty() and (not game.network_assignment_active() or phone.data.profile.get("configured",false)):
				draw_social_navigation(column)
		"files": draw_files()
		"notes": draw_notes()
		"map": draw_map()
		"agenda","clock": draw_agenda()
		"settings": draw_settings()
		"calls": draw_calls()
		"notices": draw_notices()
		"attachment": draw_attachment()
	switching = false

func app_icon(parent: Control, id: String, title: String, dock: bool = false) -> void:
	var icon := Icon.new()
	icon.app = id
	icon.caption = "" if dock else title
	icon.tooltip_text = title
	icon.icon_size = 56.0 if dock else 61.0
	icon.custom_minimum_size = Vector2(79,68 if dock else 89)
	icon.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	icon.pressed.connect(func(): navigate(id))
	for state in ["normal","hover","pressed","focus"]:
		icon.add_theme_stylebox_override(state,StyleBoxEmpty.new())
	parent.add_child(icon)

func draw_home(column: VBoxContainer) -> void:
	if not is_instance_valid(content): return
	var welcome := label(content,"Día %d · Acampada València"%game.s.day,21,Color.WHITE)
	welcome.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	welcome.custom_minimum_size.y = 47
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation",9)
	grid.add_theme_constant_override("v_separation",16)
	content.add_child(grid)
	for app in APPS:
		app_icon(grid,app[0],app[1])
	var hint := label(content,"Desliza para consultar tus aplicaciones",14,Color("dce9ff"))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var dock := PanelContainer.new()
	dock.add_theme_stylebox_override("panel",style(Color(0.83,0.88,0.98,0.22),Color(1,1,1,0.15),25,1))
	column.add_child(dock)
	var shortcuts := HBoxContainer.new()
	shortcuts.add_theme_constant_override("separation",6)
	dock.add_child(shortcuts)
	app_icon(shortcuts,"calls","Teléfono",true)
	app_icon(shortcuts,"messages","Mensajes",true)
	app_icon(shortcuts,"camera","Cámara",true)
	app_icon(shortcuts,"notices","Avisos · %d"%phone.unread(),true)

func section_title(parent: Control, title: String) -> void:
	label(parent,title,15,Color("8e93a0") if is_dark() else Color("666b77"))

func list_entry(parent: Control, headline: String, detail: String, command: Callable, image_key: String = "", unread: bool = false) -> void:
	var shell := PanelContainer.new()
	shell.add_theme_stylebox_override("panel",style(Color("303747") if is_dark() else Color("f3f4f8"),Color.TRANSPARENT,13))
	parent.add_child(shell)
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation",10)
	shell.add_child(line)
	var avatar := PanelContainer.new()
	avatar.custom_minimum_size = Vector2(46,46)
	avatar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	avatar.add_theme_stylebox_override("panel",style(Color("8192b1") if image_key.is_empty() else Color("e3e7ee"),Color.TRANSPARENT,23))
	line.add_child(avatar)
	if image_key.is_empty():
		var initial := label(avatar,headline.substr(0,1).to_upper(),22,Color.WHITE)
		initial.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		initial.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	elif phone.data.contacts.has(image_key):
		var face := TextureRect.new()
		face.texture = game.World.CROWD_TEXTURES[int(phone.data.contacts[image_key].sprite)]
		face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		face.custom_minimum_size = Vector2(40,42)
		avatar.add_child(face)
	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation",2)
	line.add_child(body)
	var main_label := label(body,("• " if unread else "")+headline,20,foreground())
	main_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if not detail.is_empty(): label(body,detail,15,Color("b8bdca") if is_dark() else Color("6c7180"))
	var arrow := label(line,"›",27,accent())
	arrow.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	arrow.custom_minimum_size.x = 24
	# A standard button handles touch, keyboard focus and ScrollContainer cancellation.
	var touch := button(shell,"",command,46)
	touch.tooltip_text = headline
	for state in ["normal","hover","pressed","focus"]:
		touch.add_theme_stylebox_override(state,StyleBoxEmpty.new())
	touch.add_theme_stylebox_override("focus",style(Color.TRANSPARENT,accent(),10,2))


func draw_contacts() -> void:
	if target.is_empty():
		section_title(content,"TODOS LOS CONTACTOS · %d"%phone.data.contacts.size())
		if phone.data.contacts.is_empty():
			label(content,"Sin contactos",25)
			label(content,"Habla con alguien en la plaza para intercambiar números.",17,Color("747985"))
		var search := LineEdit.new()
		search.placeholder_text = "Buscar contactos"
		search.custom_minimum_size.y = 42
		content.add_child(search)
		var results := VBoxContainer.new()
		content.add_child(results)
		var names: Array = phone.data.contacts.keys()
		names.sort()
		for who in names:
			list_entry(results,who,phone.data.contacts[who].commission,func(): navigate("contacts",who),who)
		search.text_changed.connect(func(query):
			for i in range(names.size()):
				results.get_child(i).visible = str(names[i]).to_lower().contains(query.to_lower()))
		return
	var person: Dictionary = phone.data.contacts.get(target,{})
	if person.is_empty(): return
	var portrait_view := TextureRect.new()
	portrait_view.texture = game.World.CROWD_TEXTURES[int(person.sprite)]
	portrait_view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait_view.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait_view.custom_minimum_size.y = 107
	content.add_child(portrait_view)
	label(content,target,27,GOLD)
	label(content,"%s · %s"%[person.commission,person.number])
	var who := target
	button(content,"Enviar mensaje",func():
		phone.group(who,who,[who])
		navigate("messages",who))
	button(content,"Llamar",func():
		start_call(who,false)
		navigate("calls"))
	button(content,"Mensaje directo",func():
		phone.group("dm:"+who,who,[who],"direct")
		navigate("direct","dm:"+who))

func draw_messages() -> void:
	var app := at
	if not phone.data.threads.has(target):
		var found := false
		for key in phone.data.threads:
			var item: Dictionary = phone.data.threads[key]
			if item.app != app: continue
			found = true
			list_entry(content,item.title,str(item.items.size())+" mensajes",func(): navigate(app,key))
		if not found: label(content,"Todavía no hay conversaciones.")
		return
	var key := target
	var thread: Dictionary = phone.data.threads[key]
	label(content,thread.title,24,GOLD)
	if thread.people.size()>1: label(content,", ".join(thread.people),15)
	write(content,"","Escribe una respuesta",func(value):
		phone.message(key,"Tú",value)
		Story.reply(phone,key)
		rebuild(),"Enviar")
	var items: Array = thread.items
	for i in range(items.size()-1,-1,-1):
		var item: Dictionary = items[i]
		var bubble := PanelContainer.new()
		var outgoing: bool = item.by=="Tú"
		var bubble_row := row(content)
		if outgoing:
			var spacer := Control.new()
			spacer.custom_minimum_size.x = 45
			bubble_row.add_child(spacer)
		bubble.add_theme_stylebox_override("panel",style(Color("1779eb") if outgoing else Color("e9e9ef"),Color.TRANSPARENT,18))
		bubble.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bubble_row.add_child(bubble)
		if not outgoing:
			var spacer := Control.new()
			spacer.custom_minimum_size.x = 45
			bubble_row.add_child(spacer)
		var col := VBoxContainer.new()
		bubble.add_child(col)
		label(col,item.by,14,Color("dceeff") if outgoing else Color("656977"))
		label(col,item.body,18,Color.WHITE if outgoing else Color("242631"))
		if not item.attachment.is_empty(): button(col,"Abrir adjunto",func(): navigate("attachment",item.attachment),43)

func draw_mail() -> void:
	var tabs := row(content)
	for entry in [["in","Entrada"],["out","Enviados"],["draft","Borradores"]]:
		var tab: String = entry[0]
		button(tabs,entry[1],func():
			letter_tab = tab
			navigate("mail","",false),42)
	if target.begins_with("read:"):
		for item in phone.data.mail:
			if item.id!=target.trim_prefix("read:"): continue
			label(content,item.subject,22,GOLD)
			label(content,item.by,16)
			label(content,item.body)
			if not item.attachment.is_empty(): button(content,"Abrir adjunto",func(): navigate("attachment",item.attachment))
		return
	if target=="attach":
		draw_attachment_picker()
		return
	if target=="new":
		var draft: Dictionary = phone.data.drafts.get("mail",{"subject":"","body":"","to":"Organización"})
		var recipients := ["Organización","Comunicación","Cuidados"]
		var recipient := OptionButton.new()
		for option in recipients: recipient.add_item(option)
		recipient.selected = maxi(0,recipients.find(draft.to))
		recipient.custom_minimum_size.y = 48
		content.add_child(recipient)
		var subject := LineEdit.new()
		subject.placeholder_text = "Asunto"
		subject.text = draft.subject
		subject.max_length = 75
		subject.custom_minimum_size.y = 50
		content.add_child(subject)
		subject.text_changed.connect(func(value):
			draft.subject = value
			save_draft(draft))
		recipient.item_selected.connect(func(index):
			draft.to = recipients[index]
			save_draft(draft))
		write(content,draft.body,"Mensaje",func(value):
			phone.mail(draft.to,draft.subject if not draft.subject.is_empty() else "Consulta de la plaza",value,str(draft.get("attachment","")),true)
			phone.mail(draft.to,"Re: "+(draft.subject if not draft.subject.is_empty() else "Consulta de la plaza"),"Hemos recibido tu mensaje. La comisión lo revisará en la plaza.")
			phone.data.drafts.erase("mail")
			phone.changed = true
			letter_tab = "out"
			navigate("mail","",false),"Enviar correo",func(value):
			draft.body = value
			save_draft(draft))
		button(content,"Adjuntar o cambiar archivo",func():
			save_draft(draft)
			navigate("mail","attach"))
		if not str(draft.get("attachment","")).is_empty(): label(content,"Adjunto seleccionado",16,GOLD)
		return
	button(content,"Redactar",func(): navigate("mail","new"))
	if letter_tab=="draft":
		if phone.data.drafts.has("mail"): button(content,"Reabrir borrador",func(): navigate("mail","new"))
		else: label(content,"Sin borradores.")
		return
	var search := LineEdit.new()
	search.placeholder_text = "Buscar en el correo"
	search.custom_minimum_size.y = 46
	content.add_child(search)
	var results := VBoxContainer.new()
	content.add_child(results)
	var searchable: Array[String] = []
	var count := 0
	for item in phone.data.mail:
		if item.out != (letter_tab=="out"): continue
		count += 1
		searchable.append((str(item.subject)+" "+str(item.by)+" "+str(item.body)).to_lower())
		list_entry(results,item.subject,item.by+" · "+str(item.body).left(48),func(): navigate("mail","read:"+item.id),"",not item.read)
	search.text_changed.connect(func(query):
		for i in range(searchable.size()):
			results.get_child(i).visible = searchable[i].contains(query.to_lower()))
	if count==0: label(content,"Esta bandeja está vacía.")

func draw_attachment_picker() -> void:
	for key in phone.data.files:
		button(content,phone.data.files[key].title,func(): set_mail_attachment("file:"+key))
	for picture in phone.data.photos:
		button(content,"Foto "+str(picture.id),func(): set_mail_attachment("photo:"+picture.id))
	button(content,"Quitar adjunto",func(): set_mail_attachment(""))

func set_mail_attachment(reference: String) -> void:
	var draft: Dictionary = phone.data.drafts.mail
	draft.attachment = reference
	save_draft(draft)
	navigate("mail","new",false)

func save_draft(value: Dictionary) -> void:
	phone.data.drafts.mail = value
	phone.changed = true

func capture_photo() -> void:
	if capturing or not shown or DisplayServer.get_name()=="headless": return
	capturing = true
	var requested_phone := phone
	update_view()
	await RenderingServer.frame_post_draw
	capturing = false
	if not shown or at!="camera" or phone!=requested_phone: return
	var subject: Dictionary = game.capture_network_subject(camera_stage.plaza_frame())
	var key := phone.photo(viewfinder.get_texture().get_image(),subject)
	if key.is_empty():
		label(content,"Galería llena. Elimina una foto sin compartir.",17,GOLD)
		return
	phone.data.settings.battery = maxi(65,int(phone.data.settings.get("battery",100))-1)
	if subject.has("subject"):
		phone.data.network.prepared = -1
		phone.notify("gallery",key,"Foto de Redes guardada",Photo.SUBJECT_NAMES[subject.subject])
	else:
		phone.notify("gallery",key,"Foto guardada","Captura de la plaza.")
		if game.network_assignment_active() and int(phone.data.network.get("prepared",-1))>=0:
			phone.notify("camera","","Motivo fuera del visor","Vuelve a encuadrar el acontecimiento para que la foto cuente.")
	if phone.data.settings.sound: notify_sound.play()
	game.s.save_game()
	navigate("gallery",key)

func update_view() -> void:
	camera_stage.zoom = zoom
	camera_stage.aim = aim
	camera_stage.queue_redraw()
	viewfinder.render_target_update_mode = SubViewport.UPDATE_ONCE

func draw_camera() -> void:
	label(content,"Arrastra el visor para encuadrar.",16)
	view = TextureRect.new()
	view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	view.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	view.custom_minimum_size.y = 286
	view.mouse_filter = Control.MOUSE_FILTER_STOP
	view.gui_input.connect(func(event):
		if event is InputEventMouseMotion and (event.button_mask & MOUSE_BUTTON_MASK_LEFT):
			aim = (aim-event.relative/view.size*2).clamp(-Vector2.ONE,Vector2.ONE)
			update_view()
		elif event is InputEventScreenDrag and not Input.emulate_mouse_from_touch:
			aim = (aim-event.relative/view.size*2).clamp(-Vector2.ONE,Vector2.ONE)
			update_view())
	content.add_child(view)
	view.texture = viewfinder.get_texture()
	view.draw.connect(func():
		var width := minf(view.size.x,view.size.y*480.0/316)
		var height := width*316/480.0
		var frame := Rect2((view.size-Vector2(width,height))/2,Vector2(width,height))
		var shade := Color(1.0,1.0,1.0,0.42)
		view.draw_rect(frame,shade,false,1.5)
		for i in [1,2]:
			var x: float = frame.position.x+frame.size.x*i/3.0
			var y: float = frame.position.y+frame.size.y*i/3.0
			view.draw_line(Vector2(x,frame.position.y),Vector2(x,frame.end.y),shade)
			view.draw_line(Vector2(frame.position.x,y),Vector2(frame.end.x,y),shade))
	update_view()
	var tools := row(content)
	button(tools,"Zoom %s×"%[["1","1,4","1,8"][zoom]],func():
		zoom = (zoom+1)%3
		rebuild())
	var shutter := button(tools,"●",capture_photo,66)
	shutter.tooltip_text = "Disparar"
	shutter.add_theme_font_size_override("font_size",38)
	for state in ["normal","hover","pressed","focus"]:
		shutter.add_theme_stylebox_override(state,style(Color("25262b"),Color.WHITE,32,3))
	button(content,"Abrir galería",func(): navigate("gallery"))

func image_widget(parent: Control, key: String, height: float = 220) -> void:
	for item in phone.data.photos:
		if item.id!=key or not item.has("shot"): continue
		var card := PhotoCard.new()
		card.shot = item.shot
		card.custom_minimum_size.y = height
		parent.add_child(card)
		return
	var pic := TextureRect.new()
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pic.custom_minimum_size.y = height
	if not textures.has(key):
		var picture := phone.image_by_id(key)
		if picture!=null: textures[key] = ImageTexture.create_from_image(picture)
	pic.texture = textures.get(key)
	parent.add_child(pic)

func draw_gallery() -> void:
	var key := target
	if key.contains(":"):
		draw_share(key.get_slice(":",0),key.get_slice(":",1))
		return
	if key.is_empty():
		button(content,"Abrir cámara",func(): navigate("camera"))
		if phone.data.photos.is_empty():
			label(content,"Aún no hay fotografías.")
		section_title(content,"BIBLIOTECA · %d"%phone.data.photos.size())
		var tiles := GridContainer.new()
		tiles.columns = 3
		tiles.add_theme_constant_override("h_separation",5)
		tiles.add_theme_constant_override("v_separation",8)
		content.add_child(tiles)
		for photo in phone.data.photos:
			var tile := VBoxContainer.new()
			tile.custom_minimum_size.x = 116
			tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			tiles.add_child(tile)
			image_widget(tile,photo.id,95)
			var name := "Foto "+str(photo.id)
			if photo.has("subject"): name = Photo.SUBJECTS[photo.subject]
			button(tile,name,func(): navigate("gallery",photo.id),40)
		return
	var source: Array = phone.data.photos.filter(func(item): return item.id==key)
	if source.is_empty(): return
	if source[0].has("subject"): label(content,Photo.SUBJECT_NAMES[source[0].subject],19,GOLD)
	image_widget(content,key,220 if alt_size().x>500 else 290)
	var actions := row(content)
	button(actions,"Ampliar",func(): navigate("attachment","photo:"+key))
	button(actions,"Compartir",func(): navigate("gallery","share:"+key))
	button(actions,"Eliminar",func(): navigate("gallery","delete:"+key))

func draw_share(kind: String, key: String) -> void:
	if kind=="delete":
		label(content,"¿Eliminar esta foto de la galería?")
		button(content,"Confirmar borrado",func():
			if phone.delete_photo(key):
				textures.erase(key)
				navigate("gallery","",false)
			else: label(content,"Esta foto está vinculada a una publicación o un mensaje.",17,GOLD))
		return
	for thread_key in phone.data.threads:
		var thread: Dictionary = phone.data.threads[thread_key]
		var file_ref := ("photo:" if kind=="share" else "file:")+key
		button(content,"Enviar a "+thread.title,func():
			phone.message(thread_key,"Tú","Te comparto esto.",file_ref)
			navigate(thread.app,thread_key))
	if kind=="share":
		button(content,"Publicar en Instagram",func(): navigate("social","publish:"+key))
		button(content,"Añadir a historia",func(): navigate("social","story:"+key))

func draw_social() -> void:
	if target=="account":
		draw_social_profile()
		return
	if game.network_assignment_active() and not phone.data.profile.get("configured",false):
		label(content,"Crea la cuenta simulada de Acampada València para iniciar el encargo.")
		button(content,"Crear perfil",func(): navigate("social","account"))
		return
	if target.begins_with("publish:") or target.begins_with("story:"):
		var key := target.get_slice(":",1)
		var is_story := target.begins_with("story:")
		image_widget(content,key,195)
		write(content,"","Pie de foto",func(value):
			phone.publish(key,value,is_story)
			if game.network_publication(): return
			social_tab = "stories" if is_story else "profile"
			navigate("social","",false),"Compartir")
		return
	if social_tab=="profile":
		label(content,phone.data.profile.get("name","@acampadavalencia"),23,foreground())
		var header := row(content)
		if phone.data.profile.get("configured",false):
			var avatar_col := VBoxContainer.new()
			avatar_col.custom_minimum_size.x = 92
			header.add_child(avatar_col)
			draw_profile_avatar(avatar_col,phone.data.profile.get("avatar",""))
		var stats := VBoxContainer.new()
		stats.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		header.add_child(stats)
		label(stats,"%d publicaciones"%(phone.data.social.size()+game.s.posts.size()),20,foreground())
		label(stats,"%d seguidores"%phone.data.followers.size(),20,foreground())
		if phone.data.profile.get("configured",false):
			label(content,phone.data.profile.bio,17)
			button(content,"Editar perfil",func(): navigate("social","account"),43)
		for name in phone.data.followers: label(content,name,15)
	if social_tab=="stories":
		if phone.data.stories.is_empty(): label(content,"Ninguna historia publicada.")
		for entry in phone.data.stories: social_card(entry,true)
		return
	if game.network_assignment_active():
		label(content,"Encargo · %d/3 temas publicados"%Photo.published_subjects(phone).size(),18,GOLD)
		var pending := Photo.next_subject(phone)
		if pending>=0: label(content,"Vuelve a la plaza: "+Photo.SUBJECT_NAMES[pending]+".",17)
		else: label(content,"Publica en el perfil las fotos de los tres temas desde Galería.",17)
	button(content,"Elegir foto de la galería",func(): navigate("gallery"))
	if target.begins_with("campaign:"):
		var index := int(target.get_slice(":",1))
		if index in range(game.s.posts.size()): campaign_card(index,game.s.posts[index],true)
		return
	if target.is_empty():
		for i in range(game.s.posts.size()): campaign_card(i,game.s.posts[i],false)
	for entry in phone.data.social:
		if not target.is_empty() and target!=entry.id: continue
		social_card(entry,false)
	if phone.data.social.is_empty() and game.s.posts.is_empty(): label(content,"El perfil aún no tiene publicaciones.")

func draw_social_navigation(parent: Control) -> void:
	var bar := row(parent)
	for entry in [["feed","Inicio"],["stories","Historias"],["publish","＋"],["direct","MD"],["profile","Perfil"]]:
		var key: String = entry[0]
		var tab := button(bar,entry[1],func():
			if key=="direct": navigate("direct")
			elif key=="publish": navigate("gallery")
			else:
				social_tab = key
				navigate("social","",false),44)
		tab.add_theme_font_size_override("font_size",14 if key!="publish" else 23)
		tab.add_theme_color_override("font_color",accent() if key==social_tab else foreground())
		tab.add_theme_stylebox_override("normal",StyleBoxEmpty.new())

func draw_profile_avatar(parent: Control, avatar: String) -> void:
	if avatar=="camp-logo":
		var mark := TextureRect.new()
		mark.texture = game.World.TENT
		mark.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		mark.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		mark.custom_minimum_size.y = 74
		parent.add_child(mark)
	elif not avatar.is_empty(): image_widget(parent,avatar,95)

func draw_social_profile() -> void:
	var profile: Dictionary = phone.data.profile
	var name_field := LineEdit.new()
	name_field.text = profile.get("name","Acampada València")
	name_field.placeholder_text = "Nombre del perfil"
	name_field.max_length = 42
	name_field.custom_minimum_size.y = 48
	content.add_child(name_field)
	var description := LineEdit.new()
	description.text = profile.get("bio","")
	description.placeholder_text = "Descripción de la acampada"
	description.max_length = 150
	description.custom_minimum_size.y = 48
	content.add_child(description)
	name_field.text_changed.connect(func(value):
		profile.name = value
		phone.changed = true)
	description.text_changed.connect(func(value):
		profile.bio = value
		phone.changed = true)
	draw_profile_avatar(content,profile.get("avatar",""))
	button(content,"Usar emblema de la acampada",func():
		profile.avatar = "camp-logo"
		phone.changed = true
		rebuild())
	for photo in phone.data.photos:
		button(content,"Usar foto "+str(photo.id)+" como imagen",func():
			profile.avatar = photo.id
			phone.changed = true
			rebuild())
	button(content,"Guardar perfil",func():
		var name_text := name_field.text.strip_edges()
		var bio := description.text.strip_edges()
		if not save_profile(name_text,bio,str(profile.get("avatar",""))):
			label(content,"Completa el nombre, la descripción y la imagen para continuar.",17,GOLD)
			return
		social_tab = "profile"
		navigate("social","",false))

func save_profile(name: String, bio: String, avatar: String) -> bool:
	if name.is_empty() or bio.is_empty() or avatar.is_empty(): return false
	if avatar!="camp-logo" and not phone.data.photos.any(func(photo): return photo.id==avatar): return false
	phone.data.profile = {"name":name,"bio":bio,"avatar":avatar,"configured":true}
	phone.changed = true
	game.s.save_game()
	return true

func campaign_card(index: int, shot: Dictionary, detailed: bool) -> void:
	var key := "campaign:%d"%index
	label(content,"@acampadavalencia · Encargo de Redes",17,GOLD)
	var picture := PhotoCard.new()
	picture.shot = shot
	picture.custom_minimum_size.y = 198
	content.add_child(picture)
	label(content,Photo.SUBJECTS[int(shot.caption)],19)
	if detailed:
		if shot.has("second"):
			var second := PhotoCard.new()
			second.shot = shot.second
			second.custom_minimum_size.y = 198
			content.add_child(second)
		draw_comments(key)
	else:
		button(content,"Ver comentarios",func(): navigate("social",key),43)

func social_card(entry: Dictionary, story: bool) -> void:
	label(content,entry.by,17,GOLD)
	image_widget(content,entry.photo,195)
	label(content,entry.caption)
	if not story:
		if target==entry.id: draw_comments(entry.id)
		else: button(content,"Ver comentarios · %d"%phone.data.comments.get(entry.id,[]).size(),func(): navigate("social",entry.id),43)

func draw_comments(key: String) -> void:
	write(content,"","Comentar publicación",func(value):
		phone.comment(key,"Tú",value)
		rebuild(),"Comentar")
	for entry in phone.data.comments.get(key,[]):
		label(content,entry.by+" · "+entry.body,17)

func draw_notes() -> void:
	var key := target
	if key.is_empty():
		button(content,"Nueva nota",func(): navigate("notes","new"))
		for note in phone.data.notes:
			list_entry(content,note.body.left(45),"Nota guardada",func(): navigate("notes",note.id))
		if phone.data.notes.is_empty(): label(content,"Aún no has escrito notas.")
		return
	var original := ""
	for note in phone.data.notes:
		if note.id==key: original = note.body
	write(content,original,"Propuesta, idea o recordatorio",func(value):
		if key=="new":
			phone.data.notes.push_front({"id":phone.id(),"body":value})
		else:
			for note in phone.data.notes:
				if note.id==key: note.body = value
			phone.changed = true
		navigate("notes","",false))

func draw_files() -> void:
	if target.begins_with("share:"):
		draw_share("document",target.get_slice(":",1))
		return
	if target.is_empty():
		for key in phone.data.files:
			list_entry(content,phone.data.files[key].title,"Documento",func(): navigate("files",key))
		if phone.data.files.is_empty(): label(content,"No se han recibido documentos.")
		return
	var ref := target
	var file: Dictionary = phone.data.files.get(ref,{})
	if file.is_empty(): return
	label(content,file.title,24,GOLD)
	label(content,file.body)
	button(content,"Compartir en Mensajes",func(): navigate("files","share:"+ref))

func draw_attachment() -> void:
	var key := target.get_slice(":",1)
	if target.begins_with("photo:"):
		image_widget(content,key,390)
	else:
		var file: Dictionary = phone.data.files.get(key,{})
		if not file.is_empty():
			label(content,file.title,24,GOLD)
			label(content,file.body)

func draw_map() -> void:
	var locations: Array = game.world.map_locations(game.s,game.elapsed)
	var chart := Control.new()
	chart.custom_minimum_size.y = 225
	content.add_child(chart)
	chart.draw.connect(func():
		var width := minf(chart.size.x, chart.size.y * 16/9.0)
		var frame := Rect2((chart.size.x-width)/2,0,width,width*9/16.0)
		chart.draw_texture_rect(game.World.PLAZA,frame,false)
		for i in range(locations.size()):
			var place: Dictionary = locations[i]
			var mark := frame.position + Vector2(place.pos)*width/1280.0
			chart.draw_circle(mark,9,INK)
			chart.draw_string(FONTS,mark+Vector2(-5,5),str(i+1),HORIZONTAL_ALIGNMENT_LEFT,-1,13,Color.WHITE))
	for i in range(locations.size()):
		label(content,"%d · %s"%[i+1,locations[i].label],17)
	button(content,"Abrir mapa de la plaza",func():
		close()
		progress = 0
		game.toggle_map())

func draw_agenda() -> void:
	var is_clock := at=="clock"
	if is_clock:
		label(content,"%02d:00"%game.s.clock_hour(),43,GOLD)
		label(content,"Hora interna · Día %d"%game.s.day)
		var timers := row(content)
		for seconds in [30,60,120]:
			button(timers,"%ds"%seconds,func():
				var key := phone.id()
				phone.schedule(key,"Temporizador de %ds"%seconds,game.s.day,game.s.clock_hour(),"Ha terminado el temporizador.",true,phone.data.time+seconds)
				navigate("clock",key,false))
		button(content,"Alarma a la próxima hora",func():
			var next_hour: int = game.s.clock_hour()+1
			phone.schedule(phone.id(),"Alarma",game.s.day+int(next_hour>=24),next_hour%24,"Ha llegado la hora programada.",true)
			rebuild())
	else:
		label(content,"Calendario · Día %d"%game.s.day,22,GOLD)
	var events: Array = phone.data.agenda.keys()
	events.sort_custom(func(a,b):
		var first: Dictionary = phone.data.agenda[a]
		var second: Dictionary = phone.data.agenda[b]
		return first.day*24+first.hour < second.day*24+second.hour)
	for key in events:
		var entry: Dictionary = phone.data.agenda[key]
		if not is_clock and entry.when>=0: continue
		var slot := button(content,timer_caption(entry),func(): navigate("clock" if is_clock else "agenda",key,false))
		if entry.when>=0: timer_labels[key] = slot
		if target==key:
			label(content,entry.body,17)
			if not entry.fired:
				button(content,"Desactivar recordatorio" if entry.armed else "Activar recordatorio",func():
					entry.armed = not entry.armed
					phone.changed = true
					rebuild(),44)
	if events.is_empty(): label(content,"Aún no hay convocatorias ni alarmas.")

func timer_caption(entry: Dictionary) -> String:
	var caption: String = entry.title
	if entry.when>=0: caption += " · %ds"%ceili(maxf(0,entry.when-phone.data.time))
	else: caption += " · Día %d, %02d:00"%[entry.day,entry.hour]
	if entry.fired: caption += " ✓"
	return caption

func draw_settings() -> void:
	for entry in [["sound","Sonido"],["vibration","Vibración simulada"],["notifications","Avisos durante la exploración"]]:
		var key: String = entry[0]
		var node := CheckButton.new()
		node.text = entry[1]
		node.custom_minimum_size.y = 53
		node.button_pressed = phone.data.settings[key]
		node.toggled.connect(func(state):
			phone.data.settings[key] = state
			phone.changed = true)
		content.add_child(node)
	label(content,"Contactos, correo y red social funcionan dentro de la simulación.",16)

func start_call(who: String, inbound: bool) -> void:
	if not phone.data.contacts.has(who) or call_state in ["Marcando","Entrante","En llamada"]: return
	call_name = who
	call_incoming = inbound
	call_seconds = 0
	call_state = "Entrante" if inbound else "Marcando"
	store_call()
	if inbound: phone.notify("calls",who,"Llamada de "+who,"Pulsa para abrir Teléfono.")
	build_if("calls")

func store_call() -> void:
	phone.data.active_call = {"name":call_name,"state":call_state,"incoming":call_incoming,"seconds":call_seconds}
	phone.changed = true

func finish_call(outcome: String) -> void:
	phone.data.active_call.clear()
	phone.record_call(call_name,call_incoming,outcome)
	call_state = "Finalizada"
	call_seconds = 0
	build_if("calls")

func draw_calls() -> void:
	if not call_state.is_empty():
		var portrait := PanelContainer.new()
		portrait.custom_minimum_size = Vector2(118,118)
		portrait.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		portrait.add_theme_stylebox_override("panel",style(Color("526781"),Color.TRANSPARENT,59))
		content.add_child(portrait)
		var face := label(portrait,call_name.left(1).to_upper(),54,Color.WHITE)
		face.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		face.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		var caller := label(content,call_name,36,foreground())
		caller.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var state_label := label(content,call_state,21,foreground())
		state_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		if call_state=="Entrante":
			button(content,"Responder",func():
				call_state = "En llamada"
				call_seconds = 0
				store_call()
				rebuild())
		if call_state=="En llamada":
			label(content,"«Nos vemos en la plaza. Te enviaré los detalles por Mensajes.»")
		if call_state!="Finalizada":
			button(content,"Colgar",func(): finish_call("Rechazada" if call_state=="Entrante" else "Finalizada"))
	for who in phone.data.contacts:
		list_entry(content,who,"Llamar",func(): start_call(who,false),who)
	for call in phone.data.calls:
		label(content,("%s · %s · %s"%[call.name,"Entrante" if call.incoming else "Saliente",call.outcome]),17)
	if phone.data.contacts.is_empty(): label(content,"Consigue un contacto en la plaza para llamar.")

func draw_notices() -> void:
	if phone.data.notices.is_empty(): label(content,"Estás al día.")
	for entry in phone.data.notices:
		button(content,("• " if not entry.read else "")+entry.title,func():
			entry.read = true
			phone.changed = true
			var route: String = entry.target
			if entry.app=="mail": route = "read:"+route
			navigate(entry.app,route))
