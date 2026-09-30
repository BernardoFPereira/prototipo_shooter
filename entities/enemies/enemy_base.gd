class_name EnemyBase
extends RigidBody3D
 
@onready var anim_player: AnimationPlayer = $AnimationPlayer
@onready var sight_area: Area3D = $SightArea
@onready var sight_collision: CollisionShape3D = $SightArea/SightCollision
@onready var sword_collision_area: Area3D = $SwordCollisionArea
@onready var sword_hit_collision: CollisionShape3D = $SwordCollisionArea/SwordHitCollision
@onready var nav_agent: NavigationAgent3D = $NavigationAgent3D
@onready var ground_raycast: RayCast3D = $GroundRaycast
@onready var shield_area: Area3D = get_node_or_null("ShieldArea3D")
 
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
@export var patrol_route_name: String = ""
var _patrol_waypoints: Array[Vector3] = []
var _patrol_index: int = 0
var _patrol_loop: bool = true
 
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
@export var detection_range: float = 20.0
@export var engagement_buffer: float = 0.5
@export var eye_height: float = 1.5
 
@export_category("Hit Reaction")
#Velocidade horizontal (m/s) do empurrão quando leva tiro, na direção do tiro.
@export var hit_knockback_force: float = 5.0
#Velocidade pra cima (m/s) do empurrão. Menos = menos tempo no ar.
@export var hit_knockback_up: float = 6.0
#Multiplicador de gravidade enquanto está em HIT (cai mais rápido, fica menos tempo no ar).
@export var hit_gravity_scale: float = 2.0
#Velocidade da animação de hit. 1.5 = stagger de ~0,3 s em vez de ~0,45 s.
@export var hit_anim_speed: float = 1
#Quão rápido o deslize horizontal para depois que ele encosta no chão, ainda em HIT.
@export var hit_ground_friction: float = 5.0
## Tempo mínimo (s) em HIT antes de poder voltar a perseguir, pra golpes que quase não tiram ele
## do chão (senão sairia do HIT no mesmo frame em que entrou).
@export var hit_min_stagger: float = 0.2
var _base_gravity_scale: float = 1.0
var _hit_elapsed: float = 0.0
var _hit_was_airborne: bool = false

@export_category("Animation")
## Tempo (s) de transição entre animações — mesmo esquema do play_animation_with_blend do player.
@export var anim_blend_time: float = 0.15

@export_category("Shield")

enum AttackType { SWORD, SHOOT }

enum ShieldMode {
	SWORD_BLOCK_SWORD_BREAK, #Braço bloqueado, braço quebra. Tiro normal.
	SWORD_BLOCK_SHOOT_BREAK, #Braço bloqueado, tiro quebra.
	SHOOT_BLOCK_SHOOT_BREAK, #Tiro bloqueado, tiro quebra. Braço normal.
	SHOOT_BLOCK_SWORD_BREAK, #Tiro bloqueado, braço quebra.
}


@export var SHIELD_MODE_COLORS := {
	ShieldMode.SWORD_BLOCK_SWORD_BREAK: Color(0.545, 0.0, 1.0),
	ShieldMode.SWORD_BLOCK_SHOOT_BREAK: Color(0.0, 0.75, 1.0),
	ShieldMode.SHOOT_BLOCK_SHOOT_BREAK: Color(1.0, 0.45, 0.0),
	ShieldMode.SHOOT_BLOCK_SWORD_BREAK: Color(1.0, 0.1, 0.25),
}

@export var shield_mode: ShieldMode = ShieldMode.SWORD_BLOCK_SWORD_BREAK:
	set(value):
		shield_mode = value
		_apply_shield_color()

@export var shield_up: bool = false:
	set(value):
		shield_up = value
		if is_node_ready() and not _is_breaking_shield:
			_update_shield_visual()
@export var shield_str: int = 1

@export_group("Shield Break FX")
@export var shield_break_fx: PackedScene = preload("res://entities/enemies/ShieldBreakGlyphs.tscn")
@export var shield_glitch_time: float = 0.3
@export var hitstop_duration: float = 0.07
@export var hitstop_time_scale: float = 0.05

var _shield_hits_left: int = 1
var _shield_mesh: MeshInstance3D
var _shield_material: ShaderMaterial
var _is_breaking_shield: bool = false
var _shield_break_tween: Tween

static var _hitstop_owner: EnemyBase = null
static var _hitstop_previous_scale: float = 1.0

signal shield_broken

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
	_base_gravity_scale = gravity_scale
	_shield_hits_left = max(shield_str, 1)
	_setup_shield_material()
	_update_shield_visual()
	_resolve_patrol_route()
	_ready_extra()
 
