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

@onready var sword_model = $sword

var state = SwordState.THROWN

var speed: int = 35
var direction: Vector3
var damage: float = 25.0

var is_on_button: bool 
var pressed_button: SwordButton
var sword_owner: Player

func _ready():
	collision_area.body_entered.connect(_on_sword_impact)

func _process(delta):
	match state:
		SwordState.THROWN:
			global_position += direction * speed * delta
		SwordState.PULLED_BACK:
			global_position = lerp(global_position, sword_owner.head.global_position, 0.1)
		SwordState.STUCK:
			pass

func start(dir) -> void:
	direction = dir

func set_state(new_state: SwordState):
	match new_state:
		SwordState.THROWN:
			stuck_collision.disabled = true
			flying_collision.disabled = false
			collision_area.set_collision_layer_value(2, false)
			collision_area.set_collision_layer_value(4, false)
			collision_area.set_collision_layer_value(10, false)
			
		SwordState.PULLED_BACK:
			stuck_collision.disabled = true
			flying_collision.disabled = false
			collision_area.set_collision_mask_value(5, false)
			collision_area.set_collision_layer_value(2, false)
			collision_area.set_collision_layer_value(4, true)
			collision_area.set_collision_layer_value(10, false)
			if is_on_button:
				pressed_button.set_state(pressed_button.button_states.UNPRESSED)
				pressed_button = null
				is_on_button = false
			
			animation_player.play("flying")
			
		SwordState.STUCK:
			stuck_collision.disabled = false
			flying_collision.disabled = true
			collision_area.set_collision_layer_value(2, true)
			collision_area.set_collision_layer_value(4, false)
			collision_area.set_collision_layer_value(10, true)
			
			animation_player.play("stuck")
		
	state = new_state

func register_impact():
	queue_free()

func _on_sword_impact(body):
	if body is Player and state == SwordState.PULLED_BACK:
		print("Sword collided player")
		if sword_owner == body:
			print(sword_owner)
			collision_area.set_collision_layer_value(4, true)
		return
	
	var collision_result: KinematicCollision3D = collision_area.move_and_collide(global_position)
	if collision_result:
		var collision_parent = collision_result.get_collider().get_parent()
		if collision_parent is SwordButton: #abre as portas linkadas nos botões
			print("parent detected")
			collision_parent.set_state(collision_parent.button_states.PRESSED)
			is_on_button = true
			pressed_button = collision_parent
		else:
			print("no parent detected")
		var collision_normal = collision_result.get_normal()
		var collision_pos = collision_result.get_position()
		print(collision_pos)
		print(collision_result.get_collider())
		global_position = collision_pos + collision_normal
		look_at(global_position + collision_normal)
		#sword_model.look_at(collision_pos)
		sword_model.transform = stuck_collision.transform
		sword_model.rotate_z(deg_to_rad(90))
	
	#print("-----> Thrown sword hit something!")
	#print("-----> Should STUCK!")
	call_deferred("set_state", SwordState.STUCK)

#func _on_sword_area_impact(area):
	#if area is Enemy:
		#match state:
			#SwordState.THROWN:
				#var tween = get_tree().create_tween()
				#tween.tween_property(sword_owner, "global_position", global_position, 0.16)
				#speed = 0
				#print("Throw hit enemy!")
				#set_state(SwordState.PULLED_BACK)
			#SwordState.PULLED_BACK:
				## TODO: Deal damage
				#print("Sword hit enemy on way back")
		#return
