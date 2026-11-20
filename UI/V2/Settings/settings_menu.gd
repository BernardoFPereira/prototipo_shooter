class_name SettingsPanel
extends Control


@onready var window_mode_option: OptionButton = %WindowModeOption
@onready var resolution_option: OptionButton = %ResolutionOption
@onready var vsync_check: CheckButton = %VSyncCheck
@onready var max_fps_option: OptionButton = %MaxFpsOption
@onready var fov_slider: HSlider = %FovSlider
@onready var fov_value: Label = %FovValue
@onready var brightness_slider: HSlider = %BrightnessSlider
@onready var brightness_value: Label = %BrightnessValue
@onready var show_fps_check: CheckButton = %ShowFpsCheck
@onready var music_slider: HSlider = %MusicSlider
@onready var music_value: Label = %MusicValue
@onready var music_mute: CheckButton = %MusicMute
@onready var sfx_slider: HSlider = %SFXSlider
@onready var sfx_value: Label = %SFXValue
@onready var sfx_mute: CheckButton = %SFXMute
@onready var hud_slider: HSlider = %HUDSlider
@onready var hud_value: Label = %HUDValue
@onready var hud_mute: CheckButton = %HUDMute
@onready var sens_slider: HSlider = %SensSlider
@onready var sens_value: Label = %SensValue
@onready var invert_y_check: CheckButton = %InvertYCheck
@onready var camera_motion_slider: HSlider = %CameraMotionSlider
@onready var camera_motion_value: Label = %CameraMotionValue

@onready var reset_button: Button = %ResetButton

var _is_setup: bool = false
var _updating: bool = false


func _ready() -> void:
	setup()


func setup() -> void:
	if _is_setup:
		return
	_is_setup = true
	_fill_options()
	_connect_signals()
	refresh_from_settings()


func refresh_from_settings() -> void:
	_updating = true
	window_mode_option.select(UI.window_mode)
	resolution_option.select(maxi(UI.resolutions.keys().find(UI.resolution_key), 0))
	vsync_check.button_pressed = UI.vsync
	max_fps_option.select(maxi(UI.FPS_OPTIONS.find(UI.max_fps), 0))
	fov_slider.value = UI.fov
	brightness_slider.value = UI.brightness * 100.0
	show_fps_check.button_pressed = UI.show_fps
	music_slider.value = UI.music_percent
	sfx_slider.value = UI.sfx_percent
	hud_slider.value = UI.hud_percent
	music_mute.button_pressed = UI.music_muted
	sfx_mute.button_pressed = UI.sfx_muted
	hud_mute.button_pressed = UI.hud_muted
	sens_slider.value = UI.sensitivity_to_slider(UI.mouse_sensitivity)
	invert_y_check.button_pressed = UI.invert_y
	camera_motion_slider.value = UI.camera_motion * 100.0
	_updating = false
	_update_value_labels()


func _fill_options() -> void:
	window_mode_option.clear()
	for mode_name in UI.WINDOW_MODE_NAMES:
		window_mode_option.add_item(mode_name)
	resolution_option.clear()
	for key in UI.resolutions:
		resolution_option.add_item(key)
	max_fps_option.clear()
	for fps in UI.FPS_OPTIONS:
		if fps == 0:
			max_fps_option.add_item("Sem limite")
		else:
			max_fps_option.add_item(str(fps))


func _connect_signals() -> void:
	window_mode_option.item_selected.connect(func(i): _apply(func(): UI.set_window_mode(i)))
	resolution_option.item_selected.connect(func(i): _apply(func(): UI.set_resolution(UI.resolutions.keys()[i])))
	vsync_check.toggled.connect(func(on): _apply(func(): UI.set_vsync(on)))
	max_fps_option.item_selected.connect(func(i): _apply(func(): UI.set_max_fps(UI.FPS_OPTIONS[i])))
	fov_slider.value_changed.connect(func(v): _apply(func(): UI.set_fov(v), false))
	brightness_slider.value_changed.connect(func(v): _apply(func(): UI.set_brightness(v / 100.0), false))
	show_fps_check.toggled.connect(func(on): _apply(func(): UI.set_show_fps(on)))

	music_slider.value_changed.connect(func(v): _apply(func(): UI.set_volume(UI.AudioBus.MUSIC, v), false))
	sfx_slider.value_changed.connect(func(v): _apply(func(): UI.set_volume(UI.AudioBus.SFX, v), false))
	hud_slider.value_changed.connect(func(v): _apply(func(): UI.set_volume(UI.AudioBus.HUD, v), false))
	music_mute.toggled.connect(func(on): _apply(func(): UI.set_muted(UI.AudioBus.MUSIC, on)))
	sfx_mute.toggled.connect(func(on): _apply(func(): UI.set_muted(UI.AudioBus.SFX, on)))
	hud_mute.toggled.connect(func(on): _apply(func(): UI.set_muted(UI.AudioBus.HUD, on)))

	sens_slider.value_changed.connect(func(v): _apply(func(): UI.set_mouse_sensitivity(UI.slider_to_sensitivity(v)), false))
	invert_y_check.toggled.connect(func(on): _apply(func(): UI.set_invert_y(on)))
	camera_motion_slider.value_changed.connect(func(v): _apply(func(): UI.set_camera_motion(v / 100.0), false))

	reset_button.pressed.connect(_on_reset_pressed)

	for control in find_children("*", "Control", true, false):
		if control is BaseButton or control is Slider:
			control.mouse_entered.connect(_on_button_hovered)
		if control is Slider:
			control.drag_ended.connect(func(_changed): UI.play_sound("confirm_button"))


func _apply(change: Callable, click_sound: bool = true) -> void:
	if _updating:
		return
	change.call()
	_update_value_labels()
	if click_sound:
		UI.play_sound("confirm_button")


func _update_value_labels() -> void:
	fov_value.text = str(roundi(fov_slider.value)) + "°"
	brightness_value.text = str(roundi(brightness_slider.value)) + "%"
	music_value.text = str(roundi(music_slider.value)) + "%"
	sfx_value.text = str(roundi(sfx_slider.value)) + "%"
	hud_value.text = str(roundi(hud_slider.value)) + "%"
	sens_value.text = str(snappedf(sens_slider.value, 0.1))
	camera_motion_value.text = str(roundi(camera_motion_slider.value)) + "%"
	resolution_option.tooltip_text = "Fullscreen: Afeta a resolução da câmera 3D / Janela: Afeta o tamanho da janela"


func _on_reset_pressed() -> void:
	UI.reset_to_defaults()
	refresh_from_settings()
	UI.play_sound("back_button")


func _on_button_hovered() -> void:
	UI.play_sound("hover_button")
