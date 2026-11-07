extends SceneTree
## 在真实渲染模式下生成三张检查截图，不使用 headless。

var game: Node3D

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://build"))
	game = load("res://scenes/main.tscn").instantiate()
	game.save_path = "user://test_save.cfg"
	root.add_child(game)
	current_scene = game
	await create_timer(0.5).timeout
	await _save("01_start.png")

	game.start_game()
	for value in [12.0, 22.0, 33.0, 43.0]:
		await create_timer(0.32).timeout
		game.rules.apply_angle(value)
		await create_timer(0.4).timeout
	await create_timer(0.32).timeout
	game.rules.press()
	await create_timer(0.65).timeout
	await _save("02_playing.png")
	await create_timer(0.6).timeout
	game.rules.release()
	await create_timer(0.72).timeout
	game.rules.apply_angle(10.0)
	await create_timer(0.9).timeout
	await _save("03_result.png")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_save.cfg"))
	print("SCREENSHOTS_OK")
	quit(0)

func _save(file_name: String) -> void:
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var path := "res://build/" + file_name
	var error := image.save_png(path)
	print("CAPTURE ", ProjectSettings.globalize_path(path), " error=", error, " size=", image.get_size())
