class_name Player
extends CharacterBody3D

var move_speed := 12
var drag := 25
var gravity := 42

const JUMP_VELOCITY := 16

@onready var get_sword_area = $GetSwordArea
@onready var sword_hit_area = $SwordHitArea

#@onready var player_input_synchronizer_component: PlayerInputSynchronizerComponent = $PlayerInputSyncronizer
#@onready var player_state_synchronizer = $MultiplayerSynchronizer

@onready var head: Node3D = $Head
@onready var camera = $Head/Camera3D
@onready var weapon = $Head/Weapon
@onready var muzzle = $Head/Cannon/Muzzle

@onready var animation_player: AnimationPlayer = $AnimationPlayer

@onready var activation_timer = $ActivationTimer

var mouse_sensitivity := 0.001
var input_mouse: Vector2
#var input_multiplayer_authority: int
var movement_vector: Vector2

var sword_scene: PackedScene = preload("uid://dyngooikjw5l6")
var projectile_scene: PackedScene = preload("uid://cdu40asu3x8p7")

var is_blocking: bool
var is_disarmed: bool
var thrown_sword: Sword

func _ready():
	animation_player.animation_finished.connect(_on_animation_finished)
	get_sword_area.body_entered.connect(_on_sword_back)
	
	#camera.current = (multiplayer.get_unique_id() == input_multiplayer_authority)
	#player_input_synchronizer_component.set_multiplayer_authority(input_multiplayer_authority)

func _process(delta):
	_rotate_camera()

func _physics_process(delta):
	movement_vector = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction = (transform.basis * Vector3(movement_vector.x, 0, movement_vector.y)).normalized()
	if movement_vector:
		velocity.z = lerpf(direction.z * move_speed, 0, delta * move_speed)
		velocity.x = lerpf(direction.x * move_speed, 0, delta * move_speed)
	else:
		velocity.z = move_toward(velocity.z, 0, delta * (drag * 4))
		velocity.x = move_toward(velocity.x, 0, delta * (drag * 4))
		
	if not is_on_floor():
		velocity.y -= gravity * delta
	
	head.rotation.z = lerp_angle(head.rotation.z, -movement_vector.x / drag, delta * 6)
	
	move_and_slide()

func _rotate_camera():
	if input_mouse:
		rotate_y(-input_mouse.x * mouse_sensitivity)
		head.rotate_x(-input_mouse.y * mouse_sensitivity)
		
	head.rotation.x = clamp(head.rotation.x, deg_to_rad(-70), deg_to_rad(60))
	head.rotation.z = clamp(head.rotation.z, -deg_to_rad(50), deg_to_rad(50))
	head.rotation.y = clamp(head.rotation.y, deg_to_rad(0), deg_to_rad(0))
	input_mouse = Vector2.ZERO

func _unhandled_input(event):
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		input_mouse = event.relative
		
func _input(event):
		
	if Input.is_action_just_pressed("click"):
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	
	if Input.is_action_just_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		
	if Input.is_action_just_pressed("attack"):
		try_attack()
	
	if Input.is_action_just_pressed("fire"):
		try_fire()
	
	if Input.is_action_just_pressed("block"):
		if !is_blocking:
			try_block()
		
	if Input.is_action_just_released("block"):
		release_block()
		
	if Input.is_action_just_pressed("throw_sword"): 
		if !is_disarmed:
			try_throw_sword()
		else:
			try_pull_sword()
		
	if Input.is_action_just_pressed("jump"):
		try_jump()

func release_mouse_mode():
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func try_pull_sword():
	if !activation_timer.is_stopped():
		return
	if !is_disarmed or !thrown_sword:
		return
		
	print("Pulling sword back!")
	thrown_sword.set_state(thrown_sword.SwordState.PULLED_BACK)

func try_throw_sword():
	if is_disarmed:
		return
	
	print("Throwing Sword!")
	var sword = sword_scene.instantiate() as Sword
	
	sword.transform = head.global_transform
	get_parent().add_child(sword, true)
	sword.start(-head.global_transform.basis.z)
	sword.sword_owner = self
	
	is_disarmed = true
	thrown_sword = sword
	activation_timer.start()
	
	weapon.visible = false

func try_attack():
	if animation_player.current_animation != "attack":
		animation_player.play("attack")
		print("Attacking!")

func try_fire():
	if animation_player.current_animation != "fire":
		var projectile = projectile_scene.instantiate() as Projectile
		projectile.transform = muzzle.global_transform
		get_parent().add_child(projectile, true)
		projectile.start(-head.global_transform.basis.z)
		animation_player.play("fire")
		# TODO: Instantiate projectiles
		print("Firing gun!")

func try_block():
	if animation_player.current_animation == "idle":
		animation_player.play("block")
		print("Blocking!")
	
	is_blocking = true

func release_block():
	#if animation_player.current_animation == "block":
	animation_player.play("idle")
	print("Stopped blocking!")
		
	is_blocking = false

func try_jump():
	if !is_on_floor():
		return
		
	print("Jumping!")
	velocity.y += JUMP_VELOCITY

func _on_animation_finished(anim_name):
	match anim_name:
		"attack":
			animation_player.play("idle")
		_:
			pass

func _on_sword_hit():
	print(sword_hit_area.collision_result)
	if sword_hit_area.collision_result:
		if sword_hit_area.collision_result[0].collider is Enemy:
			print("Enemy hit")
			var enemy = sword_hit_area.collision_result[0].collider as Enemy
			enemy.spawn_blood(sword_hit_area.collision_result[0].point)
	print("Sword Hit time")
	pass

func _on_sword_back(body):
	var sword: Sword = body.get_parent()
	if sword is Sword and sword.sword_owner == self:
		is_disarmed = false
		body.get_parent().register_impact()
		weapon.visible = true
