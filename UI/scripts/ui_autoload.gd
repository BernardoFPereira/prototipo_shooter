extends CanvasLayer

## Autoload "UI": sons de interface, música e TODAS as configurações do jogo.
##
## Configurações: cada uma tem uma variável e uma função set_* que aplica na hora e emite
## settings_changed. O menu de configurações (UI/V2/Settings) só chama essas funções; quem
## precisa reagir (câmera, player) lê as variáveis daqui. save_settings() grava em
## user://menu_settings.cfg e load_settings() lê (e converte o formato antigo).

signal settings_changed

#region SETTINGS
const SETTINGS_FILE := "user://menu_settings.cfg"

enum WindowMode { WINDOWED, FULLSCREEN, BORDERLESS }
const WINDOW_MODE_NAMES := ["Janela", "Tela cheia", "Tela cheia sem borda"]

## Resolução: em janela muda o tamanho da janela; em qualquer modo, o 3D é renderizado nessa
## resolução (scaling_3d_scale) e esticado. HUD e menus continuam na base de 1920x1080.
var resolutions: Dictionary = {
	"1920x1080": Vector2i(1920, 1080),
	"1600x900": Vector2i(1600, 900),
	"1366x768": Vector2i(1366, 768),
	"1280x720": Vector2i(1280, 720),
	"960x540": Vector2i(960, 540),
	"800x450": Vector2i(800, 450),
}
const BASE_HEIGHT: float = 1080.0 # altura do viewport do projeto (display/window/size)

const FPS_OPTIONS := [30, 60, 120, 144, 0] # 0 = sem limite

const DEFAULTS := {
	"window_mode": WindowMode.WINDOWED,
	"resolution": "1920x1080",
	"vsync": true,
	"max_fps": 0,
	"fov": 75.0,
	"show_fps": false,
	"brightness": 1.0,
	"music_percent": 70.0,
	"sfx_percent": 80.0,
	"hud_percent": 80.0,
	"music_muted": false,
	"sfx_muted": false,
	"hud_muted": false,
	"mouse_sensitivity": 0.0012,
	"invert_y": false,
	"camera_motion": 1.0,
	"screen_shake": 1.0,
}

# Vídeo
var window_mode: int = DEFAULTS.window_mode
var resolution_key: String = DEFAULTS.resolution
var current_resolution: Vector2i = Vector2i(1920, 1080)
var is_fullscreen: bool:
	get: return window_mode != WindowMode.WINDOWED
var vsync: bool = DEFAULTS.vsync
var max_fps: int = DEFAULTS.max_fps
var fov: float = DEFAULTS.fov
var show_fps: bool = DEFAULTS.show_fps
var brightness: float = DEFAULTS.brightness

# Áudio (0 a 100 na barra)
var music_percent: float = DEFAULTS.music_percent
var sfx_percent: float = DEFAULTS.sfx_percent
var hud_percent: float = DEFAULTS.hud_percent
var music_muted: bool = false
var sfx_muted: bool = false
var hud_muted: bool = false

# Conforto (0 a 1)
var camera_motion: float = DEFAULTS.camera_motion
var screen_shake: float = DEFAULTS.screen_shake
#endregion

#region CONTROLS
var is_keyboard: bool = true
var mouse_sensitivity: float = DEFAULTS.mouse_sensitivity
var invert_y: bool = DEFAULTS.invert_y
const SENSITIVITY_MIN: float = 0.0003
const SENSITIVITY_MAX: float = 0.004
const SENS_SLIDER_MAX: float = 20.0

func slider_to_sensitivity(value: float) -> float:
	var normalized = clampf(value / SENS_SLIDER_MAX, 0.0, 1.0)
	return lerp(SENSITIVITY_MIN, SENSITIVITY_MAX, normalized)

func sensitivity_to_slider(sens: float) -> float:
	var normalized = clampf((sens - SENSITIVITY_MIN) / (SENSITIVITY_MAX - SENSITIVITY_MIN), 0.0, 1.0)
	return normalized * SENS_SLIDER_MAX
#endregion

#region AUDIO MANAGEMENT
enum AudioBus {
	MASTER = 0,
	MUSIC = 1,
	SFX = 2,
	HUD = 3
}
 
enum SoundCategory {
	SFX,
	MUSIC,
	HUD
}
 
