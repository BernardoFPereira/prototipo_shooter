class_name MainMenu
extends Control

#region MAIN MENU VARIABLES
const plain_background: Texture2D = preload("uid://d3cmexsyvqeow")
const credits_background: Texture2D = preload("uid://cr6rlefuxcgye")
const quit_background: Texture2D = preload("uid://doesa2icl3m3e")
@onready var quit_group = $Background/MainPanel/QuitGroup
@onready var active_background = $Background/MainPanel/ActiveBackground
@onready var play_button = $Background/MainPanel/PlayButton
@onready var config_button = $Background/MainPanel/ConfigButton
@onready var ctrls_button = $Background/MainPanel/ControlsButton
@onready var credits_button = $Background/MainPanel/CreditsButton
@onready var quit_button = $Background/MainPanel/QuitButton
@onready var really_quit_button = $Background/MainPanel/QuitGroup/Yes

#endregion

#region CONFIGURATION VARIABLES
const config_background = preload("uid://dg6ppk1tadlyx")
const res_button_selected_texture = preload("uid://cev240nhyxski")
const off_button_texture = preload("uid://cp8sjbs1efomi")
const on_button_texture = preload("uid://bo5sjwobb2r68")
const res_button = preload("uid://bjlxctidiwjf3")

@onready var config_group = $Background/MainPanel/ConfigGroup
@onready var windowed_button = $Background/MainPanel/ConfigGroup/WindowMode/WindowedButton
@onready var fullscreen_button = $Background/MainPanel/ConfigGroup/WindowMode/FullscreenButton
@onready var music_bar = $Background/MainPanel/ConfigGroup/Audio/MusicBar
@onready var music_slider = $Background/MainPanel/ConfigGroup/Audio/MusicSlider
@onready var toggle_music_button = $Background/MainPanel/ConfigGroup/Audio/ToggleMusicButton
@onready var sfx_bar = $Background/MainPanel/ConfigGroup/Audio/SFXBar
@onready var sfx_slider = $Background/MainPanel/ConfigGroup/Audio/SFXSlider
@onready var toggle_sfx_button = $Background/MainPanel/ConfigGroup/Audio/ToggleSFXButton
@onready var hud_bar = $Background/MainPanel/ConfigGroup/Audio/HUDBar
@onready var hud_slider = $Background/MainPanel/ConfigGroup/Audio/HUDSlider
@onready var toggle_hudsfx_button = $Background/MainPanel/ConfigGroup/Audio/ToggleHUDSFXButton
@onready var resolutions_list = $Background/MainPanel/ConfigGroup/Resolution/ResolutionOptions/ResolutionVBox
@onready var sens_bar = $Background/MainPanel/ConfigGroup/MouseSens/SensBar
@onready var sens_slider = $Background/MainPanel/ConfigGroup/MouseSens/SensSlider

#endregion

#region CONTROLS VARIABLES
const ctrls_key_background = preload("uid://4yexgr2qbd41")
const ctrls_joy_background = preload("uid://nb4doc1n4fhh")
@onready var ctrls_group = $Background/MainPanel/ControlsGroup
@onready var keyboard_button = $Background/MainPanel/ControlsGroup/KeyboardButton
@onready var joystick_button = $Background/MainPanel/ControlsGroup/JoystickButton
#endregion

var level_scene: PackedScene = load("uid://ij2y5aqlc1dt")
var resolution_button_group: ButtonGroup

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	
	active_background.texture = null
	
	add_resolutions()
	update_button_values()
	
	setup_window_mode_buttons()
	setup_audio_buttons()
	
	config_group.visible = false
	ctrls_group.visible = false

func _on_play_pressed() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	get_tree().change_scene_to_packed(level_scene)
	UI.play_sound("confirm_button")
	UI.save_settings()

func _on_quit_pressed() -> void:
	UI.save_settings()
	UI.play_sound("back_button")
	get_tree().quit(0)

#region CONFIGURATION
func setup_window_mode_buttons() -> void:
	var window_mode_group = ButtonGroup.new()
	windowed_button.button_group = window_mode_group
	fullscreen_button.button_group = window_mode_group
	
	windowed_button.button_pressed = not UI.is_fullscreen
	fullscreen_button.button_pressed = UI.is_fullscreen
	
	windowed_button.toggled.connect(_on_windowed_button_toggled)
	fullscreen_button.toggled.connect(_on_fullscreen_button_toggled)

