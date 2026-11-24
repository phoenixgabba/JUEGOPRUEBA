extends RefCounted

var app := "home"
var item := ""
var history: Array[Array] = []

func reset() -> void:
	history.clear()
	app = "home"
	item = ""

func go(destination: String, key: String, remember: bool = true) -> void:
	if remember: history.append([app,item])
	app = destination
	item = key

func back() -> bool:
	if history.is_empty():
		if app=="home": return false
		reset()
	else:
		var prior: Array = history.pop_back()
		go(prior[0],prior[1],false)
	return true
