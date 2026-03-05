extends GPUParticles3D

func _process(delta):
	if !emitting:
		queue_free()
