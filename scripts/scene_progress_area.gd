extends Area3D

@export var level_to_load: PackedScene
@export var is_final_level: bool
var main_menu_scene = load("uid://d2rqkagxvdfhw")

func _on_body_entered(body):
	if body is Player:
		body.next_level(level_to_load)
		if is_final_level:
			body.next_level(main_menu_scene)
			#get_tree().change_scene_to_packed(main_menu_scene)
		#get_tree().change_scene_to_packed(level_to_load)