var sounds: Dictionary = {
	"hover_button": {
		"stream": preload("res://assets/sounds/hud/hover_button.wav"),
		"bus": AudioBus.HUD,
		"category": SoundCategory.HUD,
		"volume_db": 0.0,
		"pitch_scale": 1.0
	},
	"confirm_button": {
		"stream": preload("res://assets/sounds/hud/confirm_button.wav"),
		"bus": AudioBus.HUD,
		"category": SoundCategory.HUD,
		"volume_db": 0.0,
		"pitch_scale": 1.0
	},
	"back_button": {
		"stream": preload("res://assets/sounds/hud/back_button.wav"),
		"bus": AudioBus.HUD,
		"category": SoundCategory.HUD,
		"volume_db": 0.0,
		"pitch_scale": 1.0
	},
	"soundtrack_1": {
		"stream": preload("uid://irff2xea5j5w"),
		"bus": AudioBus.MUSIC,
		"category": SoundCategory.MUSIC,
		"volume_db": 0.0,
		"pitch_scale": 1.0,
		"loop": true
	},
}
 
var audio_players: Dictionary = {}
var current_music: String = ""
var current_music_player: AudioStreamPlayer = null
#endregion
 
#region PLAYER VARIABLES
var is_introduction: bool
var is_walk_introduction: bool
var is_fire_introduction: bool
#endregion
 
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS # o contador de FPS e o brilho funcionam no menu de pausa
	layer = 120 # acima do HUD e dos menus, abaixo da tela de load (128)
	_setup_audio_players()
	_build_overlays()
	load_settings()
	play_music("soundtrack_1", 0)
 
func _setup_audio_players() -> void:
	for bus in AudioBus.values():
		var player = AudioStreamPlayer.new()
		player.bus = AudioServer.get_bus_name(bus)
		player.process_mode = Node.PROCESS_MODE_ALWAYS # sons de UI tocam mesmo com o jogo pausado (menu de pausa, tela de load)
		add_child(player)
		audio_players[bus] = player
	current_music_player = AudioStreamPlayer.new()
	current_music_player.bus = AudioServer.get_bus_name(AudioBus.MUSIC)
	current_music_player.process_mode = Node.PROCESS_MODE_ALWAYS
	self.add_child(current_music_player)
	current_music_player.name = "GlobalMusicPlayer"
 
#region AUDIO PLAYBACK
func play_sound(sound_name: String) -> void:
	var sound_data = sounds[sound_name]
	var player = audio_players[sound_data.bus]
	if sound_data.category == SoundCategory.MUSIC and music_muted:
		return
	if sound_data.category == SoundCategory.SFX and sfx_muted:
		return
	if sound_data.category == SoundCategory.HUD and hud_muted:
		return
	player.stream = sound_data.stream
	if sound_data.category == SoundCategory.MUSIC and sound_data.get("loop", false):
		player.finished.connect(_on_music_finished.bind(player, sound_data.stream), CONNECT_ONE_SHOT)
	player.play()
 
func _on_music_finished(player: AudioStreamPlayer, stream: AudioStream) -> void:
	player.stream = stream
	player.play()
 
func play_music(music_name: String, fade_in: float = 0.0) -> void:
	# O mudo agora é feito no bus (AudioServer.set_bus_mute), então a música sempre toca e só
	# fica em silêncio — assim, ao desmutar, ela volta na hora.
	if not is_instance_valid(current_music_player):
		_setup_audio_players()
	var sound_data = sounds[music_name]
	current_music = music_name
	if fade_in > 0:
		_fade_in_music(sound_data.stream, fade_in)
	else:
		current_music_player.stream = sound_data.stream
		current_music_player.volume_db = sound_data.volume_db
		current_music_player.play()
 
func stop_music(fade_out: float = 0.0) -> void:
	if not is_instance_valid(current_music_player):
		return
	if fade_out > 0:
		_fade_out_music(fade_out)
	else:
		current_music_player.stop()
 
func _fade_in_music(stream: AudioStream, duration: float) -> void:
	current_music_player.stream = stream
	current_music_player.volume_db = MIN_DB
	current_music_player.play()
	var tween = create_tween()
	tween.tween_property(current_music_player, "volume_db", 0.0, duration)
 
func _fade_out_music(duration: float) -> void:
	var tween = create_tween()
	tween.tween_property(current_music_player, "volume_db", MIN_DB, duration)
	tween.tween_callback(current_music_player.stop)
#endregion

#region VOLUME
const MIN_DB: float = -80.0
## Volume (dB) com a barra no máximo. 0 = volume original dos sons.
const VOLUME_MAX_DB: float = 0.0

