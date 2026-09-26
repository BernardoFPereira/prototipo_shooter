extends Node3D

func _ready():
	if get_children():
		for child in get_children():
			child.emitting = true
	#$Puffs.emitting = true
	#$Flash.emitting = true
	#emitting = true

func _process(delta):
	await get_tree().create_timer(1.5).timeout
	queue_free()
