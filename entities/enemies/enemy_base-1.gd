class_name EnemyBase
extends RigidBody3D
 
@onready var anim_player: AnimationPlayer = $AnimationPlayer
# SightArea antiga não é mais usada (a detecção agora é por can_see_target()). O script desliga ela
# no _ready se ainda existir na cena — pode apagar o nó no editor.
@onready var _legacy_sight_area: Area3D = get_node_or_null("SightArea")
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
 
var blood_particles_scene = preload("uid://dauurgt5mibfk")
 
@export_category("Targets")
@export var target: CharacterBody3D
@export var patrol_route_name: String = ""
var _patrol_waypoints: Array[Vector3] = []
var _patrol_index: int = 0
var _patrol_loop: bool = true
 
@export_category("Combat Properties")
@export var max_health: float = 100
## Distância máxima pra atacar (com linha de visão livre).
@export var attack_range: float = 2
## Tempo mínimo (s) entre o fim de um ataque e o começo do próximo.
@export var attack_cooldown: float = 0.5
## Distância em que ele para de se aproximar pra atacar. 0 = para logo dentro do attack_range
## (attack_range - engagement_buffer). Útil no ranged: ex. 15 pra atirar de longe sem vir até o player.
@export var preferred_distance: float = 0.0
var current_health: float
var _attack_cooldown_left: float = 0.0
 
@export_category("Movement Properties")
@export var patrol_speed: float = 2.0
@export var chase_speed: float = 6.0
@export var rotation_speed: float = 5.0
var is_floating: bool
 
@export_category("Detection & Engagement")
## Até onde ele enxerga (dentro do ângulo de visão).
@export var detection_range: float = 20.0
## Ângulo de visão total, centrado na frente dele. 360 = enxerga em volta toda.
@export_range(10.0, 360.0) var fov_degrees: float = 120.0
## Abaixo dessa distância ele percebe o player mesmo pelas costas (ainda precisa de linha de visão).
@export var hearing_range: float = 4.0
## Altura dos "olhos" (e do ponto mirado no player) pro teste de linha de visão.
@export var eye_height: float = 1.5
## Folga pra ele parar um pouco DENTRO do attack_range, sem ficar alternando perseguir/atacar
## quando o player se mexe na borda do alcance.
@export var engagement_buffer: float = 0.5
## De quanto em quanto tempo (s) ele checa se está vendo o player.
@export var perception_interval: float = 0.15
## Sem ver o player por esse tempo (s), desiste da perseguição e vai até a última posição vista.
@export var lose_target_time: float = 4.0
## Tempo (s) que ele fica parado na última posição vista antes de voltar a patrulhar.
@export var search_time: float = 2.5
## Distância pra considerar um ponto de patrulha/busca alcançado.
@export var waypoint_reach_distance: float = 1.0
## Começa já perseguindo o player (ex: inimigos que saem de uma porta de spawn).
@export var start_alerted: bool = false

var _can_see_target: bool = false
var _time_since_seen: float = INF
var _last_known_position: Vector3
var _perception_timer: float = 0.0
var _search_timer: float = 0.0
 
@export_category("Hit Reaction")
@export var hit_knockback_force: float = 5.0
@export var hit_knockback_up: float = 6.0
@export var hit_gravity_scale: float = 2.0
@export var hit_anim_speed: float = 1
@export var hit_ground_friction: float = 5.0
@export var hit_min_stagger: float = 0.2
var _base_gravity_scale: float = 1.0
var _hit_elapsed: float = 0.0
var _hit_was_airborne: bool = false

@export_category("Animation")
@export var anim_blend_time: float = 0.15

@export_category("Shield")

enum AttackType { SWORD, SHOOT }

enum ShieldMode {
	SWORD_BLOCK_SWORD_BREAK, # braço bloqueado, braço quebra - tiro normal
	SWORD_BLOCK_SHOOT_BREAK, # Bbraço bloqueado, tiro quebra
	SHOOT_BLOCK_SHOOT_BREAK, # tiro bloqueado, tiro quebra - braço normal
	SHOOT_BLOCK_SWORD_BREAK, # tiro bloqueado, braço quebra
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
	SEARCHING, ## perdeu o player de vista: vai até a última posição vista e espera um pouco
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
	if _legacy_sight_area:
		_legacy_sight_area.monitoring = false
	_perception_timer = randf() * perception_interval # espalha as checagens entre inimigos
	_ready_extra()
	if start_alerted:
		alert()
 
func _ready_extra() -> void:
	pass
 
func _pre_state_change(new_state: EnemyState) -> void:
	pass
 
func _configure_engagement_ranges() -> void:
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
	_update_perception(delta)
	if _attack_cooldown_left > 0.0:
		_attack_cooldown_left -= delta

