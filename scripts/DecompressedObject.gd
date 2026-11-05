extends StaticBody3D
class_name DecompressedObject

@export var move_target: Marker3D

func _ready():
	move_target = get_tree().get_first_node_in_group("DecompressMoveTarget")

func _process(delta):
	global_position = global_position.lerp(move_target.global_position, delta * 2)
