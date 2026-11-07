extends Control

signal stamp_pressed
signal stamp_released
signal start_requested
signal restart_requested
signal help_requested
signal mute_requested

const Rules = preload("res://scripts/rules.gd")
const PaperDocument = preload("res://scripts/document.gd")
const FONT_REGULAR = preload("res://assets/fonts/NotoSansSC-Regular.otf")
const FONT_BOLD = preload("res://assets/fonts/NotoSansSC-Bold.otf")
const W := 540.0
const H := 960.0
const CREAM := Color("f0eee8")
const PALE := Color("e9e4d2")
const MUTED := Color("c9c4b4")
const RED := Color("ff8a7a")
const GOLD := Color("ffe28a")
const START_RECT := Rect2(140, 476, 260, 58)
const RESTART_RECT := Rect2(174, 888, 192, 46)
const HELP_RECT := Rect2(444, 12, 36, 30)
const MUTE_RECT := Rect2(490, 12, 34, 30)
const HELP_CLOSE_RECT := Rect2(150, 724, 240, 54)

var game: Node3D
var _scale := 1.0
var _offset := Vector2.ZERO

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	size = Vector2(W, H)

func _draw() -> void:
	if not game:
		return
	_scale = minf(size.x / W, size.y / H)
	_offset = (size - Vector2(W, H) * _scale) / 2.0
	draw_set_transform(_offset, 0.0, Vector2.ONE * _scale)
	_draw_dial()
	if game.rules.result_visible():
		_draw_result()
	_draw_header()
	if game.rules.phase == "idle":
		_draw_start()
	elif game.rules.n == 0 and game.rules.popup_time < 0.1 and game.rules.phase in ["move", "ready"]:
		_outlined_center("按住时印章抬起，松开后盖章", Vector2(W / 2, 606), 20, CREAM, 460)
	_draw_popup()
	if game.help_visible:
		_draw_help()

func _draw_header() -> void:
	draw_rect(Rect2(0, 0, W, 92), Color(0.941, 0.933, 0.91, 0.97))
	_text("审批单盖章接力", Vector2(16, 29), 17, Color("5b5a55"), FONT_BOLD)
	_right_text("最佳 %d 人" % game.best_n, Vector2(430, 28), 15, Color("5b5a55"), FONT_BOLD)
	var current: int = mini(game.rules.n, Rules.LAST_INDEX)
	_text("%d / 21" % (current + 1), Vector2(16, 77), 19, Color("5b5a55"), FONT_BOLD)
	_text("已完成" if game.rules.clear else Rules.RANKS[current], Vector2(102, 78), 31, Color("222222"), FONT_BOLD)
	_right_text("比上一位更直立", Vector2(524, 77), 16, Color("5b5a55"), FONT_BOLD)
	_small_button(HELP_RECT, "?", game.help_visible)
	_small_button(MUTE_RECT, "静" if game.sound.muted else "声", game.sound.muted)

