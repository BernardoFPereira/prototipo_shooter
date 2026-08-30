@tool
extends NinePatchRect
class_name AssistantTextBox

# ============================================================
# GLOW (mesma lógica do GlowTextureRect, adaptada pro NinePatchRect)
# ============================================================

@export_group("Glow")
@export var glow_tint: Color = Color(0.0, 1.0, 0.0):
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

var _mat: ShaderMaterial
var _initialized := false

# ============================================================
# ANCORAGEM FIXA (canto superior direito) — valores em PIXELS DE TELA
# ============================================================

@export_group("Anchoring")
@export var margin_top: float = 184.0
@export var margin_right: float = 13.0

# ============================================================
# TEXT BOX — todos os valores abaixo em PIXELS DE TELA (o script converte internamente)
# ============================================================

@export_group("Text Box")
@export var rich_text_label: RichTextLabel
@export var padding: Vector2 = Vector2(20, 20)
@export var min_size: Vector2 = Vector2(160, 60)
@export var max_width: float = 400.0
@export var resize_duration: float = 0.2

var _text_box_ready := false

# ============================================================
# LIFECYCLE
# ============================================================

func _ready():
	_ensure_material()
	_apply_glow_params()
	call_deferred("_setup_text_box")

func _setup_text_box():
	if rich_text_label == null:
		push_warning("AssistantTextBox: rich_text_label não atribuído em %s" % name)
		return

	rich_text_label.fit_content = true
	rich_text_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	rich_text_label.scroll_active = false

	_text_box_ready = true
	_update_size(false)

# ============================================================
# API PÚBLICA
# ============================================================

func set_message(text: String, animate: bool = true):
	if rich_text_label == null:
		push_warning("AssistantTextBox: rich_text_label não atribuído em %s" % name)
		return

	while not _text_box_ready:
		await get_tree().process_frame

	# remove tags BBCode só para fins de medição de largura (ex: [right]...[/right])
	var plain_text = _strip_bbcode(text)

	var local_padding = _to_local(padding)
	var local_max_width = max_width / max(scale.x, 0.001)
	var rtl_scale = rich_text_label.scale
	var max_wrap_width = (local_max_width - local_padding.x * 2) / max(rtl_scale.x, 0.001)

	var font_info = _get_font_and_size()
	var lines = _wrap_text(plain_text, max_wrap_width, font_info.font, font_info.size)

	# reconstrói o texto final com as linhas quebradas, preservando o BBCode original
	# se o texto tinha tags envolvendo tudo (ex: [right]...[/right]), reaplica em volta do resultado
	var wrapped_plain = "\n".join(lines)
	rich_text_label.text = _reapply_bbcode_wrapper(text, wrapped_plain)

	var content_line_width = 0.0
	for line in lines:
		var w = font_info.font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, font_info.size).x
		content_line_width = max(content_line_width, w)

	rich_text_label.position = local_padding
	rich_text_label.custom_minimum_size.x = content_line_width
	rich_text_label.size.x = content_line_width

	await get_tree().process_frame
	await get_tree().process_frame

	_update_size(animate, content_line_width * rtl_scale.x)

func _strip_bbcode(text: String) -> String:
	var regex = RegEx.new()
	regex.compile("\\[.*?\\]")
	return regex.sub(text, "", true)

func _reapply_bbcode_wrapper(original: String, wrapped_plain: String) -> String:
	# extrai a tag de abertura e fechamento do BBCode original, se existir,
	# e reaplica em volta do texto já quebrado em linhas
	var open_regex = RegEx.new()
	open_regex.compile("^(\\[[a-zA-Z]+\\])")
	var open_match = open_regex.search(original)

	var close_regex = RegEx.new()
	close_regex.compile("(\\[/[a-zA-Z]+\\])$")
	var close_match = close_regex.search(original)

	var prefix = open_match.get_string(1) if open_match else ""
	var suffix = close_match.get_string(1) if close_match else ""

	return prefix + wrapped_plain + suffix

# ============================================================
# MEDIÇÃO DE TEXTO (wrap manual)
# ============================================================

func _get_font_and_size() -> Dictionary:
	var font: Font = rich_text_label.get_theme_font("normal_font")
	if font == null:
		font = rich_text_label.get_theme_default_font()
	var font_size: int = rich_text_label.get_theme_font_size("normal_font_size")
	if font_size <= 0:
		font_size = 16
	return {"font": font, "size": font_size}

func _wrap_text(text: String, max_width_local: float, font: Font, font_size: int) -> PackedStringArray:
	var words = text.split(" ")
	var lines: PackedStringArray = []
	var current_line := ""

	for word in words:
		var candidate = word if current_line == "" else current_line + " " + word
		var w = font.get_string_size(candidate, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		if w <= max_width_local or current_line == "":
			current_line = candidate
		else:
			lines.append(current_line)
			current_line = word

	if current_line != "":
		lines.append(current_line)

	return lines

# ============================================================
# CONVERSÃO PIXELS DE TELA <-> UNIDADES LOCAIS (considerando scale do NinePatchRect)
# ============================================================

func _to_local(screen_units: Vector2) -> Vector2:
	return Vector2(
		screen_units.x / max(scale.x, 0.001),
		screen_units.y / max(scale.y, 0.001)
	)

# ============================================================
# RESIZE INTERNO
# ============================================================

func _update_size(animate: bool = true, content_width_local: float = -1.0):
	var local_padding = _to_local(padding)
	var local_min_size = _to_local(min_size)
	var local_max_width = max_width / max(scale.x, 0.001)

	var rtl_scale = rich_text_label.scale
	var content_height = rich_text_label.get_content_height() * rtl_scale.y

	# se não recebeu largura de conteúdo medida, usa max_width como antes (fallback)
	var content_width = content_width_local if content_width_local >= 0.0 else local_max_width - local_padding.x * 2

	var target_width = clamp(
		content_width + local_padding.x * 2,
		local_min_size.x,
		local_max_width
	)

	var target_size = Vector2(
		target_width,
		max(local_min_size.y, content_height + local_padding.y * 2)
	)

	var effective_size = target_size * scale

	var screen_width = get_viewport_rect().size.x
	var target_position = Vector2(
		screen_width - margin_right - effective_size.x,
		margin_top
	)

	if animate:
		var tween = create_tween()
		tween.set_trans(Tween.TRANS_QUAD)
		tween.set_parallel(true)
		tween.tween_property(self, "size", target_size, resize_duration)
		tween.tween_property(self, "position", target_position, resize_duration)
	else:
		size = target_size
		position = target_position

# ============================================================
# HELPERS DO GLOW (moldura)
# ============================================================

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

func _apply_glow_params():
	if not _ensure_material():
		return
	_mat.set_shader_parameter("glow_tint", Vector3(glow_tint.r, glow_tint.g, glow_tint.b))
	_mat.set_shader_parameter("detect_color", Vector3(detect_color.r, detect_color.g, detect_color.b))
	_mat.set_shader_parameter("threshold", threshold)
	_mat.set_shader_parameter("intensity", intensity)
	_mat.set_shader_parameter("blur_size", blur_size)
	_mat.set_shader_parameter("line_opacity", line_opacity)
