extends Node3D
class_name BlastDoor

@onready var decompression_fx = $DecompressionFX
@onready var gpu_particles_3d = $DecompressionFX/GPUParticles3D
@onready var animation_player = $AnimationPlayer
@onready var decompress_loop = $DecompressLoop
@onready var decompress_start = $DecompressStart
@onready var open_sfx = $OpenSFX

func start_decompress():
	decompression_fx.visible = true
	gpu_particles_3d.emitting = true
	
func open_blast_door():
	animation_player.play("open")
	open_sfx.play()
	decompress_start.play()
	await get_tree().create_timer(0.5).timeout
	decompress_loop.play()

func close_blast_door():
	animation_player.play_backwards("open")

func _on_open_sfx_finished():
	decompress_loop.play()
