class_name FieldPlayer
extends CharacterBody3D

var game: Node
var yaw := 0.0
var pitch := -.12
var health := 100.0
var stamina := 100.0
var ammo := 24
var reserve := 120
var fire_cooldown := 0.0
var reload_time := 0.0
var walk_time := 0.0
var rig: Node3D
var camera: Camera3D
var spring: SpringArm3D
var visual: Node3D
var limbs: Array = []
var hand_motion := Vector2.ZERO
var hand_aim := Vector2.ZERO
var hand_shoot := false

func _ready() -> void:
	collision_layer = 2
	collision_mask = 1
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = .38
	capsule.height = 1.9
	shape.shape = capsule
	shape.position.y = .95
	add_child(shape)
	var body := WorldProps.humanoid(self, Color("263f55"), Color("d49c50"))
	visual = body.root
	limbs = body.limbs
	WorldProps.box(visual, Vector3(0, 1.2, .29), Vector3(.5, .55, .25), Color("5c725d"), false)
	WorldProps.box(visual, Vector3(.43, 1.28, -.5), Vector3(.12, .18, 1), Color("222e38"), false)
	WorldProps.box(visual, Vector3(.43, 1.34, -.92), Vector3(.14, .07, .2), Color("c6b585"), false)
	rig = Node3D.new()
	rig.position = Vector3(.7, 1.5, 0)
	add_child(rig)
	spring = SpringArm3D.new()
	spring.spring_length = 5.4
	spring.margin = .18
	spring.collision_mask = 1
	spring.add_excluded_object(get_rid())
	rig.add_child(spring)
	camera = Camera3D.new()
	camera.position = Vector3(0, .25, 0)
	camera.fov = 72
	camera.current = true
	camera.far = 170
	spring.add_child(camera)

func look(relative: Vector2) -> void:
	yaw -= relative.x * .0026
	pitch = clampf(pitch - relative.y * .0022, -.8, .48)

func _physics_process(dt: float) -> void:
	if not is_instance_valid(game) or not game.playing:
		return
	fire_cooldown = maxf(0, fire_cooldown - dt)
	if reload_time > 0:
		reload_time = maxf(0, reload_time - dt)
		if reload_time == 0:
			var amount := mini(24 - ammo, reserve)
			ammo += amount
			reserve -= amount
	if game.hand.enabled:
		yaw -= hand_aim.x * dt * 1.8
		pitch = clampf(pitch - hand_aim.y * dt * .9, -.8, .48)
	else:
		yaw -= Input.get_axis("look_left", "look_right") * dt * 1.7
		pitch = clampf(pitch - Input.get_axis("look_up", "look_down") * dt, -.8, .48)
	rig.rotation.y = yaw
	rig.position = Vector3(cos(yaw) * .7, 1.5, -sin(yaw) * .7)
	spring.rotation.x = pitch
	var motion := Input.get_vector("left", "right", "forward", "back")
	if game.hand.enabled:
		motion = hand_motion
	var direction := Basis(Vector3.UP, yaw) * Vector3(motion.x, 0, motion.y)
	var sprinting := Input.is_action_pressed("sprint") and motion.length() > .2 and stamina > 0
	var speed := 8.6 if sprinting else 5.2
	stamina = clampf(stamina + (-22 if sprinting else 16) * dt, 0, 100)
	velocity.x = direction.x * speed
	velocity.z = direction.z * speed
	if not is_on_floor():
		velocity.y -= 22 * dt
	elif Input.is_action_just_pressed("jump"):
		velocity.y = 7.2
	move_and_slide()
	position.x = clampf(position.x, -42, 42)
	position.z = clampf(position.z, -42, 42)
	if position.y < -8:
		position = game.map_data.spawn
	var aiming := Input.is_action_pressed("aim") or hand_shoot
	if direction.length() > .1 and not aiming:
		visual.rotation.y = lerp_angle(visual.rotation.y, atan2(-direction.x, -direction.z), dt * 12)
	else:
		visual.rotation.y = lerp_angle(visual.rotation.y, yaw, dt * 12)
	spring.spring_length = lerpf(spring.spring_length, 3.3 if aiming else 5.4, dt * 9)
	camera.fov = lerpf(camera.fov, 57 if aiming else 72, dt * 9)
	walk_time += dt * (13 if sprinting else 9)
	var stride := sin(walk_time) * .65 * motion.length()
	limbs[0].rotation.x = stride
	limbs[2].rotation.x = -stride
	limbs[1].rotation.x = -.65 if aiming else -stride * .5
	limbs[3].rotation.x = -.7
	if Input.is_action_pressed("fire") or hand_shoot:
		shoot()

func reload() -> void:
	if reload_time <= 0 and ammo < 24 and reserve > 0:
		reload_time = 1.65
		game.notice("Đang thay đạn…")

func shoot() -> void:
	if fire_cooldown > 0 or reload_time > 0 or not game.playing:
		return
	if ammo <= 0:
		reload()
		return
	ammo -= 1
	fire_cooldown = .18
	var center := get_viewport().get_visible_rect().size / 2
	var origin := camera.project_ray_origin(center)
	var end := origin + camera.project_ray_normal(center) * 120
	var query := PhysicsRayQueryParameters3D.create(origin, end, 5, [get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	var target: Vector3 = hit.get("position", end)
	# The camera selects the target, but walls between the muzzle and target block the shot.
	var muzzle := global_position + Vector3(0, 1.3, 0) + Basis(Vector3.UP, yaw) * Vector3(.43, 0, -.9)
	var muzzle_query := PhysicsRayQueryParameters3D.create(muzzle, target, 5, [get_rid()])
	var obstruction := get_world_3d().direct_space_state.intersect_ray(muzzle_query)
	if not obstruction.is_empty():
		hit = obstruction
		target = hit.position
	if hit.get("collider") is FieldEnemy:
		var enemy: FieldEnemy = hit.collider
		enemy.take_damage(28, target)
	game.tracer(muzzle, target)
	game.make_noise(global_position)
	game.play_sound("shot")

func hurt(damage: float) -> void:
	if not game.playing:
		return
	health = maxf(0, health - damage)
	game.hud.damage_flash = .5
	if health <= 0:
		game.finish(false)
