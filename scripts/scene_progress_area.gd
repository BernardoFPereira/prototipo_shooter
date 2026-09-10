extends Area3D

@export var level_to_load: PackedScene
@export var is_final_level: bool

func _on_body_entered(body):
	if body is Player:
		body.next_level(level_to_load)
		#get_tree().change_scene_to_packed(level_to_load)