	match current_state:
		EnemyState.IDLE:
			_stop_moving()
			if _can_see_target:
				set_current_state(EnemyState.CHASING)
			elif not _patrol_waypoints.is_empty():
				set_current_state(EnemyState.PATROLLING)

		EnemyState.PATROLLING:
			if _can_see_target:
				set_current_state(EnemyState.CHASING)
			elif _patrol_waypoints.is_empty():
				set_current_state(EnemyState.IDLE)
			elif _move_to(_patrol_waypoints[_patrol_index], patrol_speed, waypoint_reach_distance):
				_advance_patrol_waypoint()
			else:
				_face_movement()

		EnemyState.CHASING:
			if not _has_valid_target():
				set_current_state(EnemyState.IDLE)
				return
			if _time_since_seen > lose_target_time:
				set_current_state(EnemyState.SEARCHING)
				return

			if _attack_cooldown_left <= 0.0 and target_is_in_range():
				set_current_state(EnemyState.ATTACKING)
				return

			if _can_see_target:
				# Vendo: aproxima até a distância de combate e fica de frente pro player.
				_move_to(target.global_position, chase_speed, _engage_distance())
				_face_target()
			else:
				# Não vendo: vai até onde viu o player pela última vez.
				_move_to(_last_known_position, chase_speed, waypoint_reach_distance)
				_face_movement()

		EnemyState.SEARCHING:
			if _can_see_target:
				set_current_state(EnemyState.CHASING)
			elif _move_to(_last_known_position, patrol_speed, waypoint_reach_distance):
				_search_timer -= delta
				if _search_timer <= 0.0:
					set_current_state(EnemyState.PATROLLING if not _patrol_waypoints.is_empty() else EnemyState.IDLE)
			else:
				_face_movement()

		EnemyState.HIT:
			_face_target()
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
				set_current_state(EnemyState.CHASING if _has_valid_target() else EnemyState.IDLE)

		EnemyState.ATTACKING:
			_face_target()

		EnemyState.DEAD:
			rotation.y = 0

#region PERCEPTION
## Checa a visão a cada perception_interval segundos (não todo frame: o raycast tem custo).
func _update_perception(delta: float) -> void:
	_time_since_seen += delta
	_perception_timer -= delta
	if _perception_timer > 0.0:
		return
	_perception_timer = perception_interval
	_can_see_target = can_see_target()
	if _can_see_target:
		_time_since_seen = 0.0
		_last_known_position = target.global_position

## O inimigo enxerga o player se: está a até detection_range, dentro do ângulo de visão (ou perto
## o bastante pra "ouvir", hearing_range) e com linha de visão livre.
func can_see_target() -> bool:
	if not _has_valid_target() or current_state == EnemyState.DEAD:
		return false
	var to_target := target.global_position - global_position
	var distance := to_target.length()
	if distance > detection_range:
		return false
	if distance > hearing_range and fov_degrees < 360.0:
		var flat := Vector3(to_target.x, 0.0, to_target.z).normalized()
		# A frente do modelo é +Z (o look_at do script usa use_model_front = true).
		var forward := global_transform.basis.z
		forward.y = 0.0
		if forward.normalized().dot(flat) < cos(deg_to_rad(fov_degrees * 0.5)):
			return false
	return has_line_of_sight()

## Raio dos "olhos" do inimigo até a mesma altura no player; true se nada da camada 1 (cenário)
## estiver no caminho. Usado pela detecção e pelo ataque.
func has_line_of_sight() -> bool:
	if not _has_valid_target():
		return false
	var from := global_position + Vector3(0, eye_height, 0)
	var to := target.global_position + Vector3(0, eye_height, 0)
	var ray_params := PhysicsRayQueryParameters3D.create(from, to)
	ray_params.exclude = [self, target]
	ray_params.collision_mask = 1
	return get_world_3d().direct_space_state.intersect_ray(ray_params).is_empty()

## Faz o inimigo perseguir o player imediatamente (ex: ao levar dano, ou spawnar já alerta).
func alert(at_position: Vector3 = Vector3.INF) -> void:
	if not _has_valid_target() or current_state == EnemyState.DEAD:
		return
	_last_known_position = target.global_position if at_position == Vector3.INF else at_position
	_time_since_seen = 0.0
	if current_state in [EnemyState.IDLE, EnemyState.PATROLLING, EnemyState.SEARCHING]:
		set_current_state(EnemyState.CHASING)

func _has_valid_target() -> bool:
	return target != null and is_instance_valid(target)

## Distância em que ele para de se aproximar quando está vendo o player.
func _engage_distance() -> float:
	var max_stop := maxf(0.1, attack_range - engagement_buffer)
	if preferred_distance > 0.0:
		return clampf(preferred_distance, 0.1, max_stop)
	return max_stop
#endregion

#region MOVEMENT
## Anda até `point` pela navmesh. Retorna true quando chegou (a `reach_distance` dele).
## Toda a movimentação (patrulha, perseguição, busca) passa por aqui:
##   1. diz ao NavigationAgent pra onde ir e com que tolerância de chegada;
##   2. pega o próximo ponto do caminho e calcula a velocidade DESEJADA;
##   3. com avoidance: entrega a desejada pro agente (nav_agent.velocity) e o servidor devolve
##      uma velocidade SEGURA pelo sinal velocity_computed -> _on_velocity_computed aplica.
##      Sem avoidance: aplica a desejada direto.
func _move_to(point: Vector3, speed: float, reach_distance: float) -> bool:
	nav_agent.target_desired_distance = reach_distance
	nav_agent.max_speed = speed
	# Só recalcula o caminho se o destino mudou de verdade (setar todo frame força repath).
	if nav_agent.target_position.distance_to(point) > 0.25:
		nav_agent.target_position = point

