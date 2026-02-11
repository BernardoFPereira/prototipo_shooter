extends CharacterBody3D

@onready var camera = $Head/Camera
@onready var container = $Head/Camera/WeaponContainer
@onready var raycast = $Head/Camera/RayCast3D
@onready var head = $Head
@onready var interact_text = $"../HUD/InteractText"
@onready var stand_collision = $StandCollision
@onready var crouch_collision = $CrouchCollision

@export_subgroup("Properties")
@export var move_speed := 10
@export var jump_strength := 300
@export var crouch_amount := 30
@export var crosshair: TextureRect

@export_subgroup("Weapons")
@export var weapons: Array[Weapon] = []
var weapon: Weapon
var weapon_index := 0

var std_gravity = ProjectSettings.get_setting("physics/3d/default_gravity")
var gravity = std_gravity
var mouse_sensitivity = 0.002
var weapon_offset = Vector3(0.2, -0.2, -0.1)
var movement_velocity: Vector3


var input_mouse: Vector2
var mouse_captured

var can_pickup := [false, null, null]

func _ready():
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	weapon = weapons[weapon_index]
	
	if weapon.model:
		var weapon_model = weapon.model.instantiate()
		container.add_child(weapon_model)
	
	#weapon_model.transform = weapon.transform
	#weapon_model.rotation_degrees = weapon.rotation
	if weapon.crosshair:
		crosshair.texture = weapon.crosshair

func _physics_process(delta):
	var applied_velocity: Vector3
	
	handle_controls(delta)
	
	movement_velocity = transform.basis * movement_velocity
	applied_velocity = velocity.lerp(movement_velocity, delta * 5)
	
	if !is_on_floor():
		gravity += 1.5
		applied_velocity.y -= gravity * delta
	elif gravity != std_gravity:
		gravity = std_gravity
		
	velocity = applied_velocity
	move_and_slide()
	
	container.position = lerp(container.position, weapon_offset - (basis.inverse() * applied_velocity / 80), delta * 10)
	
	head.rotation.z = lerp_angle(head.rotation.z, -input_mouse.x * delta, delta * 5) / 2
	
	# Falling/respawning
	if position.y < -10:
		get_tree().reload_current_scene()
	
func _input(event):
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		input_mouse = event.relative
		
		rotate_y(-input_mouse.x * mouse_sensitivity)
		camera.rotate_x(-input_mouse.y * mouse_sensitivity)
		camera.rotation.x = clamp(camera.rotation.x, deg_to_rad(-80), deg_to_rad(80))
		
		head.rotation.z = clamp(head.rotation.z, -deg_to_rad(50), deg_to_rad(50))
		
	if event.is_action_pressed("click"):
		action_shoot()
		
	if event.is_action_pressed("weapon_switch"):
		weapon_toggle()
		
	if event.is_action_pressed("weapon_drop"):
		action_drop_weapon()
	
func handle_controls(delta):
	if Input.is_action_just_pressed("click") and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		mouse_captured = true
	
	if Input.is_action_just_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		mouse_captured = false
		
		input_mouse = Vector2.ZERO
	
	var input = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	movement_velocity = Vector3(input.x, 0, input.y).normalized() * move_speed
	
	# Jump
	if Input.is_action_just_pressed("jump") and is_on_floor():
		movement_velocity.y += jump_strength
		
	# Interact (So far is just 'Pick Up Weapon')
	if can_pickup[0] and Input.is_action_just_pressed("interact"):
		#var is_unnarmed: bool
		
		action_drop_weapon()
		action_pickup_weapon(can_pickup[1])
		can_pickup[2].queue_free()
	
	if Input.is_action_just_pressed("crouch"):
		#can_crouch = true
		action_crouch(delta)
	
	if Input.is_action_just_released("crouch"):
		#can_stand = true
		action_stand(delta)
	
func action_crouch(delta):
	#var target_head_pos = Vector3(0, camera.global_position.y - 30, 0)
	
	move_speed /= 2
	head.position = lerp(head.position, head.position + Vector3(0, -0.7, 0), delta)
	stand_collision.disabled = true
	crouch_collision.disabled = false
	
