class_name Trash
extends RigidBody3D

@export_group("Esmagar")
@export var crush_fx: PackedScene
@export var debris_color: Color = Color(0.36, 0.33, 0.27)
@export var debris_count: Vector2i = Vector2i(10, 16)
@export var size: float = 1.0

@export_group("Pedaços da mesh")
@export var shard_scenes: Array[PackedScene] = []
@export_range(0.0, 1.0) var shard_chance: float = 0.3
@export var shards_per_crush: Vector2i = Vector2i(1, 2)

@export_group("Limpeza")
@export var max_lifetime: float = 60.0

var _age: float = 0.0
var _crushed: bool = false


func _physics_process(delta: float) -> void:
	if max_lifetime <= 0.0:
		return
	_age += delta
	if _age >= max_lifetime:
		queue_free()


func crush(ignore_bodies: Array = []) -> void:
	if _crushed:
		return
	_crushed = true
	if crush_fx != null:
		var fx: TrashCrushFX = crush_fx.instantiate()
		fx.color = debris_color
		fx.source_size = size
		fx.debris_count = randi_range(debris_count.x, debris_count.y)
		fx.ignore_bodies = ignore_bodies
		fx.spawn_position = global_position
		fx.shard_scenes = _pick_shards()
		get_parent().add_child(fx)

	visible = false
	$AudioStreamPlayer3D.play()
	await get_tree().create_timer(2).timeout
	queue_free()


func _pick_shards() -> Array:
	if randf() >= shard_chance:
		return []
	var pool: Array = []
	for scene in shard_scenes:
		if scene != null:
			pool.append(scene)
	pool.shuffle()
	var amount: int = mini(randi_range(shards_per_crush.x, shards_per_crush.y), pool.size())
	return pool.slice(0, amount)
