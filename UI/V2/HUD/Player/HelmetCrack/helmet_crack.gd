class_name HelmetCrack
extends CanvasLayer


signal finished

@export var randomize_impact: bool = true
@export var impact_area: Rect2 = Rect2(0.3, 0.25, 0.4, 0.35)
@export var randomize_pattern: bool = true
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


func reset() -> void:
	anim.play("RESET")
	anim.advance(0.0)
	anim.stop()
	crack_rect.visible = false


func _on_animation_finished(anim_name: StringName) -> void:
	if anim_name == &"crack":
		finished.emit()
