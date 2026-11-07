extends Control
## 审批单绘制在 SubViewport 中，再作为 3D 纸张的纹理。

const Rules = preload("res://scripts/rules.gd")
const FONT_REGULAR = preload("res://assets/fonts/NotoSansSC-Regular.otf")
const FONT_BOLD = preload("res://assets/fonts/NotoSansSC-Bold.otf")
const CW := 1000.0
const CH := 880.0
const COLS := 7
const CELL := 128.0
const LABEL_H := 40.0
const BOX_H := 112.0
const ROW_H := LABEL_H + BOX_H + 18.0
const GRID_X := (CW - COLS * CELL) / 2.0
const GRID_Y := 232.0
const IMPRINT_R := 46.0
const INK := Color("bf3a2e")

var current_index := 0
var history: Array[float] = []
var bad_at := -1
var bad_angle := 0.0
var over := false
var clear := false
var document_no := 1
var document_date := ""
var paper_texture: Texture2D
var _last_signature := ""

func _ready() -> void:
	size = Vector2(CW, CH)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if ResourceLoader.exists("res://assets/textures/paper_fiber.png"):
		paper_texture = load("res://assets/textures/paper_fiber.png")

static func cell_center(index: int) -> Vector2:
	var row := 2 - floori(float(index) / COLS)
	var col := COLS - 1 - index % COLS
	return Vector2(
		GRID_X + col * CELL + CELL / 2.0,
		GRID_Y + row * ROW_H + LABEL_H + BOX_H / 2.0
	)

func sync(rules: RefCounted) -> void:
	current_index = rules.n
	history = rules.history.duplicate()
	over = rules.phase == "over"
	clear = rules.clear
	bad_at = rules.n if over and not clear else -1
	bad_angle = rules.bad_angle
	var signature := str([current_index, history, bad_at, bad_angle, over, clear, document_no, document_date])
	if signature != _last_signature:
		_last_signature = signature
		queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(0, 0, CW, CH), Color("f1efe8"))
	if paper_texture:
		draw_texture_rect(paper_texture, Rect2(0, 0, CW, CH), false, Color(1, 1, 1, 0.22))
	draw_rect(Rect2(4, 4, CW - 8, CH - 8), Color("c9c6bc"), false, 5.0)
	_center_text("审  批  单", Vector2(CW / 2.0, 74), 60, Color("333333"), FONT_BOLD)
	_text("起案编号", Vector2(GRID_X, 151), 28, Color("6f6c64"), FONT_BOLD)
	_text("起 案 日", Vector2(GRID_X, 197), 28, Color("6f6c64"), FONT_BOLD)
	draw_rect(Rect2(GRID_X + 140, 156, 220, 3), Color("c4c1b8"))
	draw_rect(Rect2(GRID_X + 140, 202, 300, 3), Color("c4c1b8"))
	_text("第 %d 号" % document_no, Vector2(GRID_X + 150, 151), 29, Color("3d3a35"), FONT_BOLD)
	_text(document_date, Vector2(GRID_X + 150, 197), 28, Color("3d3a35"), FONT_BOLD)
	_right_text("← 审批顺序", Vector2(CW - GRID_X, 196), 24, Color("6f6c64"), FONT_BOLD)

	for index in range(Rules.LAST_INDEX + 1):
		_draw_cell(index)

	var rng := RandomNumberGenerator.new()
	rng.seed = 17
	var body_y := GRID_Y + 3.0 * ROW_H + 30.0
	var line := 0
	while body_y + line * 36.0 < CH - 30.0:
		var width := 380.0 + rng.randf() * 480.0
		draw_rect(Rect2(GRID_X, body_y + line * 36.0, width, 10), Color("c4c1b8"))
		line += 1

	if over:
		_box_stamp("已批准" if clear else "退  回", Vector2(CW - GRID_X - 120, 84), -0.12, 62)

func _draw_cell(index: int) -> void:
	var center := cell_center(index)
	var origin := center - Vector2(CELL / 2.0, BOX_H / 2.0)
	var active := index == current_index and not over
	var cell_rect := Rect2(origin - Vector2(0, LABEL_H), Vector2(CELL, LABEL_H + BOX_H))
	draw_rect(cell_rect, Color("fbf6dc") if active else Color("f7f5ef"))
	var border := Color("2a2a2a") if active else Color("8d8a82")
	draw_rect(cell_rect, border, false, 5.0 if active else 2.5)
	draw_line(origin, origin + Vector2(CELL, 0), border, 5.0 if active else 2.5, true)
	var rank: String = Rules.RANKS[index]
	var font_size := 25
	while FONT_BOLD.get_string_size(rank, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > CELL - 10 and font_size > 13:
		font_size -= 1
	draw_string(FONT_BOLD, origin - Vector2(0, 9), rank, HORIZONTAL_ALIGNMENT_CENTER, CELL, font_size, Color("222222") if active else Color("5f5c55"))
	if index < history.size():
		draw_imprint(self, center, history[index], Rules.NAMES[index], 0.95, IMPRINT_R)
	if index == bad_at:
		draw_imprint(self, center, bad_angle, Rules.NAMES[index], 0.95, IMPRINT_R)

static func draw_imprint(canvas: CanvasItem, at: Vector2, angle: float, person_name: String, alpha: float = 1.0, radius: float = IMPRINT_R) -> void:
	var color := Color(INK, alpha)
	canvas.draw_set_transform(at, -deg_to_rad(90.0 - angle), Vector2.ONE)
	canvas.draw_arc(Vector2.ZERO, radius, 0, TAU, 64, color, radius * 0.1, true)
	var characters := person_name.split("")
	var font_size := int(radius * (0.72 if characters.size() == 2 else 0.55))
	var step := font_size * 0.98
	for i in range(characters.size()):
		var y := (i - (characters.size() - 1) / 2.0) * step + radius * 0.04
		canvas.draw_string(FONT_BOLD, Vector2(-radius, y + font_size * 0.35), characters[i], HORIZONTAL_ALIGNMENT_CENTER, radius * 2.0, font_size, color)
	canvas.draw_set_transform(Vector2.ZERO)

func _box_stamp(text: String, at: Vector2, rotation: float, font_size: int) -> void:
	draw_set_transform(at, rotation, Vector2.ONE)
	var color := Color(0.66, 0.2, 0.16, 0.88)
	var width := FONT_BOLD.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x + font_size * 0.9
	var height := font_size * 1.5
	draw_rect(Rect2(-width / 2.0, -height / 2.0, width, height), color, false, font_size * 0.1)
	draw_string(FONT_BOLD, Vector2(-width / 2.0, font_size * 0.36), text, HORIZONTAL_ALIGNMENT_CENTER, width, font_size, color)
	draw_set_transform(Vector2.ZERO)

func _text(text: String, at: Vector2, font_size: int, color: Color, font: Font = FONT_REGULAR) -> void:
	draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)

func _center_text(text: String, at: Vector2, font_size: int, color: Color, font: Font = FONT_REGULAR) -> void:
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	draw_string(font, at - Vector2(width / 2.0, 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)

func _right_text(text: String, at: Vector2, font_size: int, color: Color, font: Font = FONT_REGULAR) -> void:
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	draw_string(font, at - Vector2(width, 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
