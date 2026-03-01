class_name Player
extends CharacterBody3D

var move_speed := 12
var drag := 25
var gravity := 42

const JUMP_VELOCITY := 16

@onready var get_sword_area = $GetSwordArea

@onready var player_input_synchronizer_component: PlayerInputSynchronizerComponent = $PlayerInputSyncronizer
@onready var head: Node3D = $Head
@onready var camera = $Head/Camera3D
@onready var weapon = $Head/Weapon

@onready var animation_player: AnimationPlayer = $AnimationPlayer

@onready var activation_timer = $ActivationTimer

var sword_scene: PackedScene = preload("uid://dyngooikjw5l6")

var mouse_sensitivity := 0.001
var input_multiplayer_authority: int

func _ready():
	animation_player.animation_finished.connect(_on_animation_finished)
	get_sword_area.body_entered.connect(_on_sword_back)
	
	camera.current = (multiplayer.get_unique_id() == input_multiplayer_authority)
	
	player_input_synchronizer_component.set_multiplayer_authority(input_multiplayer_authority)

func _process(delta):
	if player_input_synchronizer_component.is_attack_pressed:
		try_attack()
			
	if player_input_synchronizer_component.is_throw_pressed:
		if !player_input_synchronizer_component.is_disarmed:
			try_throw_sword()
		else:
			try_pull_sword()
	
	if is_multiplayer_authority():
		var movement_vector: Vector2 = player_input_synchronizer_component.movement_vector
		var direction = (transform.basis * Vector3(movement_vector.x, 0, movement_vector.y)).normalized()
		if direction:
			velocity.z = lerpf(direction.z * move_speed, 0, delta * move_speed)
			velocity.x = lerpf(direction.x * move_speed, 0, delta * move_speed)
		else:
			velocity.z = lerpf(velocity.z, 0, delta * drag/4)
			velocity.x = lerpf(velocity.x, 0, delta * drag/4)
			
		if not is_on_floor():
			velocity.y -= gravity * delta
		
		head.rotation.z = lerp_angle(head.rotation.z, -movement_vector.x / drag, delta * 6)
		_rotate_camera()
		
		move_and_slide()
		
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
	if !is_multiplayer_authority(): return
	
	if !activation_timer.is_stopped():
		return
	if !player_input_synchronizer_component.is_disarmed or !player_input_synchronizer_component.thrown_sword:
		return
		
	print("Pulling sword back!")
	player_input_synchronizer_component.thrown_sword.set_state(
		player_input_synchronizer_component.thrown_sword.SwordState.PULLED_BACK
		)

func try_throw_sword():
	if is_multiplayer_authority():
		if player_input_synchronizer_component.is_disarmed:
			return
		
		print("Throwing Sword!")
		var sword = sword_scene.instantiate() as Sword
		
		sword.transform = head.global_transform
		get_parent().add_child(sword, true)
		sword.start(-head.global_transform.basis.z)
		sword.sword_owner = self
		
		player_input_synchronizer_component.is_disarmed = true
		player_input_synchronizer_component.thrown_sword = sword
		activation_timer.start()
	if !is_multiplayer_authority():
		rpc_id(input_multiplayer_authority, "request_server_disarm_switch", true)
		weapon.visible = false

func try_attack():
	if animation_player.current_animation != "attack":
		player_input_synchronizer_component.current_animation = "attack"
		if !is_multiplayer_authority():
			rpc_id(1, "request_server_animation", "attack")
		print("Attacking!")

func try_jump():
	if !is_on_floor():
		return
		
	print("Jumping!")
	velocity.y += JUMP_VELOCITY

func _on_animation_finished(anim_name):
	match anim_name:
		"attack":
			player_input_synchronizer_component.current_animation = "idle"
			if !is_multiplayer_authority():
				rpc_id(1, "request_server_animation", "idle")
		_:
			pass

func _on_sword_back(body):
	var sword: Sword = body.get_parent()
	if sword is Sword and sword.sword_owner == self:
		if is_multiplayer_authority():
			print("REARM SERVER")
			print(input_multiplayer_authority)
			rpc_id(input_multiplayer_authority, "request_server_disarm_switch", false)
			player_input_synchronizer_component.is_disarmed = false
			body.get_parent().register_impact()
			rpc_id(sword.sword_owner.input_multiplayer_authority, "notify_sword_returned")

@rpc("any_peer", "call_local", "reliable")
func request_server_animation(anim_name: String):
	if is_multiplayer_authority():
		player_input_synchronizer_component.current_animation = anim_name

@rpc("any_peer", "call_local", "reliable")
func request_server_disarm_switch(value: bool):
	if is_multiplayer_authority():
		player_input_synchronizer_component.is_disarmed = value

@rpc("any_peer", "call_local", "reliable")
func notify_sword_returned():
	print("Client: server confirmed sword returned")
	weapon.visible = true 