func _draw_dial() -> void:
	var rules = game.rules
	var center := Vector2(290, 940)
	var radius := 262.0
	draw_rect(Rect2(0, 632, W, 328), Color(0.22, 0.227, 0.239, 0.96))
	_sector(center, radius, 0, 90, Color("8f8b80"))
	var low: float = rules.previous_angle if rules.has_previous else 0.0
	var allowed := Color("e9e4d2") if rules.phase != "over" or rules.clear else Color("bdb8aa")
	_sector(center, radius, low, 90, allowed)
	for degree in range(91):
		var tick := 26.0 if degree % 10 == 0 else (16.0 if degree % 5 == 0 else 9.0)
		draw_line(_dial_point(center, degree, radius - tick), _dial_point(center, degree, radius), Color("3a302a"), 1.4, true)
	for degree in range(0, 91, 30):
		_center(str(degree), _dial_point(center, degree, radius + 22) + Vector2(0, 6), 16, PALE, FONT_BOLD)
	for i in range(rules.history.size()):
		draw_line(_dial_point(center, rules.history[i], radius - 40), _dial_point(center, rules.history[i], radius), Color(0.75, 0.23, 0.18, 0.45), 2.0, true)
	if rules.has_previous:
		draw_line(center, _dial_point(center, rules.previous_angle, radius + 6), Color("bf3a2e"), 4.0, true)
	var shown: float = rules.stamp_angle if rules.phase == "over" and not rules.clear else rules.angle
	if not rules.clear:
		shown = minf(shown, Rules.AUTO_ANGLE)
		draw_line(center, _dial_point(center, shown, radius - 4), Color("1e1a17"), 4.0, true)
		draw_circle(center, 66, Color("f1efe8"))
		PaperDocument.draw_imprint(self, center + Vector2(0, -4), shown, Rules.NAMES[mini(rules.n, Rules.LAST_INDEX)], 1.0, 46)
	var tx := 376.0
	_text("上一位", Vector2(tx, 751), 17, MUTED, FONT_BOLD)
	_text(Rules.format_angle(rules.previous_angle) if rules.has_previous else "−", Vector2(tx, 785), 29, RED, FONT_BOLD)
	_text("当前", Vector2(tx, 825), 17, MUTED, FONT_BOLD)
	_text("−" if rules.clear else Rules.format_angle(minf(shown, Rules.AUTO_ANGLE)), Vector2(tx, 863), 36, Color.WHITE, FONT_BOLD)
	_text("剩余角度", Vector2(tx, 903), 17, MUTED, FONT_BOLD)
	_text(Rules.format_angle(rules.remaining()), Vector2(tx, 937), 28, PALE, FONT_BOLD)

func _draw_start() -> void:
	draw_rect(Rect2(0, 92, W, 540), Color(0.12, 0.13, 0.14, 0.18))
	_panel(Rect2(34, 250, 472, 306), Color(0.96, 0.95, 0.92, 0.97), 12)
	_center("审批单盖章接力", Vector2(W / 2, 305), 32, Color("292825"), FONT_BOLD)
	_center("21 个人，一枚审批单，只有 90°", Vector2(W / 2, 344), 18, Color("6f6c64"), FONT_REGULAR)
	_center("按住：印章从 0° 逐渐抬起", Vector2(W / 2, 392), 19, Color("383631"), FONT_BOLD)
	_center("松开：盖章  ·  必须比上一位更直立", Vector2(W / 2, 426), 18, Color("383631"), FONT_BOLD)
	_center("相同、更前倾或超过 90° 都会退回", Vector2(W / 2, 454), 16, Color("8a4a40"), FONT_REGULAR)
	_button(START_RECT, "开始审批", true)
	_center("鼠标 / 触摸 / 空格键", Vector2(W / 2, 582), 15, CREAM, FONT_REGULAR)

func _draw_popup() -> void:
	var rules = game.rules
	if rules.result_done and not rules.result_visible() and (rules.popup_time < 0.65 or rules.phase == "over"):
		if rules.last_ok:
			var alpha := clampf(1.0 - maxf(0, rules.popup_time - 0.4) / 0.25, 0, 1)
			_outlined_center("已批准  %s" % Rules.format_angle(rules.stamp_angle), Vector2(W / 2, 604), 26, Color(CREAM, alpha), 480)
		else:
			_outlined_center("退 回", Vector2(W / 2, 538), 50, RED, 480)
			_outlined_center(rules.failure_reason, Vector2(W / 2, 586), 19, Color.WHITE, 500)
	if rules.phase == "over" and rules.clear and not rules.result_visible():
		_outlined_center("全部批准", Vector2(W / 2, 538), 48, GOLD, 480)
		_outlined_center("剩余角度 %s" % Rules.format_angle(rules.remaining()), Vector2(W / 2, 586), 21, Color.WHITE, 480)

