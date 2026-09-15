extends Area3D

@onready var level_complete_screen = $LevelCompleteScreen

@export var level_to_load: PackedScene
@export var is_final_level: bool

var main_menu_scene = load("uid://d2rqkagxvdfhw")

signal continue_button_pressed

#func _ready():
	#continue_button_pressed.connect(_on_continue_button_pressed)
	#pass

func load_next_level(level_to_load):
	get_tree().change_scene_to_packed(level_to_load)

func _on_body_entered(body):
	if body is Player:
		#body.get_node("GameHUD").visible = false
		body.process_mode = Node.PROCESS_MODE_DISABLED
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		level_complete_screen.visible = true
		
		#get_tree().change_scene_to_packed(level_to_load)
		#if is_final_level:
			#get_tree().change_scene_to_packed(main_menu_scene)

#func _on_continue_button_pressed():
	#if is_final_level:
		#get_tree().change_scene_to_packed(main_menu_scene)
		#return
	#
	#load_next_level(level_to_load)

func _on_continue_button_down():
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if is_final_level:
		get_tree().change_scene_to_packed(main_menu_scene)
		return
	
	load_next_level(level_to_load)

func _on_quit_button_down():
	get_tree().change_scene_to_packed(main_menu_scene)
