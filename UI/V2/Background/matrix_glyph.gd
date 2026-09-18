extends TextureRect
class_name MatrixGlyph

const GLOW_SHADER := preload("res://UI/V2/HUD/2DGlowShader.gdshader")

var _mat: ShaderMaterial

func _ready() -> void:
	_mat = ShaderMaterial.new()
	_mat.shader = GLOW_SHADER
	material = _mat
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func configure(tex: Texture2D, glow_tint: Color, intensity: float, blur_size: float,
		threshold: float = 0.1, line_opacity: float = 0.5) -> void:
	if _mat == null:
		push_warning("MatrixGlyph.configure() chamado antes de add_child() — chamem depois.")
		_ready()

	texture = tex
	_mat.set_shader_parameter("glow_source", tex)
	_mat.set_shader_parameter("glow_tint", Vector3(glow_tint.r, glow_tint.g, glow_tint.b))
	_mat.set_shader_parameter("detect_color", Vector3(1.0, 1.0, 1.0))
	_mat.set_shader_parameter("threshold", threshold)
	_mat.set_shader_parameter("intensity", intensity)
	_mat.set_shader_parameter("blur_size", blur_size)
	_mat.set_shader_parameter("line_opacity", line_opacity)
