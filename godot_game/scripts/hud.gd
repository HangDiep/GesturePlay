class_name FieldHUD
extends CanvasLayer

var game: Node
var root: Control
var menu: PanelContainer
var pause_panel: PanelContainer
var stats: Label
var mission: Label
var message: Label
var hand_status: Label
var preview: TextureRect
var radar: FieldRadar
var hand_toggle: CheckButton
var map_buttons: Array[Button] = []
var pause_title: Label
var pause_body: Label
var resume_button: Button
var damage_flash := 0.0
var overlay: Control
var notice_time := 0.0

func _ready() -> void:
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	var theme := Theme.new()
	theme.default_font_size = 16
	theme.set_color("font_color", "Label", Color("e5eeed"))
	for state in ["normal", "hover", "pressed", "focus"]:
		var style := panel_style(Color("243b45") if state == "normal" else Color("44665b"))
		style.content_margin_left = 18
		style.content_margin_right = 18
		style.content_margin_top = 12
		style.content_margin_bottom = 12
		theme.set_stylebox(state, "Button", style)
	root.theme = theme
	mission = label_at(Vector2(26, 20), 23)
	stats = label_at(Vector2(26, 58), 16)
	message = label_at(Vector2(0, 105), 19)
	message.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	message.offset_top = 105
	message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hand_status = label_at(Vector2(26, 91), 13)
	preview = TextureRect.new()
	preview.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	preview.offset_left = -218
	preview.offset_top = 22
	preview.offset_right = -26
	preview.offset_bottom = 166
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(preview)
	radar = FieldRadar.new()
	radar.game = game
	root.add_child(radar)
	radar.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	radar.offset_left = 26
	radar.offset_top = -198
	radar.offset_right = 192
	radar.offset_bottom = -32
	var help := label_at(Vector2.ZERO, 14)
	help.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	help.offset_left = 214
	help.offset_top = -70
	help.offset_right = -20
	help.offset_bottom = -18
	help.text = "WASD di chuyển · Chuột / IJKL xoay nhìn · Chuột trái bắn · Chuột phải ngắm\nShift chạy · Space nhảy · R thay đạn · Q đèn chớp · E bẫy · Esc tạm dừng"
	overlay = BattleOverlay.new()
	overlay.hud = self
	root.add_child(overlay)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_menu()
	_build_pause()

func _build_menu() -> void:
	menu = PanelContainer.new()
	root.add_child(menu)
	menu.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	menu.offset_left = -550
	menu.offset_top = -225
	menu.offset_right = 550
	menu.offset_bottom = 225
	menu.add_theme_stylebox_override("panel", panel_style(Color(.045, .08, .11, .94)))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	menu.add_child(box)
	var heading := Label.new()
	heading.text = "DEAD SIGNAL / 3D"
	heading.add_theme_font_size_override("font_size", 36)
	box.add_child(heading)
	var description := Label.new()
	description.text = "Bạn là người sống sót. Khám phá bản đồ, thu hồi 3 lõi tín hiệu và trở về điểm cứu hộ."
	box.add_child(description)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	box.add_child(row)
	for i in range(4):
		var button := Button.new()
		button.text = "%02d\n%s\n\n%s" % [i + 1, SignalMaps.DETAILS[i].title, SignalMaps.DETAILS[i].subtitle.replace(" • ", "\n")]
		button.custom_minimum_size = Vector2(253, 185)
		button.pressed.connect(func(): game.select_map(i))
		row.add_child(button)
		map_buttons.append(button)
	hand_toggle = CheckButton.new()
	hand_toggle.text = "Bàn tay qua webcam (mở tay: đi · chụm: ngắm/bắn · nắm: thay đạn)"
	hand_toggle.toggled.connect(func(value): game.hand.set_enabled(value))
	box.add_child(hand_toggle)
	var footer := HBoxContainer.new()
	box.add_child(footer)
	var note := Label.new()
	note.text = "Góc nhìn sau lưng  •  4 môi trường  •  Chơi một người"
	note.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(note)
	var start := Button.new()
	start.text = "VÀO BẢN ĐỒ"
	start.pressed.connect(func(): game.start_round())
	footer.add_child(start)

