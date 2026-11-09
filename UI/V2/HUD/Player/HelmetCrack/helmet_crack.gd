class_name HelmetCrack
extends CanvasLayer

## Vidro do capacete rachando (morte do player).
## O efeito é o shader helmet_crack.gdshader no nó Crack; a animação "crack" do AnimationPlayer
## controla o quanto já rachou (crack_progress) e o clarão do impacto (flash) — dá pra ajustar
## o ritmo mexendo nas keys dela. O formato (quantas rachaduras, espessura, cores, refração)
## fica no material do Crack (Inspector > Material > Shader Parameters).
##
## Fica numa CanvasLayer acima do GameHUD (layer -1), então o HUD apagado fica "atrás" do vidro
## e as rachaduras não escurecem junto com ele. Só aparece dentro da visão do capacete
## (onde o HUD-HelmetFrame.png é transparente).

signal finished

## Sorteia o ponto do impacto dentro de impact_area a cada morte.
@export var randomize_impact: bool = true
## Região da tela (0-1) onde o impacto pode cair.
@export var impact_area: Rect2 = Rect2(0.3, 0.25, 0.4, 0.35)
## Sorteia um desenho de rachadura diferente a cada morte.
@export var randomize_pattern: bool = true
## Som de vidro quebrando (opcional). Toca no bus SFX.
@export var crack_sound: AudioStream
@export var crack_sound_volume_db: float = 0.0

@onready var crack_rect: ColorRect = $Crack
@onready var anim: AnimationPlayer = $AnimationPlayer
var _mat: ShaderMaterial
var _sound: AudioStreamPlayer


func _ready() -> void:
	_mat = crack_rect.material as ShaderMaterial
	anim.animation_finished.connect(_on_animation_finished)
	reset()


## Racha o vidro. impact_uv (0-1 na tela) é opcional; sem ele usa o sorteio/valor do material.
func play(impact_uv: Variant = null) -> void:
	if _mat:
		if impact_uv is Vector2:
			_mat.set_shader_parameter("impact_point", impact_uv)
		elif randomize_impact:
			_mat.set_shader_parameter("impact_point", Vector2(
				randf_range(impact_area.position.x, impact_area.end.x),
				randf_range(impact_area.position.y, impact_area.end.y)))
		if randomize_pattern:
			_mat.set_shader_parameter("seed", randf() * 100.0)
	crack_rect.visible = true
	anim.play("crack")
	if crack_sound:
		if _sound == null:
			_sound = AudioStreamPlayer.new()
			_sound.bus = &"SFX"
			add_child(_sound)
		_sound.stream = crack_sound
		_sound.volume_db = crack_sound_volume_db
		_sound.play()


## Volta o vidro ao normal (e esconde, pra não gastar nada enquanto não é usado).
func reset() -> void:
	anim.play("RESET")
	anim.advance(0.0)
	anim.stop()
	crack_rect.visible = false


func _on_animation_finished(anim_name: StringName) -> void:
	if anim_name == &"crack":
		finished.emit()
