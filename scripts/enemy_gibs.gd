extends Node3D

@export var spatter_decal_textures: Array[Texture]
@export var decal_amount: int

func _ready():
	for child in get_children():
		if child is GPUParticles3D:
			child.emitting = true
	
	spawn_decals()

func spawn_decals():
	for decal in decal_amount:
		var decal_to_spawn = Decal.new()
		decal_to_spawn.texture_albedo = spatter_decal_textures[randi_range(0, 3)]
		decal_to_spawn.size = Vector3(6, 2, 6)
		decal_to_spawn.upper_fade = 0
		decal_to_spawn.lower_fade = 0
		decal_to_spawn.cull_mask = 1
		
		add_sibling(decal_to_spawn)
		decal_to_spawn.global_position = global_position + Vector3(randf_range(-3.0, 3.0), -2, randf_range(-3.0, 3.0))
		
		await get_tree().create_timer(.5).timeout

func _on_timer_timeout():
	queue_free()
