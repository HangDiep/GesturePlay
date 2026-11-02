class_name Hand3DBridge
extends Node

var game: Node
var enabled := false
var socket := WebSocketPeer.new()
var status := "Bàn phím + chuột"
var last_received := 0
var last_seq := -1
var epoch := ""
var packet: Dictionary = {}
var centered := false
var center := Vector2(.5, .5)
var previous_fist := false
var frame_texture: ImageTexture
var was_open := false
var lost_paused := false

func set_enabled(value: bool) -> void:
	if enabled == value:
		return
	enabled = value
	centered = false
	packet = {}
	_reset_player()
	if value:
		socket = WebSocketPeer.new()
		var error := socket.connect_to_url("ws://127.0.0.1:8766")
		status = "Đang kết nối webcam…" if error == OK else "Không kết nối được dịch vụ tay"
		was_open = false
	else:
		if socket.get_ready_state() == WebSocketPeer.STATE_OPEN:
			command("stop")
			socket.close()
		status = "Bàn phím + chuột"
		game.hud.preview.texture = null

func command(action: String, extra: Dictionary = {}) -> void:
	if socket.get_ready_state() != WebSocketPeer.STATE_OPEN:
		return
	var payload := {"type": "command", "action": action}
	payload.merge(extra)
	socket.send_text(JSON.stringify(payload))

func _process(_dt: float) -> void:
	if not enabled:
		return
	socket.poll()
	var state := socket.get_ready_state()
	if state == WebSocketPeer.STATE_OPEN:
		if not was_open:
			was_open = true
			command("start", {"camera_index": 0, "backend": "dshow"})
			command("preview", {"enabled": true})
		while socket.get_available_packet_count() > 0:
			var data := socket.get_packet()
			if not socket.was_string_packet():
				var image := Image.new()
				if image.load_jpg_from_buffer(data) == OK:
					if frame_texture == null:
						frame_texture = ImageTexture.create_from_image(image)
					else:
						frame_texture.update(image)
					game.hud.preview.texture = frame_texture
				continue
			var decoded = JSON.parse_string(data.get_string_from_utf8())
			if decoded is Dictionary:
				accept(decoded)
	elif state == WebSocketPeer.STATE_CLOSED:
		status = "Mất kết nối tay. Tắt/bật mục Bàn tay để thử lại."
		_reset_player()
	var fresh := Time.get_ticks_msec() - last_received <= 250
	var ready: bool = fresh and packet.get("valid", false) and packet.get("ready", false)
	if not ready:
		_reset_player()
		if game.playing:
			game.pause_game("Mất tín hiệu tay — giữ tay rõ trong webcam rồi tiếp tục.")
			lost_paused = true
		return
	if not is_instance_valid(game.player):
		return
	var palm := Vector2(float(packet.get("palm_x", .5)), float(packet.get("palm_y", .5)))
	if not palm.is_finite():
		_reset_player()
		return
	if not centered:
		center = palm
		centered = true
	var delta := palm - center
	var fist: bool = packet.get("fist", false)
	var pinched: bool = packet.get("pinched", false)
	# Open palm steers a camera-relative walking joystick. Pinch holds still to aim/fire.
	var motion := Vector2(_deadzone(delta.x, .045), _deadzone(delta.y, .045)) * 5
	game.player.hand_motion = Vector2.ZERO if fist or pinched else motion.limit_length(1)
	game.player.hand_aim = Vector2(_deadzone(delta.x, .06) * 4, _deadzone(delta.y, .06) * 3) if pinched else Vector2.ZERO
	game.player.hand_shoot = pinched and not fist
	if fist and not previous_fist and game.playing:
		game.player.reload()
	previous_fist = fist
	status = "Chụm: ngắm/bắn · mở tay: di chuyển · nắm: thay đạn"

func accept(data: Dictionary) -> void:
	if data.get("type") == "error":
		status = str(data.get("message", "Lỗi nhận diện"))
		return
	if data.get("type") != "hand" or data.get("protocol") != 1:
		return
	var next_epoch := str(data.get("epoch", ""))
	var sequence := int(data.get("seq", -1))
	if next_epoch == epoch and sequence <= last_seq:
		return
	epoch = next_epoch
	last_seq = sequence
	packet = data
	var age := float(data.get("age_ms", 100000)) if data.get("age_ms") != null else 100000.0
	var sent := float(data.get("sent_at_ms", Time.get_unix_time_from_system() * 1000))
	var transport := maxf(0, Time.get_unix_time_from_system() * 1000 - sent)
	last_received = Time.get_ticks_msec() - int(age + transport)
	if not data.get("ready", false):
		status = str(data.get("tracker_message", "Giữ tay rõ trong webcam…"))

func _deadzone(value: float, zone: float) -> float:
	return signf(value) * maxf(0, absf(value) - zone)

func _reset_player() -> void:
	previous_fist = false
	if is_instance_valid(game.player):
		game.player.hand_motion = Vector2.ZERO
		game.player.hand_aim = Vector2.ZERO
		game.player.hand_shoot = false

func ready_to_play() -> bool:
	return not enabled or (Time.get_ticks_msec() - last_received <= 250 and packet.get("valid", false) and packet.get("ready", false) and packet.get("released", false))
