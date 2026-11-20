extends Node3D
class_name PatrolRoute

@export var route_name: String = ""

@export var loop: bool = true

func _ready() -> void:
	if route_name != "":
		add_to_group(route_name)
	else:
		push_warning(str(name) + ": PatrolRoute sem route_name.")

func get_waypoints() -> Array:
	var points: Array = []
	for child in get_children():
		if child is Marker3D:
			points.append(child.global_position)
	return points
