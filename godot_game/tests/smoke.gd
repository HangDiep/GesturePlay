extends SceneTree

var game: Node
var failures := 0
var checks := 0

func _initialize() -> void:
	_run.call_deferred()

func check(value: bool, description: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error("FAILED: " + description)
	else:
		print("PASS: " + description)

func frames(count: int) -> void:
	for i in range(count):
		await physics_frame

func _run() -> void:
	game = load("res://main.tscn").instantiate()
	game.audio_enabled = false
	root.add_child(game)
	await frames(2)
	var geometry_counts: Array[int] = []
	for index in range(4):
		game.select_map(index)
		await frames(3)
		check(game.map_data.cores.size() == 3, "map %d has three objective cores" % (index + 1))
		var count: int = game.world.find_children("*", "StaticBody3D", true, false).size()
		geometry_counts.append(count)
		check(count > 18, "map %d has solid environment geometry" % (index + 1))
		check(_reachable(game.map_data.spawn, game.map_data.cores), "all objectives reachable on map %d" % (index + 1))
	check(geometry_counts[0] != geometry_counts[1] and geometry_counts[1] != geometry_counts[2] and geometry_counts[2] != geometry_counts[3], "four maps have different physical layouts")
	game.select_map(1)
	await frames(3)
	game.start_round()
	var start: Vector3 = game.player.position
	Input.action_press("forward")
	await frames(60)
	Input.action_release("forward")
	check(game.player.position.z < start.z - 4, "W moves the playable third-person character")
	check(absf(game.player.position.x - start.x) < .1, "forward movement follows camera orientation")
	var original_yaw: float = game.player.yaw
	Input.action_press("look_right")
	await frames(10)
	Input.action_release("look_right")
	check(game.player.yaw < original_yaw, "keyboard camera fallback rotates the third-person view")
	game.player.yaw = 0
	game.pause_game("test")
	var frozen: float = game.elapsed
	await frames(15)
	check(game.elapsed == frozen, "pause freezes gameplay time")
	game.resume_game()
	await frames(3)
	check(game.elapsed > frozen, "resume advances gameplay")
	game.player.ammo = 1
	game.player.shoot()
	check(game.player.ammo == 0, "shooting consumes ammunition")
	game.player.reload()
	await frames(105)
	check(game.player.ammo == 24 and game.player.reserve == 96, "reload transfers reserve rounds after its delay")
	var enemy: FieldEnemy = game.spawn_enemy(0, game.player.position + Vector3(3, 0, 0))
	var breaker: FieldEnemy = game.spawn_enemy(1, game.player.position + Vector3(-3, 0, 0))
	check(enemy.health == 45 and breaker.health == 135, "enemy types have individual health values")
	check(FieldEnemy.SPEED[0] > FieldEnemy.SPEED[1], "runner moves faster than heavy enemy")
	game.use_flash()
	check(enemy.stunned > 3 and breaker.stunned > 3, "flash stuns nearby enemies")
	check(not game.use_flash(), "flash cannot bypass its cooldown")
	var boss: FieldEnemy = game.spawn_enemy(3, game.player.position + Vector3(0, 0, -3))
	var armor_damage := boss.take_damage(30, boss.position + Vector3.UP * 2.1)
	check(is_equal_approx(armor_damage, 10), "boss armor reduces incoming damage")
	boss.weak = 3
	var weak_damage := boss.take_damage(30, boss.position + Vector3.UP * 2.1)
	check(is_equal_approx(weak_damage, 30), "exposed boss core receives full damage")
	boss.weak = 0
	boss.stun(1.5)
	check(boss.charge == 0 and boss.stunned == 1.5, "stun interrupts the boss windup")
	var previous_kills: int = game.kills
	enemy.take_damage(100, enemy.position + Vector3.UP)
	check(enemy.health == 0 and enemy.collision_layer == 0 and game.kills == previous_kills + 1, "dead enemies stop colliding and count once")
	enemy.take_damage(100, enemy.position + Vector3.UP)
	check(game.kills == previous_kills + 1, "corpse cannot be killed twice")
	var old_health: float = game.player.health
	game.player.hurt(15)
	check(game.player.health == old_health - 15, "player health takes combat damage")
	game.back_to_menu()
	await frames(3)
	game.select_map(1)
	await frames(3)
	game.start_round()
	game.player.pitch = 0
	var ray_target: FieldEnemy = game.spawn_enemy(0, game.player.position + Vector3(.7, 0, -7))
	ray_target.stun(3)
	await frames(3)
	game.player.shoot()
	check(ray_target.health == 17, "camera ray and muzzle path hit a visible 3D enemy")
	game.back_to_menu()
	await frames(3)
	game.start_round()
	var charging_boss: FieldEnemy = game.spawn_enemy(3, game.player.position + Vector3(0, 0, -2.5))
	await frames(3)
	check(charging_boss.charge > 1, "nearby boss announces its heavy strike before damage")
	await frames(90)
	check(charging_boss.weak > 2 and game.player.health == 68, "boss heavy strike damages player then exposes its core")
	var wall_enemy: FieldEnemy = game.spawn_enemy(0, game.player.position + Vector3(0, 0, -1))
	WorldProps.box(game.world, game.player.position + Vector3(0, 1.5, -.5), Vector3(8, 3, .1), Color.GRAY)
	await frames(2)
	check(not wall_enemy._clear_to_player(), "solid cover blocks enemy melee line of sight")
	game.back_to_menu()
	await frames(3)
	game.select_map(0)
	await frames(3)
	game.start_round()
	for item in game.items:
		if item.kind == "core":
			game.player.position = item.node.position
			await frames(2)
	check(game.cores == 3, "exploring and approaching cores collects all objectives")
	game.player.position = game.map_data.exit
	await frames(2)
	check(game.completed and not game.playing, "collecting cores and returning to extraction completes the mission")
	game.back_to_menu()
	await frames(3)
	game.start_round()
	game.elapsed = 89
	for i in range(12):
		game._physics_process(.025)
	check(game.wave == 4, "wave definitions activate in scheduled order")
	check(game.enemies.size() == 9 and game.pending.is_empty(), "four scheduled waves spawn their configured nine enemies")
	game.elapsed = 121
	game._physics_process(.025)
	check(game.pending.size() == 3 and game.enemies.size() == 9, "active enemy cap queues later encounters")
	game.pause_game("end")
	var stamp := int(Time.get_unix_time_from_system() * 1000)
	game.hand.accept({"type": "hand", "protocol": 1, "epoch": "test", "seq": 2, "valid": true, "ready": true, "released": true, "age_ms": 0, "sent_at_ms": stamp})
	game.hand.accept({"type": "hand", "protocol": 1, "epoch": "test", "seq": 1, "valid": false})
	check(game.hand.last_seq == 2 and game.hand.packet.valid, "hand bridge rejects out-of-order packets")
	game.hand.enabled = true
	game.hand.last_received = Time.get_ticks_msec() - 1000
	check(not game.hand.ready_to_play(), "stale hand data cannot resume gameplay")
	game.hand.enabled = false
	print("3D_CHECKS: %d passed, %d failed" % [checks - failures, failures])
	game.queue_free()
	await process_frame
	await process_frame
	WorldProps.materials.clear()
	quit(0 if failures == 0 else 1)

func _reachable(start: Vector3, goals: Array) -> bool:
	# Flood fill actual collision clearance, using a capsule-sized ground probe.
	var step := 2.0
	var visited := {}
	var queue: Array[Vector2i] = [Vector2i(roundi(start.x / step), roundi(start.z / step))]
	var cursor := 0
	var shape := SphereShape3D.new()
	shape.radius = .5
	while cursor < queue.size():
		var cell: Vector2i = queue[cursor]
		cursor += 1
		if visited.has(cell) or absi(cell.x) > 20 or absi(cell.y) > 20:
			continue
		var query := PhysicsShapeQueryParameters3D.new()
		query.shape = shape
		query.transform.origin = Vector3(cell.x * step, .8, cell.y * step)
		query.collision_mask = 1
		if not game.get_world_3d().direct_space_state.intersect_shape(query).is_empty():
			continue
		visited[cell] = true
		for offset in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			queue.append(cell + offset)
	for goal in goals:
		var cell := Vector2i(roundi(goal.x / step), roundi(goal.z / step))
		if not visited.has(cell):
			return false
	return true
