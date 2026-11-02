class_name FieldEnemy
extends CharacterBody3D

const HEALTH = [45.0, 135.0, 70.0, 300.0]
const SPEED = [4.0, 2.0, 2.8, 2.25]
const DAMAGE = [8.0, 17.0, 10.0, 32.0]
const NAMES = ["KẺ SĂN ĐUỔI", "KẺ PHÁ GIÁP", "KẺ GÂY NHIỄU", "VẬT CHỦ"]
var game: Node
var kind := 0
var health := 45.0
var stunned := 0.0
var weak := 0.0
var charge := 0.0
var attack_cooldown := 0.0
var hit_time := 0.0
var death_time := 0.0
var walk_time := 0.0
var noise_time := 0.0
var noise_target := Vector3.ZERO
var body: Node3D
var limbs: Array = []
var label: Label3D
var core: MeshInstance3D
var turn_sign := 1.0
var dodge_time := 0.0

func _ready() -> void:
	health = HEALTH[kind]
	collision_layer = 4
	collision_mask = 1
	var scale_factor := 1.65 if kind == 3 else 1.22 if kind == 1 else 1.0
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.height = 1.9 * scale_factor
	capsule.radius = .42 * scale_factor
	shape.position.y = capsule.height / 2
	shape.shape = capsule
	add_child(shape)
	var color: Color = [Color("884c43"), Color("7a6856"), Color("467d8b"), Color("424c67")][kind]
	var model := WorldProps.humanoid(self, color, Color("edbd73"), scale_factor)
	body = model.root
	limbs = model.limbs
	if kind == 3:
		core = WorldProps.cylinder(body, Vector3(0, 1.3, -.26), .18, .08, Color("7c8799"))
		core.rotation.x = PI / 2
		WorldProps.box(body, Vector3(-.53, 1.5, 0), Vector3(.45, .35, .6), color.lightened(.15), false)
		WorldProps.box(body, Vector3(.53, 1.5, 0), Vector3(.45, .35, .6), color.lightened(.15), false)
	if kind == 2:
		WorldProps.cylinder(body, Vector3(.2, 2.25, 0), .035, .55, Color("7bd1df"))
	label = WorldProps.sign_at(self, Vector3(0, 2.3 * scale_factor, 0), NAMES[kind], Color("f1dbb2"))
	label.font_size = 24
	label.pixel_size = .008
	turn_sign = -1 if get_instance_id() % 2 == 0 else 1
	add_to_group("enemies")

func _physics_process(dt: float) -> void:
	if not game.playing:
		return
	if health <= 0:
		death_time += dt
		body.rotation.z = lerpf(body.rotation.z, 1.5, dt * 8)
		body.scale *= maxf(.01, 1 - dt * 1.4)
		if death_time > .85:
			queue_free()
		return
	weak = maxf(0, weak - dt)
	stunned = maxf(0, stunned - dt)
	hit_time = maxf(0, hit_time - dt)
	attack_cooldown = maxf(0, attack_cooldown - dt)
	noise_time = maxf(0, noise_time - dt)
	dodge_time = maxf(0, dodge_time - dt)
	if kind == 3:
		core.material_override = WorldProps.material(Color("ffe078") if weak > 0 else Color("68768a"), weak > 0)
	var state := "CHOÁNG" if stunned > 0 else "ĐIỂM YẾU" if weak > 0 else "NẠP ĐÒN!" if charge > 0 else "GIÁP" if kind == 3 else ""
	label.text = "%s\n%d/%d %s" % [NAMES[kind], ceili(health), int(HEALTH[kind]), state]
	label.modulate = Color("9de8ed") if stunned > 0 else Color("ffe389") if weak > 0 else Color("ffb6a0")
	var to_player: Vector3 = game.player.global_position - global_position
	to_player.y = 0
	var distance := to_player.length()
	var direction := to_player.normalized()
	if stunned > 0 or weak > 0:
		velocity.x = 0
		velocity.z = 0
	elif charge > 0:
		charge = maxf(0, charge - dt)
		velocity.x = 0
		velocity.z = 0
		body.rotation.y = atan2(-direction.x, -direction.z)
		if charge == 0:
			if distance < 4.6 and _clear_to_player():
				game.player.hurt(DAMAGE[kind])
			weak = 3.2
			attack_cooldown = 4.2
			game.notice("Boss lộ lõi sáng! Bắn vào ngực.")
			game.play_sound("boss_slam")
	elif distance < (3.6 if kind == 3 else 1.5) and _clear_to_player():
		velocity.x = 0
		velocity.z = 0
		if attack_cooldown == 0:
			if kind == 3:
				charge = 1.4
				game.notice("Boss đang nạp đòn — lùi ra xa!")
				game.play_sound("boss_charge")
			else:
				game.player.hurt(DAMAGE[kind])
				attack_cooldown = 1.3
	else:
		if noise_time > 0 and distance > 8:
			direction = (noise_target - global_position).normalized()
			direction.y = 0
		direction = _steer(direction)
		velocity.x = direction.x * SPEED[kind]
		velocity.z = direction.z * SPEED[kind]
		body.rotation.y = lerp_angle(body.rotation.y, atan2(-direction.x, -direction.z), dt * 8)
	if not is_on_floor():
		velocity.y -= 22 * dt
	move_and_slide()
	walk_time += dt * (11 if kind == 0 else 6)
	var stride := sin(walk_time) * .6 if velocity.length() > .2 and stunned <= 0 else 0.0
	limbs[0].rotation.x = stride
	limbs[2].rotation.x = -stride
	body.position.y = .06 * sin(hit_time * 65) if hit_time > 0 else 0

func _clear_to_player() -> bool:
	var start := global_position + Vector3.UP
	var end: Vector3 = game.player.global_position + Vector3.UP
	return get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(start, end, 1)).is_empty()

func _steer(direction: Vector3) -> Vector3:
	var start := global_position + Vector3.UP * .7
	var forward := PhysicsRayQueryParameters3D.create(start, start + direction * 2.5, 1)
	var blocked := not get_world_3d().direct_space_state.intersect_ray(forward).is_empty()
	if blocked or dodge_time > 0:
		if blocked:
			dodge_time = .8
		for side in [turn_sign, -turn_sign]:
			var tangent := direction.rotated(Vector3.UP, side * 1.25)
			var q := PhysicsRayQueryParameters3D.create(start, start + tangent * 1.8, 1)
			if get_world_3d().direct_space_state.intersect_ray(q).is_empty():
				turn_sign = side
				return tangent
		return -direction
	return direction

func stun(seconds: float) -> void:
	if health <= 0:
		return
	stunned = maxf(stunned, seconds)
	charge = 0
	attack_cooldown = maxf(attack_cooldown, 1)

func take_damage(amount: float, point: Vector3) -> float:
	if health <= 0:
		return 0
	var weak_hit := kind == 3 and weak > 0 and absf(point.y - global_position.y - 2.1) < .65
	var damage := amount / 3 if kind == 3 and not weak_hit else amount
	health = maxf(0, health - damage)
	hit_time = .3
	game.floating_text(point, "−%d%s" % [ceili(damage), " GIÁP" if kind == 3 and not weak_hit else ""], Color("ffe199"))
	if health == 0:
		collision_layer = 0
		label.text = "TIÊU DIỆT"
		game.kills += 1
		game.play_sound("kill")
	return damage
