@tool
extends BTCondition

## InAttackRange
##
## Retorna SUCCESS se blackboard[target_var] existir e estiver a uma distância
## <= attack_range do agente. Retorna FAILURE caso contrário (alvo nulo ou longe).

@export var attack_range: float = 2.0
@export var target_var: StringName = &"target"


func _generate_name() -> String:
	return "InAttackRange (%s) of %s" % [attack_range, LimboUtility.decorate_var(target_var)]


func _tick(_delta: float) -> Status:
	var target: Node3D = blackboard.get_var(target_var, null)
	if not is_instance_valid(target):
		return FAILURE

	var body: Node3D = agent as Node3D
	var dist: float = body.global_position.distance_to(target.global_position)
	return SUCCESS if dist <= attack_range else FAILURE