## Barra (0–100) -> dB. Curva de amplitude linear: 50% = -6 dB, 25% = -12 dB, 10% = -20 dB.
## A antiga tirava 2 dB por passo (metade da barra já era -25 dB, quase mudo).
func percent_to_db(percent: float) -> float:
	if percent <= 0.0:
		return MIN_DB
	return VOLUME_MAX_DB + linear_to_db(clampf(percent / 100.0, 0.0, 1.0))

func db_to_percent(db: float) -> float:
	if db <= MIN_DB:
		return 0.0
	return clampf(db_to_linear(db - VOLUME_MAX_DB) * 100.0, 0.0, 100.0)

func get_volume(bus: AudioBus) -> float:
	match bus:
		AudioBus.MUSIC: return music_percent
		AudioBus.SFX: return sfx_percent
		AudioBus.HUD: return hud_percent
	return 100.0

func is_muted(bus: AudioBus) -> bool:
	match bus:
		AudioBus.MUSIC: return music_muted
		AudioBus.SFX: return sfx_muted
		AudioBus.HUD: return hud_muted
	return false

func set_volume(bus: AudioBus, percent: float) -> void:
	percent = clampf(percent, 0.0, 100.0)
	match bus:
		AudioBus.MUSIC: music_percent = percent
		AudioBus.SFX: sfx_percent = percent
		AudioBus.HUD: hud_percent = percent
	AudioServer.set_bus_volume_db(bus, percent_to_db(percent))
	settings_changed.emit()

func set_muted(bus: AudioBus, muted: bool) -> void:
	match bus:
		AudioBus.MUSIC: music_muted = muted
		AudioBus.SFX: sfx_muted = muted
		AudioBus.HUD: hud_muted = muted
	AudioServer.set_bus_mute(bus, muted)
	settings_changed.emit()
#endregion


#region VÍDEO
func set_window_mode(mode: int) -> void:
	window_mode = clampi(mode, 0, WindowMode.size() - 1)
	match window_mode:
		WindowMode.WINDOWED:
			get_window().mode = Window.MODE_WINDOWED
			_apply_window_size()
			_apply_window_size.call_deferred() # alguns sistemas só aceitam o tamanho depois de sair da tela cheia
		WindowMode.FULLSCREEN:
			get_window().mode = Window.MODE_EXCLUSIVE_FULLSCREEN
		WindowMode.BORDERLESS:
			get_window().mode = Window.MODE_FULLSCREEN
	_apply_render_scale()
	settings_changed.emit()

func set_resolution(key: String) -> void:
	if not resolutions.has(key):
		key = DEFAULTS.resolution
	resolution_key = key
	current_resolution = resolutions[key]
	if window_mode == WindowMode.WINDOWED:
		_apply_window_size()
	_apply_render_scale()
	settings_changed.emit()

func set_vsync(enabled: bool) -> void:
	vsync = enabled
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if enabled else DisplayServer.VSYNC_DISABLED)
	settings_changed.emit()

func set_max_fps(fps: int) -> void:
	max_fps = maxi(fps, 0)
	Engine.max_fps = max_fps
	settings_changed.emit()

func set_fov(value: float) -> void:
	fov = clampf(value, 60.0, 120.0)
	settings_changed.emit() # a câmera do player lê UI.fov

func set_show_fps(enabled: bool) -> void:
	show_fps = enabled
	if _fps_label:
		_fps_label.visible = enabled
	settings_changed.emit()

func set_brightness(value: float) -> void:
	brightness = clampf(value, 0.5, 1.5)
	if _brightness_rect:
		_brightness_rect.visible = not is_equal_approx(brightness, 1.0)
		_brightness_rect.material.set_shader_parameter("brightness", brightness)
	settings_changed.emit()

## O 3D renderiza na resolução escolhida e é esticado pra tela (HUD/menus não mudam).
func _apply_render_scale() -> void:
	get_tree().root.scaling_3d_scale = clampf(current_resolution.y / BASE_HEIGHT, 0.25, 1.0)

## Em janela: tamanho da janela = resolução (limitado ao tamanho útil do monitor).
func _apply_window_size() -> void:
	var usable := DisplayServer.screen_get_usable_rect().size
	var size := current_resolution
	if size.x > usable.x or size.y > usable.y:
		var ratio := minf(float(usable.x) / size.x, float(usable.y) / size.y)
		size = Vector2i(int(size.x * ratio), int(size.y * ratio))
	get_window().size = size
	center_window()

func center_window() -> void:
	var screen_center = DisplayServer.screen_get_position() + DisplayServer.screen_get_size() / 2
	var window_size = get_window().get_size_with_decorations()
	get_window().set_position(screen_center - window_size / 2)
