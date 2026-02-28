class_name Sword
extends Node3D

enum SwordState {
	THROWN,
	PULLED_BACK,
	STUCK,
}

@onready var animation_player = $AnimationPlayer
@onready var collision_area = $CollisionArea
@onready var stuck_collision = $CollisionArea/StuckCollision
@onready var flying_collision = $CollisionArea/FlyingCollision

var state = SwordState.THROWN :
	set(value):
		state = value
		match value:
			SwordState.THROWN:
				call_deferred("_switch_collisions", value)
			SwordState.PULLED_BACK:
				call_deferred("_switch_collisions", value)
				animation_player.play("flying")
			SwordState.STUCK:
				animation_player.play("stuck")
				call_deferred("_switch_collisions", value)

var speed: int = 35
var direction: Vector3

var sword_owner: Player

func _ready():
	collision_area.body_entered.connect(_on_sword_impact)

func _process(delta):
	if !is_multiplayer_authority(): return
	match state:
		SwordState.THROWN:
			global_position += direction * speed * delta
			var collision_result: KinematicCollision3D = collision_area.move_and_collide(global_position)
			if collision_result:
				var collision_pos = collision_result.get_position()
				print(collision_pos)
		SwordState.PULLED_BACK:
			global_position = lerp(global_position, sword_owner.head.global_position, 0.1)
		SwordState.STUCK:
			pass

func start(direction) -> void:
	self.direction = direction

func set_state(new_state: SwordState):
	if !is_multiplayer_authority(): return
	
	#match new_state:
		#SwordState.THROWN:
			#call_deferred("_switch_collisions", new_state)
		#SwordState.PULLED_BACK:
			#call_deferred("_switch_collisions", new_state)
			#animation_player.play("flying")
		#SwordState.STUCK:
			#animation_player.play("stuck")
			#call_deferred("_switch_collisions", new_state)
		
	state = new_state

func _switch_collisions(new_state: SwordState):
	match new_state:
		SwordState.THROWN:
			stuck_collision.disabled = true
			flying_collision.disabled = false
			collision_area.set_collision_mask_value(2, false)
			collision_area.set_collision_mask_value(3, false)
			collision_area.freeze = false
			
		SwordState.PULLED_BACK:
			stuck_collision.disabled = true
			flying_collision.disabled = false
			collision_area.set_collision_mask_value(5, false)
			collision_area.set_collision_mask_value(2, false)
			collision_area.set_collision_mask_value(3, true)
			collision_area.freeze = false
			
		SwordState.STUCK:
			stuck_collision.disabled = false
			flying_collision.disabled = true
			collision_area.set_collision_mask_value(2, true)
			collision_area.set_collision_mask_value(3, false)
			collision_area.freeze = true

func _on_sword_impact(body):
	if !is_multiplayer_authority(): return
	
	if body is Player and state == SwordState.PULLED_BACK:
		if sword_owner == body:
			sword_owner.player_input_synchronizer_component.is_disarmed = false
			#sword_owner.player_input_synchronizer_component.is_weapon_visible = true
			#sword_owner.weapon.show()
			call_deferred("queue_free")
			return
		else:
			return
	
	print("-----> Thrown sword hit something!")
	print("-----> Should STUCK!")
	set_state(SwordState.STUCK)

