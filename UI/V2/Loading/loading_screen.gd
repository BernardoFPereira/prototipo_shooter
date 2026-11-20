extends CanvasLayer


signal loading_started
signal loading_finished

@export var min_duration: float = 3.0
@export var fade_time: float = 0.4
@export var loading_text: String = "CARREGANDO"
@export var first_level_name: String = "LABORATÓRIO"
@export var main_menu_name: String = "MENU PRINCIPAL"
@export var muted_buses: PackedStringArray = PackedStringArray(["SFX", "HUD"])
@export var max_arrows: int = 2
@export var arrow_interval: float = 0.4
@export var rain_prewarm_seconds: float = 25.0

const MATRIX_RAIN_SCENE: PackedScene = preload("res://UI/V2/Background/MatrixRainBackground.tscn")

var is_loading: bool = false
var current_level_name: String = ""

@onready var _root: Control = $Root
@onready var _rain_holder: Control = $Root/RainHolder
@onready var _title_label: Label = $Root/Texts/Title
@onready var _name_label: Label = $Root/Texts/LevelName

var _rain: Control = null
var _arrows_time: float = 0.0
var _elapsed: float = 0.0
var _muted_by_me: Array = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root.visible = false
	_root.modulate.a = 0.0


func _process(delta: float) -> void:
	if not is_loading:
		return
	_arrows_time += delta
	_elapsed += delta
	_update_title()


func _input(_event: InputEvent) -> void:
	if is_loading:
		get_viewport().set_input_as_handled()


func _update_title() -> void:
	var steps: int = maxi(max_arrows, 0) + 1
	var count: int = int(_arrows_time / maxf(arrow_interval, 0.01)) % steps
	if count == 0:
		_title_label.text = loading_text
	else:
		_title_label.text = ">".repeat(count) + " " + loading_text + " " + "<".repeat(count)


func change_scene(target, display_name: String = "", mouse_mode_after: Input.MouseMode = Input.MOUSE_MODE_CAPTURED) -> void:
	if is_loading:
		push_warning("SceneLoader: já existe um load em andamento, ignorando.")
		return
	if target == null or (target is String and target == ""):
		push_error("SceneLoader: cena de destino vazia.")
		return
	current_level_name = display_name
	_run(target, display_name, mouse_mode_after)


func reload_current_scene(mouse_mode_after: Input.MouseMode = Input.MOUSE_MODE_CAPTURED) -> void:
	var scene: Node = get_tree().current_scene
	if scene == null or scene.scene_file_path == "":
		get_tree().reload_current_scene()
		return
	change_scene(scene.scene_file_path, current_level_name, mouse_mode_after)


func go_to_main_menu(menu_scene) -> void:
	change_scene(menu_scene, main_menu_name, Input.MOUSE_MODE_VISIBLE)


func _run(target, display_name: String, mouse_mode_after: Input.MouseMode) -> void:
	is_loading = true
	loading_started.emit()

	get_tree().paused = true
	Engine.time_scale = 1.0
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN

	_arrows_time = 0.0
	_update_title()
	_name_label.text = display_name
	_name_label.visible = display_name != ""
	_spawn_rain()
	_root.visible = true
	await _fade(1.0)
	_mute_buses(true)
	_elapsed = 0.0

	var packed: PackedScene = await _load_scene(target)
	while _elapsed < min_duration:
		await get_tree().process_frame
	if packed == null:
		push_error("SceneLoader: não consegui carregar " + str(target))
		_end(mouse_mode_after)
		return

	get_tree().change_scene_to_packed(packed)
	await get_tree().process_frame
	await get_tree().process_frame
	get_tree().paused = true

	await _fade(0.0)
	_end(mouse_mode_after)


func _end(mouse_mode_after: Input.MouseMode) -> void:
	_root.visible = false
	_free_rain()
	_mute_buses(false)
	Input.mouse_mode = mouse_mode_after
	get_tree().paused = false
	is_loading = false
	loading_finished.emit()


func _load_scene(target) -> PackedScene:
	if target is PackedScene:
		return target
	var path: String = target
	if path.begins_with("uid://"):
		var id: int = ResourceUID.text_to_id(path)
		if ResourceUID.has_id(id):
			path = ResourceUID.get_id_path(id)
	if ResourceLoader.load_threaded_request(path, "PackedScene") != OK:
		return load(path) as PackedScene
	while true:
		var status: ResourceLoader.ThreadLoadStatus = ResourceLoader.load_threaded_get_status(path)
		if status == ResourceLoader.THREAD_LOAD_LOADED:
			return ResourceLoader.load_threaded_get(path) as PackedScene
		if status == ResourceLoader.THREAD_LOAD_FAILED or status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			return null
		await get_tree().process_frame
	return null


func _fade(to_alpha: float) -> void:
	if fade_time <= 0.0:
		_root.modulate.a = to_alpha
		return
	var tween: Tween = create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(_root, "modulate:a", to_alpha, fade_time)
	await tween.finished


func _spawn_rain() -> void:
	_free_rain()
	_rain = MATRIX_RAIN_SCENE.instantiate()
	_rain.background_color = Color.BLACK
	_rain_holder.add_child(_rain)
	var step: float = 0.1
	var t: float = 0.0
	while t < rain_prewarm_seconds:
		_rain._process(step)
		t += step


func _free_rain() -> void:
	if is_instance_valid(_rain):
		_rain.queue_free()
	_rain = null


func _mute_buses(mute: bool) -> void:
	if mute:
		_muted_by_me.clear()
		for bus_name in muted_buses:
			var idx: int = AudioServer.get_bus_index(bus_name)
			if idx != -1 and not AudioServer.is_bus_mute(idx):
				AudioServer.set_bus_mute(idx, true)
				_muted_by_me.append(idx)
	else:
		for idx in _muted_by_me:
			AudioServer.set_bus_mute(idx, false)
		_muted_by_me.clear()
