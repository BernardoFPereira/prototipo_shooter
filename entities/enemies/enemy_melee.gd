class_name EnemyMelee
extends RigidBody3D


@onready var anim_player = $AnimationPlayer
@onready var sight_area = $SightArea
@onready var sight_collision = $SightArea/SightCollision
@onready var sword_collision_area = $SwordCollisionArea
@onready var sword_hit_collision = $SwordCollisionArea/SwordHitCollision
@onready var nav_agent = $NavigationAgent3D
@onready var attack_collision = $Armature/Skeleton3D/BoneAttachment3D/AttackArea/AttackCollision
@onready var ground_raycast = $GroundRaycast

var player_in_sight_area: bool = false

var blood_particles_scene = preload("uid://dauurgt5mibfk")

@export_category("Targets")
var has_target: bool
@export var target: CharacterBody3D
@export var patrol_route: PathFollow3D

@export_category("Combat Properties")
var current_health: float
@export var max_health: float = 100
@export var attack_range: float = 2
@export var attack_damage: int = 55

@export_category("Movement Properties")
var is_floating: bool
@export var patrol_speed: float = 2.0
@export var chase_speed: float = 6.0
@export var rotation_speed: float = 5.0


var current_state : EnemyState = EnemyState.IDLE
enum EnemyState {
	IDLE,
	PATROLLING,
	CHASING,
	HIT,
	ATTACKING,
	DEAD,
}

func _ready():
	sword_collision_area.body_entered.connect(_on_sword_entered)
	sight_area.body_entered.connect(_on_sight_area_body_entered)
	sight_area.body_exited.connect(_on_sight_area_body_exited)

	current_health = max_health

func _process(delta):
	pass
	
func _physics_process(delta):
	
	var pos2d = Vector2(global_position.x, global_position.z)
	var target_pos2d = Vector2(target.global_position.x, target.global_position.z)
	var rotation_direction = -(pos2d - target_pos2d)
	
	
	match current_state:
		EnemyState.IDLE:
			if patrol_route != null:
				set_current_state(EnemyState.PATROLLING)
				
			if player_in_sight_area:
				sight_area.monitoring = false
				sight_area.monitoring = true
		
		EnemyState.PATROLLING:
			if patrol_route.has_enemy:
				linear_velocity = Vector3.ZERO
				if get_parent() != patrol_route:
					move_to_parent(patrol_route)
				patrol_route.progress += patrol_speed * delta
		
		EnemyState.CHASING:
			nav_agent.target_position = target.position
			var next_path_pos: Vector3 = nav_agent.get_next_path_position()
			var direction = global_position.direction_to(next_path_pos)
			if nav_agent.avoidance_enabled:
				nav_agent.velocity = direction * chase_speed
			else:
				_on_velocity_computed(direction * chase_speed)
			
			
			rotation.y = lerp_angle(rotation.y, atan2(rotation_direction.x, rotation_direction.y), delta * rotation_speed)
			
			if nav_agent.is_navigation_finished():
				nav_agent.velocity = Vector3.ZERO
				if target_is_in_range():
					set_current_state(EnemyState.ATTACKING)
		
		EnemyState.HIT:
			rotation.y = lerp_angle(rotation.y, atan2(rotation_direction.x, rotation_direction.y), delta * rotation_speed)
		
		EnemyState.ATTACKING:
			rotation.y = lerp_angle(rotation.y, atan2(rotation_direction.x, rotation_direction.y), delta * rotation_speed)
		
		EnemyState.DEAD:
			rotation.y = 0
		

func take_damage(amount: float):
	if current_health > 0:
		current_health -= clampf(amount, 0, max_health) 
		if current_health <= 0:
			set_current_state(EnemyState.DEAD)
		else:
			set_current_state(EnemyState.HIT)

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
				sword.set_state(sword.SwordState.PULLED_BACK)
				
				take_damage(current_health)
				
			sword.SwordState.PULLED_BACK:
				take_damage(sword.damage)

func set_current_state(new_state):
	match new_state:
		EnemyState.IDLE:
			if current_health <= 0:
				return
			nav_agent = null
			attack_collision.disabled = true
			anim_player.play("idle")
		
		EnemyState.PATROLLING:
			if get_parent() != patrol_route and patrol_route != null:
				move_to_parent(patrol_route)
			
			if !patrol_route.has_enemy:
				patrol_route.has_enemy = true
			
			attack_collision.disabled = true
			anim_player.play("patrol")
		
		EnemyState.CHASING:
			if current_health <= 0:
				return
			
			if get_parent() is PathFollow3D:
				move_to_parent(get_tree().current_scene)
			
			nav_agent = $NavigationAgent3D
			attack_collision.disabled = true
			has_target = true
			anim_player.play("chase")
	
		EnemyState.HIT:
			if current_health <= 0:
				return
			nav_agent = null
			attack_collision.disabled = true
			anim_player.play("hit",-1, 1.5)
		
		EnemyState.ATTACKING:
			if current_health <= 0:
				return
			linear_velocity = Vector3.ZERO
			attack_collision.disabled = false
			anim_player.play("attack")
		
		EnemyState.DEAD:
			nav_agent = null
			linear_velocity = Vector3.ZERO
			attack_collision.disabled = true
			anim_player.play("hit",-1, 1.5)
	
	current_state = new_state

func receive_sword_impact(damage: int, hit_position: Vector3, impact_strength: int):
	set_current_state(EnemyState.HIT)
	take_damage(damage)
	linear_velocity.y += 5
	linear_velocity.y = clamp(linear_velocity.y, -6, 6)

func receive_rocket_impact(hit_position: Vector3, damage: int):
	set_current_state(EnemyState.HIT)
	spawn_blood(global_position)
	linear_velocity.y += 5
	linear_velocity.y = clamp(linear_velocity.y, -6, 6)
	take_damage(damage)

func finished_attacking():
	if !is_floating:
		set_current_state(EnemyState.CHASING)
	else:
		set_current_state(EnemyState.HIT)

func finished_get_hit():
	if !is_floating:
		set_current_state(EnemyState.CHASING)
	else:
		set_current_state(EnemyState.HIT)
	
	if current_health <= 0:
		anim_player.play("dead")

func finished_dead():
	await get_tree().create_timer(5).timeout
	queue_free()

func target_is_in_range() -> bool:
	if not target:
		return false
	
	var distance = global_position.distance_to(target.global_position)
	if distance > attack_range:
		return false
	
	var space_state = get_world_3d().direct_space_state
	
	var from = global_position + Vector3(0, 1.5, 0)
	var to = target.global_position + Vector3(0, 1.5, 0)
	
	var ray_params = PhysicsRayQueryParameters3D.create(from, to)
	ray_params.exclude = [self, target]
	ray_params.collision_mask = 1
	
	var result = space_state.intersect_ray(ray_params)
	
	return result.is_empty()

func move_to_parent(new_parent: Node):
	var current_global_position = global_position
	
	get_parent().remove_child(self)
	new_parent.add_child(self)
	
	global_position = current_global_position

func check_is_floating():
	if ground_raycast.is_colliding():
		is_floating = false
	else:
		is_floating = true

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
			set_current_state(EnemyState.CHASING)

func _on_sight_area_body_exited(body):
	if body == target:
		player_in_sight_area = false

func _on_attack_area_body_entered(body):
	print("Hit Player")
	if body == target:
		target.take_damage(attack_damage)

func _on_velocity_computed(safe_velocity):
	if current_state == EnemyState.CHASING:
		linear_velocity = safe_velocity
