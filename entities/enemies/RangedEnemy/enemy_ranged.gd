class_name EnemyRanged
extends RigidBody3D


@onready var anim_player = $AnimationPlayer
@onready var sight_area = $SightArea
@onready var sight_collision = $SightArea/SightCollision
@onready var sword_collision_area = $SwordCollisionArea
@onready var sword_hit_collision = $SwordCollisionArea/SwordHitCollision
@onready var nav_agent = $NavigationAgent3D
@onready var ground_raycast = $GroundRaycast
@onready var muzzle_point = $Armature/Skeleton3D/BoneAttachment3D/MuzzlePoint

#Sounds
@onready var idle_sfx = $SFX/Idle
@onready var hit_sfx = $SFX/Hit
@onready var shot_sfx = $SFX/Shot

@export var idle_sound_interval: float = 2.0
@export var idle_sound_variation: float = 1.5
@export var enable_idle_sounds: bool = true
var _idle_timer: Timer
var _is_idle_sounds_enabled: bool = true

var player_in_sight_area: bool = false

var blood_particles_scene = preload("uid://dauurgt5mibfk")
var enemy_projectile_scene = preload("uid://bkecmbnogq48m")

@export_category("Targets")
var has_target: bool
@export var target: CharacterBody3D
@export var patrol_route: PathFollow3D

@export_category("Combat Properties")
var current_health: float
@export var max_health: float = 100
@export var attack_range: float = 2

@export_category("Movement Properties")
var is_floating: bool
@export var patrol_speed: float = 2.0
@export var chase_speed: float = 6.0
@export var rotation_speed: float = 5.0

#HUD
@onready var hud_animations = $HUDAnimations
@onready var detection_ch := $DetectionCH
var detected = false

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
	detection_ch.visible  = false
	
	#var enemies = get_tree().get_nodes_in_group("Enemies")
	#for enemy in enemies:
		#if enemy is EnemyMelee:
			#add_collision_exception_with(enemy)
		#elif enemy is EnemyRanged:
			#add_collision_exception_with(enemy)
	
	_setup_idle_sound_timer()
	
	current_health = max_health

func _process(delta):
	pass
	
func _physics_process(delta):
	check_is_floating()
	
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
			
			look_at(Vector3(target.global_position.x, global_position.y, target.global_position.z), Vector3.UP, true)
			#rotation.y = lerp_angle(rotation.y, atan2(rotation_direction.x, rotation_direction.y), delta * rotation_speed)
			
			if target_is_in_range():
					set_current_state(EnemyState.ATTACKING)
			
			if nav_agent.is_navigation_finished():
				nav_agent.velocity = Vector3.ZERO
				if target_is_in_range():
					set_current_state(EnemyState.ATTACKING)
		
		EnemyState.HIT:
			look_at(Vector3(target.global_position.x, global_position.y, target.global_position.z), Vector3.UP, true)
			#rotation.y = lerp_angle(rotation.y, atan2(rotation_direction.x, rotation_direction.y), delta * rotation_speed)
		
		EnemyState.ATTACKING:
			look_at(Vector3(target.global_position.x, global_position.y, target.global_position.z), Vector3.UP, true)
			#rotation.y = lerp_angle(rotation.y, atan2(rotation_direction.x, rotation_direction.y), delta * rotation_speed)
		
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
				
				receive_sword_impact(current_health, sword.global_position, 250)
				
			sword.SwordState.PULLED_BACK:
				receive_sword_impact(sword.damage, sword.global_position, 250)

