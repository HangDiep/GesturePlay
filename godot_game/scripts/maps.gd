class_name SignalMaps
extends RefCounted

const DETAILS = [
	{"title": "RỪNG THÔNG", "subtitle": "Đường mòn • trạm gác • khe đá", "color": Color("a8c9a1"),
	"ground": Color("50634c"), "sky": Color("a6c4c8"), "story": "Thu hồi 3 lõi tín hiệu giữa khu rừng, rồi đến trạm cứu hộ."},
	{"title": "THỊ TRẤN BỎ HOANG", "subtitle": "Phố hẹp • quảng trường • nhà dân", "color": Color("e4ba85"),
	"ground": Color("716e65"), "sky": Color("d4b39b"), "story": "Tìm 3 lõi trong các khu phố và mở đường tới quảng trường."},
	{"title": "BẾN CẢNG", "subtitle": "Container • cầu tàu • cần cẩu", "color": Color("82cbd5"),
	"ground": Color("485f6c"), "sky": Color("8aaabf"), "story": "Luồn qua bãi container, thu hồi 3 lõi và tới bến sơ tán."},
	{"title": "NHÀ MÁY PHẢN ỨNG", "subtitle": "Bồn chứa • đường ống • vùng nhiễm", "color": Color("b7d68b"),
	"ground": Color("37454a"), "sky": Color("4b626b"), "story": "Lấy 3 lõi điều khiển, tránh vùng nhiễm và thoát qua cổng nhà máy."}
]

static func build(parent: Node3D, index: int) -> Dictionary:
	var d: Dictionary = DETAILS[index]
	WorldProps.box(parent, Vector3(0, -.55, 0), Vector3(88, 1, 88), d.ground)
	# Visible boundary geometry has physical collision, keeping play inside the map.
	for at in [Vector3(-44, 1, 0), Vector3(44, 1, 0)]:
		WorldProps.box(parent, at, Vector3(1.5, 4, 90), Color(d.ground).darkened(.25))
	for at in [Vector3(0, 1, -44), Vector3(0, 1, 44)]:
		WorldProps.box(parent, at, Vector3(90, 4, 1.5), Color(d.ground).darkened(.25))
	var rng := RandomNumberGenerator.new()
	rng.seed = 715 + index
	var spawn := Vector3(0, .1, 30)
	var cores := [Vector3(-27, .5, -24), Vector3(27, .5, -18), Vector3(0, .5, -31)]
	var hazards: Array[Vector3] = []
	match index:
		0:
			for i in range(58):
				var at := Vector3(rng.randf_range(-40, 40), 0, rng.randf_range(-39, 24))
				if absf(at.x) < 5 or _near(at, cores):
					continue
				WorldProps.tree(parent, at, rng.randf_range(.7, 1.2))
			for side in [-1, 1]:
				WorldProps.box(parent, Vector3(side * 19, 1.2, 9), Vector3(10, 2.4, 3), Color("747d72"))
				WorldProps.cylinder(parent, Vector3(side * 36, 2.8, -6), 5, 5.6, Color("7c8984"), 2, true)
			_hut(parent, Vector3(-27, 0, -30), Color("726551"))
			WorldProps.box(parent, Vector3(0, -.025, 0), Vector3(6, .03, 80), Color("9b8e6b"), false)
		1:
			cores[1] = Vector3(28, .5, -24)
			for x in [-28, -14, 14, 28]:
				for z in [-13, 6, 23]:
					_building(parent, Vector3(x, 0, z), rng.randf_range(4, 8), Color("b6a28a") if x < 0 else Color("819b9a"))
			WorldProps.box(parent, Vector3(0, -.02, 1), Vector3(8, .04, 84), Color("454d56"), false)
			WorldProps.box(parent, Vector3(0, -.015, -24), Vector3(84, .04, 7), Color("454d56"), false)
			for z in range(-36, 39, 8):
				WorldProps.box(parent, Vector3(0, .02, z), Vector3(.18, .02, 2.4), Color("dbc88e"), false)
			WorldProps.cylinder(parent, Vector3(0, 1, -12), 2.2, 2, Color("bcc5be"), 2.2, true)
		2:
			for x in [-29, -16, 16, 29]:
				for z in [-7, 10, 24]:
					var color: Color = [Color("ac634d"), Color("537e8a"), Color("bca563")][rng.randi_range(0, 2)]
					_container(parent, Vector3(x, 0, z), color)
					if x == -29 or x == 29:
						_container(parent, Vector3(x, 3.2, z), color.lightened(.1))
			WorldProps.box(parent, Vector3(0, -.03, -36), Vector3(86, .02, 13), Color("377e94"), false)
			WorldProps.box(parent, Vector3(0, .06, -36), Vector3(7, .2, 13), Color("ac9879"))
			for x in [-34, 34]:
				WorldProps.box(parent, Vector3(x, 7, -26), Vector3(1.4, 14, 1.4), Color("d3a553"))
				WorldProps.box(parent, Vector3(x * .5, 14, -26), Vector3(36, 1.2, 1.2), Color("d3a553"))
			cores[2] = Vector3(0, .5, -39)
		3:
			for x in [-25, 25]:
				for z in [-5, 17]:
					WorldProps.cylinder(parent, Vector3(x, 4, z), 4.5, 8, Color("8a9a9d"), 4.5, true)
					WorldProps.cylinder(parent, Vector3(x, 8.1, z), 4.7, .25, Color("d6c16f"))
				WorldProps.box(parent, Vector3(x, 4.8, -26), Vector3(1.5, 9.6, 1.5), Color("ad9865"))
			WorldProps.box(parent, Vector3(0, 9.6, -26), Vector3(52, 1.5, 1.5), Color("b7a16d"))
			WorldProps.box(parent, Vector3(0, 1.2, 7), Vector3(9, 2.4, 3), Color("687b7e"))
			for side in [-1, 1]:
				for z in [-18, -3, 14, 27]:
					WorldProps.box(parent, Vector3(side * 12, .7, z), Vector3(2.8, 1.4, 2.4), Color("657577"))
				WorldProps.cylinder(parent, Vector3(side * 36, 3.5, 5), 1.1, 7, Color("a79869"), 1.1, true)
				WorldProps.box(parent, Vector3(side * 36, 6.7, 12), Vector3(1.2, 1.2, 16), Color("a79869"))
			for at in [Vector3(-11, 0, -13), Vector3(13, 0, 14), Vector3(27, 0, -31)]:
				hazards.append(at)
				WorldProps.cylinder(parent, at + Vector3(0, .015, 0), 3, .04, Color("8fbb43"))
				WorldProps.sign_at(parent, at + Vector3(0, 1.2, 0), "VÙNG NHIỄM", Color("d7e58a"))
	# Shared small supplies are deliberately away from large buildings and spawn.
	var supplies := [Vector3(-7, .5, 18), Vector3(8, .5, -5), Vector3(35, .5, -22)]
	WorldProps.sign_at(parent, Vector3(0, 4, 34), "ĐIỂM CỨU HỘ", Color("a7ecc6"))
	WorldProps.cylinder(parent, Vector3(0, .03, 34), 3.2, .08, Color("62a88f"))
	return {"spawn": spawn, "cores": cores, "supplies": supplies, "exit": Vector3(0, 0, 34), "hazards": hazards}

