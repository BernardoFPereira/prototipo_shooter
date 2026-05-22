extends CanvasLayer

#region SETTINGS
const SETTINGS_FILE := "user://menu_settings.cfg"

var resolutions: Dictionary = {
	"1920x1080": Vector2i(1920,1080),
	"1600x900": Vector2i(1600,900),
	"1366x768": Vector2i(1366,768),
	"1280x720": Vector2i(1280,720),
	"800x600": Vector2i(800,600),
}
var current_resolution: Vector2i = Vector2i(1920, 1080)
var is_fullscreen: bool = false
var music_volume: float = 0.0
var sfx_volume: float = 0.0
var hud_volume: float = 0.0
var music_muted: bool = false
var sfx_muted: bool = false
var hud_muted: bool = false
#endregion

#region CONTROLS
var is_keyboard: bool = true
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

func _ready() -> void:
	_setup_audio_players()
	
	play_music("soundtrack_1", 0)
	load_settings()

func _setup_audio_players() -> void:
	for bus in AudioBus.values():
		var player = AudioStreamPlayer.new()
		player.bus = AudioServer.get_bus_name(bus)
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
	if music_muted:
		return
	
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

#region VOLUME CONTROL
func set_music_volume_db(volume: float) -> void:
	music_volume = clamp(volume, MIN_DB, MAX_DB)
	if not music_muted:
		AudioServer.set_bus_volume_db(AudioBus.MUSIC, music_volume)

func set_sfx_volume_db(volume: float) -> void:
	sfx_volume = clamp(volume, MIN_DB, MAX_DB)
	if not sfx_muted:
		AudioServer.set_bus_volume_db(AudioBus.SFX, sfx_volume)

func set_hud_volume_db(volume: float) -> void:
	hud_volume = clamp(volume, MIN_DB, MAX_DB)
	if not hud_muted:
		AudioServer.set_bus_volume_db(AudioBus.HUD, hud_volume)

func set_music_muted(muted: bool) -> void:
	music_muted = muted
	if muted:
		AudioServer.set_bus_volume_db(AudioBus.MUSIC, MIN_DB)
	else:
		AudioServer.set_bus_volume_db(AudioBus.MUSIC, music_volume)

func set_sfx_muted(muted: bool) -> void:
	sfx_muted = muted
	if muted:
		AudioServer.set_bus_volume_db(AudioBus.SFX, MIN_DB)
	else:
		AudioServer.set_bus_volume_db(AudioBus.SFX, sfx_volume)

func set_hud_muted(muted: bool) -> void:
	hud_muted = muted
	if muted:
		AudioServer.set_bus_volume_db(AudioBus.HUD, MIN_DB)
	else:
		AudioServer.set_bus_volume_db(AudioBus.HUD, hud_volume)

#endregion

#region WINDOW MANAGEMENT
func center_window() -> void:
	var screen_center = DisplayServer.screen_get_position() + DisplayServer.screen_get_size() / 2
	var window_size = get_window().get_size_with_decorations()
	get_window().set_position(screen_center - window_size / 2)

#region VOLUME MAPPING FUNCTIONS
const MIN_DB: float = -80
const MAX_DB: float = -5

const VOLUME_CURVE_POWER: float = 0.4

func slider_to_db(value: float) -> float:
	
	if value <= 0:
		return MIN_DB
	
	var normalized = value / 10.0
	
	var curve = pow(normalized, VOLUME_CURVE_POWER)
	
	var db = MIN_DB + (curve * (MAX_DB - MIN_DB))
	
	return db

func db_to_slider(db: float) -> float:
	if db <= MIN_DB:
		return 0.0
	
	var normalized = (db - MIN_DB) / (MAX_DB - MIN_DB)
	
	var curve = pow(normalized, 1.0 / VOLUME_CURVE_POWER)
	
	var value = curve * 10.0
	
	return clamp(value, 0.0, 10.0)
#endregion

func apply_settings() -> void:
	if not is_fullscreen:
		get_window().size = current_resolution
	
	if is_fullscreen:
		get_window().mode = Window.MODE_EXCLUSIVE_FULLSCREEN
	else:
		get_window().mode = Window.MODE_WINDOWED
	
	set_music_volume_db(music_volume)
	set_sfx_volume_db(sfx_volume)
	set_hud_volume_db(hud_volume)
	set_music_muted(music_muted)
	set_sfx_muted(sfx_muted)
	set_hud_muted(hud_muted)

func save_settings() -> void:
	var config = ConfigFile.new()
	
	config.set_value("video", "resolution", str(current_resolution.x, "x", current_resolution.y))
	config.set_value("video", "fullscreen", is_fullscreen)
	
	config.set_value("audio", "music_volume", music_volume)
	config.set_value("audio", "sfx_volume", sfx_volume)
	config.set_value("audio", "hud_volume", hud_volume)
	config.set_value("audio", "music_muted", music_muted)
	config.set_value("audio", "sfx_muted", sfx_muted)
	config.set_value("audio", "hud_muted", hud_muted)
	
	config.save(SETTINGS_FILE)
	print("Settings saved to: ", SETTINGS_FILE)

func load_settings() -> void:
	var config = ConfigFile.new()
	
	if not config.load(SETTINGS_FILE) == OK:
		current_resolution = resolutions["1920x1080"]
		is_fullscreen = false
		music_volume = 0.0
		sfx_volume = 0.0
		hud_volume = 0.0
		music_muted = false
		sfx_muted = false
		hud_muted = false
		apply_settings()
		return
	
	var resolution_str = config.get_value("video", "resolution", "1920x1080")
	if resolutions.has(resolution_str):
		current_resolution = resolutions[resolution_str]
	else:
		current_resolution = resolutions["1920x1080"]
	
	is_fullscreen = config.get_value("video", "fullscreen", false)
	
	music_volume = config.get_value("audio", "music_volume", 0.0)
	sfx_volume = config.get_value("audio", "sfx_volume", 0.0)
	hud_volume = config.get_value("audio", "hud_volume", 0.0)
	music_muted = config.get_value("audio", "music_muted", false)
	sfx_muted = config.get_value("audio", "sfx_muted", false)
	hud_muted = config.get_value("audio", "hud_muted", false)
	
	apply_settings()
	print("Settings loaded from: ", SETTINGS_FILE)
#endregion

func _exit_tree() -> void:
	if is_instance_valid(current_music_player):
		current_music_player.queue_free()
