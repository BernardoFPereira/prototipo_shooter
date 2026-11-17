extends Node3D


var color: Color = Color(0.36, 0.33, 0.27)
var source_size: float = 1.0
var debris_count: int = 5
var ignore_bodies: Array = []
var spawn_position: Vector3 = Vector3.ZERO
var shard_scenes: Array = []
var shard_scale: float = 1.0

@export_group("Pedaços com física")
@export var debris_size_ratio: Vector2 = Vector2(0.12, 0.3)
@export var debris_spread_speed: float = 2.5
@export var debris_vertical_speed: Vector2 = Vector2(-3.0, 1.0)
@export_flags_3d_physics var debris_layer: int = 1 << 18
@export_flags_3d_physics var debris_mask: int = 1 | (1 << 4) | (1 << 18)

@export_group("Partículas")
@export var lifetime: float = 3.0


func _ready() -> void:
	global_position = spawn_position
	for child in get_children():
		if child is GPUParticles3D:
			_tint_particles(child)
			child.emitting = true
	_spawn_debris()
	_spawn_shards()
	get_tree().create_timer(lifetime, false).timeout.connect(queue_free)


func _tint_particles(particles: GPUParticles3D) -> void:
	var mat: ParticleProcessMaterial = particles.process_material as ParticleProcessMaterial
	if mat == null:
		return
	mat = mat.duplicate()
	if particles.name == "Dust":
		mat.color = color.lerp(Color(0.6, 0.58, 0.52), 0.6)
	else:
		mat.color = color
	particles.process_material = mat


func _spawn_debris() -> void:
	var holder: Node = get_parent()
	for i in debris_count:
		var piece: TrashDebris = TrashDebris.new()
		var piece_size: float = source_size * randf_range(debris_size_ratio.x, debris_size_ratio.y)
		piece.setup(piece_size, color.darkened(randf_range(0.0, 0.25)))
		piece.collision_layer = debris_layer
		piece.collision_mask = debris_mask
		for body in ignore_bodies:
			if body is PhysicsBody3D and is_instance_valid(body):
				piece.add_collision_exception_with(body)
		holder.add_child(piece)
		var offset: Vector3 = Vector3(randf_range(-0.5, 0.5), randf_range(-0.3, 0.3), randf_range(-0.5, 0.5)) * source_size
		piece.global_position = global_position + offset
		piece.rotation = Vector3(randf() * TAU, randf() * TAU, randf() * TAU)
		var dir: Vector2 = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)).limit_length(1.0) * debris_spread_speed
		piece.linear_velocity = Vector3(dir.x, randf_range(debris_vertical_speed.x, debris_vertical_speed.y), dir.y)
		piece.angular_velocity = Vector3(randf_range(-8, 8), randf_range(-8, 8), randf_range(-8, 8))


func _spawn_shards() -> void:
	var holder: Node = get_parent()
	for scene in shard_scenes:
		if scene == null or not scene.can_instantiate():
			continue
		var shard: TrashShard = TrashShard.create(scene, shard_scale)
		shard.collision_layer = debris_layer
		shard.collision_mask = debris_mask
		for body in ignore_bodies:
			if body is PhysicsBody3D and is_instance_valid(body):
				shard.add_collision_exception_with(body)
		holder.add_child(shard)
		var offset: Vector3 = Vector3(randf_range(-0.4, 0.4), randf_range(-0.2, 0.2), randf_range(-0.4, 0.4)) * source_size
		shard.global_position = global_position + offset
		shard.rotation = Vector3(randf() * TAU, randf() * TAU, randf() * TAU)
		var dir: Vector2 = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)).limit_length(1.0) * debris_spread_speed * 0.6
		shard.linear_velocity = Vector3(dir.x, randf_range(debris_vertical_speed.x, debris_vertical_speed.y), dir.y)
		shard.angular_velocity = Vector3(randf_range(-4, 4), randf_range(-4, 4), randf_range(-4, 4))