func _ready_extra() -> void:
	pass
 
func _pre_state_change(new_state: EnemyState) -> void:
	pass
 
func _configure_engagement_ranges() -> void:
	nav_agent.target_desired_distance = max(0.1, attack_range - engagement_buffer)
 
	var shape := sight_collision.shape
	if shape is SphereShape3D:
		shape = shape.duplicate()
		shape.radius = detection_range
		sight_collision.shape = shape
	else:
		push_warning("%s: SightArea/SightCollision não usa SphereShape3D — detection_range não tem efeito automático nele." % name)
 
	if attack_range > detection_range:
		push_warning("%s: attack_range (%.1f) é maior que detection_range (%.1f) — o inimigo vai atacar assim que detectar o jogador, sem perseguir de verdade. Ajuste um dos dois." % [name, attack_range, detection_range])
 
#region PATROL
func _resolve_patrol_route() -> void:
	_patrol_waypoints.clear()
	_patrol_index = 0
	_patrol_loop = true
 
	if patrol_route_name == "":
		return
 
	var route := get_tree().get_first_node_in_group(patrol_route_name) as PatrolRoute
	if route == null:
		push_warning("%s: nenhuma PatrolRoute encontrada com route_name = \"%s\"." % [name, patrol_route_name])
		return
 
	_patrol_waypoints = route.get_waypoints()
	_patrol_loop = route.loop
	if _patrol_waypoints.is_empty():
		push_warning("%s: a PatrolRoute \"%s\" não tem nenhum Marker3D filho." % [name, patrol_route_name])
 
func assign_patrol_route(route_name: String) -> void:
	patrol_route_name = route_name
	_resolve_patrol_route()
	if current_state == EnemyState.IDLE and not _patrol_waypoints.is_empty():
		set_current_state(EnemyState.PATROLLING)
 
func _advance_patrol_waypoint() -> void:
	if _patrol_waypoints.is_empty():
		return
	if _patrol_index < _patrol_waypoints.size() - 1:
		_patrol_index += 1
	elif _patrol_loop:
		_patrol_index = 0
#endregion
 
func _physics_process(delta: float) -> void:
	check_is_floating()
 
	match current_state:
		EnemyState.IDLE:
			if not _patrol_waypoints.is_empty():
				set_current_state(EnemyState.PATROLLING)
 
			if player_in_sight_area:
				sight_area.monitoring = false
				sight_area.monitoring = true
 
		EnemyState.PATROLLING:
			if _patrol_waypoints.is_empty():
				set_current_state(EnemyState.IDLE)
			else:
				nav_agent.target_position = _patrol_waypoints[_patrol_index]
				var next_path_pos: Vector3 = nav_agent.get_next_path_position()
				var direction = global_position.direction_to(next_path_pos)
				if nav_agent.avoidance_enabled:
					nav_agent.velocity = direction * patrol_speed
				else:
					_on_velocity_computed(direction * patrol_speed)
 
				if direction.length() > 0.01:
					look_at(global_position + Vector3(direction.x, 0, direction.z), Vector3.UP, true)
 
				if nav_agent.is_navigation_finished():
					nav_agent.velocity = Vector3.ZERO
					_advance_patrol_waypoint()
 
		EnemyState.CHASING:
			# Null target safeguard
			if !target:
				#push_warning("No target found")
				queue_free()
				return
				
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
			if not is_floating:
				var slow := clampf(hit_ground_friction * delta, 0.0, 1.0)
				linear_velocity.x = lerpf(linear_velocity.x, 0.0, slow)
				linear_velocity.z = lerpf(linear_velocity.z, 0.0, slow)

			# A animação de hit fica em loop enquanto ele está no ar; assim que encosta no chão
			# (depois de ter saído dele, ou depois do stagger mínimo) volta a perseguir.
			_hit_elapsed += delta
			if is_floating:
				_hit_was_airborne = true
			elif _hit_was_airborne or _hit_elapsed >= hit_min_stagger:
				set_current_state(EnemyState.CHASING if target else EnemyState.IDLE)
 
		EnemyState.ATTACKING:
			look_at(Vector3(target.global_position.x, global_position.y, target.global_position.z), Vector3.UP, true)
 
		EnemyState.DEAD:
			rotation.y = 0
 
