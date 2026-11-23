extends Node3D

@onready var spark_main = $SparkMain
@onready var circle_spark = $CircleSpark
@onready var glare = $Glare
@onready var animation_player = $AnimationPlayer
@onready var audio_stream = $AudioStream
@onready var timer = $Timer

@export var is_load_scene: bool = false

func _on_timer_timeout():
	spark_main.emitting = true
	circle_spark.emitting = true
	glare.emitting = true
	animation_player.play("flicker")
	if !is_load_scene:
		audio_stream.play()
	
	timer.wait_time = randf_range(1.2, 4.0)
	timer.start()
