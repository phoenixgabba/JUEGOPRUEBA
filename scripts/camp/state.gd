extends RefCounted
class_name CampState

const SAVE_PATH := "user://acampada-day1-v2.json"
var day := 1
const DAY_TWO_ORDER := [4, 0, 1, 2, 3]
const ACCESSIBILITY := 4
const NETWORKS := 0
var day_two_commissions := 0
var day_two_completed := 0
var media_count := 0
var phase := "talk"
var talked := {"Patricia": false, "Alejandro": false, "Marina": false}
var collected := {"lona": false, "varillas": false, "piquetas": false}
var build_stage := 0
var respect := 0
var energy := 100
var health := 100
var wellbeing := 65
var cash := 12
var people := 20
var capacity := 0
var tents := 0
var pitch_swaps := {}
var commissions := 0
var delivery := ""
var delivery_progress := 0.0
var material_boxes := 0
var choice := ""
var player := Vector2(650, 495)
var minutes := 0.0

func has_day_two_commission(index: int) -> bool:
	return (day_two_completed & (1 << index)) != 0

func next_day_two_commission() -> int:
	for index in DAY_TWO_ORDER:
		if not has_day_two_commission(index):
			return index
	return -1

func finish_day_two_commission(index: int) -> void:
	if not has_day_two_commission(index):
		day_two_completed |= 1 << index
		day_two_commissions += 1

func clock_hour() -> int:
	if day == 2: return 22 if phase == "finished" else mini(21, 9 + floori((tents - 25) * 0.48))
	if phase == "finished": return 22
	return [16, 17, 19, 21][commissions]

func daylight() -> String:
	var hour := clock_hour()
	if hour < 12: return "MAÑANA"
	if hour < 20: return "TARDE"
	return "NOCHE"

func light_level() -> float:
	return clampf((clock_hour() - 16) / 15.0, 0.0, 0.4)

func all_talked() -> bool:
	return bool(talked.Patricia) and bool(talked.Alejandro) and bool(talked.Marina)

func all_collected() -> bool:
	return bool(collected.lona) and bool(collected.varillas) and bool(collected.piquetas)

func resources() -> int:
	var total := 0
	for key in collected:
		if collected[key]: total += 1
	return total if build_stage == 0 else 0

func save_game() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null: return
	f.store_string(JSON.stringify({"version":4,"day_two_completed":day_two_completed,"day":day,"day_two_commissions":day_two_commissions,"media_count":media_count,"phase":phase,"talked":talked,"collected":collected,"build_stage":build_stage,"respect":respect,"energy":energy,"health":health,"wellbeing":wellbeing,"cash":cash,"people":people,"capacity":capacity,"tents":tents,"pitch_swaps":pitch_swaps,"commissions":commissions,"delivery":delivery,"delivery_progress":delivery_progress,"material_boxes":material_boxes,"choice":choice,"x":player.x,"y":player.y,"minutes":minutes}))
	f.close()

func load_game() -> bool:
	if not FileAccess.file_exists(SAVE_PATH): return false
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null: return false
	var d = JSON.parse_string(f.get_as_text())
	if not d is Dictionary or int(d.get("version", 0)) not in [1, 2, 3, 4]: return false
	day = clampi(int(d.get("day", 1)), 1, 2)
	day_two_commissions = clampi(int(d.get("day_two_commissions", 0)), 0, 5)
	# Earlier Day 2 saves opened Redes through Accesibilidad in index order.
	day_two_completed = clampi(int(d.get("day_two_completed", (1 << day_two_commissions) - 1)), 0, 31)
	media_count = clampi(int(d.get("media_count", 0)), 0, 3)
	phase = str(d.get("phase", "talk"))
	var previous: Dictionary = d.get("talked", {})
	talked = {
		"Patricia": bool(previous.get("Patricia", previous.get("Alba", false))),
		"Alejandro": bool(previous.get("Alejandro", previous.get("Alejando", previous.get("Joan", false)))),
		"Marina": bool(previous.get("Marina", previous.get("Mar", false))),
	}
	collected = d.get("collected", collected)
	build_stage = clampi(int(d.get("build_stage", 0)), 0, 4)
	respect = int(d.get("respect", 0))
	energy = int(d.get("energy", 100))
	health = int(d.get("health", 100))
	wellbeing = int(d.get("wellbeing", 65))
	cash = int(d.get("cash", 12))
	people = int(d.get("people", 4))
	capacity = int(d.get("capacity", 0))
	tents = clampi(int(d.get("tents", 0)), 0, 50 if day == 2 else 25)
	pitch_swaps = d.get("pitch_swaps", {})
	commissions = clampi(int(d.get("commissions", 0)), 0, 3)
	delivery = str(d.get("delivery", ""))
	delivery_progress = clampf(float(d.get("delivery_progress", 0.0)), 0.0, 1.0)
	material_boxes = maxi(0, int(d.get("material_boxes", 0)))
	choice = str(d.get("choice", ""))
	player = Vector2(clampf(float(d.get("x",640)),0,1280), clampf(float(d.get("y",620)),0,720))
	minutes = float(d.get("minutes",0))
	if int(d.get("version", 0)) == 1:
		pitch_swaps.clear()
		capacity = maxi(0, tents - 1) * 2
		if phase != "finished" and tents >= 6:
			# Old saves completed Communication before Kitchen.
			if commissions == 2: commissions = 1
			if (commissions == 0 and material_boxes > 0) or (commissions == 1 and tents >= 12) or (commissions == 2 and tents >= 19):
				phase = "commissions"
				delivery = ""
			elif tents == 25:
				phase = "expansion"
				delivery = "close"
	return true

func reset_save() -> void:
	if FileAccess.file_exists(SAVE_PATH): DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
