extends Node3D
class_name PatrolRoute
 
@export var route_name: String = ""
 
@export var loop: bool = true
 
func _ready() -> void:
	if route_name != "":
		add_to_group(route_name)
	else:
		push_warning("%s: PatrolRoute sem route_name — nenhum inimigo vai conseguir achar essa rota pelo nome." % name)
 
func get_waypoints() -> Array[Vector3]:
	var points: Array[Vector3] = []
	for child in get_children():
		if child is Marker3D:
			points.append(child.global_position)
	return points