	var next_path_pos := nav_agent.get_next_path_position()
	if nav_agent.is_navigation_finished():
		_stop_moving()
		return true

	var direction := next_path_pos - global_position
	direction.y = 0.0
	var desired := direction.normalized() * speed
	if nav_agent.avoidance_enabled:
		nav_agent.velocity = desired
	else:
		_apply_horizontal_velocity(desired)
	return false

func _stop_moving() -> void:
	if nav_agent.avoidance_enabled:
		nav_agent.velocity = Vector3.ZERO
	_apply_horizontal_velocity(Vector3.ZERO)

## Só mexe em X/Z: o Y fica com a física (gravidade, rampas, knockback).
func _apply_horizontal_velocity(v: Vector3) -> void:
	linear_velocity.x = v.x
	linear_velocity.z = v.z

func _face_target() -> void:
	if _has_valid_target():
		var p := target.global_position
		if Vector2(p.x - global_position.x, p.z - global_position.z).length() > 0.05:
			look_at(Vector3(p.x, global_position.y, p.z), Vector3.UP, true)

func _face_movement() -> void:
	var v := Vector3(linear_velocity.x, 0.0, linear_velocity.z)
	if v.length() > 0.1:
		look_at(global_position + v, Vector3.UP, true)
#endregion

func take_damage(amount: float) -> void:
	# Levar dano sempre alerta (ex: tiro pelas costas, fora do ângulo de visão).
	if _has_valid_target():
		_last_known_position = target.global_position
		_time_since_seen = 0.0
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

		EnemyState.SEARCHING:
			if current_state == EnemyState.DEAD:
				return
			_pre_state_change(new_state)
			_search_timer = search_time
			_play_anim("patrol", true)
			resume_idle_sounds()
 
		EnemyState.CHASING:
			if current_state == EnemyState.DEAD:
				return
			_pre_state_change(new_state)
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
			_stop_moving()
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
	_attack_cooldown_left = attack_cooldown
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
 
## Pode atacar agora: dentro do attack_range e com linha de visão.
func target_is_in_range() -> bool:
	if not _has_valid_target():
		return false
	if global_position.distance_to(target.global_position) > attack_range:
		return false
	return has_line_of_sight()

func check_is_floating() -> void:
	is_floating = not ground_raycast.is_colliding()
 
# Ainda conectados na cena (SightArea). Não fazem mais nada — quando apagarem o nó SightArea das
# cenas dos inimigos, podem apagar essas duas funções também.
func _on_sight_area_body_entered(_body: Node) -> void:
	pass

func _on_sight_area_body_exited(_body: Node) -> void:
	pass

## Velocidade SEGURA devolvida pelo avoidance (ver _move_to). Só aplica nos estados em que o
## inimigo está andando por conta própria, e só em X/Z.
func _on_velocity_computed(safe_velocity: Vector3) -> void:
	if current_state in [EnemyState.CHASING, EnemyState.PATROLLING, EnemyState.SEARCHING]:
		_apply_horizontal_velocity(safe_velocity)
 
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
