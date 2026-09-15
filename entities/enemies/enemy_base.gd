class_name EnemyBase
extends RigidBody3D

## Base class para todo inimigo (EnemyMelee, EnemyRanged, e qualquer tipo futuro).
## Concentra tudo que estava duplicado entre enemy_melee.gd e enemy_ranged.gd: máquina de
## estados, perseguição/navegação, detecção do jogador, sons de idle, dano/morte e a
## configuração de alcance (detecção + ataque).
##
## As subclasses só adicionam o que é realmente específico delas:
## - EnemyMelee: o hitbox de ataque da espada (attack_area) e o liga/desliga dele
## - EnemyRanged: o projétil que ela atira
##
## Para estender o comportamento por tipo, sobrescreva _ready_extra() (setup extra) e
## _pre_state_change() (reação a troca de estado) — veja EnemyMelee como exemplo.

@onready var anim_player: AnimationPlayer = $AnimationPlayer
@onready var sight_area: Area3D = $SightArea
@onready var sight_collision: CollisionShape3D = $SightArea/SightCollision
@onready var sword_collision_area: Area3D = $SwordCollisionArea
@onready var sword_hit_collision: CollisionShape3D = $SwordCollisionArea/SwordHitCollision
@onready var nav_agent: NavigationAgent3D = $NavigationAgent3D
@onready var ground_raycast: RayCast3D = $GroundRaycast

#region SOUNDS
@onready var idle_sfx: AudioStreamPlayer3D = $SFX/Idle
@onready var hit_sfx: AudioStreamPlayer3D = $SFX/Hit
@export var idle_sound_interval: float = 2.0
@export var idle_sound_variation: float = 1.5
@export var enable_idle_sounds: bool = true
var _idle_timer: Timer
var _is_idle_sounds_enabled: bool = true
#endregion

var player_in_sight_area: bool = false
var has_target: bool

var blood_particles_scene = preload("uid://dauurgt5mibfk")

@export_category("Targets")
@export var target: CharacterBody3D
@export var patrol_route: PathFollow3D

@export_category("Combat Properties")
@export var max_health: float = 100
@export var attack_range: float = 2
var current_health: float

@export_category("Movement Properties")
@export var patrol_speed: float = 2.0
@export var chase_speed: float = 6.0
@export var rotation_speed: float = 5.0
var is_floating: bool

@export_category("Detection & Engagement")
## Alcance de detecção. Redimensiona sozinho o SphereShape3D de SightArea/SightCollision — antes
## esse número só existia como o tamanho do collider, escondido dentro da árvore de nós.
@export var detection_range: float = 20.0
## Margem entre onde o NavigationAgent3D para de andar (target_desired_distance) e o attack_range
## real, pra evitar que o inimigo fique "vibrando" bem na borda do alcance de ataque.
@export var engagement_buffer: float = 0.5
## Altura usada no raycast de linha-de-visão de target_is_in_range(). Ajustável por instância
## (ex: um inimigo maior/menor com o "olho" em outra altura).
@export var eye_height: float = 1.5

#HUD
@onready var hud_animations = $HUDAnimations
@onready var detection_ch = $SubViewport/DetectionCH
var detected := false

var current_state: EnemyState = EnemyState.IDLE
enum EnemyState {
	IDLE,
	PATROLLING,
	CHASING,
	HIT,
	ATTACKING,
	DEAD,
}

func _ready() -> void:
	detection_ch.visible = false
	_configure_engagement_ranges()
	_setup_idle_sound_timer()
	current_health = max_health
	_ready_extra()

	# Nota histórica (mantida dos dois scripts originais): existia uma tentativa de registrar
	# cada inimigo como exceção de colisão com os outros inimigos do grupo "Enemies". Ficou
	# comentada nos dois — trazendo pra cá caso o grupo queira retomar:
	#var enemies = get_tree().get_nodes_in_group("Enemies")
	#for enemy in enemies:
		#if enemy is EnemyMelee:
			#add_collision_exception_with(enemy)
		#elif enemy is EnemyRanged:
			#add_collision_exception_with(enemy)

## Sobrescreva em subclasses para setup extra específico do tipo de inimigo.
func _ready_extra() -> void:
	pass

