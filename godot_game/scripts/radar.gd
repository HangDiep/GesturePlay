class_name FieldRadar
extends Control

var game: Node

func _draw() -> void:
	if not is_instance_valid(game.player):
		return
	var rect := Rect2(Vector2.ZERO, size)
	draw_style_box(_background(), rect)
	for line in range(1, 4):
		draw_line(Vector2(line * size.x / 4, 0), Vector2(line * size.x / 4, size.y), Color(1, 1, 1, .08))
		draw_line(Vector2(0, line * size.y / 4), Vector2(size.x, line * size.y / 4), Color(1, 1, 1, .08))
	for item in game.items:
		if item.kind == "core" and not item.taken:
			draw_circle(_point(item.node.position), 3, Color("ffda8c"))
	draw_arc(_point(game.map_data.exit), 5, 0, TAU, 20, Color("8ce3b0"), 2)
	if not game.jammed:
		for enemy in game.enemies:
			if is_instance_valid(enemy) and enemy.health > 0 and enemy.position.distance_to(game.player.position) < 23:
				draw_circle(_point(enemy.position), 2.5 if enemy.kind < 3 else 4, Color("f08e7c"))
	var p := _point(game.player.position)
	var forward := Vector2(-sin(game.player.yaw), -cos(game.player.yaw))
	draw_line(p, p + forward * 12, Color("c6edfb"), 2)
	draw_circle(p, 4, Color("ecf6fc"))

func _point(world: Vector3) -> Vector2:
	return Vector2(world.x / 88 + .5, world.z / 88 + .5) * size

func _background() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(.04, .08, .11, .88)
	style.border_color = Color("749593")
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	return style
