extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	main.screen = "play"
	main.s.phase = "return_tent"
	main.s.tents = 25
	main.s.commissions = 3
	main.s.player = CampWorld.ORGANIZATION
	main.start_day_two()
	main.interact()
	assert(main.rest_time < 0 and main.s.day == 1)
	main.s.save_game()
	assert(CampState.new().load_game())
	var door := CampWorld.tent_door(main.s)
	assert(CampWorld.walkable(door, main.s))
	assert(main.world.map_locations(main.s, 0).any(func(item): return item.label == "Tu tienda"))
	main.s.player = door
	main.interact()
	assert(main.rest_time == 0)
	main._process(1.3)
	assert(main.s.phase == "wake" and main.s.day == 1)
	main.interact()
	assert(main.s.day == 1)
	main.start_game(true)
	assert(main.s.phase == "wake" and main.s.player == door)
	Input.action_press("move_left")
	main._process(0.2)
	Input.action_release("move_left")
	assert(main.s.player == door)
	main.interact()
	assert(main.s.phase == "meeting_two" and main.s.day == 2)

	main.s.player = CampWorld.MEETING
	main.interact()
	assert(main.day_two_open)
	var activity = main.day_two_activity
	play_assembly(activity)
	activity.action("finish")
	main._process(0.01)
	assert(main.s.assembly_plan in ["Acceso", "Cuidados", "Difusión", "Descanso"])

	for turn in range(CampState.DAY_TWO_ORDER.size()):
		var i: int = CampState.DAY_TWO_ORDER[turn]
		assert(main.s.phase == "commissions_two")
		assert(main.s.next_day_two_commission() == i)
		main.s.player = main.DayTwo.POINTS[i]
		main.interact()
		assert(main.day_two_open and main.commission_open)
		match i:
			0: play_photo(activity)
			1: play_dispatch(activity)
			2: play_mediation(activity)
			3: play_clinic(activity)
			4: play_access(activity)
		assert(activity.session.report)
		activity.action("finish")
		assert(activity.done)
		main._process(0.01)
		assert(main.s.day_two_commissions == turn + 1)
		main.close_dialog()
		for j in range(5):
			assert(CampWorld.walkable(CampWorld.next_pitch(main.s), main.s))
			assert(main.s.delivery == "delegated")
			main.update_deliveries(6.1)

	assert(main.s.tents == 50 and main.s.delivery == "close")
	main.s.save_game()
	var restored := CampState.new()
	assert(restored.load_game())
	assert(restored.day == 2 and restored.tents == 50 and restored.day_two_commissions == 5)
	assert(restored.assembly_plan == main.s.assembly_plan)
	assert(restored.media_count == 3 and restored.posts.size() == 3 and restored.day_two_completed == 31)
	main.open_phone()
	assert(activity.mode == "perfil")
	activity.action("next")
	assert(activity.session.view_index == 1)
	var normal_save := FileAccess.get_file_as_string(CampState.SAVE_PATH)
	main.test_build = true
	for checkpoint in range(13):
		main.load_checkpoint(checkpoint)
		assert(main.s.practice)
		main.s.save_game()
		main.s.reset_save()
		assert(FileAccess.get_file_as_string(CampState.SAVE_PATH) == normal_save)
	# Returning from an open activity must release its input before the next checkpoint.
	main.load_checkpoint(5)
	main.paused = true
	main.clickables = [{"rect": Rect2(0, 0, 100, 100), "id": "title"}]
	main.pointer_down(Vector2(20, 20), -1)
	assert(main.screen == "selector" and not main.commission_open)
	main.clickables = [{"rect": Rect2(0, 0, 100, 100), "id": "checkpoint:6"}]
	main.pointer_down(Vector2(20, 20), -1)
	assert(main.commission_open and activity.mode == "seguridad")
	verify_tradeoffs(main.DayTwo)
	main.activity_sound.stop()
	main.queue_free()
	await process_frame
	print("[day-two] PASS: descanso, amanecer, asamblea, cinco comisiones, 50 tiendas, perfil y selector aislado")
	quit(0)


func play_assembly(activity) -> void:
	var game = activity.session
	activity.action("vote")
	assert(game.chapter == 0)
	activity.action("delegate:0")
	activity.action("delegate:1")
	assert(not game.tutorial)
	while not game.report:
		var solved := false
		for mask in range(1, 1 << game.options.size()):
			game.selected.clear()
			game.remaining = game.budget.duplicate()
			var affordable := true
			for j in range(game.options.size()):
				if (mask & (1<<j)) == 0: continue
				var option: int = game.options[j]
				activity.action("card:%d"%option)
				if not option in game.selected: affordable = false
			if not affordable: continue
			var coverage: Array = game.effects()
			var votes := 0
			for person in range(4):
				if game.support(person,coverage): votes += 1
			if votes >= 2 and coverage[game.needs[0]] > 0:
				activity.action("vote")
				assert(game.voting)
				activity.tick(4)
				solved = true
				break
		assert(solved, "No viable coalition in chapter %s" % game.chapter)
		if not solved: return
	assert(game.score > 0)

func play_access(activity) -> void:
	var game = activity.session
	var source := Vector2i(3,2)
	var destination := Vector2i(2,0)
	assert(activity.begin_aim(game.center(source),5))
	activity.aim(game.center(destination)-game.center(source),5)
	activity.release_aim(5)
	assert(game.furniture.has(destination) and not game.tutorial)
	activity.action("tool:lane")
	activity.action("cell:3:2")
	assert(game.lane_supply <= 14 and game.lanes.has(source))
	for step in range(850):
		activity.tick(0.25)
		if game.report: break
	assert(game.active_time >= 190 and game.served >= 10 and game.accessible > 0)

