class_name PauseMenu
extends Control

@onready var player: Player = get_tree().get_first_node_in_group("player")
@onready var game_hud_canvas: Control = player.game_hud_canvas
@onready var menu_canvas: Control = self


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_toggle_pause_menu()

func _toggle_pause_menu() -> void:
	if get_tree().paused:
		get_tree().paused = false
		menu_canvas.visible = false
		game_hud_canvas.visible = true
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	else:
		get_tree().paused = true
		menu_canvas.visible = true
		game_hud_canvas.visible = false
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _on_resume_button_pressed() -> void:
	get_tree().paused = false
	menu_canvas.visible = false
	game_hud_canvas.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _on_menu_button_pressed() -> void:
	get_tree().paused = false
	UI.save_settings()
	get_tree().change_scene_to_packed(load("uid://d2rqkagxvdfhw"))
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