## Sobrescreva em subclasses para reagir a uma troca de estado antes da lógica comum rodar.
## (ex: EnemyMelee liga/desliga o hitbox da espada aqui.)
func _pre_state_change(new_state: EnemyState) -> void:
	pass

## Único lugar que decide alcance de detecção e de ataque — ver Contexto.md / Programado.md no
## Projeto pra entender por que isso existia espalhado entre o export attack_range, o tamanho do
## collider de SightArea e o target_desired_distance do NavigationAgent3D.
func _configure_engagement_ranges() -> void:
	nav_agent.target_desired_distance = max(0.1, attack_range - engagement_buffer)

	var shape := sight_collision.shape
	if shape is SphereShape3D:
		# Sub-resources carregados de uma .tscn são compartilhados entre todas as instâncias da
		# cena a menos que sejam duplicados — sem isso, mudar detection_range de UM inimigo
		# redimensionaria o SightArea de todos os outros da mesma cena.
		shape = shape.duplicate()
		shape.radius = detection_range
		sight_collision.shape = shape
	else:
		push_warning("%s: SightArea/SightCollision não usa SphereShape3D — detection_range não tem efeito automático nele." % name)

	if attack_range > detection_range:
		push_warning("%s: attack_range (%.1f) é maior que detection_range (%.1f) — o inimigo vai atacar assim que detectar o jogador, sem perseguir de verdade. Ajuste um dos dois." % [name, attack_range, detection_range])

func _physics_process(delta: float) -> void:
	check_is_floating()

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

			if target_is_in_range():
				set_current_state(EnemyState.ATTACKING)

			if nav_agent.is_navigation_finished():
				nav_agent.velocity = Vector3.ZERO
				if target_is_in_range():
					set_current_state(EnemyState.ATTACKING)

		EnemyState.HIT:
			look_at(Vector3(target.global_position.x, global_position.y, target.global_position.z), Vector3.UP, true)

		EnemyState.ATTACKING:
			look_at(Vector3(target.global_position.x, global_position.y, target.global_position.z), Vector3.UP, true)

		EnemyState.DEAD:
			rotation.y = 0

func take_damage(amount: float) -> void:
	if current_health > 0:
		current_health -= clampf(amount, 0, max_health)
		if current_health <= 0:
			set_current_state(EnemyState.DEAD)
		else:
			set_current_state(EnemyState.HIT)

func spawn_blood(position: Vector3) -> void:
	var blood_particles: GPUParticles3D = blood_particles_scene.instantiate()
	blood_particles.emitting = true
	get_tree().root.add_child(blood_particles)
	blood_particles.global_position = position

func _on_sword_entered(body: Node) -> void:
	if body.get_parent() is Sword:
		var sword := body.get_parent() as Sword
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

func set_current_state(new_state: EnemyState) -> void:
	match new_state:
		EnemyState.IDLE:
			if current_state == EnemyState.DEAD:
				return
			_pre_state_change(new_state)
			anim_player.play("idle")
			resume_idle_sounds()

		EnemyState.PATROLLING:
			_pre_state_change(new_state)
			if get_parent() != patrol_route and patrol_route != null:
				move_to_parent(patrol_route)

			if not patrol_route.has_enemy:
				patrol_route.has_enemy = true

			nav_agent.max_speed = patrol_speed
			anim_player.play("patrol")
			resume_idle_sounds()

		EnemyState.CHASING:
			if current_state == EnemyState.DEAD:
				return
			_pre_state_change(new_state)
			if get_parent() is PathFollow3D:
				move_to_parent(get_tree().current_scene)

			has_target = true
			nav_agent.max_speed = chase_speed
			anim_player.play("chase")
			if _idle_timer:
				_idle_timer.wait_time = idle_sound_interval / 2.0

		EnemyState.HIT:
			if current_state == EnemyState.DEAD:
				return
			_pre_state_change(new_state)
			nav_agent.max_speed = 0
			anim_player.play("hit")
			pause_idle_sounds()
			hit_sfx.play()

		EnemyState.ATTACKING:
			if current_state == EnemyState.DEAD:
				return
			_pre_state_change(new_state)
			linear_velocity = Vector3.ZERO
			anim_player.play("attack")
			pause_idle_sounds()

		EnemyState.DEAD:
			_pre_state_change(new_state)
			nav_agent.set_avoidance_enabled(false)
			sword_collision_area.set_collision_mask_value(6, false)
			nav_agent.max_speed = 0
			anim_player.play("hit")
			stop_idle_sounds()

	current_state = new_state

