extends RefCounted

const Data = preload("res://scripts/camp/phone/data.gd")

static func talk(phone: Data, person: String) -> void:
	if not Data.CONTACTS.has(person) or phone.seen("contact:"+person): return
	var info: Array = Data.CONTACTS[person]
	phone.contact(person,info[0],info[1],info[2])
	phone.group(person, person, [person])
	phone.message(person,person,{"Patricia":"Te dejo mi número. Si hay una convocatoria, te aviso por aquí.","Alejandro":"Ya tienes mi número para coordinar las tareas de la plaza.","Marina":"Si necesitas apoyo en la plaza, puedes escribirme."}[person])

static func sync(phone: Data, day: int, phase: String, commissions: int, completed: int) -> void:
	if phase=="meeting" and not phone.seen("assembly:1"):
		phone.schedule("assembly1","Primera asamblea",1,16,"Nos encontramos en el círculo de la plaza.",true)
	if commissions>=1 and not phone.seen("org"):
		phone.document("turnos","Turnos de Organización","Organización coordina los turnos, los materiales y la oferta de tiendas desde su punto en la plaza.")
		phone.group("org","Organización",["Alejandro","Patricia"])
		phone.message("org","Alejandro","Aquí tienes la ficha de los turnos.","file:turnos")
		phone.mail("Organización","Ficha de turnos","Puedes consultar la ficha desde el adjunto o desde Archivos.","file:turnos")
	if day==2 and phase=="meeting_two" and not phone.seen("assembly:2"):
		phone.schedule("assembly2","Segunda asamblea",2,9,"Vuelve al círculo central para organizar las comisiones.",true)
	if day==2 and completed!=0:
		var names := ["Redes","Seguridad","Convivencia","Punto sanitario","Accesibilidad"]
		for i in range(5):
			if (completed & (1 << i)) == 0 or phone.seen("commission:"+str(i)): continue
			phone.unlock("commission:"+str(i))
			phone.schedule("commission:"+str(i),names[i],day,9,"Comisión activa en el mapa de la plaza.")
			phone.notify("agenda","commission:"+str(i),names[i],"Comisión abierta en la plaza.")
			if i==0 and phone.data.contacts.has("Patricia"):
				phone.group("dm:Patricia","Patricia",["Patricia"],"direct")
				phone.message("dm:Patricia","Patricia","El perfil de Redes ya está activo. Podemos revisar aquí las publicaciones.")

static func reply(phone: Data, key: String) -> void:
	if not phone.data.threads.has(key): return
	var thread: Dictionary = phone.data.threads[key]
	if thread.people.is_empty(): return
	var sender: String = thread.people[0]
	var answers := {"Patricia":"Gracias. Estoy pendiente de los avisos de la plaza.","Alejandro":"Recibido. Lo tendremos en cuenta al repartir los turnos.","Marina":"Gracias por avisar. Puedes encontrarme en la plaza."}
	phone.message(key,sender,answers.get(sender,"Recibido. Lo comentamos en la plaza."))
