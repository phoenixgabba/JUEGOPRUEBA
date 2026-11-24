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
	activity.action("good")
	assert(activity.round_index == 0)
	for round_index in range(3):
		for speaker in range(round_index + 1):
			activity.action(str(speaker))
		activity.action("bad")
		assert(activity.round_index == round_index)
		activity.action("good")
	main._process(0.01)

	for turn in range(CampState.DAY_TWO_ORDER.size()):
		var i: int = CampState.DAY_TWO_ORDER[turn]
		assert(main.s.phase == "commissions_two")
		assert(main.s.next_day_two_commission() == i)
		main.s.player = main.DayTwo.POINTS[i]
		main.interact()
		assert(main.day_two_open and main.commission_open)
		for j in range(3):
			match i:
				0:
					activity.action("confirm")
					assert(activity.stage == 0)
					while activity.camera.x > 0: activity.action("left")
					while activity.camera.y < 0: activity.action("down")
					for step in range(j): activity.action("zoom")
					activity.action("confirm")
					assert(activity.stage == 1)
					for step in range(activity.subjects[j]):
						activity.action("caption")
						activity.action("audience")
					activity.action("confirm")
					assert(activity.stage == 2)
					activity.action("confirm")
				1:
					activity.action(str((activity.incident_groups[j] + 1) % 4))
					assert(activity.stage == 0)
					activity.action(str(activity.incident_groups[j]))
					activity.action("bad")
					assert(activity.stage == 1)
					activity.action("good")
					activity.action("confirm")
				2:
					activity.action("good")
					assert(activity.stage == 0)
					activity.action("0")
					activity.action("1")
					activity.action("bad")
					assert(activity.tension > 1)
					activity.action("good")
					assert(activity.tension == 0)
					activity.action("confirm")
				3:
					activity.action("listen")
					var expected: int = activity.CARE[activity.care_queue[j]][2]
					activity.action(str((expected + 1) % 4))
					assert(activity.round_index == j)
					if expected < 2 and activity.stock[expected] == 0:
						activity.action(str(expected))
						assert(activity.round_index == j)
						activity.action("restock")
					activity.action(str(expected))
				4:
					activity.action("confirm")
					assert(activity.route.is_empty())
					var first_row := 2 if j == 0 else 1
					for cell: Vector2i in activity.furniture.keys():
						if cell.y < first_row or cell.y > first_row + j: continue
						for x in range(1, 7):
							var vacant := Vector2i(x,0)
							if activity.furniture.has(vacant): continue
							activity.action(str(cell.y * 8 + cell.x))
							activity.action(str(x))
							break
					activity.action("confirm")
					assert(not activity.route.is_empty())
					activity.tick(4)
			assert(activity.round_index == j + 1)
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
	assert(restored.media_count == 3 and restored.posts.size() == 3 and restored.day_two_completed == 31)
	main.open_phone()
	assert(activity.mode == "perfil")
	activity.action("right")
	assert(activity.media_view == 1)
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
	main.activity_sound.stop()
	main.queue_free()
	await process_frame
	print("[day-two] PASS: descanso, amanecer, asamblea, cinco comisiones, 50 tiendas, perfil y selector aislado")
	quit(0)
