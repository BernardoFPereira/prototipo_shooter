@tool
extends NinePatchRect
class_name AssistantTextBox

## Caixa de mensagem do assistente (AVIC). Se ajusta sozinha ao texto do RichTextLabel filho:
##   - a borda DIREITA da caixa fica fixa na tela (margin_right) e ela cresce/encolhe pra esquerda;
##   - o texto fica colado na borda direita, com `padding` de folga em volta.
##
## O texto é medido direto pela fonte, linha por linha, ANTES de ir pro RichTextLabel: separa nos
## \n da mensagem, quebra por espaço as linhas que passam do max_width, e mede cada uma. Isso não
## depende do RichTextLabel já ter montado o layout (no jogo, o get_content_width() às vezes ainda
## devolvia a medida de uma linha só, e a caixa ficava pequena demais).
##
## Todas as medidas exportadas (padding, max_width, min_size, margens) são em PIXELS DE TELA.
## O script converte sozinho pra escala deste nó (scale) e do RichTextLabel (scale dele).

signal message_timeout
## Emitido quando o texto termina de aparecer (fim da animação de digitação).
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
var _initialized := false


@export_group("Anchoring")
## Distância (px de tela) do topo da tela até o topo da caixa.
@export var margin_top: float = 184.0
## Distância (px de tela) da borda direita da tela até a borda direita da caixa.
@export var margin_right: float = 13.0


@export_group("Text Box")
@export var rich_text_label: RichTextLabel
## Folga (px de tela) entre a borda da caixa e o texto. x = esquerda/direita, y = cima/baixo.
@export var padding: Vector2 = Vector2(20, 20)
## Tamanho mínimo da caixa (px de tela).
@export var min_size: Vector2 = Vector2(160, 60)
## Largura máxima da caixa (px de tela). Linhas mais largas que isso quebram automaticamente.
@export var max_width: float = 400.0
## Quanto tempo (s) a mensagem fica na tela depois de terminar de aparecer. 0 = pra sempre.
@export var message_display_time: float = 20.0

const ANIM_SPEED: int = 30 # caracteres por segundo
var animate_text: bool = false
var _text_box_ready := false
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
		push_warning("AssistantTextBox: rich_text_label não atribuído em %s" % name)
		return
	# O tamanho do label é aplicado por este script; o fit_content só atrapalharia.
	rich_text_label.fit_content = false
	rich_text_label.scroll_active = false
	rich_text_label.clip_contents = false
	_text_box_ready = true


#region MENSAGEM
func set_message(text: String, animate: bool = true) -> void:
	if rich_text_label == null:
		push_warning("AssistantTextBox: rich_text_label não atribuído em %s" % name)
		return
	while not _text_box_ready:
		await get_tree().process_frame

	_display_timer.stop()
	if _resize_tween and _resize_tween.is_valid():
		_resize_tween.kill()
	animate_text = false
	text_audio_stream.playing = false
	visible = false

	# Conversões: px de tela -> unidades desta caixa -> unidades do label.
	var box_scale := scale
	var label_scale := rich_text_label.scale
	var pad := padding / box_scale
	var max_text_width: float = (max_width / box_scale.x - pad.x * 2.0) / label_scale.x

	# 1) Quebra em linhas e mede pela fonte (determinístico, não depende do layout do label).
	var font: Font = rich_text_label.get_theme_font("normal_font")
	var font_size: int = rich_text_label.get_theme_font_size("normal_font_size")
	var lines := _wrap_text(_strip_bbcode(text), max_text_width, font, font_size)
	var text_width := 0.0
	for line in lines:
		text_width = maxf(text_width, font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x)
	var line_height := font.get_height(font_size) + rich_text_label.get_theme_constant("line_separation")
	var text_height := line_height * lines.size()

	# 2) O label recebe o texto já quebrado (sem quebra automática) e fica do tamanho exato dele.
	rich_text_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	rich_text_label.text = _reapply_bbcode_wrapper(text, "\n".join(lines))
	rich_text_label.size = Vector2(ceilf(text_width) + 1.0, text_height)

	# 3) Caixa = texto + padding. A altura começa no mínimo e cresce animada.
	var min_local := min_size / box_scale
	var box_width := maxf(rich_text_label.size.x * label_scale.x + pad.x * 2.0, min_local.x)
	var box_height := maxf(text_height * label_scale.y + pad.y * 2.0, min_local.y)
	size = Vector2(box_width, 0.0) # 0 = trava na altura mínima do NinePatchRect

	# 4) Borda direita fixa na tela.
	position = Vector2(get_parent_area_size().x - margin_right - size.x * box_scale.x, margin_top)

	# 5) Texto colado na borda direita da caixa (posicionado DEPOIS de redimensionar a caixa).
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


## Separa nos \n da mensagem e, dentro de cada parágrafo, quebra por espaço quando a linha passa de
## max_width_px (medido na fonte). Separar no \n PRIMEIRO é essencial: o get_string_size() ignora
## \n e mediria duas linhas como se fossem uma só.
func _wrap_text(text: String, max_width_px: float, font: Font, font_size: int) -> PackedStringArray:
	var lines: PackedStringArray = []
	for paragraph in text.split("\n"):
		var current_line := ""
		for word in paragraph.split(" "):
			var candidate = word if current_line == "" else current_line + " " + word
			if current_line == "" or font.get_string_size(candidate, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x <= max_width_px:
				current_line = candidate
			else:
				lines.append(current_line)
				current_line = word
		lines.append(current_line)
	return lines


func _strip_bbcode(text: String) -> String:
	var regex := RegEx.new()
	regex.compile("\\[.*?\\]")
	return regex.sub(text, "", true)


## Recoloca a tag que envolvia a mensagem (ex: "[right]" no começo). Só tags simples no começo/fim;
## tags que mudam fonte ou tamanho no meio do texto deixariam a medição errada.
func _reapply_bbcode_wrapper(original: String, wrapped_plain: String) -> String:
	var open_regex := RegEx.new()
	open_regex.compile("^(\\[[a-zA-Z]+\\])")
	var open_match := open_regex.search(original)
	var close_regex := RegEx.new()
	close_regex.compile("(\\[/[a-zA-Z]+\\])$")
	var close_match := close_regex.search(original)
	var prefix := open_match.get_string(1) if open_match else ""
	var suffix := close_match.get_string(1) if close_match else ""
	return prefix + wrapped_plain + suffix
#endregion


#region TIMER
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
#endregion


#region GLOW
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
#endregion