func _build_pause() -> void:
	pause_panel = PanelContainer.new()
	root.add_child(pause_panel)
	pause_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	pause_panel.offset_left = -285
	pause_panel.offset_top = -155
	pause_panel.offset_right = 285
	pause_panel.offset_bottom = 155
	pause_panel.add_theme_stylebox_override("panel", panel_style(Color(.045, .08, .11, .96)))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 17)
	pause_panel.add_child(box)
	pause_title = Label.new()
	pause_title.add_theme_font_size_override("font_size", 30)
	box.add_child(pause_title)
	pause_body = Label.new()
	pause_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	pause_body.custom_minimum_size = Vector2(510, 62)
	box.add_child(pause_body)
	resume_button = Button.new()
	resume_button.text = "TIẾP TỤC"
	resume_button.pressed.connect(func(): game.resume_game())
	box.add_child(resume_button)
	var back := Button.new()
	back.text = "CHỌN BẢN ĐỒ KHÁC"
	back.pressed.connect(func(): game.back_to_menu())
	box.add_child(back)
	var mouse := Button.new()
	mouse.text = "CHUYỂN SANG BÀN PHÍM + CHUỘT"
	mouse.pressed.connect(func(): hand_toggle.button_pressed = false)
	box.add_child(mouse)
	pause_panel.hide()

func label_at(at: Vector2, font_size: int) -> Label:
	var label := Label.new()
	label.position = at
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_shadow_color", Color(.02, .04, .06, .9))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 2)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(label)
	return label

func select(index: int) -> void:
	for i in range(map_buttons.size()):
		map_buttons[i].modulate = SignalMaps.DETAILS[i].color if i == index else Color("84979d")

func show_pause(title: String, reason: String, finished: bool = false) -> void:
	pause_title.text = title
	pause_body.text = reason
	resume_button.visible = not finished
	pause_panel.show()

func notice(value: String) -> void:
	message.text = value
	notice_time = 3.5

func _process(dt: float) -> void:
	if not is_instance_valid(game.player):
		return
	var p: FieldPlayer = game.player
	var map: Dictionary = SignalMaps.DETAILS[game.selected_map]
	mission.text = "%02d / %s    •    LÕI %d/3" % [game.selected_map + 1, map.title, game.cores]
	stats.text = "MÁU %d/100    THỂ LỰC %d    ĐẠN %d / %d    HẠ %d    ĐỢT %d/5    %02d:%02d" % [ceili(p.health), int(p.stamina), p.ammo, p.reserve, game.kills, game.wave, int(game.elapsed) / 60, int(game.elapsed) % 60]
	if p.reload_time > 0:
		stats.text += "    THAY ĐẠN %.1fs" % p.reload_time
	hand_status.text = game.hand.status if game.hand.enabled else "Q: Đèn chớp %d  •  E: Bẫy điện %d" % [game.flashes, game.traps]
	preview.visible = game.hand.enabled
	if game.playing:
		notice_time = maxf(0, notice_time - dt)
		damage_flash = maxf(0, damage_flash - dt)
		if notice_time == 0:
			message.text = "Đủ 3 lõi! Trở về vòng sáng xanh ở điểm xuất phát." if game.cores >= 3 else ""
	overlay.queue_redraw()
	radar.queue_redraw()

static func panel_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = Color("668379")
	style.set_border_width_all(1)
	style.set_corner_radius_all(10)
	style.content_margin_left = 24
	style.content_margin_right = 24
	style.content_margin_top = 22
	style.content_margin_bottom = 22
	return style

class BattleOverlay extends Control:
	var hud: FieldHUD
	func _draw() -> void:
		if not hud.game.playing:
			return
		var center := size / 2
		var color := Color("f8e9c5")
		draw_arc(center, 7, 0, TAU, 24, color, 1.5)
		for direction in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
			draw_line(center + direction * 12, center + direction * 18, color, 2)
		if hud.damage_flash > 0:
			draw_rect(Rect2(Vector2.ZERO, size), Color(.8, .1, .05, hud.damage_flash * .24), false, 18)
		if hud.game.jammed:
			for i in range(12):
				var y := fmod(hud.game.elapsed * 91 + i * 73, size.y)
				draw_line(Vector2(0, y), Vector2(size.x, y), Color(.5, .85, .9, .16), 2)