func action_stand(delta):
	#var target_head_pos = Vector3(0, camera.global_position.y + 30, 0)
	
	move_speed *= 2
	head.global_translate(Vector3(0, +0.7, 0))
	stand_collision.disabled = false
	crouch_collision.disabled = true

func action_shoot():
	# Weapon knockback
	container.position.z += weapon.knockback * 0.1
	#var preshot_rotation = camera.rotation.x
	camera.rotation.x += weapon.knockback * 0.01

	# Particle spawn with shot. Kinda works, but it's sketchy
	#var muzzle: Marker3D
	#for c in container.get_children(true):
		#muzzle = c.get_child(-1)
	#var particle = preload("res://pew_particle.tscn")
	#var particle_inst = particle.instantiate()
	#particle_inst.transform = muzzle.global_transform
	#particle_inst.emitting = true
	#get_tree().root.add_child(particle_inst)
	
	for n in weapon.shot_count:
		raycast.target_position.x = randf_range(-weapon.spread, weapon.spread)
		raycast.target_position.y = randf_range(-weapon.spread, weapon.spread)
		raycast.force_raycast_update()
		
		if !raycast.is_colliding():
			return
		
		var collider = raycast.get_collider()
		
		if collider.has_method("damage"):
			collider.damage(weapon.damage)
		
		var impact = preload("res://impact.tscn")
		var impact_instance = impact.instantiate()
		impact_instance.play("shot")
		get_tree().root.add_child(impact_instance)
		
		impact_instance.position = raycast.get_collision_point() + (raycast.get_collision_normal() / 10)
		impact_instance.look_at(camera.global_transform.origin, Vector3.UP, true)
	
func weapon_toggle():
	if Input.is_action_just_pressed("weapon_switch"):
		weapon_index = wrap(weapon_index + 1, 0, weapons.size())
		initiate_weapon_toggle(weapon_index)

func initiate_weapon_toggle(index: int):
	weapon_index = index
	toggle_weapon()

func toggle_weapon():
	weapon = weapons[weapon_index]
	
	for n in container.get_children():
		container.remove_child(n)
		
	var weapon_model = weapon.model.instantiate()
	container.add_child(weapon_model)
	
	raycast.target_position = Vector3(0, 0, -1) * weapon.max_distance
	crosshair.texture = weapon.crosshair

func action_drop_weapon():
	var weapon_scene = weapon.model.instantiate()
	weapon_scene.position = position + Vector3(0, 1.3, 0) * transform.basis
	weapon_scene.rotation.x = -90
	
	for rigidbody: RigidBody3D in weapon_scene.find_children("*", "RigidBody3D", true):
		rigidbody.freeze = false
		rigidbody.apply_impulse(transform.basis * Vector3.FORWARD * 3)
		rigidbody.apply_torque_impulse(Vector3(100,100,100))
	
	get_tree().root.add_child.call_deferred(weapon_scene,true)
	
	var unnarmed = preload("res://weapons/unnarmed.tres")
	weapons[weapon_index] = unnarmed
	toggle_weapon()

func action_pickup_weapon(weapon_to_pick):
	weapons[weapon_index] = weapon_to_pick
	toggle_weapon()

func action_jump():
	pass

func _on_area_3d_body_entered(body: RigidBody3D):
	var parent = body.owner
	var weapon_name: String = parent.owner.name.to_lower().rstrip("0123456789")
	var pretty_name: String
	
	if "_" in weapon_name:
		var split_name = weapon_name.split("_")
		var first_name = split_name[0].to_pascal_case()
		var second_name = split_name[1].to_pascal_case()
		
		pretty_name = first_name + " " + second_name
	else:
		pretty_name = weapon_name.to_pascal_case()
		
	interact_text.text = "Press E to pick up " + pretty_name
	interact_text.show()
	
	var weapon_to_pick = load("res://weapons/" + weapon_name + ".tres")
	
	can_pickup = [true, weapon_to_pick, parent]
	
func _on_area_3d_body_exited(_body: RigidBody3D):
	interact_text.hide()
	interact_text.text = "Press E to pick up "
	
	can_pickup = [false, null, null]
