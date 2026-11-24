extends RefCounted

const CONTACTS := {
	"Patricia": ["AC-001","Comunicación",0],
	"Alejandro": ["AC-002","Organización",1],
	"Marina": ["AC-003","Cuidados",2],
}
const LIMIT := 32
var changed := false
var data := {
	"contacts":{}, "threads":{}, "mail":[], "drafts":{}, "photos":[], "social":[],
	"stories":[], "comments":{}, "followers":[], "agenda":{}, "notes":[], "files":{},
	"notices":[], "calls":[], "active_call":{}, "settings":{"sound":true,"vibration":true,"notifications":true},
	"unlocks":{}, "once":{}, "time":0.0, "next_id":1,
}

func restore(saved: Variant) -> void:
	if not saved is Dictionary: return
	for key in data:
		if not saved.has(key): continue
		if typeof(saved[key]) == typeof(data[key]) or key in ["time","next_id"]:
			data[key] = saved[key]
	changed = false

func id() -> String:
	var value := str(int(data.next_id))
	data.next_id = int(data.next_id)+1
	changed = true
	return value

func seen(key: String) -> bool:
	if data.once.has(key): return true
	data.once[key] = true
	changed = true
	return false

func notify(app: String, target: String, title: String, detail: String) -> void:
	data.notices.push_front({"id":id(),"app":app,"target":target,"title":title,"body":detail,"read":false})
	if data.notices.size()>100: data.notices.pop_back()

func unread() -> int:
	return data.notices.filter(func(entry): return not entry.read).size()

func contact(name: String, number: String, commission: String, sprite: int) -> void:
	if data.contacts.has(name): return
	data.contacts[name] = {"number":number,"commission":commission,"sprite":sprite}
	notify("contacts",name,"Nuevo contacto",name)

func group(key: String, title: String, people: Array, app: String = "messages") -> void:
	if data.threads.has(key): return
	data.threads[key] = {"title":title,"people":people.duplicate(),"app":app,"items":[]}
	changed = true

func message(key: String, sender: String, body: String, attachment: String = "") -> void:
	if not data.threads.has(key): return
	var thread: Dictionary = data.threads[key]
	thread.items.append({"by":sender,"body":body,"attachment":attachment,"time":data.time})
	changed = true
	if sender!="Tú": notify(thread.app,key,thread.title,body)

func mail(sender: String, subject: String, body: String, attachment: String = "", outgoing: bool = false) -> String:
	var key := id()
	data.mail.push_front({"id":key,"by":sender,"subject":subject,"body":body,"attachment":attachment,"out":outgoing,"read":outgoing})
	if not outgoing: notify("mail",key,subject,sender)
	return key

func document(key: String, title: String, body: String) -> void:
	data.files[key] = {"title":title,"body":body}
	changed = true

func schedule(key: String, title: String, day: int, hour: int, body: String, alarm: bool = false, game_time: float = -1) -> void:
	data.agenda[key] = {"title":title,"day":day,"hour":hour,"body":body,"armed":alarm,"when":game_time,"fired":false}
	changed = true

func unlock(key: String) -> void:
	data.unlocks[key] = true
	changed = true

func photo(image: Image) -> String:
	if image == null or image.is_empty(): return ""
	if data.photos.filter(func(item): return item.has("jpg")).size() >= LIMIT: return ""
	var key := id()
	var encoded := Marshalls.raw_to_base64(image.save_jpg_to_buffer(0.78))
	data.photos.push_front({"id":key,"jpg":encoded,"time":data.time})
	return key

func import_campaign(posts: Array) -> void:
	for i in range(posts.size()):
		var key := "campaign-%d"%i
		if not data.photos.any(func(item): return item.id==key):
			data.photos.push_front({"id":key,"shot":posts[i].duplicate(true),"time":data.time})
			changed = true

func image_by_id(key: String) -> Image:
	for item in data.photos:
		if item.id != key or not item.has("jpg"): continue
		var image := Image.new()
		if image.load_jpg_from_buffer(Marshalls.base64_to_raw(item.jpg)) == OK: return image
	return null

func delete_photo(key: String) -> bool:
	if key.begins_with("campaign-"): return false
	if data.social.any(func(post): return post.photo == key) or data.stories.any(func(story): return story.photo == key):
		return false
	if data.threads.values().any(func(thread): return thread.items.any(func(item): return item.attachment == "photo:"+key)):
		return false
	if data.mail.any(func(letter): return letter.attachment == "photo:"+key): return false
	if data.drafts.get("mail",{}).get("attachment","") == "photo:"+key: return false
	for i in range(data.photos.size()):
		if data.photos[i].id != key: continue
		data.photos.remove_at(i)
		changed = true
		return true
	return false

func publish(photo_id: String, body: String, story: bool, as_player: bool = true) -> void:
	var key := id()
	var entry := {"id":key,"photo":photo_id,"caption":body,"by":"Tú" if as_player else "Comunicación","at":data.time}
	if story:
		data.stories.push_front(entry)
	else:
		data.social.push_front(entry)
		if as_player and data.contacts.has("Patricia"):
			comment(key,"Patricia","Gracias por compartir lo que pasa en la plaza.")
			if not "Patricia" in data.followers:
				data.followers.append("Patricia")
				notify("social",key,"Nueva seguidora","Patricia sigue el perfil.")

func comment(key: String, who: String, body: String) -> void:
	if not data.comments.has(key): data.comments[key] = []
	data.comments[key].append({"by":who,"body":body})
	changed = true
	if who!="Tú": notify("social",key,"Comentario de "+who,body)

func record_call(who: String, incoming: bool, outcome: String) -> void:
	data.calls.push_front({"name":who,"incoming":incoming,"outcome":outcome})
	if data.calls.size()>30: data.calls.pop_back()
	changed = true

func tick(delta: float, day: int, hour: int) -> void:
	data.time = float(data.time)+delta
	for key in data.agenda:
		var item: Dictionary = data.agenda[key]
		if not item.armed or item.fired: continue
		var due: bool = data.time >= item.when if item.when >= 0 else day * 24 + hour >= item.day * 24 + item.hour
		if due:
			item.fired = true
			notify("clock" if item.when >= 0 else "agenda",key,item.title,item.body)
