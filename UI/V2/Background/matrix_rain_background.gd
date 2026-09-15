extends Control
class_name MatrixRainBackground

const CHAR_PATHS := [
	"res://assets/textures/ui/matrix_rain/char_01.png",
	"res://assets/textures/ui/matrix_rain/char_02.png",
	"res://assets/textures/ui/matrix_rain/char_03.png",
	"res://assets/textures/ui/matrix_rain/char_04.png",
	"res://assets/textures/ui/matrix_rain/char_05.png",
	"res://assets/textures/ui/matrix_rain/char_06.png",
	"res://assets/textures/ui/matrix_rain/char_07.png",
	"res://assets/textures/ui/matrix_rain/char_08.png",
]

@export var glyph_textures: Array[Texture2D] = []
@export var background_color: Color = Color(0.02, 0.02, 0.035, 1.0)

const GLOW_TINT := Color(0.0, 1.0, 0.0)
const GLOW_THRESHOLD := 0.1
const GLOW_INTENSITY := 1.5
const GLOW_BLUR_SIZE := 1.0
const GLOW_LINE_OPACITY := 0.5

class LayerConfig:
	var column_count: int
	var glyph_size: float
	var fall_speed_range: Vector2
	var spawn_interval_range: Vector2
	var alpha: float

	func _init(p_column_count: int, p_glyph_size: float, p_fall_speed_range: Vector2,
			p_spawn_interval_range: Vector2, p_alpha: float) -> void:
		column_count = p_column_count
		glyph_size = p_glyph_size
		fall_speed_range = p_fall_speed_range
		spawn_interval_range = p_spawn_interval_range
		alpha = p_alpha

var _layers: Array = []
var _columns: Array = []
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_rng.randomize()
	_load_default_textures()
	_setup_background()
	_setup_layers()
	_build_columns()

func _load_default_textures() -> void:
	if not glyph_textures.is_empty():
		return
	for path in CHAR_PATHS:
		if ResourceLoader.exists(path):
			glyph_textures.append(load(path))
	if glyph_textures.is_empty():
		push_warning("MatrixRainBackground: nenhum glifo encontrado em assets/textures/ui/matrix_rain/ — a chuva de caracteres não vai aparecer.")

func _setup_background() -> void:
	var bg := ColorRect.new()
	bg.name = "DarkBackground"
	bg.color = background_color
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	move_child(bg, 0)

func _setup_layers() -> void:
	_layers = [
		LayerConfig.new(16, 14.0, Vector2(35.0, 65.0), Vector2(0.5, 1.4), 0.35), # fundo
		LayerConfig.new(11, 20.0, Vector2(75.0, 125.0), Vector2(0.35, 1.0), 0.65), # meio
		LayerConfig.new(7, 28.0, Vector2(135.0, 200.0), Vector2(0.2, 0.7), 1.0), # frente
	]

func _build_columns() -> void:
	if glyph_textures.is_empty():
		return
	for layer in _layers:
		for i in layer.column_count:
			_columns.append({
				"layer": layer,
				"x": _rng.randf_range(0.0, 1.0),
				"next_spawn_time": _rng.randf_range(0.0, layer.spawn_interval_range.y),
				"glyphs": [],
			})

func _process(delta: float) -> void:
	if glyph_textures.is_empty() or size.y <= 0.0:
		return
	for col in _columns:
		col.next_spawn_time -= delta
		if col.next_spawn_time <= 0.0:
			_spawn_glyph(col)
			col.next_spawn_time = _rng.randf_range(col.layer.spawn_interval_range.x, col.layer.spawn_interval_range.y)

		var to_remove: Array = []
		for glyph in col.glyphs:
			if not is_instance_valid(glyph):
				to_remove.append(glyph)
				continue
			glyph.position.y += glyph.get_meta("fall_speed") * delta
			if glyph.position.y > size.y + glyph.size.y:
				to_remove.append(glyph)
		for glyph in to_remove:
			col.glyphs.erase(glyph)
			if is_instance_valid(glyph):
				glyph.queue_free()

func _spawn_glyph(col: Dictionary) -> void:
	var layer: LayerConfig = col.layer
	var tex: Texture2D = glyph_textures[_rng.randi_range(0, glyph_textures.size() - 1)]

	var glyph := MatrixGlyph.new()
	glyph.size = Vector2(layer.glyph_size, layer.glyph_size)
	glyph.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	glyph.stretch_mode = TextureRect.STRETCH_SCALE
	glyph.pivot_offset = Vector2(layer.glyph_size, layer.glyph_size) * 0.5
	glyph.rotation = PI if _rng.randf() < 0.5 else 0.0
	glyph.modulate.a = layer.alpha
	glyph.position = Vector2(col.x * size.x - layer.glyph_size * 0.5, -layer.glyph_size)
	glyph.set_meta("fall_speed", _rng.randf_range(layer.fall_speed_range.x, layer.fall_speed_range.y))
	add_child(glyph)
	glyph.configure(tex, GLOW_TINT, GLOW_INTENSITY, GLOW_BLUR_SIZE, GLOW_THRESHOLD, GLOW_LINE_OPACITY)
	col.glyphs.append(glyph)
