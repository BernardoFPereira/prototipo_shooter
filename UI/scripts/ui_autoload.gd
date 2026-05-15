extends CanvasLayer

#region SETTINGS
const SETTINGS_FILE := "user://menu_settings.cfg"

const MIN_DB: float = -80.0
const MAX_DB: float = 6.0

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
var music_muted: bool = false
var sfx_muted: bool = false
#endregion

#region AUDIO MANAGEMENT
enum AudioBus {
	MASTER = 0,
	MUSIC = 1,
	SFX = 2
}

# Sound categories
enum SoundCategory {
	SFX,
	MUSIC
}

# Dictionary of all game sounds
var sounds: Dictionary = {
	# UI Sounds
	"hover_button": {
		"stream": preload("uid://bsyrvpekg5hr1"),
		"bus": AudioBus.SFX,
		"category": SoundCategory.SFX,
		"volume_db": 0.0,
		"pitch_scale": 1.0
	},
	"confirm_button": {
		"stream": preload("uid://b0u28r3efrtiw"),
		"bus": AudioBus.SFX,
		"category": SoundCategory.SFX,
		"volume_db": 0.0,
		"pitch_scale": 1.0
	},
	"back_button": {
		"stream": preload("uid://cfw67125uhk2b"),
		"bus": AudioBus.SFX,
		"category": SoundCategory.SFX,
		"volume_db": 0.0,
		"pitch_scale": 1.0
	},
	
	## Gameplay SFX
	#"jump": {
		##"stream": preload("res://assets/sounds/sfx/jump.wav"),
		#"bus": AudioBus.SFX,
		#"category": SoundCategory.SFX,
		#"volume_db": 0.0,
		#"pitch_scale": 1.0
	#},
	#"damage": {
		##"stream": preload("res://assets/sounds/sfx/damage.wav"),
		#"bus": AudioBus.SFX,
		#"category": SoundCategory.SFX,
		#"volume_db": 0.0,
		#"pitch_scale": 1.0
	#},
	#"death": {
		##"stream": preload("res://assets/sounds/sfx/death.wav"),
		#"bus": AudioBus.SFX,
		#"category": SoundCategory.SFX,
		#"volume_db": 0.0,
		#"pitch_scale": 1.0
	#},
	
	# Background Music
	"soundtrack_1": {
		"stream": preload("res://assets/sounds/music/soundtrack_1.wav"),
		"bus": AudioBus.MUSIC,
		"category": SoundCategory.MUSIC,
		"volume_db": 0.0,
		"pitch_scale": 1.0,
		"loop": true
	},
	#"level_music": {
		##"stream": preload("res://assets/sounds/music/level.ogg"),
		#"bus": AudioBus.MUSIC,
		#"category": SoundCategory.MUSIC,
		#"volume_db": 0.0,
		#"pitch_scale": 1.0,
		#"loop": true
	#}
}

# Audio players for each bus
var audio_players: Dictionary = {}
var current_music: String = ""
var current_music_player: AudioStreamPlayer = null
#endregion

func _ready() -> void:
	# Initialize audio players for each bus
	_setup_audio_players()
	
	# Load settings (which applies audio settings)
	load_settings()

func _setup_audio_players() -> void:
	# Create audio players for each bus if they don't exist
	for bus in AudioBus.values():
		var player = AudioStreamPlayer.new()
		player.bus = AudioServer.get_bus_name(bus)
		add_child(player)
		audio_players[bus] = player
	
	# Special player for looping music
	current_music_player = AudioStreamPlayer.new()
	current_music_player.bus = AudioServer.get_bus_name(AudioBus.MUSIC)
	add_child(current_music_player)

#region AUDIO PLAYBACK
func play_sound(sound_name: String) -> void:
	
	var sound_data = sounds[sound_name]
	var player = audio_players[sound_data.bus]
	
	# Check if sound is muted based on category
	if sound_data.category == SoundCategory.MUSIC and music_muted:
		return
	if sound_data.category == SoundCategory.SFX and sfx_muted:
		return
	
	# Configure and play
	player.stream = sound_data.stream
	
	# Handle looping for music
	if sound_data.category == SoundCategory.MUSIC and sound_data.get("loop", false):
		player.finished.connect(_on_music_finished.bind(player, sound_data.stream), CONNECT_ONE_SHOT)
	
	player.play()

func _on_music_finished(player: AudioStreamPlayer, stream: AudioStream) -> void:
	player.stream = stream
	player.play()

func play_music(music_name: String, fade_in: float = 0.0) -> void:
	if music_muted:
		return
	
	var sound_data = sounds[music_name]
	current_music = music_name
	
	if fade_in > 0:
		_fade_in_music(sound_data.stream, fade_in)
	else:
		current_music_player.stream = sound_data.stream
		current_music_player.volume_db = sound_data.volume_db
		current_music_player.play()

func stop_music(fade_out: float = 0.0) -> void:
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
#endregion

#region WINDOW MANAGEMENT
func center_window() -> void:
	var screen_center = DisplayServer.screen_get_position() + DisplayServer.screen_get_size() / 2
	var window_size = get_window().get_size_with_decorations()
	get_window().set_position(screen_center - window_size / 2)

func slider_to_db(value: float) -> float:
	return MIN_DB + (value / 10.0) * (MAX_DB - MIN_DB)

func db_to_slider(db: float) -> float:
	return (db - MIN_DB) / (MAX_DB - MIN_DB) * 10.0

func apply_settings() -> void:
	if not is_fullscreen:
		get_window().size = current_resolution
	
	if is_fullscreen:
		get_window().mode = Window.MODE_EXCLUSIVE_FULLSCREEN
	else:
		get_window().mode = Window.MODE_WINDOWED
	
	set_music_volume_db(music_volume)
	set_sfx_volume_db(sfx_volume)
	set_music_muted(music_muted)
	set_sfx_muted(sfx_muted)

func save_settings() -> void:
	var config = ConfigFile.new()
	
	config.set_value("video", "resolution", str(current_resolution.x, "x", current_resolution.y))
	config.set_value("video", "fullscreen", is_fullscreen)
	
	config.set_value("audio", "music_volume", music_volume)
	config.set_value("audio", "sfx_volume", sfx_volume)
	config.set_value("audio", "music_muted", music_muted)
	config.set_value("audio", "sfx_muted", sfx_muted)
	
	config.save(SETTINGS_FILE)
	print("Settings saved to: ", SETTINGS_FILE)

func load_settings() -> void:
	var config = ConfigFile.new()
	
	if not config.load(SETTINGS_FILE) == OK:
		current_resolution = resolutions["1920x1080"]
		is_fullscreen = false
		music_volume = 0.0
		sfx_volume = 0.0
		music_muted = false
		sfx_muted = false
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
	music_muted = config.get_value("audio", "music_muted", false)
	sfx_muted = config.get_value("audio", "sfx_muted", false)
	
	apply_settings()
	print("Settings loaded from: ", SETTINGS_FILE)
#endregion
