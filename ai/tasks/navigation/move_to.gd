@tool
extends BTAction

## MoveTo
##
## Move o agente usando NavigationAgent3D (com avoidance). O destino pode vir de:
##   - target_node_var: um Node3D no blackboard (perseguição - reavaliado a cada tick,
##     então funciona mesmo se o alvo estiver se movendo)
##   - target_position_var: um Vector3 no blackboard (patrulha / roaming)
## Se target_node_var estiver preenchido e válido, ele tem prioridade sobre
## target_position_var.
##
## Este task NÃO chama move_and_slide() nem aplica gravidade - ele só define a
## velocidade desejada via nav_agent.set_velocity(), que dispara o cálculo de
## avoidance de forma assíncrona. Quem aplica a velocidade final (safe_velocity)
## e chama move_and_slide() é o _physics_process() do MeleeAgent, através do
## sinal "velocity_computed" do NavigationAgent3D. Veja MeleeAgent.gd.
##
## Retorna RUNNING enquanto viaja, SUCCESS ao chegar (is_navigation_finished),
## FAILURE se nenhum destino válido foi encontrado.

@export var target_node_var: StringName = &""
@export var target_position_var: StringName = &""
@export var speed: float = 4.0
@export var rotate_to_face_direction: bool = true
@export var rotation_speed: float = 8.0
## Nome de uma animação em loop pra tocar enquanto se move (ex.: "chase", "patrol").
## Deixe vazio para não mexer na animação.
@export var movement_animation: String = ""

var _nav_agent: NavigationAgent3D
var _anim_player: AnimationPlayer
var _has_destination: bool = false


func _generate_name() -> String:
	var source := LimboUtility.decorate_var(target_node_var) if target_node_var != &"" \
		else LimboUtility.decorate_var(target_position_var)
	return "MoveTo %s  speed: %s" % [source, speed]


func _setup() -> void:
	_nav_agent = agent.get_node("NavigationAgent3D")
	_anim_player = agent.get_node_or_null("AnimationPlayer")


func _enter() -> void:
	_update_destination()
	if _has_destination and movement_animation != "" and is_instance_valid(_anim_player):
		_anim_player.play(movement_animation)


func _tick(delta: float) -> Status:
	_update_destination()

	if not _has_destination:
		return FAILURE

	if _nav_agent.is_navigation_finished():
		return SUCCESS

	var body: Node3D = agent as Node3D
	var next_pos: Vector3 = _nav_agent.get_next_path_position()
	var to_next: Vector3 = next_pos - body.global_position
	to_next.y = 0.0

	var direction: Vector3 = Vector3.ZERO
	if to_next.length() > 0.01:
		direction = to_next.normalized()

	_nav_agent.set_velocity(direction * speed)

	if rotate_to_face_direction and direction.length() > 0.01:
		var target_angle: float = atan2(direction.x, direction.z)
		body.rotation.y = lerp_angle(body.rotation.y, target_angle, delta * rotation_speed)

	return RUNNING


func _exit() -> void:
	# Zera a velocidade desejada para não deixar o agente "deslizando" quando
	# esta task é interrompida (ex.: tomou dano no meio da perseguição).
	if is_instance_valid(_nav_agent):
		_nav_agent.set_velocity(Vector3.ZERO)


func _update_destination() -> void:
	_has_destination = false

	if target_node_var != &"":
		var target_node: Node3D = blackboard.get_var(target_node_var, null)
		if is_instance_valid(target_node):
			_nav_agent.target_position = target_node.global_position
			_has_destination = true
			return

	if target_position_var != &"":
		var pos: Variant = blackboard.get_var(target_position_var, null)
		if pos != null and pos is Vector3:
			_nav_agent.target_position = pos
			_has_destination = true
