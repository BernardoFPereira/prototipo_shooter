class_name Enemy
extends RigidBody3D

var max_health: int
var current_health: int

enum EnemyState {
	IDLE,
	CHASE,
	DEAD,
}

@onready var sword_collision_area = $SwordCollisionArea
var blood_particles_scene = preload("uid://dauurgt5mibfk")

func _ready():
	sword_collision_area.body_entered.connect(_on_sword_entered)

func _process(delta):
	pass

func deal_damage(amount: int):
	current_health -= clampi(current_health, 0, max_health)
	pass

func spawn_blood(position: Vector3):
	var blood_particles: GPUParticles3D = blood_particles_scene.instantiate()
	blood_particles.emitting = true
	get_tree().root.add_child(blood_particles)
	blood_particles.global_position = position

func _on_sword_entered(body):
	if body.get_parent() is Sword:
		var sword = body.get_parent() as Sword
		spawn_blood(sword.global_position)
		
		match sword.state:
			sword.SwordState.THROWN:
				var tween = get_tree().create_tween()
				tween.tween_property(sword.sword_owner, "global_position", sword.global_position, 0.16)
				sword.speed = 0
				print("Throw hit enemy!")
				sword.set_state(sword.SwordState.PULLED_BACK)
			sword.SwordState.PULLED_BACK:
				# TODO: Deal damage
				print("Sword hit enemy on way back")
		
