extends Control

const Story = preload("res://scripts/camp/phone/story.gd")
const PhotoCard = preload("res://scripts/camp/phone/photo_card.gd")
const Icon = preload("res://scripts/camp/phone/icon.gd")
const Data = preload("res://scripts/camp/phone/data.gd")
const Photo = preload("res://scripts/camp/activities_two/photo.gd")
const APPS := [
	["contacts","Contactos","●","799b94"],["social","Instagram","◎","ab5475"],["messages","Mensajes","▰","509873"],
	["mail","Correo","✉","557caa"],["camera","Cámara","◉","73838e"],["gallery","Galería","▧","bd9450"],
	["map","Mapa","◆","729265"],["agenda","Agenda","▦","a27158"],["notes","Notas","≡","bc964d"],
	["files","Archivos","■","558da3"],["settings","Ajustes","✦","76868b"],["clock","Reloj","◷","776b96"],
]
const NAMES := {"home":"Acampada València","contacts":"Contactos","social":"Instagram · simulación","messages":"Mensajes",
	"mail":"Correo","camera":"Cámara de la plaza","gallery":"Galería","map":"Mapa","agenda":"Agenda","notes":"Notas",
	"files":"Archivos","settings":"Ajustes","clock":"Reloj","calls":"Teléfono","direct":"Mensajes directos",
	"notices":"Notificaciones","compose":"Redactar","attachment":"Adjunto"}
const FONTS := preload("res://assets/template/fonts/ui_regular.tres")
const INK := Color("142e2d")
const PAPER := Color("eff0db")
const GOLD := Color("e8bd74")
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
	handset.add_theme_stylebox_override("panel", style(INK,Color("899b82"),30,4))
	handset.draw.connect(func():
		if at=="home":
			handset.draw_texture_rect(game.COVER,Rect2(Vector2(12,12),handset.size-Vector2(24,24)),false,Color(0.57,0.76,0.64,0.15)))
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

func make_theme() -> Theme:
	var result := Theme.new()
	result.default_font = FONTS
	result.default_font_size = 19
	for state in ["normal","hover","pressed","focus","disabled"]:
		var color := Color("294d49") if state=="normal" else Color("396864")
		result.set_stylebox(state,"Button",style(color,Color("56786c"),9,1))
	result.set_color("font_color","Label",PAPER)
	result.set_color("font_color","Button",PAPER)
	result.set_color("font_color","LineEdit",PAPER)
	result.set_stylebox("normal","LineEdit",style(Color("203e3a"),GOLD,8,1))
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
	return Vector2(680,474) if size.x > size.y*1.24 else Vector2(430,760)

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
			status.text = "%02d:00   ·   DÍA %d" % [game.s.clock_hour(),game.s.day]
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
	if progress>0: draw_rect(Rect2(Vector2.ZERO,size),Color(0.025,0.065,0.06,progress*0.74))

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
	node.add_theme_color_override("font_color",tint)
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
	handset.queue_redraw()
	var margin := MarginContainer.new()
	handset.add_child(margin)
	margin.position = Vector2(18,18)
	margin.size = handset.size - Vector2(36,36)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation",8)
	margin.add_child(column)
	var status_row := row(column)
	status = label(status_row,"%02d:00   ·   DÍA %d"%[game.s.clock_hour(),game.s.day],17,GOLD)
	status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	signals = Control.new()
	var indicator := signals
	indicator.custom_minimum_size = Vector2(69,20)
	status_row.add_child(indicator)
	indicator.draw.connect(func():
		var capacity: float = int(phone.data.settings.get("battery",100))/100.0
		for i in range(3):
			var height := 5+i*4
			indicator.draw_rect(Rect2(2+i*7,16-height,5,height),GOLD)
		indicator.draw_rect(Rect2(28,4,33,13),GOLD,false,2)
		indicator.draw_rect(Rect2(62,8,3,5),GOLD)
		indicator.draw_rect(Rect2(31,7,27*capacity,7),GOLD))
	var nav := row(column)
	button(nav,"‹ Atrás",back,44)
	button(nav,"Inicio",home,44)
	button(nav,"Cerrar",close,44)
	label(column,NAMES.get(at,at),24,GOLD)
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
		"social": draw_social()
		"files": draw_files()
		"notes": draw_notes()
		"map": draw_map()
		"agenda","clock": draw_agenda()
		"settings": draw_settings()
		"calls": draw_calls()
		"notices": draw_notices()
		"attachment": draw_attachment()
	switching = false

