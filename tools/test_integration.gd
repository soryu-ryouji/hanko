extends SceneTree
## 通过真实 InputEvent 验证开始、长按、盖章、帮助、静音和重开。

var failures: Array[String] = []
var checks := 0
var game: Node3D

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	game.save_path = "user://test_integration.cfg"
	root.add_child(game)
	current_scene = game
	await create_timer(0.15).timeout
	_expect(game.rules.phase == "idle", "启动后显示开始页")
	await _click(Vector2(270, 505))
	await create_timer(0.36).timeout
	_expect(game.rules.phase == "ready", "点击开始按钮进入游戏")
	await _key(KEY_SPACE, true)
	await create_timer(0.22).timeout
	await _key(KEY_SPACE, false)
	await create_timer(0.1).timeout
	_expect(game.rules.history.size() == 1, "空格长按并松开产生一次盖章")
	if game.rules.history.size() == 1:
		_expect(game.rules.history[0] > 0.0, "真实输入记录非零角度")
	_expect(game.document.history.size() == 1, "3D 审批单同步印影")
	await create_timer(0.4).timeout
	await _key(KEY_F1, true)
	await _key(KEY_F1, false)
	_expect(game.help_visible, "F1 打开中文帮助")
	await _key(KEY_F1, true)
	await _key(KEY_F1, false)
	_expect(not game.help_visible, "再次按 F1 关闭帮助")
	var old_mute: bool = game.sound.muted
	await _key(KEY_M, true)
	await _key(KEY_M, false)
	_expect(game.sound.muted != old_mute, "M 切换静音")
	await create_timer(0.35).timeout
	game.rules.apply_angle(100.0)
	await create_timer(1.0).timeout
	_expect(game.rules.result_visible(), "失败后显示结算")
	await _click(Vector2(270, 910))
	await create_timer(0.1).timeout
	_expect(game.rules.n == 0 and game.rules.history.is_empty(), "点击再来一单重置游戏")
	await create_timer(0.32).timeout
	await _touch(Vector2(270, 600), true)
	await create_timer(0.2).timeout
	await _touch(Vector2(270, 600), false)
	await create_timer(0.1).timeout
	_expect(game.rules.history.size() == 1, "触摸长按与鼠标、键盘共用判定")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_integration.cfg"))
	if failures.is_empty():
		print("PASS: %d 项输入集成断言全部通过" % checks)
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)

func _click(point: Vector2) -> void:
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.position = point
	down.global_position = point
	down.pressed = true
	root.push_input(down, true)
	await process_frame
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.position = point
	up.global_position = point
	up.pressed = false
	root.push_input(up, true)
	await process_frame

func _touch(point: Vector2, pressed: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = 0
	event.position = point
	event.pressed = pressed
	root.push_input(event, true)
	await process_frame

func _key(code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	root.push_input(event, true)
	await process_frame

func _expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
