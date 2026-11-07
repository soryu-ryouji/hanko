extends Node3D

const Rules = preload("res://scripts/rules.gd")
const PaperDocument = preload("res://scripts/document.gd")
const GameUI = preload("res://scripts/game_ui.gd")
const Sound = preload("res://scripts/sound.gd")
const HOVER := 0.16
const PAPER_WIDTH := 3.0
const PIXELS_PER_UNIT := 1000.0 / PAPER_WIDTH

var rules := Rules.new()
var document: Control
var ui: Control
var sound: Node
var hanko: Node3D
var camera: Camera3D
var best_n := 0
var best_rest := 0.0
var plays := 0
var help_visible := false
var save_path := "user://save.cfg"
var _move_from := Vector2.ZERO
var _last_phase := ""
var _last_n := -1
var _shake := 0.0
var _saved_this_round := false

func _ready() -> void:
	_build_world()
	_build_document()
	_build_hanko()
	_build_ui()
	sound = Sound.new()
	add_child(sound)
	rules.stamp_committed.connect(_on_stamp_committed)
	rules.game_finished.connect(_on_game_finished)
	_load_save()
	_reset_document_number()
	document.sync(rules)
	_update_hanko_pose()

func _build_world() -> void:
	var world := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("474b4f")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("f2f0ea")
	environment.ambient_light_energy = 0.65
	world.environment = environment
	add_child(world)

	var sunlight := DirectionalLight3D.new()
	sunlight.rotation_degrees = Vector3(-55, -30, 0)
	sunlight.light_color = Color("ffffff")
	sunlight.light_energy = 1.1
	sunlight.shadow_enabled = false
	add_child(sunlight)

	camera = Camera3D.new()
	camera.fov = 34.0
	camera.near = 0.1
	camera.far = 60.0
	camera.position = Vector3(0, 8.8, 2.2)
	add_child(camera)
	camera.current = true
	camera.look_at(Vector3(0, 0, 0.85))

	var desk := MeshInstance3D.new()
	var desk_mesh := BoxMesh.new()
	desk_mesh.size = Vector3(14, 0.6, 14)
	desk.mesh = desk_mesh
	var desk_material := StandardMaterial3D.new()
	desk_material.albedo_color = Color("6a5c4a")
	desk_material.roughness = 0.92
	if ResourceLoader.exists("res://assets/textures/wood_desk.png"):
		desk_material.albedo_color = Color("b8b0a5")
		desk_material.albedo_texture = load("res://assets/textures/wood_desk.png")
		desk_material.uv1_scale = Vector3(3, 3, 3)
	desk.material_override = desk_material
	desk.position.y = -0.3
	add_child(desk)

func _build_document() -> void:
	var viewport := SubViewport.new()
	viewport.name = "PaperViewport"
	viewport.size = Vector2i(1000, 880)
	viewport.disable_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	document = PaperDocument.new()
	viewport.add_child(document)

	var base := MeshInstance3D.new()
	var base_mesh := BoxMesh.new()
	base_mesh.size = Vector3(PAPER_WIDTH, 0.012, 880.0 / PIXELS_PER_UNIT)
	base.mesh = base_mesh
	base.material_override = _material("e6e3da")
	base.position.y = 0.006
	add_child(base)

	var paper := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(PAPER_WIDTH, 880.0 / PIXELS_PER_UNIT)
	paper.mesh = plane
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_texture = viewport.get_texture()
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	paper.material_override = material
	paper.position.y = 0.0125
	add_child(paper)

func _build_hanko() -> void:
	hanko = Node3D.new()
	hanko.name = "Hanko"
	add_child(hanko)
	var radius := 46.0 / PIXELS_PER_UNIT * 1.04
	_add_cylinder(radius, radius, 0.0, 0.02, "b3382d")
	_add_cylinder(radius, radius * 0.96, 0.02, 0.5, "3a302a")
	_add_cylinder(radius * 0.96, radius * 0.8, 0.5, 0.56, "3a302a")
	_add_box(Vector3(radius * 0.34, 0.03, radius * 1.5), Vector3(0, 0.575, -radius * 0.55), "e8e2cf")
	_add_box(Vector3(radius * 0.3, 0.1, 0.03), Vector3(0, 0.36, -radius * 0.97), "e8e2cf")

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	ui = GameUI.new()
	ui.game = self
	layer.add_child(ui)
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.stamp_pressed.connect(rules.press)
	ui.stamp_released.connect(rules.release)
	ui.start_requested.connect(start_game)
	ui.restart_requested.connect(start_game)
	ui.help_requested.connect(toggle_help)
	ui.mute_requested.connect(toggle_mute)

func _physics_process(delta: float) -> void:
	rules.advance(delta)
	document.sync(rules)
	_update_hanko_pose()
	_shake = maxf(0.0, _shake - delta)

