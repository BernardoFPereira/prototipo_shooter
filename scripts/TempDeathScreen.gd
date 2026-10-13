extends Control

const MAIN_MENU = preload("res://Scenes/Maps/MainMenu.tscn")



# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass


# CONTINUE
func _on_texture_button_button_up():
	get_tree().reload_current_scene()
	pass # Replace with function body.

# QUIT TO MENU
func _on_texture_button_2_button_down():
	get_tree().change_scene_to_packed(MAIN_MENU)
	pass # Replace with function body.
