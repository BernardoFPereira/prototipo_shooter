extends Camera3D

@export var cam_target: Player

var height_offset: float = 14

func _ready():
	pass


func _process(delta):
	global_position = Vector3(cam_target.global_position.x, cam_target.global_position.y + height_offset, cam_target.global_position.z)
	rotation.y = cam_target.rotation.y
	pass
