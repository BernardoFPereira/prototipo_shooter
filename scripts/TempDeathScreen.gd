extends Control

## Tela "Tentar novamente" (aparece pelo Player.die(), alguns segundos depois da animação de morte).
## As trocas de cena passam pela tela de load (SceneLoader).

const MAIN_MENU := "uid://d2rqkagxvdfhw" # res://Scenes/Maps/MainMenu.tscn


# CONTINUE
func _on_texture_button_button_up():
	SceneLoader.reload_current_scene()

# QUIT TO MENU
func _on_texture_button_2_button_down():
	SceneLoader.go_to_main_menu(MAIN_MENU)
