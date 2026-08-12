@tool
extends BTAction

## GetRandomPoint
##
## Godot 4.2 não tem NavigationServer3D.map_get_random_point() (só foi
## adicionado em versões posteriores). Em vez disso: gera um ponto aleatório
## dentro de roam_radius a partir de blackboard[origin_var] (ou da posição
## atual do agente) e usa map_get_closest_point() para "encaixar" esse ponto
## na navmesh mais próxima. Guarda o resultado em blackboard[position_var].
## Sempre retorna SUCCESS.

@export var roam_radius: float = 8.0
@export var position_var: StringName = &"roam_target"
@export var origin_var: StringName = &"spawn_position"
@export var max_attempts: int = 8


func _generate_name() -> String:
	return "GetRandomPoint  radius: %s -> %s" % [roam_radius, LimboUtility.decorate_var(position_var)]


func _tick(_delta: float) -> Status:
	var body: Node3D = agent as Node3D
	var origin: Vector3 = blackboard.get_var(origin_var, body.global_position)
	var map_rid: RID = body.get_world_3d().navigation_map

	var point: Vector3 = origin
	for i in range(max_attempts):
		var random_offset := Vector3(
			randf_range(-roam_radius, roam_radius),
			0.0,
			randf_range(-roam_radius, roam_radius)
		)
		if random_offset.length() > roam_radius:
			continue

		var raw_point: Vector3 = origin + random_offset
		var snapped: Vector3 = NavigationServer3D.map_get_closest_point(map_rid, raw_point)

		if origin.distance_to(snapped) <= roam_radius * 1.2:
			point = snapped
			break
		point = snapped  # fallback: usa a última tentativa mesmo se um pouco fora do raio

	blackboard.set_var(position_var, point)
	return SUCCESS