func setup_audio_buttons() -> void:
	var music_slider_value = UI.db_to_slider(UI.music_volume) if not UI.music_muted else 0
	var sfx_slider_value = UI.db_to_slider(UI.sfx_volume) if not UI.sfx_muted else 0
	var hud_slider_value = UI.db_to_slider(UI.hud_volume) if not UI.hud_muted else 0
	
	music_slider.value = music_slider_value
	sfx_slider.value = sfx_slider_value
	hud_slider.value = hud_slider_value
	
	toggle_music_button.button_pressed = not UI.music_muted
	toggle_sfx_button.button_pressed = not UI.sfx_muted
	toggle_hudsfx_button.button_pressed = not UI.hud_muted
	
	_on_music_slider_value_changed(music_slider_value)
	_on_sfx_slider_value_changed(sfx_slider_value)
	_on_hud_slider_value_changed(hud_slider_value)

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

func _on_music_slider_value_changed(value: float) -> void:
	var mapped_db = UI.slider_to_db(value)
	
	music_bar.value = value
	
	if value <= 0:
		if not UI.music_muted:
			toggle_music_button.button_pressed = false
			_on_toggle_music_button_toggled(false)
	else:
		if UI.music_muted:
			toggle_music_button.button_pressed = true
			_on_toggle_music_button_toggled(true)
		
		if toggle_music_button.button_pressed:
			UI.music_volume = mapped_db
			AudioServer.set_bus_volume_db(UI.AudioBus.MUSIC, mapped_db)
		else:
			UI.music_volume = mapped_db

func _on_sfx_slider_value_changed(value: float) -> void:
	var mapped_db = UI.slider_to_db(value)
	
	sfx_bar.value = value
	
	if value <= 0:
		if not UI.sfx_muted:
			toggle_sfx_button.button_pressed = false
			_on_toggle_sfx_button_toggled(false)
	else:
		if UI.sfx_muted:
			toggle_sfx_button.button_pressed = true
			_on_toggle_sfx_button_toggled(true)
		
		if toggle_sfx_button.button_pressed:
			UI.sfx_volume = mapped_db
			AudioServer.set_bus_volume_db(UI.AudioBus.SFX, mapped_db)
		else:
			UI.sfx_volume = mapped_db

func _on_hud_slider_value_changed(value: float) -> void:
	var mapped_db = UI.slider_to_db(value)
	
	hud_bar.value = value
	
	if value <= 0:
		if not UI.hud_muted:
			toggle_hudsfx_button.button_pressed = false
			_on_toggle_hudsfx_button_toggled(false)
	else:
		if UI.hud_muted:
			toggle_hudsfx_button.button_pressed = true
			_on_toggle_hudsfx_button_toggled(true)
		
		if toggle_hudsfx_button.button_pressed:
			UI.hud_volume = mapped_db
			AudioServer.set_bus_volume_db(UI.AudioBus.HUD, mapped_db)
		else:
			UI.hud_volume = mapped_db


func _on_toggle_music_button_toggled(toggled_on: bool) -> void:
	if toggled_on:
		var current_slider_value = music_slider.value
		if current_slider_value <= 0:
			music_slider.value = 1
			current_slider_value = 1
		
		AudioServer.set_bus_volume_db(UI.AudioBus.MUSIC, UI.slider_to_db(current_slider_value))
		toggle_music_button.icon = on_button_texture
		UI.music_muted = false
		UI.play_sound("confirm_button")
	else:
		UI.music_volume = AudioServer.get_bus_volume_db(UI.AudioBus.MUSIC)
		AudioServer.set_bus_volume_db(UI.AudioBus.MUSIC, UI.MIN_DB)
		toggle_music_button.icon = off_button_texture
		UI.music_muted = true
		UI.play_sound("back_button")

func _on_toggle_sfx_button_toggled(toggled_on: bool) -> void:
	if toggled_on:
		var current_slider_value = sfx_slider.value
		if current_slider_value <= 0:
			sfx_slider.value = 1
			current_slider_value = 1
		
		AudioServer.set_bus_volume_db(UI.AudioBus.SFX, UI.slider_to_db(current_slider_value))
		toggle_sfx_button.icon = on_button_texture
		UI.sfx_muted = false
		UI.play_sound("confirm_button")
	else:
		UI.sfx_volume = AudioServer.get_bus_volume_db(UI.AudioBus.SFX)
		AudioServer.set_bus_volume_db(UI.AudioBus.SFX, UI.MIN_DB)
		toggle_sfx_button.icon = off_button_texture
		UI.sfx_muted = true
		UI.play_sound("back_button")

