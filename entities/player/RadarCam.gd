extends Camera3D

@export var cam_target: Player

var height_offset: float = 14

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	global_position = Vector3(cam_target.global_position.x, cam_target.global_position.y + height_offset, cam_target.global_position.z) 
	rotation.y = cam_target.rotation.y
	pass
