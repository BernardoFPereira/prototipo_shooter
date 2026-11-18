class_name TrashShard
extends RigidBody3D

const MAX_SHARDS: int = 30
const FREEZE_AFTER: float = 1.5

var spawn_time: int = 0
var _rest_time: float = 0.0


func _ready() -> void:
	spawn_time = Time.get_ticks_msec()
	_remove_oldest_if_too_many()


func _remove_oldest_if_too_many() -> void:
	var shards: Array = get_tree().get_nodes_in_group("trash_shard")
	while shards.size() > MAX_SHARDS:
		var oldest: TrashShard = null
		for shard in shards:
			if shard == self:
				continue
			if oldest == null or shard.spawn_time < oldest.spawn_time:
				oldest = shard
		if oldest == null:
			return
		shards.erase(oldest)
		oldest.remove_from_group("trash_shard")
		oldest.queue_free()


func _physics_process(delta: float) -> void:
	if freeze:
		return
	if linear_velocity.length() < 0.08 and angular_velocity.length() < 0.08:
		_rest_time += delta
		if _rest_time >= FREEZE_AFTER:
			freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
			freeze = true
	else:
		_rest_time = 0.0
