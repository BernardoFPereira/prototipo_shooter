extends Node3D

@onready var spark_main = $SparkMain
@onready var circle_spark = $CircleSpark
@onready var glare = $Glare
@onready var animation_player = $"../SparkFX2/AnimationPlayer"

func _process(delta):
	var _time = randf_range(1.2, 2.5)
	await get_tree().create_timer(_time).timeout
	spark_main.emitting = true
	circle_spark.emitting = true
	glare.emitting = true
	animation_player.play("flicker")
