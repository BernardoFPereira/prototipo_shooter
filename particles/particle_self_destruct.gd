extends GPUParticles3D

#func _ready():
	#$Puffs.emitting = true
	#$Flash.emitting = true
	#emitting = true

func _process(delta):
	await get_tree().create_timer(1.5).timeout
	queue_free()
