extends Area3D

@onready var level_complete_screen = $LevelCompleteScreen

@export var level_to_load: PackedScene = null
@export var next_level_name: String = ""
@export var is_final_level: bool = false

const MAIN_MENU_SCENE: String = "uid://d2rqkagxvdfhw"
const FIRST_LEVEL_SCENE: String = "uid://cw50tmi4jwwv4"

func load_next_level(level_to_load):
	SceneLoader.change_scene(level_to_load, next_level_name)

func _on_body_entered(body):
	if body is Player:
		body.process_mode = Node.PROCESS_MODE_DISABLED
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		level_complete_screen.visible = true

func _on_continue_button_down():
	UI.is_introduction = false
	UI.is_walk_introduction = false
	UI.is_fire_introduction = false

	if is_final_level:
		UI.save_settings()
		SceneLoader.change_scene(FIRST_LEVEL_SCENE, SceneLoader.first_level_name)
		return

	UI.save_settings()
	load_next_level(level_to_load)

func _on_quit_button_down():
	SceneLoader.go_to_main_menu(MAIN_MENU_SCENE)
