extends RefCounted
## 独立的盖章规则状态机。渲染和输入不在这里处理，便于确定性测试。

signal stamp_committed(ok: bool)
signal game_finished

const RANKS: Array[String] = [
	"新员工", "职员", "资深职员", "副组长", "组长", "副主任", "主任",
	"副科长", "科长", "副处长", "处长", "副部长", "部长", "总监",
	"高级总监", "执行总监", "副总裁", "高级副总裁", "执行总裁", "总裁", "董事长"
]
const NAMES: Array[String] = [
	"陈晨", "王宁", "李然", "张远", "刘畅", "杨帆", "黄琪",
	"赵磊", "周洁", "吴昊", "徐明", "孙悦", "胡静", "朱宇",
	"高远", "林溪", "何平", "郭林", "马超", "罗真", "梁栋"
]
const LAST_INDEX := 20
const BASE_SPEED := 36.0
const SPEED_FACTOR := 1.08
const AUTO_ANGLE := 100.0

var phase := "idle"
var n := 0
var previous_angle := 0.0
var has_previous := false
var time := 0.0
var phase_time := 0.0
var angle := 0.0
var stamp_angle := 0.0
var bad_angle := 0.0
var turn_started := 0.0
var pending_press := false
var last_ok := false
var result_done := false
var failure_reason := ""
var clear := false
var history: Array[float] = []
var popup_time := 0.0
var finish_emitted := false

func reset() -> void:
	phase = "move"
	n = 0
	previous_angle = 0.0
	has_previous = false
	time = 0.0
	phase_time = 0.0
	angle = 0.0
	stamp_angle = 0.0
	bad_angle = 0.0
	turn_started = 0.0
	pending_press = false
	last_ok = false
	result_done = false
	failure_reason = ""
	clear = false
	history.clear()
	popup_time = 0.0
	finish_emitted = false

func speed_at(index: int) -> float:
	return BASE_SPEED * pow(SPEED_FACTOR, index)

func remaining() -> float:
	return 90.0 - (previous_angle if has_previous else 0.0)

func quantize(raw_angle: float) -> float:
	return round(raw_angle * 10.0) / 10.0

func press(at_time: float = -1.0) -> void:
	if phase == "move" or (phase == "stamp" and last_ok):
		pending_press = true
		return
	if phase != "ready":
		return
	pending_press = false
	phase = "turn"
	phase_time = 0.0
	angle = 0.0
	turn_started = time if at_time < 0.0 else at_time

func release(at_time: float = -1.0) -> void:
	pending_press = false
	if phase != "turn":
		return
	var now := time if at_time < 0.0 else at_time
	var raw := clampf((now - turn_started) * speed_at(n), 0.0, AUTO_ANGLE)
	apply_angle(raw)

func apply_angle(raw_angle: float) -> void:
	if phase != "turn" and phase != "ready":
		return
	var a := quantize(raw_angle)
	stamp_angle = a
	angle = a
	last_ok = true
	failure_reason = ""
	if a > 90.0:
		last_ok = false
		failure_reason = "超过 90°，向后仰倒（%s）" % format_angle(a)
	elif has_previous and a < previous_angle:
		last_ok = false
		failure_reason = "比上一位（%s）更前倾" % format_angle(previous_angle)
	elif has_previous and is_equal_approx(a, previous_angle):
		last_ok = false
		failure_reason = "与上一位同为 %s" % format_angle(a)
	phase = "stamp"
	phase_time = 0.0
	result_done = false

func advance(delta: float) -> void:
	if phase == "idle":
		return
	time += delta
	phase_time += delta
	popup_time += delta
	match phase:
		"move":
			angle = 0.0
			if phase_time >= 0.3:
				phase = "ready"
				phase_time = 0.0
				if pending_press:
					press()
		"turn":
			angle = (time - turn_started) * speed_at(n)
			if angle >= AUTO_ANGLE:
				apply_angle(AUTO_ANGLE)
		"stamp":
			if not result_done and phase_time >= 0.07:
				result_done = true
				popup_time = 0.0
				if last_ok:
					previous_angle = stamp_angle
					has_previous = true
					history.append(stamp_angle)
				else:
					bad_angle = stamp_angle
				stamp_committed.emit(last_ok)
			if result_done and phase_time > (0.32 if last_ok else 0.3):
				if last_ok:
					n += 1
					if n > LAST_INDEX:
						clear = true
						phase = "over"
						phase_time = 0.0
						_emit_finish()
					else:
						phase = "move"
						phase_time = 0.0
				else:
					phase = "over"
					phase_time = 0.0
					_emit_finish()

func result_visible() -> bool:
	return phase == "over" and phase_time > 0.5

func current_rank() -> String:
	if clear:
		return "已审批"
	return RANKS[mini(n, LAST_INDEX)]

func reach_text() -> String:
	if clear:
		return "从新员工到董事长，21 人全部完成盖章"
	if n == 0:
		return "新员工这一棒就被退回了"
	return "%s之前，共 %d 人完成盖章" % [RANKS[n], n]

func full_failure_reason() -> String:
	if clear:
		return "审批完成，剩余角度 %s" % format_angle(remaining())
	return "%s：%s" % [RANKS[mini(n, LAST_INDEX)], failure_reason]

static func format_angle(value: float) -> String:
	return "%.1f°" % value

func _emit_finish() -> void:
	if finish_emitted:
		return
	finish_emitted = true
	game_finished.emit()
