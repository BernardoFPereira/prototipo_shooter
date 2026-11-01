extends RigidBody3D
class_name DecompressedEnemy

@onready var animation_player = $AnimationPlayer
var decompress_move_target: Marker3D

# Called when the node enters the scene tree for the first time.
func _ready():
	animation_player.play("hit")
	decompress_move_target = get_tree().get_first_node_in_group("DecompressMoveTarget")
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	global_position = global_position.lerp(decompress_move_target.global_position, delta)
	pass
