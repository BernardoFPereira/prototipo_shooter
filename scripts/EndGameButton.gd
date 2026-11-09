extends TextureButton

var main_menu_scene: PackedScene = preload("res://Scenes/Maps/MainMenu.tscn")

func _on_button_down():
	get_tree().change_scene_to_packed(main_menu_scene)