#endregion


#region CONTROLES / CONFORTO
func set_mouse_sensitivity(value: float) -> void:
	mouse_sensitivity = clampf(value, SENSITIVITY_MIN, SENSITIVITY_MAX)
	settings_changed.emit()

func set_invert_y(enabled: bool) -> void:
	invert_y = enabled
	settings_changed.emit()

## 0 = câmera parada (sem balanço ao andar, inclinação, coices). 1 = normal.
func set_camera_motion(value: float) -> void:
	camera_motion = clampf(value, 0.0, 1.0)
	settings_changed.emit()

## 0 = sem tremor de tela. 1 = normal.
func set_screen_shake(value: float) -> void:
	screen_shake = clampf(value, 0.0, 1.0)
	settings_changed.emit()
#endregion


#region APLICAR / SALVAR / CARREGAR
func apply_settings() -> void:
	set_resolution(resolution_key)
	set_window_mode(window_mode)
	set_vsync(vsync)
	set_max_fps(max_fps)
	set_fov(fov)
	set_show_fps(show_fps)
	set_brightness(brightness)
	for bus in [AudioBus.MUSIC, AudioBus.SFX, AudioBus.HUD]:
		set_volume(bus, get_volume(bus))
		set_muted(bus, is_muted(bus))
	set_mouse_sensitivity(mouse_sensitivity)
	set_invert_y(invert_y)
	set_camera_motion(camera_motion)
	set_screen_shake(screen_shake)

func reset_to_defaults() -> void:
	window_mode = DEFAULTS.window_mode
	resolution_key = DEFAULTS.resolution
	current_resolution = resolutions[resolution_key]
	vsync = DEFAULTS.vsync
	max_fps = DEFAULTS.max_fps
	fov = DEFAULTS.fov
	show_fps = DEFAULTS.show_fps
	brightness = DEFAULTS.brightness
	music_percent = DEFAULTS.music_percent
	sfx_percent = DEFAULTS.sfx_percent
	hud_percent = DEFAULTS.hud_percent
	music_muted = DEFAULTS.music_muted
	sfx_muted = DEFAULTS.sfx_muted
	hud_muted = DEFAULTS.hud_muted
	mouse_sensitivity = DEFAULTS.mouse_sensitivity
	invert_y = DEFAULTS.invert_y
	camera_motion = DEFAULTS.camera_motion
	screen_shake = DEFAULTS.screen_shake
	apply_settings()
	save_settings()

func save_settings() -> void:
	var config = ConfigFile.new()
	config.set_value("meta", "version", 2)
	config.set_value("video", "window_mode", window_mode)
	config.set_value("video", "resolution", resolution_key)
	config.set_value("video", "vsync", vsync)
	config.set_value("video", "max_fps", max_fps)
	config.set_value("video", "fov", fov)
	config.set_value("video", "show_fps", show_fps)
	config.set_value("video", "brightness", brightness)
	config.set_value("audio", "music_percent", music_percent)
	config.set_value("audio", "sfx_percent", sfx_percent)
	config.set_value("audio", "hud_percent", hud_percent)
	config.set_value("audio", "music_muted", music_muted)
	config.set_value("audio", "sfx_muted", sfx_muted)
	config.set_value("audio", "hud_muted", hud_muted)
	config.set_value("controls", "mouse_sensitivity", mouse_sensitivity)
	config.set_value("controls", "invert_y", invert_y)
	config.set_value("comfort", "camera_motion", camera_motion)
	config.set_value("comfort", "screen_shake", screen_shake)
	config.set_value("controls", "is_introduction", is_introduction)
	config.set_value("controls", "is_walk_introduction", is_walk_introduction)
	config.set_value("controls", "is_fire_introduction", is_fire_introduction)
	config.save(SETTINGS_FILE)

