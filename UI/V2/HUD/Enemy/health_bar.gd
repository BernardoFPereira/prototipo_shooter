extends Sprite3D
@export var max_hp : int = 100
var real_value : float
@onready var progress_bar := $EnemyHealth/TextureProgressBar

func _ready():
	progress_bar.max_value = max_hp
	progress_bar.value = max_hp
	real_value = max_hp

func bar_take_damage(damage: float):
	real_value -= damage

	var percent = real_value / max_hp
	var new_color = Color(1.0 - percent, percent, 0.0, progress_bar.tint_progress.a)

	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(progress_bar, "value", real_value, 0.3)
	tween.tween_property(progress_bar, "tint_progress", new_color, 0.3)

func bar_dead():
	queue_free()
