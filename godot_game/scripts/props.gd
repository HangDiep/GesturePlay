class_name WorldProps
extends RefCounted

static var materials: Dictionary = {}

static func material(color: Color, glow: bool = false) -> StandardMaterial3D:
	var key := str(color) + str(glow)
	if materials.has(key):
		return materials[key]
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.85
	if glow:
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = 1.5
	materials[key] = mat
	return mat

static func box(parent: Node3D, at: Vector3, size: Vector3, color: Color,
		collision: bool = true) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = material(color)
	node.position = at
	parent.add_child(node)
	if collision:
		var body := StaticBody3D.new()
		body.collision_layer = 1
		var shape := CollisionShape3D.new()
		var cube := BoxShape3D.new()
		cube.size = size
		shape.shape = cube
		body.add_child(shape)
		node.add_child(body)
	return node

static func cylinder(parent: Node3D, at: Vector3, radius: float, height: float,
		color: Color, top: float = -1.0, collision: bool = false) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.bottom_radius = radius
	mesh.top_radius = radius if top < 0 else top
	mesh.height = height
	mesh.radial_segments = 8
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = material(color)
	node.position = at
	parent.add_child(node)
	if collision:
		var body := StaticBody3D.new()
		var shape := CollisionShape3D.new()
		var cylinder_shape := CylinderShape3D.new()
		cylinder_shape.height = height
		cylinder_shape.radius = radius
		shape.shape = cylinder_shape
		body.add_child(shape)
		node.add_child(body)
	return node

static func sign_at(parent: Node3D, at: Vector3, value: String, color: Color) -> Label3D:
	var label := Label3D.new()
	label.position = at
	label.text = value
	label.font_size = 42
	label.pixel_size = 0.014
	label.modulate = color
	label.outline_size = 8
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = false
	parent.add_child(label)
	return label

static func tree(parent: Node3D, at: Vector3, scale_factor: float = 1.0) -> void:
	var root := Node3D.new()
	parent.add_child(root)
	root.position = at
	root.scale = Vector3.ONE * scale_factor
	cylinder(root, Vector3(0, 1.8, 0), .32, 3.6, Color("66513d"), -1, true)
	cylinder(root, Vector3(0, 4.3, 0), 2.1, 4.8, Color("2e624e"), 0)
	cylinder(root, Vector3(0, 6.1, 0), 1.5, 3.8, Color("3b7959"), 0)

static func humanoid(parent: Node3D, body_color: Color, accent: Color,
		scale_factor: float = 1.0) -> Dictionary:
	var root := Node3D.new()
	parent.add_child(root)
	root.scale = Vector3.ONE * scale_factor
	box(root, Vector3(0, 1.15, 0), Vector3(.64, .72, .38), body_color, false)
	box(root, Vector3(0, 1.25, -.22), Vector3(.44, .38, .08), accent, false)
	box(root, Vector3(0, 1.75, 0), Vector3(.42, .44, .4), Color("bb9979"), false)
	box(root, Vector3(0, 1.93, 0), Vector3(.46, .12, .44), body_color, false)
	var limbs := []
	for side in [-1, 1]:
		var leg := Node3D.new()
		root.add_child(leg)
		leg.position = Vector3(side * .2, .82, 0)
		box(leg, Vector3(0, -.36, 0), Vector3(.26, .72, .3), body_color.darkened(.25), false)
		box(leg, Vector3(0, -.68, -.08), Vector3(.29, .18, .46), Color("202b34"), false)
		limbs.append(leg)
		var arm := Node3D.new()
		root.add_child(arm)
		arm.position = Vector3(side * .43, 1.45, 0)
		box(arm, Vector3(0, -.28, 0), Vector3(.22, .6, .24), body_color, false)
		limbs.append(arm)
	return {"root": root, "limbs": limbs}
