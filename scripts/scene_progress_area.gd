extends Area3D

@onready var level_complete_screen = $LevelCompleteScreen

@export var level_to_load: PackedScene = null
@export var is_final_level: bool = false

var main_menu_scene = load("uid://d2rqkagxvdfhw")
var first_level = load("uid://cw50tmi4jwwv4")

func load_next_level(level_to_load):
	get_tree().change_scene_to_packed(level_to_load)

func _on_body_entered(body):
	if body is Player:
		#body.get_node("GameHUD").visible = false
		body.process_mode = Node.PROCESS_MODE_DISABLED
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		level_complete_screen.visible = true

func _on_continue_button_down():
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	
	UI.is_introduction = false
	UI.is_walk_introduction = false
	UI.is_fire_introduction = false
	
	if is_final_level:
		UI.save_settings()
		get_tree().change_scene_to_packed(first_level)
		return
		
	UI.save_settings()
	load_next_level(level_to_load)

func _on_quit_button_down():
	get_tree().change_scene_to_packed(main_menu_scene)
