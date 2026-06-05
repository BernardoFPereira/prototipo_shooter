class_name Sword
extends Node3D

enum SwordState {
	THROWN,
	PULLED_BACK,
	STUCK,
}

@onready var animation_player = $AnimationPlayer
@onready var collision_area = $CollisionArea
#@onready var stuck_collision = $CollisionArea/StuckCollision
@onready var flying_collision = $CollisionArea/FlyingCollision

@onready var sword_model = $ArmProjectile
@onready var impact_particles = $ArmProjectile/Armature/Impact

@onready var flying_sfx = $SFX/Flying
@onready var impact_sfx = $SFX/Impact

#var state = SwordState.THROWN
var state: SwordState

var speed: int = 35
var direction: Vector3
var damage: float = 25.0

var is_on_button: bool 
var pressed_button: SwordButton
var sword_owner: Player

#func _ready():
	#collision_area.body_entered.connect(_on_sword_impact)

func _physics_process(delta):
	match state:
		SwordState.THROWN:
			global_position += direction * speed * delta
			# Calculate how far it SHOULD move this physics frame
			var velocity_vector = direction * speed * delta
			
			# Move via physics and check for an immediate impact
			var collision_result = collision_area.move_and_collide(velocity_vector)
			
			#global_position = collision_area.global_position
			#collision_area.position = Vector3.ZERO
			
			if collision_result:
				_on_sword_impact(collision_result)
				
		SwordState.PULLED_BACK:
			global_position = lerp(global_position, sword_owner.head.global_position, 0.3)
		SwordState.STUCK:
			pass

func start(player: Player, dir: Vector3) -> void:
	print(direction)
	sword_owner = player
	direction = dir
	set_as_top_level(true)
	print(direction)
	set_state(SwordState.THROWN)

func set_state(new_state: SwordState):
	match new_state:
		SwordState.THROWN:
			#if sword_owner:
				#collision_area.add_collision_exception_with(sword_owner)
			#stuck_collision.disabled = true
			flying_collision.disabled = false
			collision_area.set_collision_layer_value(2, false)
			collision_area.set_collision_layer_value(4, false)
			collision_area.set_collision_layer_value(10, false)
			flying_sfx.play()
			
		SwordState.PULLED_BACK:
			#if sword_owner:
				#collision_area.remove_collision_exception_with(sword_owner)
			#stuck_collision.disabled = true
			flying_collision.disabled = false
			collision_area.set_collision_mask_value(5, false)
			collision_area.set_collision_layer_value(2, false)
			collision_area.set_collision_layer_value(4, true)
			collision_area.set_collision_layer_value(10, false)
			flying_sfx.play()
			if is_on_button:
				pressed_button.set_state(pressed_button.button_states.UNPRESSED)
				pressed_button = null
				is_on_button = false
				pressed_button
			
			animation_player.play("flying")
			
		SwordState.STUCK:
			#stuck_collision.disabled = false
			flying_collision.disabled = true
			collision_area.set_collision_layer_value(2, true)
			collision_area.set_collision_layer_value(4, false)
			collision_area.set_collision_layer_value(10, true)
			impact_sfx.play()
			flying_sfx.stop()
			
			animation_player.play("stuck")
		
	state = new_state

func register_impact():
	queue_free()

func _on_sword_impact(result: KinematicCollision3D):
	# 1. Handle player interaction (if pulling back)
	var collider = result.get_collider()
	if collider is Player and state == SwordState.PULLED_BACK:
		if sword_owner == collider:
			collision_area.set_collision_layer_value(4, true)
			flying_sfx.stop()
		return

	# 2. Logic for Buttons/Environment
	var collision_parent = collider.get_parent()
	if collision_parent is SwordButton:
		collision_parent.set_state(collision_parent.button_states.PRESSED)
		is_on_button = true
		pressed_button = collision_parent

	# 3. Positioning (No extra move_and_collide needed!)
	var collision_normal = result.get_normal()
	var collision_pos = result.get_position()
	
	global_position = collision_pos + (collision_normal * 0.2)
	
	# 4. Bulletproof Rotation
	# Use Up Vector if hitting a wall, use Forward if hitting the floor/ceiling
	var up_vector = Vector3.UP
	if abs(collision_normal.dot(Vector3.UP)) > 0.9:
		up_vector = Vector3.FORWARD
		
	look_at(global_position + collision_normal, up_vector)
	
	# 5. Trigger visuals immediately
	impact_particles.emitting = true
	
	# 6. Set state to STUCK
	set_state(SwordState.STUCK)

#func _on_sword_impact(result: KinematicCollision3D):
	#var collider = result.get_collider()
	#if collider is Player and state == SwordState.PULLED_BACK:
		#if sword_owner == collider:
			#collision_area.set_collision_layer_value(4, true)
		#return
		#
	#var forward_motion = -global_transform.basis.z * 0.5
	#var collision_result: KinematicCollision3D = collision_area.move_and_collide(forward_motion)
	#if collision_result:
		#var collision_parent = collision_result.get_collider().get_parent()
		#if collision_parent is SwordButton: # Checa se o pai do objeto colidido é um Botao
			#print("parent detected")
			#collision_parent.set_state(collision_parent.button_states.PRESSED)
			#is_on_button = true
			#pressed_button = collision_parent
		#else:
			#print("no parent detected")
		#var collision_normal = collision_result.get_normal()
		#var collision_pos = collision_result.get_position()
		#
		#print(collision_pos)
		#print(collision_result.get_collider())
		#
		#global_position = collision_pos + (collision_normal / 4)
		#look_at(global_position + collision_normal)
		#impact_particles.emitting = true
		
		#sword_model.look_at(collision_pos)
		#sword_model.transform = flying_collision.transform
		#sword_model.rotate_z(deg_to_rad(90))
	
	#print("-----> Thrown sword hit something!")
	#print("-----> Should STUCK!")
	call_deferred("set_state", SwordState.STUCK)

