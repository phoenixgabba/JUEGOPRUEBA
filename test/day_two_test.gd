extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	main.s.phase = "finished"
	main.s.tents = 25
	main.s.commissions = 3
	main.start_day_two()
	assert(main.s.phase == "meeting_two")
	main.s.player = CampWorld.MEETING
	assert(main.interact_day_two())
	main.close_dialog()
	var day_two = main.DayTwo
	for turn in range(CampState.DAY_TWO_ORDER.size()):
		var i: int = CampState.DAY_TWO_ORDER[turn]
		assert(main.s.phase == "commissions_two")
		assert(main.s.next_day_two_commission() == i)
		if i == CampState.NETWORKS:
			for capture in range(3):
				main.s.player = day_two.MEDIA_POINTS[capture]
				assert(main.interact_day_two())
				main.close_dialog()
		main.s.player = day_two.POINTS[i]
		assert(main.interact_day_two())
		var activity = main.day_two_activity
		match i:
			0: activity.action("publish")
			1:
				for j in range(15): activity.action(str(activity.targets.find("Agitador")))
			2:
				for j in range(6):
					var first: int = activity.cards.find(j)
					activity.action(str(first))
					activity.action(str(activity.cards.find(j, first + 1)))
			3:
				for j in range(3):
					activity.pointer(activity.first_aid_piece(), 0, "down")
					activity.pointer(Vector2(335,290), 0, "move")
					activity.pointer(Vector2(335,290), 0, "up")
			4:
				for move in ["right","right","right","right","down","down","down","down","down","down"]:
					activity.action(move)
		assert(activity.done)
		main._process(0.01)
		assert(main.s.day_two_commissions == turn + 1)
		main.close_dialog()
		for j in range(5):
			var next := CampWorld.next_pitch(main.s)
			assert(CampWorld.walkable(next, main.s), "Parcela inaccesible: %s" % next)
			assert(main.s.delivery == "delegated")
			main.update_deliveries(6.1)
	assert(main.s.tents == 50 and main.s.delivery == "close")
	main.s.save_game()
	var restored := CampState.new()
	assert(restored.load_game() and restored.day == 2 and restored.tents == 50 and restored.day_two_commissions == 5 and restored.media_count == 3 and restored.day_two_completed == 31)
	print("[day-two] PASS: 5 minijuegos, 25 tiendas nuevas, entrega automática y guardado")
	quit()