func load_settings() -> void:
	var config = ConfigFile.new()
	if config.load(SETTINGS_FILE) != OK:
		reset_to_defaults()
		return
	var version: int = config.get_value("meta", "version", 1)
	# Vídeo
	if version >= 2:
		window_mode = config.get_value("video", "window_mode", DEFAULTS.window_mode)
	else: # formato antigo: só "fullscreen" true/false
		window_mode = WindowMode.FULLSCREEN if config.get_value("video", "fullscreen", false) else WindowMode.WINDOWED
	resolution_key = config.get_value("video", "resolution", DEFAULTS.resolution)
	if not resolutions.has(resolution_key):
		resolution_key = DEFAULTS.resolution
	current_resolution = resolutions[resolution_key]
	vsync = config.get_value("video", "vsync", DEFAULTS.vsync)
	max_fps = config.get_value("video", "max_fps", DEFAULTS.max_fps)
	fov = config.get_value("video", "fov", DEFAULTS.fov)
	show_fps = config.get_value("video", "show_fps", DEFAULTS.show_fps)
	brightness = config.get_value("video", "brightness", DEFAULTS.brightness)
	# Áudio
	if version >= 2:
		music_percent = config.get_value("audio", "music_percent", DEFAULTS.music_percent)
		sfx_percent = config.get_value("audio", "sfx_percent", DEFAULTS.sfx_percent)
		hud_percent = config.get_value("audio", "hud_percent", DEFAULTS.hud_percent)
	else: # formato antigo guardava dB; o máximo antigo (-5 dB) vira 100%
		music_percent = _old_db_to_percent(config.get_value("audio", "music_volume", -5.0))
		sfx_percent = _old_db_to_percent(config.get_value("audio", "sfx_volume", -5.0))
		hud_percent = _old_db_to_percent(config.get_value("audio", "hud_volume", -5.0))
	music_muted = config.get_value("audio", "music_muted", false)
	sfx_muted = config.get_value("audio", "sfx_muted", false)
	hud_muted = config.get_value("audio", "hud_muted", false)
	# Controles / conforto
	mouse_sensitivity = config.get_value("controls", "mouse_sensitivity", DEFAULTS.mouse_sensitivity)
	invert_y = config.get_value("controls", "invert_y", DEFAULTS.invert_y)
	camera_motion = config.get_value("comfort", "camera_motion", DEFAULTS.camera_motion)
	screen_shake = config.get_value("comfort", "screen_shake", DEFAULTS.screen_shake)
	is_introduction = config.get_value("controls", "is_introduction", false)
	is_walk_introduction = config.get_value("controls", "is_walk_introduction", false)
	is_fire_introduction = config.get_value("controls", "is_fire_introduction", false)
	apply_settings()

func _old_db_to_percent(db: float) -> float:
	if db <= -79.0:
		return 0.0
	# Escala antiga: barra 0–20, -5 dB no máximo, 2 dB por passo.
	var old_slider := clampf(20.0 - (-5.0 - db) / 2.0, 0.0, 20.0)
	return old_slider / 20.0 * 100.0
#endregion


#region OVERLAYS (contador de FPS e brilho)
var _fps_label: Label
var _brightness_rect: ColorRect
var _fps_timer: float = 0.0

const BRIGHTNESS_SHADER_CODE := """
shader_type canvas_item;
uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;
uniform float brightness = 1.0;
void fragment() {
	vec3 c = texture(screen_tex, SCREEN_UV).rgb;
	// Gama: clareia/escurece os meio-tons sem estourar o branco nem acinzentar o preto.
	c = pow(max(c, vec3(0.0)), vec3(1.0 / brightness));
	COLOR = vec4(c, 1.0);
}
"""

func _build_overlays() -> void:
	_brightness_rect = ColorRect.new()
	_brightness_rect.name = "BrightnessOverlay"
	_brightness_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_brightness_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader := Shader.new()
	shader.code = BRIGHTNESS_SHADER_CODE
	var mat := ShaderMaterial.new()
	mat.shader = shader
	_brightness_rect.material = mat
	_brightness_rect.visible = false
	add_child(_brightness_rect)

	_fps_label = Label.new()
	_fps_label.name = "FPSLabel"
	_fps_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_fps_label.offset_left = -220
	_fps_label.offset_right = -16
	_fps_label.offset_top = 8
	_fps_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_fps_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fps_label.add_theme_color_override("font_color", Color(0, 1, 0))
	_fps_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	_fps_label.add_theme_constant_override("outline_size", 6)
	if ResourceLoader.exists("res://UI/Fonts/m6x11plus.ttf"):
		_fps_label.add_theme_font_override("font", load("res://UI/Fonts/m6x11plus.ttf"))
	_fps_label.add_theme_font_size_override("font_size", 36)
	_fps_label.visible = false
	add_child(_fps_label)

func _process(delta: float) -> void:
	if _fps_label and _fps_label.visible:
		_fps_timer -= delta
		if _fps_timer <= 0.0:
			_fps_timer = 0.25
			_fps_label.text = "%d FPS" % Engine.get_frames_per_second()
#endregion

func _exit_tree() -> void:
	if is_instance_valid(current_music_player):
		current_music_player.queue_free()
