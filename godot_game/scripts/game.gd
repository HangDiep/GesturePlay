extends Node3D

var playing := false
var completed := false
var selected_map := 0
var world: Node3D
var player: FieldPlayer
var hud: FieldHUD
var hand: Hand3DBridge
var environment: WorldEnvironment
var sunlight: DirectionalLight3D
var map_data: Dictionary = {}
var items: Array[Dictionary] = []
var enemies: Array[FieldEnemy] = []
var effects: Array[Dictionary] = []
var elapsed := 0.0
var cores := 0
var kills := 0
var wave := 0
var flashes := 3
var traps := 3
var flash_cooldown := 0.0
var trap_cooldown := 0.0
var pending: Array[int] = []
var jammed := false
var rng := RandomNumberGenerator.new()
var effect_audio: AudioStreamPlayer
var music: AudioStreamPlayer
var audio_cache: Dictionary = {}
var audio_enabled := true
const WAVE_TIMES = [3, 27, 55, 88, 120]
const WAVE_KINDS = [[0, 0], [1, 0], [2, 0, 0], [3, 0], [1, 2, 0]]

func _ready() -> void:
	_setup_actions()
	rng.seed = 73
	environment = WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	sky.sky_material = ProceduralSkyMaterial.new()
	environment.environment.sky = sky
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("b8ccd8")
	environment.environment.ambient_light_energy = .22
	environment.environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	add_child(environment)
	sunlight = DirectionalLight3D.new()
	sunlight.rotation_degrees = Vector3(-48, -28, 0)
	sunlight.light_energy = .72
	sunlight.shadow_enabled = true
	sunlight.directional_shadow_max_distance = 75
	add_child(sunlight)
	effect_audio = AudioStreamPlayer.new()
	add_child(effect_audio)
	music = AudioStreamPlayer.new()
	music.volume_db = -25
	add_child(music)
	hand = Hand3DBridge.new()
	hand.game = self
	add_child(hand)
	hud = FieldHUD.new()
	hud.game = self
	add_child(hud)
	select_map(0)
	if OS.get_cmdline_user_args().has("--capture"):
		_capture_maps.call_deferred()

func _setup_actions() -> void:
	var keys := {"left": [KEY_A, KEY_LEFT], "right": [KEY_D, KEY_RIGHT], "forward": [KEY_W, KEY_UP],
		"back": [KEY_S, KEY_DOWN], "jump": [KEY_SPACE], "sprint": [KEY_SHIFT], "reload": [KEY_R],
		"flash": [KEY_Q], "trap": [KEY_E], "pause": [KEY_ESCAPE],
		"look_left": [KEY_J], "look_right": [KEY_L], "look_up": [KEY_I], "look_down": [KEY_K]}
	for action in keys:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action)
		for key in keys[action]:
			var event := InputEventKey.new()
			event.physical_keycode = key
			InputMap.action_add_event(action, event)
	for action in ["fire", "aim"]:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		var mouse := InputEventMouseButton.new()
		mouse.button_index = MOUSE_BUTTON_LEFT if action == "fire" else MOUSE_BUTTON_RIGHT
		InputMap.action_add_event(action, mouse)

func select_map(index: int) -> void:
	if index < 0 or index > 3:
		return
	playing = false
	completed = false
	selected_map = index
	if is_instance_valid(world):
		world.queue_free()
	world = Node3D.new()
	world.name = "ExplorableMap%d" % (index + 1)
	add_child(world)
	enemies.clear()
	items.clear()
	effects.clear()
	pending.clear()
	map_data = SignalMaps.build(world, index)
	player = FieldPlayer.new()
	player.game = self
	world.add_child(player)
	player.position = map_data.spawn
	player.spring.rotation.x = player.pitch
	for at in map_data.cores:
		_add_item(at, "core")
	for i in range(map_data.supplies.size()):
		_add_item(map_data.supplies[i], "health" if i == 0 else "ammo")
	var sky: ProceduralSkyMaterial = environment.environment.sky.sky_material
	sky.sky_top_color = SignalMaps.DETAILS[index].sky
	sky.sky_horizon_color = Color(SignalMaps.DETAILS[index].sky).lightened(.2)
	sky.ground_bottom_color = Color(SignalMaps.DETAILS[index].ground).darkened(.35)
	sky.ground_horizon_color = SignalMaps.DETAILS[index].sky
	sunlight.light_color = Color("ffd6aa") if index == 1 else Color("d9edff") if index == 2 else Color.WHITE
	sunlight.light_energy = .48 if index == 3 else .72
	cores = 0
	kills = 0
	wave = 0
	elapsed = 0
	flashes = 3
	traps = 3
	flash_cooldown = 0
	trap_cooldown = 0
	jammed = false
	hud.select(index)
	hud.message.text = SignalMaps.DETAILS[index].story