func set_current_state(new_state):
	match new_state:
		EnemyState.IDLE:
			if current_state == EnemyState.DEAD:
				return
			anim_player.play("idle")
			resume_idle_sounds()
		
		EnemyState.PATROLLING:
			if get_parent() != patrol_route and patrol_route != null:
				move_to_parent(patrol_route)
			
			if !patrol_route.has_enemy:
				patrol_route.has_enemy = true
			
			nav_agent.max_speed = 2
			anim_player.play("patrol")
			resume_idle_sounds()
	
		EnemyState.CHASING:
			if current_health <= 0:
				return
			
			if get_parent() is PathFollow3D:
				move_to_parent(get_tree().current_scene)
			
			has_target = true
			nav_agent.max_speed = 6
			anim_player.play("chase")
			if _idle_timer:
				_idle_timer.wait_time = idle_sound_interval / 2
		
		EnemyState.HIT:
			if current_health <= 0:
				return
				
			nav_agent.max_speed = 0
			anim_player.play("hit")
			pause_idle_sounds()
			hit_sfx.play()
		
		EnemyState.ATTACKING:
			if current_health <= 0:
				return
				
			linear_velocity = Vector3.ZERO
			anim_player.play("attack")
			pause_idle_sounds()
		
		EnemyState.DEAD:
			nav_agent.set_avoidance_enabled(false)
			sword_collision_area.set_collision_mask_value(6, false)
			nav_agent.max_speed = 0
			anim_player.play("hit")
			stop_idle_sounds()
	
	current_state = new_state

func receive_sword_impact(damage: int, hit_position: Vector3, impact_strength: int):
	if current_state == EnemyState.DEAD:
		return
	set_current_state(EnemyState.HIT)
	spawn_blood(global_position)
	take_damage(damage)
	linear_velocity.y += 5
	linear_velocity.y = clamp(linear_velocity.y, -6, 6)

func receive_rocket_impact(hit_position: Vector3, damage: int):
	if current_state == EnemyState.DEAD:
		return
	set_current_state(EnemyState.HIT)
	spawn_blood(global_position)
	take_damage(damage)
	linear_velocity.y += 5
	linear_velocity.y = clamp(linear_velocity.y, -6, 6)

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
		set_collision_layer_value(20, false)
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
	
	var from = global_position + Vector3(0, 1, 0)
	var to = target.global_position + Vector3(0, 1, 0)
	
	var ray_params = PhysicsRayQueryParameters3D.create(from, to)
	ray_params.exclude = [self, target]
	ray_params.collision_mask = 1
	
	var result = space_state.intersect_ray(ray_params)
	
	return result.is_empty()

func spawn_projectile():
	var projectile = enemy_projectile_scene.instantiate()
	get_parent().add_child(projectile, true)
	projectile.global_transform = muzzle_point.global_transform
	projectile.start(global_position.direction_to(target.global_position))
	shot_sfx.play()

func move_to_parent(new_parent: Node):
	
	var current_global_position = global_position
	
	#get_parent().call_deferred("remove_child", self)
	get_parent().remove_child(self)
	#new_parent.call_deferred("add_child", self)
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

func _on_velocity_computed(safe_velocity):
	if current_state == EnemyState.CHASING:
		linear_velocity = safe_velocity

#region SOUNDS
func _setup_idle_sound_timer():
	_idle_timer = Timer.new()
	_idle_timer.one_shot = false
	_idle_timer.timeout.connect(_on_idle_sound_timeout)
	
	idle_sfx.add_child(_idle_timer)
	
	_set_next_idle_interval()
	
	if enable_idle_sounds and current_state != EnemyState.DEAD:
		_idle_timer.start()

func _set_next_idle_interval():
	var min_interval = max(0.5, idle_sound_interval - idle_sound_variation)
	var max_interval = idle_sound_interval + idle_sound_variation
	_idle_timer.wait_time = randf_range(min_interval, max_interval)

func _on_idle_sound_timeout():
	if not enable_idle_sounds or not _is_idle_sounds_enabled:
		return
	
	match current_state:
		EnemyState.IDLE, EnemyState.PATROLLING:
			if not idle_sfx.playing:
				idle_sfx.play()
		
		EnemyState.DEAD:
			stop_idle_sounds()
	
	_set_next_idle_interval()

func start_idle_sounds():
	enable_idle_sounds = true
	_is_idle_sounds_enabled = true
	if _idle_timer and not _idle_timer.is_stopped():
		_idle_timer.start()
		_set_next_idle_interval()

func stop_idle_sounds():
	_is_idle_sounds_enabled = false
	if _idle_timer:
		_idle_timer.stop()

func pause_idle_sounds():
	_is_idle_sounds_enabled = false

func resume_idle_sounds():
	_is_idle_sounds_enabled = true

#endregion
