extends Control


const MAIN_MENU: String = "uid://d2rqkagxvdfhw"


func _on_texture_button_button_up():
	SceneLoader.reload_current_scene()

func _on_texture_button_2_button_down():
	SceneLoader.go_to_main_menu(MAIN_MENU)
