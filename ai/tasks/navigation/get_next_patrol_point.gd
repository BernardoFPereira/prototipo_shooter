@tool
extends BTAction

## GetNextPatrolPoint
##
## Cicla pelos filhos (Marker3D ou qualquer Node3D) de points_container_path,
## guardando a posição do próximo ponto em blackboard[position_var] e avançando
## o índice em blackboard[index_var]. Retorna SUCCESS ao escolher um ponto,
## FAILURE se o container não existir ou não tiver filhos.
##
## Dica: use um Node3D vazio chamado "PatrolPoints" com Marker3D como filhos,
## posicionados no editor. Não use Path3D/PathFollow3D - o NavigationAgent3D
## já cuida do caminho até cada ponto, então não há necessidade de interpolar
## ao longo de uma curva.

@export var points_container_path: NodePath
@export var position_var: StringName = &"patrol_target"
@export var index_var: StringName = &"patrol_index"


func _generate_name() -> String:
	return "GetNextPatrolPoint  from: %s" % [points_container_path]


func _tick(_delta: float) -> Status:
	var body: Node = agent
	var container: Node = body.get_node_or_null(points_container_path)
	if container == null or container.get_child_count() == 0:
		return FAILURE

	var count: int = container.get_child_count()
	var index: int = int(blackboard.get_var(index_var, 0))
	if index < 0 or index >= count:
		index = 0

	var point_node: Node3D = container.get_child(index)
	blackboard.set_var(position_var, point_node.global_position)
	blackboard.set_var(index_var, (index + 1) % count)
	return SUCCESS
