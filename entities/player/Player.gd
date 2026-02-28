class_name Player
extends CharacterBody3D

var move_speed := 12
var drag := 25
var gravity := 42

const JUMP_VELOCITY := 16

@onready var player_input_synchronizer_component: PlayerInputSynchronizerComponent = $PlayerInputSyncronizer
@onready var head: Node3D = $Head
@onready var camera = $Head/Camera3D
@onready var weapon = $Head/Weapon

@onready var animation_player: AnimationPlayer = $AnimationPlayer

@onready var activation_timer = $ActivationTimer

var sword_scene: PackedScene = preload("uid://dyngooikjw5l6")

var mouse_sensitivity := 0.002
var input_multiplayer_authority: int

func _ready():
	animation_player.animation_finished.connect(_on_animation_finished)
	camera.current = (multiplayer.get_unique_id() == input_multiplayer_authority)
	
	player_input_synchronizer_component.set_multiplayer_authority(input_multiplayer_authority)

func _process(delta):
	if player_input_synchronizer_component.is_attack_pressed:
		try_attack()
		
	if is_multiplayer_authority():
		var movement_vector: Vector2 = player_input_synchronizer_component.movement_vector
		var direction = (transform.basis * Vector3(movement_vector.x, 0, movement_vector.y)).normalized()
		if direction:
			#velocity = lerp(velocity,
				#Vector3(direction.x * move_speed, direction.y, direction.z * move_speed),
				#delta * drag)
			velocity.z = lerpf(direction.z * move_speed, 0, delta * move_speed)
			velocity.x = lerpf(direction.x * move_speed, 0, delta * move_speed)
		else:
			#velocity = lerp(velocity, Vector3(0, velocity.y, 0), delta * drag)
			velocity.z = lerpf(velocity.z, 0, delta * drag/4)
			velocity.x = lerpf(velocity.x, 0, delta * drag/4)
			
		if not is_on_floor():
			velocity.y -= gravity * delta
		
		head.rotation.z = lerp_angle(head.rotation.z, -movement_vector.x / drag, delta * 6)
		_rotate_camera()
		
		move_and_slide()
		
		if player_input_synchronizer_component.is_throw_pressed:
			if !player_input_synchronizer_component.is_disarmed:
				try_throw_sword()
			else:
				try_pull_sword()
		
		if player_input_synchronizer_component.is_jump_pressed:
			try_jump()

func _rotate_camera():
	var movement_vector = player_input_synchronizer_component.movement_vector
	
	if player_input_synchronizer_component.input_mouse:
		rotate_y(-player_input_synchronizer_component.input_mouse.x * mouse_sensitivity)
		head.rotate_x(-player_input_synchronizer_component.input_mouse.y * mouse_sensitivity)
		head.rotation.x = clamp(head.rotation.x, deg_to_rad(-80), deg_to_rad(80))
		head.rotation.z = clamp(head.rotation.z, -deg_to_rad(50), deg_to_rad(50))
	
	#player_input_synchronizer_component.input_mouse = Vector2.ZERO

func _input(event):
	if Input.is_action_just_pressed("click"):
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	
	if Input.is_action_just_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func release_mouse_mode():
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func try_pull_sword():
	if !activation_timer.is_stopped():
		return
	if !player_input_synchronizer_component.is_disarmed or !player_input_synchronizer_component.thrown_sword:
		return
		
	print("Pulling sword back!")
	player_input_synchronizer_component.thrown_sword.set_state(
		player_input_synchronizer_component.thrown_sword.SwordState.PULLED_BACK
		)

func try_throw_sword():
	if player_input_synchronizer_component.is_disarmed:
		return
	
	print("Throwing Sword!")
	var sword = sword_scene.instantiate() as Sword
	
	sword.transform = head.global_transform
	get_parent().add_child(sword, true)
	sword.sword_owner = self
	sword.start(-head.global_transform.basis.z)
	
	player_input_synchronizer_component.thrown_sword = sword
	player_input_synchronizer_component.is_disarmed = true
	activation_timer.start()

func try_attack():
	if animation_player.is_playing() and player_input_synchronizer_component.current_animation == "attack":
		return
	
	print("Attacking!")
	if is_multiplayer_authority():
		print(is_multiplayer_authority())
		player_input_synchronizer_component.current_animation = "attack"
	else:
		print(input_multiplayer_authority)
		rpc_id(1, "request_server_animation", "attack")
		animation_player.play("attack")

func try_jump():
	if !is_on_floor():
		return
		
	print("Jumping!")
	velocity.y += JUMP_VELOCITY

@rpc("any_peer", "reliable")
func request_server_animation(anim_name: String):
	if is_multiplayer_authority():
		player_input_synchronizer_component.current_animation = anim_name

func _on_animation_finished(anim_name):
	match anim_name:
		"attack":
			if is_multiplayer_authority():
				player_input_synchronizer_component.current_animation = "idle"
			else:
				rpc_id(1, "request_server_animation", "idle")
				animation_player.play("idle")
		_:
			pass