func _on_toggle_hudsfx_button_toggled(toggled_on: bool) -> void:
	if toggled_on:
		var current_slider_value = hud_slider.value
		if current_slider_value <= 0:
			hud_slider.value = 1
			current_slider_value = 1
		
		AudioServer.set_bus_volume_db(UI.AudioBus.HUD, UI.slider_to_db(current_slider_value))
		toggle_hudsfx_button.icon = on_button_texture
		UI.hud_muted = false
		UI.play_sound("confirm_button")
	else:
		UI.hud_volume = AudioServer.get_bus_volume_db(UI.AudioBus.HUD)
		AudioServer.set_bus_volume_db(UI.AudioBus.HUD, UI.MIN_DB)
		toggle_hudsfx_button.icon = off_button_texture
		UI.hud_muted = true
		UI.play_sound("back_button")


func _on_windowed_button_toggled(toggled_on: bool) -> void:
	if toggled_on:
		UI.is_fullscreen = false
		get_window().mode = Window.MODE_WINDOWED
		get_window().size = UI.current_resolution
		UI.play_sound("confirm_button")
		windowed_button.mouse_filter = MOUSE_FILTER_IGNORE
		UI.center_window()
		update_button_values()
		set_resolution_buttons_enabled(true)
	else:
		windowed_button.mouse_filter = MOUSE_FILTER_PASS

func _on_fullscreen_button_toggled(toggled_on: bool) -> void:
	if toggled_on:
		UI.is_fullscreen = true
		UI.play_sound("confirm_button")
		fullscreen_button.mouse_filter = MOUSE_FILTER_IGNORE
		get_window().mode = Window.MODE_EXCLUSIVE_FULLSCREEN
		set_resolution_buttons_enabled(false)
	else:
		fullscreen_button.mouse_filter = MOUSE_FILTER_PASS

func _on_resolution_button_pressed(resolution_key: String) -> void:
	if get_window().mode == Window.MODE_EXCLUSIVE_FULLSCREEN:
		return
	
	if UI.resolutions.has(resolution_key):
		UI.current_resolution = UI.resolutions[resolution_key]
		get_window().size = UI.current_resolution
		UI.center_window()
		UI.play_sound("confirm_button")
		update_button_values()

func add_resolutions() -> void:
	resolution_button_group = ButtonGroup.new()
	
	var index = 0
	for r in UI.resolutions:
		var new_button = res_button.instantiate()
		new_button.text = r
		new_button.name = "ResolutionButton" + str(index)
		new_button.button_group = resolution_button_group
		new_button.pressed.connect(_on_resolution_button_pressed.bind(r))
		new_button.mouse_entered.connect(_on_button_hovered)
		resolutions_list.add_child(new_button)
		index += 1
	update_button_values()
	set_resolution_buttons_enabled(!UI.is_fullscreen)

func update_button_values() -> void:
	var window_size_str = str(get_window().size.x, "x", get_window().size.y)
	var resolutions_index = UI.resolutions.keys().find(window_size_str)
	
	if resolutions_index == -1:
		window_size_str = "1920x1080"
		resolutions_index = UI.resolutions.keys().find(window_size_str)

	var button_name = "ResolutionButton" + str(resolutions_index)
	var selected_button = resolutions_list.get_node(button_name)
	
	if selected_button:
		selected_button.button_pressed = true

func set_resolution_buttons_enabled(enabled: bool) -> void:
	for button in resolutions_list.get_children():
		button.disabled = not enabled
		if enabled:
			button.mouse_filter = MOUSE_FILTER_PASS
		else:
			button.mouse_filter = MOUSE_FILTER_IGNORE

func _on_sens_slider_value_changed(value):
	sens_bar.value = value

func _on_button_hovered():
	UI.play_sound("hover_button")
#endregion

#region CONTROLS
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
#endregion

#region CREDITS
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
#endregion

#region QUIT
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
#endregion


