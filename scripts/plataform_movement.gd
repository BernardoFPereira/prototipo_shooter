extends Node3D

@export var path: Array[Marker3D]
@export var move_speed: float = 10
@export var start_node: int = 0

var current_node: Marker3D
var current_node_idx: int
var target

# Called when the node enters the scene tree for the first time.
func _ready():
	current_node = path[start_node]
	current_node_idx = start_node
	global_position = current_node.global_position
	target = path[current_node_idx + 1]


func _process(delta):
	move_to_next_target(delta * move_speed)

func move_to_next_target(speed):
	print(target)
	current_node_idx = path.find(current_node)
	print(current_node_idx)
	if current_node_idx == len(path) - 1:
		target = path[0]
		current_node_idx = 0
	
	#print(current_node_idx)
	
	global_position = global_position.move_toward(target.global_position, speed)
	if global_position == target.global_position:
		current_node = target
		current_node_idx += 1
		target = path[current_node_idx]
	

#func check_arrival():
	#