func take_damage(amount: float) -> void:
	if current_health > 0:
		current_health -= clampf(amount, 0, max_health)
		if current_health <= 0:
			break_shield()
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

		match sword.state:
			sword.SwordState.THROWN:
				sword.speed = 0
				sword.set_state(sword.SwordState.PULLED_BACK)

				if _shield_absorbs(AttackType.SWORD):
					sword.impact_sfx.play()
					return

				var tween = get_tree().create_tween()
				tween.tween_property(sword.sword_owner, "global_position", sword.global_position, 0.16)
				receive_sword_impact(current_health, sword.global_position, 250)

			sword.SwordState.PULLED_BACK:
				if shield_up and _shield_reacts_to(AttackType.SWORD):
					return
				receive_sword_impact(sword.damage, sword.global_position, 250)
 
#region SHIELD
func _block_type() -> AttackType:
	match shield_mode:
		ShieldMode.SWORD_BLOCK_SWORD_BREAK, ShieldMode.SWORD_BLOCK_SHOOT_BREAK:
			return AttackType.SWORD
		_:
			return AttackType.SHOOT

func _break_type() -> AttackType:
	match shield_mode:
		ShieldMode.SWORD_BLOCK_SWORD_BREAK, ShieldMode.SHOOT_BLOCK_SWORD_BREAK:
			return AttackType.SWORD
		_:
			return AttackType.SHOOT

func _shield_reacts_to(attack: AttackType) -> bool:
	return attack == _block_type() or attack == _break_type()

func _shield_absorbs(attack: AttackType) -> bool:
	if not shield_up or not _shield_reacts_to(attack):
		return false
	if attack == _break_type():
		_shield_hits_left -= 1
		if _shield_hits_left <= 0:
			break_shield()
	return true

func _apply_shield_color() -> void:
	if _shield_material:
		_shield_material.set_shader_parameter("color", SHIELD_MODE_COLORS[shield_mode])

## Quebra o escudo: na lógica ele já some na hora (o próximo arremesso teleporta), e o visual faz
## hitstop -> glitch forte -> explosão de glifos -> some.
func break_shield() -> void:
	if not shield_up:
		return
	_is_breaking_shield = true
	shield_up = false
	shield_broken.emit()
	_hitstop()
	_play_shield_break_animation()

func restore_shield() -> void:
	if _is_breaking_shield:
		_finish_shield_break()
	_shield_hits_left = max(shield_str, 1)
	shield_up = true

func _setup_shield_material() -> void:
	if shield_area == null:
		return
	for node in shield_area.find_children("*", "MeshInstance3D", true, false):
		_shield_mesh = node
		break
	if _shield_mesh and _shield_mesh.material_override is ShaderMaterial:
		_shield_material = _shield_mesh.material_override.duplicate()
		_shield_mesh.material_override = _shield_material
	_apply_shield_color()

func _play_shield_break_animation() -> void:
	if _shield_break_tween and _shield_break_tween.is_valid():
		_shield_break_tween.kill()

	if _shield_material == null:
		_spawn_shield_glyphs()
		_finish_shield_break()
		return

	var half := shield_glitch_time * 0.5
	_shield_break_tween = create_tween()
	_shield_break_tween.tween_method(_set_shield_break_progress, 0.0, 0.5, half)
	_shield_break_tween.tween_callback(_spawn_shield_glyphs)
	_shield_break_tween.tween_method(_set_shield_break_progress, 0.5, 1.0, half)
	_shield_break_tween.tween_callback(_finish_shield_break)

func _set_shield_break_progress(value: float) -> void:
	if _shield_material:
		_shield_material.set_shader_parameter("break_progress", value)

func _spawn_shield_glyphs() -> void:
	if shield_break_fx == null:
		return
	var fx := shield_break_fx.instantiate()
	get_tree().root.add_child(fx)
	if fx.has_method("play_from_shield"):
		fx.play_from_shield(_shield_mesh)
	elif _shield_mesh:
		fx.global_position = _shield_mesh.global_position

func _finish_shield_break() -> void:
	_is_breaking_shield = false
	_set_shield_break_progress(0.0)
	_update_shield_visual()

func _hitstop() -> void:
	if hitstop_duration <= 0.0 or _hitstop_owner != null:
		return
	_hitstop_owner = self
	_hitstop_previous_scale = Engine.time_scale
	Engine.time_scale = hitstop_time_scale
	await get_tree().create_timer(hitstop_duration, true, false, true).timeout
	_end_hitstop()

func _end_hitstop() -> void:
	if _hitstop_owner == self:
		Engine.time_scale = _hitstop_previous_scale
		_hitstop_owner = null

func _exit_tree() -> void:
	_end_hitstop()