func _draw_result() -> void:
	var rules = game.rules
	draw_rect(Rect2(0, 620, W, 340), Color("383a3d"))
	_text("已批准" if rules.clear else "已退回", Vector2(22, 682), 44, GOLD if rules.clear else RED, FONT_BOLD)
	_right_text("%d 人批准" % rules.n, Vector2(W - 22, 660), 29, Color.WHITE, FONT_BOLD)
	_right_text("剩余 %s" % Rules.format_angle(rules.remaining()), Vector2(W - 22, 693), 21, PALE, FONT_BOLD)
	_fit_text(rules.full_failure_reason(), Rect2(22, 711, W - 44, 30), 19, PALE)
	_draw_chart(Rect2(62, 750, W - 84, 108))
	_button(RESTART_RECT, "再来一单", true)
	_center("空格键也可以重新开始", Vector2(W / 2, 952), 13, Color("8f8b80"), FONT_REGULAR)

func _draw_chart(rect: Rect2) -> void:
	var rules = game.rules
	draw_rect(rect, Color("2c2e30"))
	var x_at := func(index: int) -> float: return rect.position.x + (index + 0.5) * rect.size.x / 21.0
	var y_at := func(value: float) -> float: return rect.end.y - clampf(value, 0, 100) / 100.0 * rect.size.y
	for degree in [0, 30, 60]:
		var y: float = y_at.call(degree)
		draw_line(Vector2(rect.position.x, y), Vector2(rect.end.x, y), Color("55585b"), 1.0, true)
	var top_y: float = y_at.call(90)
	draw_line(Vector2(rect.position.x, top_y), Vector2(rect.end.x, top_y), PALE, 2.0, true)
	for degree in [0, 30, 60, 90]:
		_right_text("%d°" % degree, Vector2(rect.position.x - 7, y_at.call(degree) + 5), 13, MUTED, FONT_BOLD)
	var points := PackedVector2Array()
	for i in range(rules.history.size()):
		points.append(Vector2(x_at.call(i), y_at.call(rules.history[i])))
	if points.size() > 1:
		draw_polyline(points, Color("d9d3c0"), 2.5, true)
	for point in points:
		draw_circle(point, 4.5, Color("ff6a58"))
	if not rules.clear:
		var bad := Vector2(x_at.call(rules.n), y_at.call(rules.bad_angle))
		draw_line(bad - Vector2(7, 7), bad + Vector2(7, 7), GOLD, 3.0, true)
		draw_line(bad + Vector2(-7, 7), bad + Vector2(7, -7), GOLD, 3.0, true)
	_text("新员工", rect.position + Vector2(0, 130), 13, MUTED, FONT_BOLD)
	_center("科长", Vector2(x_at.call(8), rect.position.y + 130), 13, MUTED, FONT_BOLD)
	_right_text("董事长", Vector2(rect.end.x, rect.position.y + 130), 13, MUTED, FONT_BOLD)

func _draw_help() -> void:
	draw_rect(Rect2(0, 0, W, H), Color(0.08, 0.09, 0.1, 0.82))
	_panel(Rect2(30, 144, 480, 654), CREAM, 12)
	_center("怎么玩", Vector2(W / 2, 202), 32, Color("292825"), FONT_BOLD)
	_help_row(1, "按住，别急着松手", "鼠标、触摸屏或空格键均可。\n印章会从水平 0° 向垂直 90° 转动。", 254)
	_help_row(2, "在合适的角度松开", "松开后立即盖章，角度精确到 0.1°。\n职位越高，印章转得越快。", 374)
	_help_row(3, "每一次都更直立", "必须严格大于上一位的角度。\n相同、倒退或超过 90° 都会被退回。", 494)
	_help_row(4, "把审批单传给董事长", "从右下角的新员工开始，共 21 棒。\n用尽量小的增量，给后面的人留下角度。", 614)
	_button(HELP_CLOSE_RECT, "明白了", true)

func _help_row(number: int, title: String, body: String, y: float) -> void:
	draw_circle(Vector2(66, y), 20, Color("bf3a2e"))
	_center(str(number), Vector2(66, y + 8), 20, Color.WHITE, FONT_BOLD)
	_text(title, Vector2(102, y + 7), 22, Color("302e29"), FONT_BOLD)
	var lines := body.split("\n")
	for i in range(lines.size()):
		_text(lines[i], Vector2(56, y + 48 + i * 29), 16, Color("625e56"), FONT_REGULAR)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_handle_press(_to_design(event.position))
		accept_event()
	elif event is InputEventScreenTouch and event.pressed:
		_handle_press(_to_design(event.position))
		accept_event()

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		stamp_released.emit()
	elif event is InputEventScreenTouch and not event.pressed:
		stamp_released.emit()