func draw_home(column: VBoxContainer) -> void:
	if not is_instance_valid(content): return
	var wallpaper := PanelContainer.new()
	wallpaper.add_theme_stylebox_override("panel",style(Color(0.15,0.27,0.24,0.77),Color("608375"),20,1))
	content.add_child(wallpaper)
	var grid := GridContainer.new()
	grid.columns = 4 if alt_size().x>500 else 3
	grid.add_theme_constant_override("h_separation",8)
	grid.add_theme_constant_override("v_separation",8)
	wallpaper.add_child(grid)
	for app in APPS:
		var id: String = app[0]
		var icon := Icon.new()
		icon.app = id
		icon.caption = app[1]
		icon.tooltip_text = app[1]
		icon.tint = Color(app[3]).darkened(0.12)
		icon.custom_minimum_size = Vector2(86,75 if alt_size().x>500 else 80)
		icon.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		icon.pressed.connect(func(): navigate(id))
		for state in ["normal","hover","pressed","focus"]:
			icon.add_theme_stylebox_override(state,StyleBoxEmpty.new())
		grid.add_child(icon)
	var dock := row(column)
	button(dock,"Llamadas",func(): navigate("calls"))
	button(dock,"Avisos · %d"%phone.unread(),func(): navigate("notices"))

func draw_contacts() -> void:
	if target.is_empty():
		if phone.data.contacts.is_empty(): label(content,"La agenda está vacía. Habla con alguien en la plaza para intercambiar números.")
		for who in phone.data.contacts:
			button(content,who+" · "+phone.data.contacts[who].commission,func(): navigate("contacts",who))
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
			button(content,item.title+" · "+str(item.items.size()),func(): navigate(app,key))
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
		bubble.add_theme_stylebox_override("panel",style(Color("34625a") if item.by=="Tú" else Color("254340"),Color("5b7769"),9,1))
		content.add_child(bubble)
		var col := VBoxContainer.new()
		bubble.add_child(col)
		label(col,item.by,16,GOLD)
		label(col,item.body,17)
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
	var count := 0
	for item in phone.data.mail:
		if item.out != (letter_tab=="out"): continue
		count += 1
		button(content,("• " if not item.read else "")+item.subject+" · "+item.by,func(): navigate("mail","read:"+item.id))
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
	var key := phone.photo(viewfinder.get_texture().get_image())
	if key.is_empty():
		label(content,"Galería llena. Elimina una foto sin compartir.",17,GOLD)
		return
	phone.data.settings.battery = maxi(65,int(phone.data.settings.get("battery",100))-1)
	phone.notify("gallery",key,"Foto guardada","Captura de la plaza.")
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
	view.custom_minimum_size.y = 221 if alt_size().x<500 else 178
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
	button(tools,"Disparar",capture_photo)
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
		var strip := ScrollContainer.new()
		strip.custom_minimum_size.y = 150
		strip.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		content.add_child(strip)
		var line := row(strip)
		for photo in phone.data.photos:
			var tile := VBoxContainer.new()
			tile.custom_minimum_size.x = 130
			line.add_child(tile)
			image_widget(tile,photo.id,95)
			button(tile,"Foto "+photo.id,func(): navigate("gallery",photo.id),44)
		return
	if not phone.data.photos.any(func(item): return item.id==key): return
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
	if target.begins_with("publish:") or target.begins_with("story:"):
		var key := target.get_slice(":",1)
		var is_story := target.begins_with("story:")
		image_widget(content,key,195)
		write(content,"","Pie de foto",func(value):
			phone.publish(key,value,is_story)
			social_tab = "stories" if is_story else "profile"
			navigate("social","",false),"Compartir")
		return
	var tabs := row(content)
	for tab in [["feed","Feed"],["profile","Perfil"],["stories","Historias"],["direct","MD"]]:
		var key: String = tab[0]
		button(tabs,tab[1],func():
			if key=="direct": navigate("direct")
			else:
				social_tab = key
				navigate("social","",false),43)
	if social_tab=="profile":
		label(content,"@acampadavalencia",23,GOLD)
		label(content,"%d seguidores · %d publicaciones"% [phone.data.followers.size(),phone.data.social.size()+game.s.posts.size()],16)
		for name in phone.data.followers: label(content,name,15)
	if social_tab=="stories":
		if phone.data.stories.is_empty(): label(content,"Ninguna historia publicada.")
		for entry in phone.data.stories: social_card(entry,true)
		return
	if game.network_assignment_available():
		button(content,"Abrir encargo de Redes",func(): game.launch_network_from_phone())
	elif game.s.day==2 and not game.s.has_day_two_commission(0):
		label(content,"Acércate al punto de Redes para empezar el encargo.",16)
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
			button(content,note.body,func(): navigate("notes",note.id))
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
			button(content,phone.data.files[key].title,func(): navigate("files",key))
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
			chart.draw_string(FONTS,mark+Vector2(-5,5),str(i+1),HORIZONTAL_ALIGNMENT_LEFT,-1,13,GOLD))
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
		label(content,call_name,30,GOLD)
		label(content,call_state,22)
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
		button(content,"Llamar a "+who,func(): start_call(who,false))
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
