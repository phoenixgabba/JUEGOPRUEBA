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

	for turn in range(5):
		var index: int = main.s.next_day_two_commission()
		assert(index == turn and main.s.phase == "commissions_two")
		assert(main.s.tents == 25 + 5*turn)
		main.s.player = main.DayTwo.POINTS[index]
		main.interact()
		if index == 0:
			play_networks(main)
		else:
			assert(main.day_two_open and main.commission_open)
			match index:
				1: play_dispatch(activity)
				2: play_memory(activity)
				3: play_clinic(activity)
				4: play_access(activity)
			assert(activity.session.report)
			activity.action("finish")
			main._process(0.01)
		assert(main.s.day_two_commissions == turn + 1)
		main.close_dialog()
		for j in range(5):
			var before: int = main.s.tents
			assert(main.s.delivery == "offer" and main.s.phase == "expansion")
			main.update_deliveries(10)
			assert(main.s.tents == before)
			main.s.player = CampWorld.ENTRANCE
			main.interact()
			main.close_dialog()
			var pitch := CampWorld.next_pitch(main.s)
			assert(CampWorld.walkable(pitch,main.s))
			main.s.player = pitch
			if main.s.phase=="build":
				for step in range(4):
					main.interact()
					assert(main.mini)
					main.complete_build_stage()
					main.close_dialog()
				main.update_deliveries(1.7)
			else:
				main.interact()
				assert(main.s.delivery == "placing")
				main.update_deliveries(0.8)
				assert(main.s.tents == before and main.s.delivery_progress > 0)
				main.update_deliveries(0.9)
			assert(main.s.tents == before + 1)
			assert(CampWorld.pitch_count(main.s) == main.s.tents - 1)
	assert(main.s.tents == 50 and main.s.delivery == "close")
	main.s.save_game()
	var restored := CampState.new()
	assert(restored.load_game())
	assert(restored.day == 2 and restored.tents == 50 and restored.day_two_commissions == 5)
	assert(restored.assembly_plan == main.s.assembly_plan)
	assert(restored.commissions + restored.day_two_commissions == 8)
	assert(restored.media_count == 3 and restored.phone.data.social.size() == 3 and restored.day_two_completed == 31)
	main.open_phone()
	main.phone_ui.navigate("social")
	assert(main.phone_ui.shown and main.phone_ui.at == "social")
	assert(restored.phone.data.photos.size() == 3)
	main.phone_ui.close()
	main.s.player = CampWorld.ORGANIZATION
	assert(main.interact_with_delivery())
	main.close_dialog()
	assert(main.s.phase == "finished" and main.screen == "result")
	var normal_save := FileAccess.get_file_as_string(CampState.SAVE_PATH)
	main.test_build = true
	for checkpoint in range(14):
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

func play_networks(main) -> void:
	assert(main.can_open_phone() and main.network_assignment_active() and not main.phone_ui.shown)
	main.open_phone()
	main.phone_ui.navigate("social","account")
	assert(not main.phone_ui.save_profile("Acampada València","","camp-logo"))
	assert(main.phone_ui.save_profile("Acampada València","Noticias de la plaza.","camp-logo"))
	main.phone_ui.close()
	main.phone_ui.progress = 0
	var pixels := Image.create_empty(64,48,false,Image.FORMAT_RGB8)
	pixels.fill(Color("85af87"))
	for i in range(3):
		var point: Vector2 = main.Networks.POINTS[i]
		main.s.player = point+Vector2(70,0)
		assert(main.capture_network_subject(Rect2(point-Vector2(40,40),Vector2(80,80))).is_empty())
		main.s.player = point
		assert(main.interact_day_two())
		assert(main.s.phone.data.network.prepared==i)
		assert(main.capture_network_subject(Rect2(0,0,24,24)).is_empty())
		var subject: Dictionary = main.capture_network_subject(Rect2(point-Vector2(40,40),Vector2(80,80)))
		assert(subject.subject==i and subject.quality>85)
		var key: String = main.s.phone.photo(pixels,subject)
		main.s.phone.publish(key,"Escena de la plaza",false)
		assert(main.network_publication() == (i==2))
	assert(main.s.phone.data.network.misses==3)

func play_dispatch(activity) -> void:
	var game = activity.session
	activity.action("spot:4")
	assert(not game.tutorial)
	var got_error := false
	for frame in range(2500):
		activity.tick(0.04)
		for slot in game.slots.keys():
			if game.slots[slot].role==0:
				activity.action("spot:%d"%slot)
			elif not got_error:
				activity.action("spot:%d"%slot)
				got_error = true
		if game.report: break
	assert(game.report and game.correct==15 and game.mistakes==1 and game.score<100)

func play_memory(activity) -> void:
	var game = activity.session
	for board in range(4):
		if board==1:
			var wrong: int = game.deck.find_custom(func(id): return id!=game.deck[0])
			activity.action("card:0")
			activity.action("card:%d"%wrong)
			activity.action("card:%d"%((wrong+1)%game.deck.size()))
			assert(game.opened.size()==2 and game.errors==1)
			activity.tick(0.9)
			assert(game.opened.is_empty())
		for i in range(game.deck.size()):
			if game.matched.has(i): continue
			activity.action("card:%d"%i)
			activity.action("card:%d"%game.deck.find(game.deck[i],i+1))
			if board==0: break
		activity.tick(0.72)
	assert(game.report and game.pairs==20 and game.errors==1)

func play_clinic(activity) -> void:
	var game = activity.session
	extract(activity)
	assert(not game.tutorial and game.stage==0)
	assert(activity.begin_aim(game.piece,6))
	activity.aim(Vector2(0,-72),6)
	activity.release_aim(6)
	assert(game.errors==1 and game.stage==0 and not game.grabbed)
	assert(activity.begin_aim(game.piece,6))
	game.cancel(6)
	assert(not game.closed and not game.grabbed)
	for i in range(5): extract(activity)
	assert(game.report and game.stage==5 and game.errors==1)

func extract(activity) -> void:
	var game = activity.session
	var path: Array = game.path.duplicate()
	var from: Vector2 = game.piece
	assert(activity.begin_aim(from,6))
	for point: Vector2 in path:
		activity.aim(point-from,6)
		assert(game.grabbed)
		from = point
	activity.release_aim(6)

func play_access(activity) -> void:
	var game = activity.session
	var shortcuts: Array = game.narrow.keys()
	assert(not shortcuts.is_empty() and game.walkable(shortcuts[0],true) and not game.walkable(shortcuts[0],false))
	assert(not game.walkable(Vector2i(0,0),true))
	var first_route: Array = game.find_route(game.player,game.destination,false)
	var step: Vector2 = first_route[1]-first_route[0]
	assert(activity.begin_aim(game.JOY+step*28,3))
	activity.tick(0.03)
	activity.release_aim(3)
	assert(game.player==first_route[1] and not game.tutorial)
	for round_index in range(3):
		var route: Array = game.find_route(game.player,game.destination,false)
		assert(route.size()>1)
		for i in range(1,route.size()):
			var direction = route[i]-route[i-1]
			var index: int = game.DIRS.find(direction)
			activity.action(["right","down","left","up"][index])
			activity.tick(0.16)
			activity.tick(0.20)
			assert(game.walkable(game.guest,false))
		for i in range(15):
			if game.stage>round_index: break
			activity.tick(0.23)
		assert(game.stage==round_index+1)
	assert(game.report and game.separated==0)
