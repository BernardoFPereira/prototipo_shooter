@tool
extends TextureRect
class_name GlowRotatingIcon

@export var glow_tint: Color = Color(1.0, 0.3, 0.3):
	set(value):
		glow_tint = value
		if _ensure_material():
			_mat.set_shader_parameter("glow_tint", Vector3(value.r, value.g, value.b))

@export var detect_color: Color = Color(1.0, 1.0, 1.0):
	set(value):
		detect_color = value
		if _ensure_material():
			_mat.set_shader_parameter("detect_color", Vector3(value.r, value.g, value.b))

@export_range(0.0, 1.0) var threshold: float = 0.1:
	set(value):
		threshold = value
		if _ensure_material():
			_mat.set_shader_parameter("threshold", value)

@export_range(0.0, 10.0) var intensity: float = 3.0:
	set(value):
		intensity = value
		if _ensure_material():
			_mat.set_shader_parameter("intensity", value)

@export_range(0.0, 20.0) var blur_size: float = 6.0:
	set(value):
		blur_size = value
		if _ensure_material():
			_mat.set_shader_parameter("blur_size", value)

@export_range(0.0, 1.0) var line_opacity: float = 1.0:
	set(value):
		line_opacity = value
		if _ensure_material():
			_mat.set_shader_parameter("line_opacity", value)

@export var rotation_speed: float = 2.0

var _mat: ShaderMaterial
var _initialized := false
var _current_rotation: float = 0.0

func _ready():
	_ensure_material()
	_apply_all()

func _process(delta):
	if Engine.is_editor_hint():
		return
	_current_rotation = wrapf(_current_rotation + rotation_speed * delta, 0.0, TAU)
	if _ensure_material():
		_mat.set_shader_parameter("rotation", _current_rotation)

func _ensure_material() -> bool:
	if _initialized:
		return _mat != null
	if material == null or not (material is ShaderMaterial):
		return false
	_mat = material.duplicate()
	material = _mat
	if texture != null:
		_mat.set_shader_parameter("glow_source", texture)
	_initialized = true
	return true

func _apply_all():
	if not _ensure_material():
		return
	_mat.set_shader_parameter("glow_tint", Vector3(glow_tint.r, glow_tint.g, glow_tint.b))
	_mat.set_shader_parameter("detect_color", Vector3(detect_color.r, detect_color.g, detect_color.b))
	_mat.set_shader_parameter("threshold", threshold)
	_mat.set_shader_parameter("intensity", intensity)
	_mat.set_shader_parameter("blur_size", blur_size)
	_mat.set_shader_parameter("line_opacity", line_opacity)
