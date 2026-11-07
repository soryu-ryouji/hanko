extends SceneTree

const Rules = preload("res://scripts/rules.gd")
const PaperDocument = preload("res://scripts/document.gd")
var failures: Array[String] = []
var checks := 0

func _init() -> void:
	_run()
	if failures.is_empty():
		print("PASS: %d 项规则断言全部通过" % checks)
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		print("FAIL: %d / %d 项断言失败" % [failures.size(), checks])
		quit(1)

func _run() -> void:
	_expect(Rules.RANKS.size() == 21, "职位数量必须为 21")
	_expect(Rules.NAMES.size() == 21, "印章姓名数量必须为 21")
	var rules = Rules.new()
	_expect(rules.speed_at(20) > rules.speed_at(0), "职位越高速度越快")
	_expect(rules.quantize(12.34) == 12.3, "角度向下舍入到 0.1")
	_expect(rules.quantize(12.35) == 12.4, "角度按 0.1 四舍五入")

	rules.reset()
	_expect(rules.phase == "move", "重开后进入移动阶段")
	rules.advance(0.31)
	_expect(rules.phase == "ready", "0.3 秒后就绪")
	rules.apply_angle(0.0)
	rules.advance(0.08)
	_expect(rules.last_ok and rules.history.size() == 1 and rules.history[0] == 0.0, "第一位允许 0°")
	rules.advance(0.3)
	_expect(rules.n == 1 and rules.phase == "move", "成功后进入下一位")

	rules.reset()
	rules.advance(0.31)
	rules.apply_angle(20.0)
	rules.advance(0.4)
	rules.advance(0.31)
	rules.apply_angle(20.04)
	_expect(not rules.last_ok, "四舍五入后相同角度必须失败")
	_expect(rules.failure_reason.contains("同为"), "相同角度给出中文原因")
	rules.advance(0.4)
	_expect(rules.phase == "over" and rules.n == 1, "失败后保留已批准人数")
	_expect(not rules.result_visible(), "结果面板稍后出现")
	rules.advance(0.51)
	_expect(rules.result_visible(), "0.5 秒后显示结果面板")

	rules.reset()
	rules.advance(0.31)
	rules.apply_angle(50.0)
	rules.advance(0.4)
	rules.advance(0.31)
	rules.apply_angle(49.9)
	_expect(not rules.last_ok and rules.failure_reason.contains("前倾"), "更小角度必须退回")

	rules.reset()
	rules.advance(0.31)
	rules.apply_angle(90.1)
	_expect(not rules.last_ok and rules.failure_reason.contains("90"), "超过 90° 必须退回")
	rules.reset()
	rules.advance(0.31)
	rules.apply_angle(90.0)
	_expect(rules.last_ok, "90.0° 本身允许")

	rules.reset()
	rules.advance(0.31)
	rules.press()
	rules.advance(3.0)
	_expect(rules.phase == "stamp" and rules.stamp_angle == 100.0, "长按到 100° 自动盖章")
	_expect(not rules.last_ok, "自动盖章必然超角失败")

	rules.reset()
	rules.press()
	_expect(rules.pending_press, "移动中允许提前按住")
	rules.advance(0.31)
	_expect(rules.phase == "turn", "就绪后自动开始转动")
	rules.release()
	_expect(rules.phase == "stamp", "松开后进入盖章")

	rules.reset()
	rules.advance(0.31)
	rules.press()
	rules.advance(1.0)
	rules.release()
	_expect(is_equal_approx(rules.stamp_angle, 36.0), "按住一秒产生 36°")

	rules.reset()
	for index in range(21):
		rules.advance(0.31)
		_expect(rules.phase == "ready", "第 %d 人就绪" % (index + 1))
		rules.apply_angle(index * 4.0)
		rules.advance(0.4)
	_expect(rules.clear and rules.n == 21, "21 人全部通过后通关")
	_expect(rules.history.size() == 21, "通关保留全部印影")
	_expect(rules.remaining() == 10.0, "通关剩余角度正确")

	rules.reset()
	_expect(rules.n == 0 and rules.history.is_empty() and not rules.clear, "重开清空所有状态")
	_expect(PaperDocument.cell_center(0).x > PaperDocument.cell_center(6).x, "第一排从右向左")
	_expect(PaperDocument.cell_center(0).y > PaperDocument.cell_center(7).y, "第二排向上移动")

func _expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