static func _near(at: Vector3, points: Array) -> bool:
	for p in points:
		if at.distance_to(p) < 4:
			return true
	return false

static func _hut(parent: Node3D, at: Vector3, color: Color) -> void:
	# Open shelters have an entrance wide enough for both player and enemies.
	WorldProps.box(parent, at + Vector3(0, 1.7, -2), Vector3(8, 3.4, .35), color)
	for side in [-1, 1]:
		WorldProps.box(parent, at + Vector3(side * 4, 1.7, 0), Vector3(.35, 3.4, 4), color)
	WorldProps.box(parent, at + Vector3(0, 3.6, 0), Vector3(8.5, .4, 4.5), color.darkened(.3))

static func _building(parent: Node3D, at: Vector3, height: float, color: Color) -> void:
	WorldProps.box(parent, at + Vector3(0, height / 2, 0), Vector3(8, height, 10), color)
	WorldProps.box(parent, at + Vector3(0, height + .15, 0), Vector3(8.5, .3, 10.5), color.darkened(.35))
	for y in [2.0, 4.5]:
		if y + 1 > height:
			continue
		for x in [-2.4, 0, 2.4]:
			WorldProps.box(parent, at + Vector3(x, y, 5.03), Vector3(1.4, 1.5, .08), Color("405969"), false)

static func _container(parent: Node3D, at: Vector3, color: Color) -> void:
	WorldProps.box(parent, at + Vector3(0, 1.6, 0), Vector3(8, 3.2, 4), color)
	for x in range(-3, 4):
		WorldProps.box(parent, at + Vector3(x, 1.6, 2.02), Vector3(.08, 2.9, .04), color.lightened(.13), false)
