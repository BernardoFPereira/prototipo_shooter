@tool
extends NinePatchRect
class_name AssistantTextBox


signal message_timeout
signal text_revealed

@onready var text_audio_stream = %TextSFX


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
var _initialized: bool = false


@export_group("Anchoring")
@export var margin_top: float = 184.0
@export var margin_right: float = 13.0


@export_group("Text Box")
@export var rich_text_label: RichTextLabel
@export var padding: Vector2 = Vector2(20, 20)
@export var min_size: Vector2 = Vector2(160, 60)
@export var max_width: float = 400.0
@export var message_display_time: float = 20.0

const ANIM_SPEED: int = 30
var animate_text: bool = false
var _text_box_ready: bool = false
var _resize_tween: Tween
var _display_timer: Timer


func _ready():
	_ensure_material()
	_apply_glow_params()
	if Engine.is_editor_hint():
		return
	visible = false
	_setup_display_timer()
	call_deferred("_setup_text_box")


func _process(delta):
	if Engine.is_editor_hint() or not animate_text:
		return

	if not text_audio_stream.playing:
		text_audio_stream.playing = true

	var total_chars = rich_text_label.get_total_character_count()
	if total_chars <= 0:
		animate_text = false
		text_revealed.emit()
		return

	if rich_text_label.visible_ratio < 1.0:
		rich_text_label.visible_ratio += (1.0 / total_chars) * (ANIM_SPEED * delta)
	else:
		text_audio_stream.playing = false
		animate_text = false
		text_revealed.emit()
		_start_display_timer()


func _setup_text_box():
	if rich_text_label == null:
		push_warning("AssistantTextBox: rich_text_label não atribuído em " + str(name))
		return
	rich_text_label.fit_content = false
	rich_text_label.scroll_active = false
	rich_text_label.clip_contents = false
	_text_box_ready = true


func set_message(text: String, animate: bool = true) -> void:
	if rich_text_label == null:
		push_warning("AssistantTextBox: rich_text_label não atribuído em " + str(name))
		return
	while not _text_box_ready:
		await get_tree().process_frame

	_display_timer.stop()
	if _resize_tween and _resize_tween.is_valid():
		_resize_tween.kill()
	animate_text = false
	text_audio_stream.playing = false
	visible = false

	var box_scale: Vector2 = scale
	var label_scale: Vector2 = rich_text_label.scale
	var pad: Vector2 = padding / box_scale
	var max_text_width: float = (max_width / box_scale.x - pad.x * 2.0) / label_scale.x

	var font: Font = rich_text_label.get_theme_font("normal_font")
	var font_size: int = rich_text_label.get_theme_font_size("normal_font_size")
	var lines: PackedStringArray = _wrap_text(_strip_bbcode(text), max_text_width, font, font_size)
	var text_width: float = 0.0
	for line in lines:
		text_width = maxf(text_width, font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x)
	var line_height: float = font.get_height(font_size) + rich_text_label.get_theme_constant("line_separation")
	var text_height: float = line_height * lines.size()

	rich_text_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	rich_text_label.text = _reapply_bbcode_wrapper(text, "\n".join(lines))
	rich_text_label.size = Vector2(ceilf(text_width) + 1.0, text_height)

	var min_local: Vector2 = min_size / box_scale
	var box_width: float = maxf(rich_text_label.size.x * label_scale.x + pad.x * 2.0, min_local.x)
	var box_height: float = maxf(text_height * label_scale.y + pad.y * 2.0, min_local.y)
	size = Vector2(box_width, 0.0)

	position = Vector2(get_parent_area_size().x - margin_right - size.x * box_scale.x, margin_top)

	rich_text_label.position = Vector2(size.x - pad.x - rich_text_label.size.x * label_scale.x, pad.y)

	visible = true

	if not animate:
		size.y = box_height
		rich_text_label.visible_ratio = 1.0
		text_revealed.emit()
		_start_display_timer()
		return

	rich_text_label.visible_ratio = 0.0
	var total_chars = maxi(rich_text_label.get_total_character_count(), 1)
	var reveal_duration = float(total_chars) / float(ANIM_SPEED)

	_resize_tween = create_tween()
	_resize_tween.set_trans(Tween.TRANS_QUAD)
	_resize_tween.set_ease(Tween.EASE_OUT)
	_resize_tween.tween_property(self, "size:y", box_height, reveal_duration)

	animate_text = true


func change_line(new_line: String) -> void:
	set_message(new_line, true)


func _wrap_text(text: String, max_width_px: float, font: Font, font_size: int) -> PackedStringArray:
	var lines: PackedStringArray = []
	for paragraph in text.split("\n"):
		var current_line: String = ""
		for word in paragraph.split(" "):
			var candidate
			if current_line == "":
				candidate = word
			else:
				candidate = current_line + " " + word
			if current_line == "" or font.get_string_size(candidate, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x <= max_width_px:
				current_line = candidate
			else:
				lines.append(current_line)
				current_line = word
		lines.append(current_line)
	return lines


func _strip_bbcode(text: String) -> String:
	var regex: RegEx = RegEx.new()
	regex.compile("\\[.*?\\]")
	return regex.sub(text, "", true)


func _reapply_bbcode_wrapper(original: String, wrapped_plain: String) -> String:
	var open_regex: RegEx = RegEx.new()
	open_regex.compile("^(\\[[a-zA-Z]+\\])")
	var open_match: RegExMatch = open_regex.search(original)
	var close_regex: RegEx = RegEx.new()
	close_regex.compile("(\\[/[a-zA-Z]+\\])$")
	var close_match: RegExMatch = close_regex.search(original)
	var prefix: String
	if open_match:
		prefix = open_match.get_string(1)
	else:
		prefix = ""
	var suffix: String
	if close_match:
		suffix = close_match.get_string(1)
	else:
		suffix = ""
	return prefix + wrapped_plain + suffix


func _setup_display_timer():
	_display_timer = Timer.new()
	_display_timer.one_shot = true
	_display_timer.timeout.connect(_on_display_timer_timeout)
	add_child(_display_timer)


func _on_display_timer_timeout():
	message_timeout.emit()


func _start_display_timer():
	if message_display_time > 0.0:
		_display_timer.start(message_display_time)


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