func _update_shield_visual() -> void:
	if shield_area == null:
		if shield_up:
			push_warning("%s: shield_up está ligado, mas a cena não tem um nó ShieldArea3D — o escudo funciona, só não aparece." % name)
		return
	shield_area.visible = shield_up
	shield_area.set_deferred("monitorable", shield_up)
#endregion

func set_current_state(new_state: EnemyState) -> void:
	match new_state:
		EnemyState.IDLE:
			if current_state == EnemyState.DEAD:
				return
			_pre_state_change(new_state)
			_play_anim("idle", true)
			resume_idle_sounds()
 
		EnemyState.PATROLLING:
			_pre_state_change(new_state)
			nav_agent.max_speed = patrol_speed
			_play_anim("patrol", true)
			resume_idle_sounds()
 
		EnemyState.CHASING:
			if current_state == EnemyState.DEAD:
				return
			_pre_state_change(new_state)
			has_target = true
			nav_agent.max_speed = chase_speed
			_play_anim("chase", true)
			if _idle_timer:
				_idle_timer.wait_time = idle_sound_interval / 2.0
 
		EnemyState.HIT:
			if current_state == EnemyState.DEAD:
				return
			_pre_state_change(new_state)
			nav_agent.max_speed = 0
			gravity_scale = _base_gravity_scale * hit_gravity_scale
			_hit_elapsed = 0.0
			_hit_was_airborne = false
			_play_anim("hit", true, hit_anim_speed)
			pause_idle_sounds()
			hit_sfx.play()
 
		EnemyState.ATTACKING:
			if current_state == EnemyState.DEAD:
				return
			_pre_state_change(new_state)
			linear_velocity = Vector3.ZERO
			_play_anim("attack", false)
			pause_idle_sounds()
 
		EnemyState.DEAD:
			_pre_state_change(new_state)
			nav_agent.set_avoidance_enabled(false)
			sword_collision_area.set_collision_mask_value(6, false)
			nav_agent.max_speed = 0
			_play_anim("hit", true, hit_anim_speed)
			stop_idle_sounds()
 
	if new_state != EnemyState.HIT:
		gravity_scale = _base_gravity_scale
	current_state = new_state
 
func receive_sword_impact(damage: int, hit_position: Vector3, impact_strength: int) -> void:
	if current_state == EnemyState.DEAD:
		return
	set_current_state(EnemyState.HIT)
	spawn_blood(hit_position)
	take_damage(damage)
	linear_velocity.y += 5
	linear_velocity.y = clamp(linear_velocity.y, -6, 6)
 

func receive_rocket_impact(hit_position: Vector3, damage: int, shot_direction: Vector3 = Vector3.ZERO) -> void:
	if current_state == EnemyState.DEAD:
		return
	if _shield_absorbs(AttackType.SHOOT):
		return
	set_current_state(EnemyState.HIT)
	spawn_blood(hit_position)
	take_damage(damage)
	apply_knockback(hit_position, shot_direction)


func apply_knockback(from_position: Vector3, shot_direction: Vector3 = Vector3.ZERO) -> void:
	var dir := Vector3(shot_direction.x, 0.0, shot_direction.z)
	if dir.length() < 0.01:
		dir = global_position - from_position
		dir.y = 0.0
	if dir.length() < 0.01 and target:
		dir = global_position - target.global_position
		dir.y = 0.0
	dir = dir.normalized()
	linear_velocity = dir * hit_knockback_force + Vector3.UP * hit_knockback_up
 
func finished_attacking() -> void:
	if not is_floating:
		set_current_state(EnemyState.CHASING)
	else:
		set_current_state(EnemyState.HIT)
 
## Chamado pela trilha de método da animação "hit" (a cada volta do loop). A saída do HIT agora
## é pelo _physics_process (quando encosta no chão); aqui só trata a morte.
func finished_get_hit() -> void:
	if current_state == EnemyState.DEAD and anim_player.current_animation == "hit":
		set_collision_layer_value(20, false)
		_play_anim("dead", false)
 
## Mesmo esquema do play_animation_with_blend() do player: transição suave (anim_blend_time),
## define se a animação faz loop e não reinicia a que já está tocando.
func _play_anim(anim_name: String, loop: bool, speed: float = 1.0) -> void:
	if not anim_player.has_animation(anim_name):
		return
	if anim_player.current_animation == anim_name and anim_player.is_playing():
		return
	var anim := anim_player.get_animation(anim_name)
	if anim:
		anim.loop_mode = Animation.LOOP_LINEAR if loop else Animation.LOOP_NONE
	anim_player.play(anim_name, anim_blend_time, speed)

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
	if current_state == EnemyState.CHASING or current_state == EnemyState.PATROLLING:
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
