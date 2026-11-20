class_name TrashCrushFX
extends Node3D

@export var debris_scene: PackedScene

@export_group("Pedaços com física")
@export var debris_size_ratio: Vector2 = Vector2(0.12, 0.3)
@export var debris_spread_speed: float = 2.5
@export var debris_vertical_speed: Vector2 = Vector2(-3.0, 1.0)

@export_group("Partículas")
@export var dust_color: Color = Color(0.6, 0.58, 0.52)
@export var lifetime: float = 3.0

var color: Color = Color(0.36, 0.33, 0.27)
var source_size: float = 1.0
var debris_count: int = 5
var ignore_bodies: Array = []
var spawn_position: Vector3 = Vector3.ZERO
var shard_scenes: Array = []

@onready var dust: GPUParticles3D = $Dust
@onready var chips: GPUParticles3D = $Chips


func _ready() -> void:
	global_position = spawn_position
	var dust_material: ParticleProcessMaterial = dust.process_material
	dust_material.color = color.lerp(dust_color, 0.6)
	var chips_material: ParticleProcessMaterial = chips.process_material
	chips_material.color = color
	dust.emitting = true
	chips.emitting = true
	_spawn_debris()
	_spawn_shards()
	get_tree().create_timer(lifetime, false).timeout.connect(queue_free)


func _ignore_crusher(body: RigidBody3D) -> void:
	for other in ignore_bodies:
		if other is PhysicsBody3D and is_instance_valid(other):
			body.add_collision_exception_with(other)


func _spawn_debris() -> void:
	if debris_scene == null:
		return
	var holder: Node = get_parent()
	for i in debris_count:
		var piece: TrashDebris = debris_scene.instantiate()
		var piece_size: float = source_size * randf_range(debris_size_ratio.x, debris_size_ratio.y)
		piece.setup(piece_size, color.darkened(randf_range(0.0, 0.25)))
		_ignore_crusher(piece)
		holder.add_child(piece)
		var offset: Vector3 = Vector3(randf_range(-0.5, 0.5), randf_range(-0.3, 0.3), randf_range(-0.5, 0.5)) * source_size
		piece.global_position = global_position + offset
		piece.rotation = Vector3(randf() * TAU, randf() * TAU, randf() * TAU)
		var spread: Vector2 = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)).limit_length(1.0) * debris_spread_speed
		piece.linear_velocity = Vector3(spread.x, randf_range(debris_vertical_speed.x, debris_vertical_speed.y), spread.y)
		piece.angular_velocity = Vector3(randf_range(-8, 8), randf_range(-8, 8), randf_range(-8, 8))


func _spawn_shards() -> void:
	var holder: Node = get_parent()
	for scene in shard_scenes:
		if scene == null:
			continue
		var shard: TrashShard = scene.instantiate()
		_ignore_crusher(shard)
		holder.add_child(shard)
		var offset: Vector3 = Vector3(randf_range(-0.4, 0.4), randf_range(-0.2, 0.2), randf_range(-0.4, 0.4)) * source_size
		shard.global_position = global_position + offset
		shard.rotation = Vector3(randf() * TAU, randf() * TAU, randf() * TAU)
		var spread: Vector2 = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)).limit_length(1.0) * debris_spread_speed * 0.6
		shard.linear_velocity = Vector3(spread.x, randf_range(debris_vertical_speed.x, debris_vertical_speed.y), spread.y)
		shard.angular_velocity = Vector3(randf_range(-4, 4), randf_range(-4, 4), randf_range(-4, 4))
