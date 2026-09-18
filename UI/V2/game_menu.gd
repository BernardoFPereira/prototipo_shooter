class_name GameMenu
extends CanvasLayer

enum Context { MAIN_MENU, PAUSE_MENU }

const config_background = preload("uid://beg6jpulxo7uw")
const ctrls_key_background = preload("uid://bmu1oequesbqo")
const credits_background = preload("uid://cr6rlefuxcgye")
const quit_background = preload("uid://dmel4nekr0nx4")

@onready var active_background = $Background/MainPanel/ActiveBackground
@onready var title_label = $Background/MainPanel/TitleLabel

@onready var play_button = $Background/MainPanel/VBoxContainer/PlayButton
@onready var resume_button = $Background/MainPanel/VBoxContainer/ResumeButton
@onready var retry_button = $Background/MainPanel/VBoxContainer/RetryButton
@onready var config_button = $Background/MainPanel/VBoxContainer/ConfigButton
@onready var ctrls_button = $Background/MainPanel/VBoxContainer/ControlsButton
@onready var credits_button = $Background/MainPanel/VBoxContainer/CreditsButton
@onready var quit_button = $Background/MainPanel/VBoxContainer/QuitButton

@onready var config_group = $Background/MainPanel/ConfigGroup
@onready var ctrls_group = $Background/MainPanel/ControlsGroup
@onready var quit_group = $Background/MainPanel/QuitGroup

@onready var settings_panel: SettingsPanel = config_group

var context: Context = Context.MAIN_MENU
var current_player: Player = null

var level_scene: PackedScene = load("uid://cw50tmi4jwwv4")
var menu_scene: PackedScene = load("uid://d2rqkagxvdfhw")


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	settings_panel.setup()
	config_group.visible = false
	ctrls_group.visible = false
	quit_group.visible = false
	active_background.texture = null
	visible = false


func _unhandled_input(event: InputEvent) -> void:
	if context == Context.PAUSE_MENU and event.is_action_pressed("ui_cancel"):
		if visible:
			close_pause_menu()
		else:
			_open_pause_menu()


#region CONTEXT SWITCHING
func open_as_main_menu() -> void:
	context = Context.MAIN_MENU
	current_player = null

	title_label.text = "MENU PRINCIPAL"
	play_button.visible = true
	resume_button.visible = false
	retry_button.visible = false
	credits_button.visible = true

	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	#UI.is_introduction = false
	#UI.is_walk_introduction = false
	#UI.is_fire_introduction = false
	visible = true
	_reset_groups()

func enter_gameplay_context(player: Player) -> void:
	context = Context.PAUSE_MENU
	current_player = player
	visible = false
	get_tree().paused = false

func _open_pause_menu() -> void:
	title_label.text = "PAUSE"
	play_button.visible = false
	resume_button.visible = true
	retry_button.visible = true
	credits_button.visible = false

	if current_player:
		current_player.game_hud_canvas.visible = false

	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	visible = true
	_reset_groups()

func close_pause_menu() -> void:
	visible = false
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	if current_player:
		current_player.game_hud_canvas.visible = true

	_reset_groups()

func _reset_groups() -> void:
	config_group.visible = false
	ctrls_group.visible = false
	quit_group.visible = false
	active_background.texture = null
	config_button.button_pressed = false
	ctrls_button.button_pressed = false
	credits_button.button_pressed = false
	quit_button.button_pressed = false
#endregion


#region BUTTON HANDLERS
func _on_play_pressed() -> void:
	UI.play_sound("confirm_button")
	UI.save_settings()
	visible = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	get_tree().change_scene_to_packed(level_scene)

func _on_resume_button_pressed() -> void:
	UI.play_sound("confirm_button")
	close_pause_menu()

func _on_retry_button_pressed() -> void:
	UI.play_sound("confirm_button")
	get_tree().paused = false
	visible = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	get_tree().reload_current_scene()

func _on_config_button_toggled(toggled_on: bool) -> void:
	if toggled_on:
		config_group.visible = true
		ctrls_group.visible = false
		ctrls_button.button_pressed = false
		credits_button.button_pressed = false
		quit_group.visible = false
		quit_button.button_pressed = false
		active_background.texture = config_background
		UI.play_sound("confirm_button")
	else:
		config_group.visible = false
		active_background.texture = null
		UI.play_sound("back_button")
		UI.save_settings()

func _on_ctrls_button_toggled(toggled_on: bool) -> void:
	if toggled_on:
		ctrls_group.visible = true
		config_group.visible = false
		config_button.button_pressed = false
		credits_button.button_pressed = false
		quit_group.visible = false
		quit_button.button_pressed = false
		active_background.texture = ctrls_key_background
		UI.play_sound("confirm_button")
	else:
		ctrls_group.visible = false
		active_background.texture = null
		UI.play_sound("back_button")

func _on_credits_button_toggled(toggled_on: bool) -> void:
	if toggled_on:
		config_group.visible = false
		config_button.button_pressed = false
		ctrls_group.visible = false
		ctrls_button.button_pressed = false
		quit_group.visible = false
		quit_button.button_pressed = false
		active_background.texture = credits_background
		UI.play_sound("confirm_button")
	else:
		active_background.texture = null
		UI.play_sound("back_button")

func _on_quit_button_toggled(toggled_on: bool) -> void:
	if toggled_on:
		quit_group.visible = true
		config_group.visible = false
		config_button.button_pressed = false
		ctrls_group.visible = false
		ctrls_button.button_pressed = false
		credits_button.button_pressed = false
		active_background.texture = quit_background
		UI.play_sound("confirm_button")
	else:
		quit_group.visible = false
		active_background.texture = null
		UI.play_sound("back_button")
		UI.save_settings()

func _on_really_quit_pressed() -> void:
	UI.save_settings()
	UI.play_sound("back_button")

	if context == Context.MAIN_MENU:
		get_tree().quit(0)
	else:
		get_tree().paused = false
		visible = false
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		get_tree().change_scene_to_packed(menu_scene)
#endregion
