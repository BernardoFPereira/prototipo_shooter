@tool
extends BTCondition

## TargetInSight
##
## Usa uma Area3D (com um CollisionShape3D customizado definindo o alcance e o
## formato do cone de visão) para listar candidatos, e depois raycasta contra
## cada um pra verificar se algo (parede etc.) está bloqueando a linha de visão.
##
## Configuração necessária na cena:
##   - A Area3D (ex.: "SightArea3D") deve ter `collision_mask` incluindo a
##     layer de detecção dos alvos (ex.: Layer 10 -> bit 512). `collision_layer`
##     dela pode ficar zerada (ninguém precisa detectar a área em si).
##   - Os alvos (Player, futuros NPCs) precisam estar no grupo "targetable" e
##     ter essa mesma layer ligada na collision_layer deles.
##
## Em caso de sucesso, guarda o alvo em blackboard[target_var] e retorna SUCCESS.
## Em caso de falha, limpa target_var e alerted_var.

@export var sight_area_path: NodePath = ^"SightArea3D"
@export var eye_height: float = 1.5
@export var target_eye_height: float = 1.0
@export_flags_3d_physics var world_collision_mask: int = 1
@export var target_var: StringName = &"target"
@export var alerted_var: StringName = &"is_alerted"

var _sight_area: Area3D


func _generate_name() -> String:
	return "TargetInSight (Area3D) -> %s" % [LimboUtility.decorate_var(target_var)]


func _setup() -> void:
	_sight_area = agent.get_node_or_null(sight_area_path)


func _tick(_delta: float) -> Status:
	if _sight_area == null:
		return FAILURE

	var body: Node3D = agent as Node3D
	var space_state := body.get_world_3d().direct_space_state
	var eye_pos: Vector3 = body.global_position + Vector3.UP * eye_height

	var best_target: Node3D = null
	var best_dist: float = INF

	for candidate in _sight_area.get_overlapping_bodies():
		if not candidate.is_in_group("targetable") or candidate == body:
			continue

		var cand: Node3D = candidate
		var dist: float = body.global_position.distance_to(cand.global_position)
		if dist >= best_dist:
			continue

		var target_point: Vector3 = cand.global_position + Vector3.UP * target_eye_height
		var query := PhysicsRayQueryParameters3D.create(eye_pos, target_point, world_collision_mask)
		query.collide_with_areas = false
		var result := space_state.intersect_ray(query)

		if not result.is_empty():
			continue  # bateu numa parede antes de chegar no alvo -> bloqueado

		best_target = cand
		best_dist = dist

	if is_instance_valid(best_target):
		blackboard.set_var(target_var, best_target)
		return SUCCESS

	blackboard.set_var(target_var, null)
	blackboard.set_var(alerted_var, false)
	return FAILURE
