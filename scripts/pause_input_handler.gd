extends Node

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS

func _input(event):
	if Input.is_action_just_pressed("ui_cancel"):
		get_parent()._toggle_pause_menu()