func _process(_delta: float) -> void:
	if ui:
		ui.queue_redraw()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and not event.echo:
		if event.keycode == KEY_F1 and event.pressed:
			toggle_help()
			get_viewport().set_input_as_handled()
			return
		if event.keycode == KEY_M and event.pressed:
			toggle_mute()
			get_viewport().set_input_as_handled()
			return
		if event.keycode == KEY_SPACE or event.keycode == KEY_ENTER:
			if event.pressed:
				if help_visible:
					help_visible = false
				elif rules.phase == "idle":
					start_game()
				elif rules.phase == "over" and rules.result_visible():
					start_game()
				else:
					rules.press()
			else:
				rules.release()
			get_viewport().set_input_as_handled()

func start_game() -> void:
	plays += 1
	_reset_document_number()
	_save()
	rules.reset()
	_saved_this_round = false
	help_visible = false
	_last_phase = ""
	_last_n = -1
	_move_from = _cell_world(0) + Vector2(0.9, 0.3)
	document.sync(rules)

func toggle_help() -> void:
	help_visible = not help_visible
	if help_visible and rules.phase == "turn":
		rules.release()

func toggle_mute() -> void:
	sound.muted = not sound.muted
	_save()

func _on_stamp_committed(ok: bool) -> void:
	sound.play("stamp")
	sound.play("ok" if ok else "bad")
	if not ok:
		_shake = 0.2
	document.sync(rules)

func _on_game_finished() -> void:
	if rules.clear:
		sound.play("done")
	_save_best()

func _save_best() -> void:
	if _saved_this_round:
		return
	_saved_this_round = true
	var rest := rules.remaining()
	if rules.n > best_n or (rules.n == best_n and rest > best_rest):
		best_n = rules.n
		best_rest = rest
	_save()

func _load_save() -> void:
	var config := ConfigFile.new()
	if config.load(save_path) == OK:
		best_n = int(config.get_value("progress", "best_n", 0))
		best_rest = float(config.get_value("progress", "best_rest", 0.0))
		plays = int(config.get_value("progress", "plays", 0))
		sound.muted = bool(config.get_value("settings", "muted", false))

func _save() -> void:
	var config := ConfigFile.new()
	config.set_value("progress", "best_n", best_n)
	config.set_value("progress", "best_rest", best_rest)
	config.set_value("progress", "plays", plays)
	config.set_value("settings", "muted", sound.muted)
	config.save(save_path)

func _reset_document_number() -> void:
	document.document_no = maxi(1, plays)
	var date := Time.get_date_dict_from_system()
	document.document_date = "%04d年%02d月%02d日" % [date.year, date.month, date.day]

func _cell_world(index: int) -> Vector2:
	var point := PaperDocument.cell_center(index)
	return Vector2((point.x - 500.0) / PIXELS_PER_UNIT, (point.y - 440.0) / PIXELS_PER_UNIT)

func _update_hanko_pose() -> void:
	if not hanko:
		return
	if rules.phase != _last_phase or rules.n != _last_n:
		if rules.phase == "move":
			_move_from = Vector2(hanko.position.x, hanko.position.z)
		_last_phase = rules.phase
		_last_n = rules.n
	if rules.phase == "idle":
		var initial := _cell_world(0)
		hanko.position.x = initial.x
		hanko.position.z = initial.y
	elif rules.phase == "move":
		var k := _ease(rules.phase_time / 0.3)
		var target := _cell_world(rules.n)
		var position_2d := _move_from.lerp(target, k)
		hanko.position.x = position_2d.x
		hanko.position.z = position_2d.y

	var y := HOVER
	if rules.phase == "stamp":
		if rules.phase_time < 0.07:
			y = HOVER * (1.0 - rules.phase_time / 0.07)
		else:
			y = HOVER * 2.2 * _ease((rules.phase_time - 0.1) / 0.2)
	elif rules.phase == "move":
		y = HOVER * 2.2 + (HOVER - HOVER * 2.2) * _ease(rules.phase_time / 0.3)
	elif rules.phase == "over":
		y = HOVER * 2.2 + rules.phase_time * 1.2
	hanko.position.y = 0.0125 + y
	var shown_angle := 0.0 if rules.phase == "move" else rules.angle
	hanko.rotation.y = deg_to_rad(90.0 - shown_angle)
	hanko.visible = not (rules.phase == "over" and rules.phase_time > 0.6)

	var shake_amount := _shake * 0.05
	camera.position.x = randf_range(-shake_amount, shake_amount)
	camera.look_at(Vector3(0, 0, 0.85))

func _add_cylinder(bottom: float, top: float, y0: float, y1: float, color: String) -> void:
	var instance := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.bottom_radius = bottom
	mesh.top_radius = top
	mesh.height = y1 - y0
	mesh.radial_segments = 8
	mesh.rings = 1
	instance.mesh = mesh
	instance.material_override = _material(color)
	instance.position.y = (y0 + y1) / 2.0
	instance.rotation.y = PI / 8.0
	hanko.add_child(instance)

func _add_box(mesh_size: Vector3, at: Vector3, color: String) -> void:
	var instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = mesh_size
	instance.mesh = mesh
	instance.material_override = _material(color)
	instance.position = at
	hanko.add_child(instance)

func _material(color: String) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(color)
	material.roughness = 0.78
	return material

static func _ease(value: float) -> float:
	var k := clampf(value, 0.0, 1.0)
	return 1.0 - pow(1.0 - k, 3.0)