func play_photo(activity) -> void:
	var game = activity.session
	activity.action("capture")
	assert(not game.tutorial and game.gallery.is_empty())
	for window in range(3):
		var target: float = game.UNLOCK[window]
		while game.simulated_time < target or game.used.has(game.event_index) or game.event_phase(game.simulated_time) < 6 or game.event_phase(game.simulated_time) > 11:
			activity.tick(0.25)
		var subject: int = game.event_index
		var required: Vector2 = game.subject_position(subject,game.simulated_time)-Vector2(220,232)
		assert(activity.begin_aim(Vector2(200,200),0))
		activity.aim((game.offset-required)*(1+game.zoom*0.22),0)
		activity.release_aim(0)
		activity.action("capture")
		activity.action("gallery")
		while game.caption != subject: activity.action("caption")
		activity.action("publish")
	assert(game.posts.size() == 3 and game.used.size() == 3 and game.score >= 65)
	for step in range(800):
		if game.report: break
		activity.tick(0.25)
	assert(game.active_time >= 185)

func play_dispatch(activity) -> void:
	var game = activity.session
	activity.action("observe:0")
	activity.action("send")
	var assignments := [-1,-1,-1]
	for step in range(800):
		if game.report: break
		activity.tick(0.25)
		for zone in range(4):
			var case: Dictionary = game.incidents[zone]
			if case.is_empty() or case.type == 5 or int(case.id) in assignments: continue
			var worker: int = game.TYPES[case.type][2]
			if game.workers[worker].zone >= 0:
				var previous: Dictionary = game.incidents[game.workers[worker].zone]
				if not previous.is_empty() and previous.id in assignments: continue
			activity.action("worker:%d"%worker)
			activity.action("observe:%d"%zone)
			activity.action("send")
			assignments[worker] = case.id
	assert(game.resolved > 1 and game.active_time >= 193)

func play_mediation(activity) -> void:
	var game = activity.session
	for chapter in range(5):
		for side in range(2):
			activity.action("person:%d"%side)
			for topic in range(3): activity.action("topic:%d"%topic)
		assert(not game.tutorial)
		for axis in range(2):
			var side: int = game.style.find(axis)
			while game.terms[axis] != game.interests[side][axis]: activity.action("term:%d"%axis)
		activity.action("pilot")
		assert(game.chapter == chapter + 1)
	assert(game.agreements == 5 and game.score > 60)

func play_clinic(activity) -> void:
	var game = activity.session
	activity.action("station:2")
	assert(game.tutorial)
	activity.action("station:0")
	assert(not game.tutorial)
	for step in range(800):
		if game.report: break
		activity.tick(0.25)
		if game.workers.all(func(worker): return worker.station >= 0): continue
		if game.boxes.min() == 0 and game.tasks[4].is_empty():
			activity.action("station:4")
			continue
		for i in range(game.queue.size()):
			var person: Dictionary = game.queue[i]
			var needs: Array = game.REQUESTS[person.kind][1]
			var station: int = 0 if person.step < 0 else needs[person.step]
			if person.assigned or not game.tasks[station].is_empty(): continue
			activity.action("person:%d"%i)
			activity.action("station:%d"%station)
			break
	assert(game.served >= 6 and game.assisted > 0 and game.active_time >= 195)


func verify_tradeoffs(factory) -> void:
	var run = factory.new()
	run.start("asamblea", "", 85)
	var assembly = run.session
	assembly.selected.assign([0,6])
	assert(assembly.effects()[0] == 3)
	assembly.selected.assign([1,5])
	assert(assembly.effects()[1] == 4)
	run.start("accesibilidad", "Acceso", 42)
	var access = run.session
	assert(access.lane_supply == 15)
	var ordinary: Array = access.route(Vector2i(0,4), Vector2i(7,4), 0)
	assert(not ordinary.is_empty())
	for point in ordinary:
		assert(not access.furniture.has(point))
	run.start("redes", "", 88)
	var photo = run.session
	run.action("capture")
	run.tick(7)
	run.action("capture")
	run.action("gallery")
	var subject: int = photo.gallery[0].subject
	while photo.caption != subject: run.action("caption")
	run.action("publish")
	run.action("gallery")
	run.action("publish")
	assert(photo.posts.size() == 1)
	run.start("seguridad", "", 94)
	var security = run.session
	security.tutorial = false
	security.incidents[0] = {"id":17,"type":5,"observed":false,"deadline":30.0,"progress":0.0,"support":false}
	security.next_event = 40
	run.action("observe:0")
	run.action("send")
	for i in range(40): run.tick(0.25)
	assert(security.unfair == 1 and security.resolved == 0)
	run.start("convivencia", "", 46)
	var mediation = run.session
	run.action("topic:0")
	run.action("person:1")
	run.action("topic:0")
	assert(not mediation.tutorial)
	run.action("break")
	run.action("break")
	assert(mediation.last_outcome == "Derivado a seguimiento")
	run.start("sanitario", "Cuidados", 19)
	var clinic = run.session
	assert(clinic.boxes[2] == 3)
	run.action("station:0")
	clinic.boxes = [0,0,0]
	run.action("station:4")
	assert(not clinic.tasks[0].is_empty() and not clinic.tasks[4].is_empty())
	for i in range(40): run.tick(0.25)
	assert(clinic.boxes[0] == 2 and clinic.boxes[2] == 1)
	clinic.finish(75, "Resultado de prueba")
	run.action("retry")
	assert(run.mode == "sanitario" and run.session.tutorial and not run.done and run.session.boxes[2] == 3)