func start_round() -> void:
	if not hand.ready_to_play():
		hud.notice("Đưa tay rõ vào webcam, mở tay ổn định rồi chọn Vào bản đồ.")
		return
	playing = true
	completed = false
	hud.menu.hide()
	hud.pause_panel.hide()
	_capture_mouse()
	hand.centered = false
	notice("Tìm 3 lõi vàng trên bản đồ. Nhặt bằng cách đi lại gần.")
	if audio_enabled and ResourceLoader.exists("res://audio/ambient.wav"):
		music.stream = load("res://audio/ambient.wav")
		music.play()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		if playing:
			pause_game("Bạn có thể đổi điều khiển hoặc chọn bản đồ khác.")
		elif hud.pause_panel.visible and not completed:
			resume_game()
		get_viewport().set_input_as_handled()
		return
	if not playing:
		return
	if event is InputEventMouseMotion and (Input.mouse_mode == Input.MOUSE_MODE_CAPTURED or Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)) and not hand.enabled:
		player.look(event.relative)
	if event.is_action_pressed("reload"):
		player.reload()
	if event.is_action_pressed("flash"):
		use_flash()
	if event.is_action_pressed("trap"):
		use_trap()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and playing:
		pause_game("Cửa sổ đang ở nền.")

func _physics_process(dt: float) -> void:
	if not playing:
		return
	elapsed += dt
	flash_cooldown = maxf(0, flash_cooldown - dt)
	trap_cooldown = maxf(0, trap_cooldown - dt)
	enemies = enemies.filter(func(e): return is_instance_valid(e))
	jammed = enemies.any(func(e): return e.health > 0 and e.kind == 2 and e.stunned <= 0 and e.position.distance_to(player.position) < 16)
	while wave < WAVE_TIMES.size() and elapsed >= WAVE_TIMES[wave]:
		for kind in WAVE_KINDS[wave]:
			pending.append(kind)
		wave += 1
		notice("Đợt %d/5 — sinh vật đang truy tìm bạn." % wave)
	var living := enemies.filter(func(e): return e.health > 0).size()
	if not pending.is_empty() and living < 9:
		spawn_enemy(pending.pop_front())
	for item in items:
		if item.taken:
			continue
		item.node.rotation.y += dt
		item.node.position.y = item.base_y + sin(elapsed * 2.6) * .15
		if item.node.position.distance_to(player.position + Vector3(0, .7, 0)) < 1.7:
			if item.kind == "health" and player.health >= 100:
				continue
			item.taken = true
			item.node.hide()
			match item.kind:
				"core":
					cores += 1
					notice("Đã thu hồi lõi %d/3." % cores)
				"health":
					player.health = minf(100, player.health + 40)
					notice("Đã hồi 40 máu.")
				"ammo":
					player.reserve += 48
					notice("Nhặt được 48 viên đạn.")
	for hazard in map_data.hazards:
		if Vector2(player.position.x - hazard.x, player.position.z - hazard.z).length() < 3:
			player.hurt(9 * dt)
	if cores >= 3 and player.position.distance_to(map_data.exit) < 3.2:
		finish(true)
	_update_effects(dt)
	if not music.playing and music.stream != null and playing:
		music.play()

func _update_effects(dt: float) -> void:
	for i in range(effects.size() - 1, -1, -1):
		var effect: Dictionary = effects[i]
		effect.time -= dt
		if effect.kind == "trap":
			for enemy in enemies:
				if enemy.health > 0 and enemy.position.distance_to(effect.node.position) < 2.8:
					enemy.stun(2 if enemy.kind == 3 else 4)
					effect.time = 0
					break
		elif effect.kind == "text":
			effect.node.position.y += dt * 1.4
		if effect.time <= 0:
			effect.node.queue_free()
			effects.remove_at(i)

func spawn_enemy(kind: int, at: Vector3 = Vector3.INF) -> FieldEnemy:
	var enemy := FieldEnemy.new()
	enemy.kind = kind
	enemy.game = self
	world.add_child(enemy)
	enemy.position = _spawn_position() if at == Vector3.INF else at
	enemies.append(enemy)
	return enemy

func _spawn_position() -> Vector3:
	var shape := CapsuleShape3D.new()
	shape.radius = .8
	shape.height = 3.3
	for attempt in range(48):
		var at := Vector3(rng.randf_range(-39, 39), .1, -39 if attempt % 2 == 0 else rng.randf_range(-38, 12))
		if attempt % 2 != 0:
			at.x = -39 if attempt % 4 == 1 else 39
		if at.distance_to(player.position) < 15:
			continue
		var query := PhysicsShapeQueryParameters3D.new()
		query.shape = shape
		query.transform = Transform3D(Basis.IDENTITY, at + Vector3.UP * 1.7)
		query.collision_mask = 1
		if get_world_3d().direct_space_state.intersect_shape(query).is_empty():
			return at
	return Vector3(0, .1, -38)

