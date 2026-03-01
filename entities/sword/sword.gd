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
		SwordState.PULLED_BACK:
			global_position = lerp(global_position, sword_owner.head.global_position, 0.1)
		SwordState.STUCK:
			pass

func start(direction) -> void:
	self.direction = direction

func set_state(new_state: SwordState):
	if !is_multiplayer_authority(): return
	state = new_state

func register_impact():
	queue_free()

func _switch_collisions(new_state: SwordState):
	match new_state:
		SwordState.THROWN:
			stuck_collision.disabled = true
			flying_collision.disabled = false
			collision_area.set_collision_layer_value(2, false)
			collision_area.set_collision_layer_value(4, false)
			
		SwordState.PULLED_BACK:
			stuck_collision.disabled = true
			flying_collision.disabled = false
			collision_area.set_collision_mask_value(5, false)
			#collision_area.set_collision_layer_value(4, true)
			collision_area.set_collision_layer_value(2, false)
			collision_area.set_collision_mask_value(3, true)
			
		SwordState.STUCK:
			stuck_collision.disabled = false
			flying_collision.disabled = true
			collision_area.set_collision_layer_value(2, true)
			collision_area.set_collision_layer_value(4, false)

func _on_sword_impact(body):
	if body is Player and state == SwordState.PULLED_BACK:
		print("Sword hit player")
		if sword_owner == body:
			print(sword_owner)
			collision_area.set_collision_layer_value(4, true)
		return
	
	if !is_multiplayer_authority(): return
			
	var collision_result: KinematicCollision3D = collision_area.move_and_collide(global_position)
	if collision_result:
		var normal = collision_result.get_normal()
		var pos = collision_result.get_position()
		print(pos)
		global_position = pos + normal * 0.1
		look_at(global_position + normal)
	
	#print("-----> Thrown sword hit something!")
	#print("-----> Should STUCK!")
	set_state(SwordState.STUCK)
