extends RigidBody3D
class_name DecompressedEnemy

@onready var animation_player = $AnimationPlayer
var current_move_target: Marker3D
#var move_target_1: Marker3D

func _ready():
	animation_player.play("hit")
	current_move_target = get_tree().get_first_node_in_group("DecompressMoveTarget")

func _process(delta):
	global_position = global_position.slerp(current_move_target.global_position, delta)