func _add_item(at: Vector3, kind: String) -> void:
	var node := Node3D.new()
	world.add_child(node)
	node.position = at
	var color := Color("ffe18e") if kind == "core" else Color("9fe6b2") if kind == "health" else Color("a9cadf")
	var mesh := WorldProps.box(node, Vector3.ZERO, Vector3(.6, .6, .6), color, false)
	mesh.material_override = WorldProps.material(color, true)
	mesh.rotation.z = .3 if kind == "core" else 0
	WorldProps.sign_at(node, Vector3(0, 1.15, 0), "LÕI TÍN HIỆU" if kind == "core" else "+ MÁU" if kind == "health" else "ĐẠN", color)
	items.append({"node": node, "kind": kind, "taken": false, "base_y": at.y})

func use_flash() -> bool:
	if not playing or flashes <= 0 or flash_cooldown > 0:
		return false
	flashes -= 1
	flash_cooldown = 6
	for enemy in enemies:
		if enemy.health > 0 and enemy.position.distance_to(player.position) < 11:
			enemy.stun(1.5 if enemy.kind == 3 else 3.5)
	notice("Đèn chớp làm choáng quái trong phạm vi 11 m.")
	play_sound("flash")
	return true

func use_trap() -> bool:
	if not playing or traps <= 0 or trap_cooldown > 0:
		return false
	traps -= 1
	trap_cooldown = 3
	var node := WorldProps.cylinder(world, player.position + Vector3(0, .06, 0), 2.5, .08, Color("80dce3"))
	effects.append({"node": node, "time": 20.0, "kind": "trap"})
	notice("Đã đặt bẫy điện. Dụ quái đi vào vòng sáng.")
	return true

func make_noise(at: Vector3) -> void:
	for enemy in enemies:
		if enemy.health > 0 and enemy.position.distance_to(at) < 32:
			enemy.noise_target = at
			enemy.noise_time = 4

func tracer(from: Vector3, to: Vector3) -> void:
	var length := from.distance_to(to)
	if length < .01:
		return
	var node := WorldProps.box(world, (from + to) / 2, Vector3(.025, .025, length), Color("ffe9a8"), false)
	node.look_at(to, Vector3.UP if absf((to - from).normalized().y) < .99 else Vector3.RIGHT)
	node.material_override = WorldProps.material(Color("ffe9a8"), true)
	effects.append({"node": node, "time": .065, "kind": "tracer"})

func floating_text(at: Vector3, value: String, color: Color) -> void:
	var label := WorldProps.sign_at(world, at + Vector3.UP * .4, value, color)
	label.font_size = 35
	label.pixel_size = .01
	effects.append({"node": label, "time": .7, "kind": "text"})

func notice(value: String) -> void:
	hud.notice(value)

func play_sound(value: String) -> void:
	if not audio_enabled:
		return
	var path := "res://audio/%s.wav" % value
	if not ResourceLoader.exists(path):
		return
	if not audio_cache.has(value):
		audio_cache[value] = load(path)
	effect_audio.stream = audio_cache[value]
	effect_audio.volume_db = -13
	effect_audio.play()

func pause_game(reason: String) -> void:
	playing = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	music.stream_paused = true
	hud.show_pause("TẠM DỪNG", reason)

func resume_game() -> void:
	if completed or not hand.ready_to_play():
		hud.pause_body.text = "Tay chưa sẵn sàng. Mở tay rõ trong webcam hoặc chuyển sang bàn phím + chuột."
		return
	playing = true
	music.stream_paused = false
	hud.pause_panel.hide()
	_capture_mouse()

func _capture_mouse() -> void:
	if OS.has_feature("web") and not JavaScriptBridge.eval("document.visibilityState === 'visible' && document.hasFocus()"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		return
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func finish(won: bool) -> void:
	if completed:
		return
	playing = false
	completed = true
	music.stop()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	hud.show_pause("ĐÃ SƠ TÁN" if won else "NHIỆM VỤ THẤT BẠI", "%s\nThu hồi %d/3 lõi · Hạ %d quái · Thời gian %ds" % [SignalMaps.DETAILS[selected_map].title, cores, kills, int(elapsed)], true)
	play_sound("win" if won else "alarm")

func back_to_menu() -> void:
	playing = false
	completed = false
	music.stop()
	music.stream_paused = false
	hud.pause_panel.hide()
	hud.menu.show()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	select_map(selected_map)

func _capture_maps() -> void:
	for index in range(4):
		select_map(index)
		if index == 0:
			hud.menu.show()
			await get_tree().process_frame
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../.cache/dead-signal-3d-menu.png"))
		hud.menu.hide()
		playing = true
		player.position = Vector3(0, .1, 26)
		await get_tree().process_frame
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var path := ProjectSettings.globalize_path("res://../.cache/dead-signal-3d-map%d.png" % (index + 1))
		get_viewport().get_texture().get_image().save_png(path)
	get_tree().quit()
