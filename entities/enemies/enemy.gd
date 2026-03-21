class_name Enemy
extends RigidBody3D

var max_health: int
var current_health: int

@onready var anim_player = $AnimationPlayer
@onready var sight_area = $SightArea

@onready var nav_agent = $NavigationAgent3D
@export var target: CharacterBody3D
@export var move_speed: float = 3.0

var player_in_sight_area : bool = false


var current_state : EnemyState = EnemyState.IDLE
enum EnemyState {
	IDLE,
	CHASE,
	HIT,
	ATTACKING,
	DEAD,
}

@onready var sword_collision_area = $SwordCollisionArea
var blood_particles_scene = preload("uid://dauurgt5mibfk")

func _ready():
	sword_collision_area.body_entered.connect(_on_sword_entered)
	sight_area.body_entered.connect(_on_sight_area_body_entered)
	sight_area.body_exited.connect(_on_sight_area_body_exited)

func _process(delta):
	pass

func _physics_process(delta):
	match current_state:
		EnemyState.IDLE:
			if player_in_sight_area:
				sight_area.monitoring = false
				sight_area.monitoring = true
		
		EnemyState.CHASE:
			nav_agent.target_position = target.position
			var next_path_pos: Vector3 = nav_agent.get_next_path_position()
			var direction := global_position.direction_to(next_path_pos)
			linear_velocity = direction * move_speed
			var rotation_speed = 4
			var target_rotation := direction.signed_angle_to(Vector3.MODEL_FRONT, Vector3.DOWN)
			if abs(target_rotation - rotation.y) > deg_to_rad(60):
				rotation_speed = 20
				
			rotation.y = move_toward(rotation.y, target_rotation, delta * rotation_speed)
			if nav_agent.is_navigation_finished():
				linear_velocity = Vector3.ZERO
				set_current_state(EnemyState.ATTACKING)
	
		EnemyState.HIT:
			pass
		
		EnemyState.ATTACKING:
			pass
		
		EnemyState.DEAD:
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


func set_current_state(new_state):
	match new_state:
		EnemyState.IDLE:
			nav_agent = null
			anim_player.play("idle")
		
		EnemyState.CHASE:
			nav_agent = $NavigationAgent3D
			anim_player.play("chase")
	
		EnemyState.HIT:
			nav_agent = null
			anim_player.play("hit")
		
		EnemyState.ATTACKING:
			nav_agent = null
			anim_player.play("attack")
		
		EnemyState.DEAD:
			pass
	
	current_state = new_state

func finished_attacking():
	set_current_state(EnemyState.CHASE)

func finished_get_hit():
	set_current_state(EnemyState.CHASE)


func _on_sight_area_body_entered(body):
	if body == target:
		player_in_sight_area = true
		
		var space_state = get_world_3d().direct_space_state
		
		var from = global_position + Vector3(0, 1.5, 0)
		var to = body.global_position + Vector3(0, 1.5, 0)
		
		var ray_params = PhysicsRayQueryParameters3D.create(from, to)
		ray_params.exclude = [self, body]
		ray_params.collision_mask = 1
		
		var result = space_state.intersect_ray(ray_params)
		
		if result.is_empty():
			set_current_state(EnemyState.CHASE)


func _on_sight_area_body_exited(body):
	if body == target:
		player_in_sight_area = false
