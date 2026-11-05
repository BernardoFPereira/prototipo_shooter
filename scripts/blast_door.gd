extends Node3D
class_name BlastDoor

@onready var decompression_fx = $DecompressionFX
@onready var gpu_particles_3d = $DecompressionFX/GPUParticles3D
@onready var animation_player = $AnimationPlayer

func start_decompress():
	decompression_fx.visible = true
	gpu_particles_3d.emitting = true
	
func open_blast_door():
	animation_player.play("open")
	
func close_blast_door():
	animation_player.play_backwards("open")
