class_name MeleeAgent
extends CharacterBody3D

## MeleeAgent
##
## Substitui o antigo EnemyMelee. Toda a decisão de comportamento fica na
## Behavior Tree (nó "BehaviourTree", um BTPlayer). Este script cuida do que
## a BT não deve cuidar: física (gravidade, move_and_slide), avoidance do
## NavigationAgent3D, e reagir a dano/morte escrevendo flags que a BT lê.

#region EXPORT VARS
@export_category("Health")
@export var max_health: float = 60.0

@export_category("Combat")
@export var attack_range: float = 2.0
@export var melee_damage: float = 15.0

@export_category("Vision")
@export var view_range: float = 12.0
@export var view_angle_degrees: float = 100.0

@export_category("Movement")
@export var chase_speed: float = 4.5
@export var patrol_speed: float = 2.0
@export var gravity: float = 20.0
@export var knockback_resistance: float = 0.5  # 0 = ignora impacto, 1 = full impacto

@export_category("Idle Behavior")
## Ative só UM destes três no editor, por instância do inimigo.
@export var is_idle: bool = true
@export var is_roaming: bool = false
@export var is_patrolling: bool = false
@export var roam_radius: float = 8.0
## Necessário apenas se is_patrolling = true. Aponte para um Node3D cujos
## filhos (Marker3D) são os pontos de patrulha, na ordem desejada.
@export var patrol_points_path: NodePath
#endregion

#region STATE (lido/escrito pela Behavior Tree via BTCheckAgentProperty / BTSetAgentProperty)
var current_health: float
var is_dead: bool = false
var death_anim_played: bool = false
#endregion

#region NODES
@onready var nav_agent: NavigationAgent3D = $NavigationAgent3D
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var bt_player: BTPlayer = $BehaviourTree
var blood_particles_scene = preload("uid://dauurgt5mibfk")
#endregion

var _spawn_position: Vector3


func _ready() -> void:
	current_health = max_health
	_spawn_position = global_position

	# Avoidance: a MoveTo task só pede uma velocidade via nav_agent.set_velocity().
	# O NavigationServer calcula a velocidade "segura" (evitando outros agentes)
	# de forma assíncrona e entrega aqui.
	nav_agent.velocity_computed.connect(_on_velocity_computed)

	# A BT roda manualmente, sincronizada com a física, para garantir que a
	# velocidade decidida pela BT já esteja pronta antes do move_and_slide().
	bt_player.update_mode = BTPlayer.UpdateMode.MANUAL

	if bt_player.blackboard:
		bt_player.blackboard.set_var(&"spawn_position", _spawn_position)


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = 0.0

	bt_player.update(delta)

	move_and_slide()


func _on_velocity_computed(safe_velocity: Vector3) -> void:
	velocity.x = safe_velocity.x
	velocity.z = safe_velocity.z


#region DAMAGE / DEATH (chamado pelo Player, equivalente ao antigo receive_sword_impact)
func receive_sword_impact(amount: float, source_position: Vector3, impact_strength: float) -> void:
	if is_dead:
		return

	current_health = maxf(current_health - amount, 0.0)

	if current_health <= 0.0:
		is_dead = true
	else:
		# Interrompe a BT no próximo tick: a raiz é um BTDynamicSelector,
		# então a task de "hit" tem prioridade e será verificada antes de
		# qualquer ataque/perseguição em andamento.
		if bt_player.blackboard:
			bt_player.blackboard.set_var(&"hit_trigger", true)

	var knockback_dir: Vector3 = (global_position - source_position)
	knockback_dir.y = 0.0
	if knockback_dir.length() > 0.01:
		knockback_dir = knockback_dir.normalized()
		velocity += knockback_dir * impact_strength * knockback_resistance


func spawn_blood(point: Vector3) -> void:
	var blood_particles: GPUParticles3D = blood_particles_scene.instantiate()
	blood_particles.emitting = true
	get_tree().root.add_child(blood_particles)
	blood_particles.global_position = point
#endregion