func _handle_press(point: Vector2) -> void:
	if HELP_RECT.has_point(point):
		help_requested.emit()
		return
	if MUTE_RECT.has_point(point):
		mute_requested.emit()
		return
	if game.help_visible:
		if HELP_CLOSE_RECT.has_point(point):
			help_requested.emit()
		return
	if game.rules.phase == "idle":
		start_requested.emit()
		return
	if game.rules.phase == "over":
		if game.rules.result_visible() and RESTART_RECT.has_point(point):
			restart_requested.emit()
		return
	stamp_pressed.emit()

func _to_design(point: Vector2) -> Vector2:
	return (point - _offset) / maxf(_scale, 0.001)

func _sector(center: Vector2, radius: float, from_angle: float, to_angle: float, color: Color) -> void:
	var points := PackedVector2Array([center])
	for degree in range(int(ceil(from_angle)), int(floor(to_angle)) + 1):
		points.append(_dial_point(center, degree, radius))
	points.append(_dial_point(center, to_angle, radius))
	if points.size() >= 3:
		draw_colored_polygon(points, color)

func _dial_point(center: Vector2, angle: float, radius: float) -> Vector2:
	var radians := deg_to_rad(angle)
	return center + Vector2(-cos(radians), -sin(radians)) * radius

func _panel(rect: Rect2, color: Color, radius: float) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(int(radius))
	style.border_color = Color(1, 1, 1, 0.18)
	style.set_border_width_all(1)
	draw_style_box(style, rect)

func _button(rect: Rect2, text: String, primary: bool) -> void:
	var hovered := rect.has_point(_to_design(get_local_mouse_position()))
	var color := Color("bf3a2e") if primary else Color("e8e2d5")
	if hovered:
		color = color.lightened(0.12)
	_panel(rect, color, 7)
	_center(text, rect.get_center() + Vector2(0, 8), 21, Color.WHITE if primary else Color("302e29"), FONT_BOLD)

func _small_button(rect: Rect2, text: String, active: bool) -> void:
	_panel(rect, Color("d9d3c8") if active else Color("e5e1d8"), 4)
	_center(text, rect.get_center() + Vector2(0, 6), 16, Color("4d4a44"), FONT_BOLD)

func _text(text: String, at: Vector2, font_size: int, color: Color, font: Font = FONT_REGULAR) -> void:
	draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)

func _center(text: String, at: Vector2, font_size: int, color: Color, font: Font = FONT_REGULAR) -> void:
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	draw_string(font, at - Vector2(width / 2.0, 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)

func _right_text(text: String, at: Vector2, font_size: int, color: Color, font: Font = FONT_REGULAR) -> void:
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	draw_string(font, at - Vector2(width, 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)

func _fit_text(text: String, rect: Rect2, font_size: int, color: Color) -> void:
	var fitted := font_size
	while FONT_BOLD.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fitted).x > rect.size.x and fitted > 11:
		fitted -= 1
	draw_string(FONT_BOLD, rect.position + Vector2(0, rect.size.y), text, HORIZONTAL_ALIGNMENT_LEFT, rect.size.x, fitted, color)

func _outlined_center(text: String, at: Vector2, font_size: int, color: Color, max_width: float) -> void:
	var fitted := font_size
	while FONT_BOLD.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fitted).x > max_width and fitted > 11:
		fitted -= 1
	var width := FONT_BOLD.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fitted).x
	var origin := at - Vector2(width / 2.0, 0)
	draw_string_outline(FONT_BOLD, origin, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fitted, 4, Color(0.11, 0.12, 0.13, color.a * 0.85))
	draw_string(FONT_BOLD, origin, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fitted, color)