func receive_sword_impact(damage: int, hit_position: Vector3, impact_strength: int) -> void:
	if current_state == EnemyState.DEAD:
		return
	set_current_state(EnemyState.HIT)
	spawn_blood(hit_position)
	take_damage(damage)
	linear_velocity.y += 5
	linear_velocity.y = clamp(linear_velocity.y, -6, 6)

func receive_rocket_impact(hit_position: Vector3, damage: int) -> void:
	if current_state == EnemyState.DEAD:
		return
	set_current_state(EnemyState.HIT)
	spawn_blood(hit_position)
	take_damage(damage)
	linear_velocity.y += 5
	linear_velocity.y = clamp(linear_velocity.y, -6, 6)

func finished_attacking() -> void:
	if not is_floating:
		set_current_state(EnemyState.CHASING)
	else:
		set_current_state(EnemyState.HIT)

func finished_get_hit() -> void:
	if not is_floating:
		set_current_state(EnemyState.CHASING)
	else:
		set_current_state(EnemyState.HIT)

	if current_state == EnemyState.DEAD:
		set_collision_layer_value(20, false)
		anim_player.play("dead")

func finished_dead() -> void:
	await get_tree().create_timer(5).timeout
	queue_free()

func target_is_in_range() -> bool:
	if not target:
		return false

	var distance = global_position.distance_to(target.global_position)
	if distance > attack_range:
		return false

	var space_state = get_world_3d().direct_space_state

	var from = global_position + Vector3(0, eye_height, 0)
	var to = target.global_position + Vector3(0, eye_height, 0)

	var ray_params = PhysicsRayQueryParameters3D.create(from, to)
	ray_params.exclude = [self, target]
	ray_params.collision_mask = 1

	var result = space_state.intersect_ray(ray_params)

	return result.is_empty()

func move_to_parent(new_parent: Node) -> void:
	var current_global_position = global_position

	get_parent().remove_child(self)
	new_parent.add_child(self)

	global_position = current_global_position

func check_is_floating() -> void:
	is_floating = not ground_raycast.is_colliding()

func _on_sight_area_body_entered(body: Node) -> void:
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

func _on_sight_area_body_exited(body: Node) -> void:
	if body == target:
		player_in_sight_area = false

func _on_velocity_computed(safe_velocity: Vector3) -> void:
	if current_state == EnemyState.CHASING:
		linear_velocity = safe_velocity

#region SOUNDS
func _setup_idle_sound_timer() -> void:
	_idle_timer = Timer.new()
	_idle_timer.one_shot = false
	_idle_timer.timeout.connect(_on_idle_sound_timeout)

	idle_sfx.add_child(_idle_timer)

	_set_next_idle_interval()

	if enable_idle_sounds and current_state != EnemyState.DEAD:
		_idle_timer.start()

func _set_next_idle_interval() -> void:
	var min_interval = max(0.5, idle_sound_interval - idle_sound_variation)
	var max_interval = idle_sound_interval + idle_sound_variation
	_idle_timer.wait_time = randf_range(min_interval, max_interval)

func _on_idle_sound_timeout() -> void:
	if not enable_idle_sounds or not _is_idle_sounds_enabled:
		return

	match current_state:
		EnemyState.IDLE, EnemyState.PATROLLING:
			if not idle_sfx.playing:
				idle_sfx.play()

		EnemyState.DEAD:
			stop_idle_sounds()

	_set_next_idle_interval()

func start_idle_sounds() -> void:
	enable_idle_sounds = true
	_is_idle_sounds_enabled = true
	if _idle_timer and not _idle_timer.is_stopped():
		_idle_timer.start()
		_set_next_idle_interval()

func stop_idle_sounds() -> void:
	_is_idle_sounds_enabled = false
	if _idle_timer:
		_idle_timer.stop()

func pause_idle_sounds() -> void:
	_is_idle_sounds_enabled = false

func resume_idle_sounds() -> void:
	_is_idle_sounds_enabled = true
#endregion
