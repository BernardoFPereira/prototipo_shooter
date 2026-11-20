class_name TrashDebris
extends RigidBody3D

const MAX_PIECES: int = 250
const FREEZE_AFTER: float = 1.0

var spawn_time: int = 0
var _rest_time: float = 0.0


func setup(piece_size: float, piece_color: Color) -> void:
	var dims: Vector3 = Vector3(randf_range(0.6, 1.0), randf_range(0.3, 0.8), randf_range(0.6, 1.0)) * piece_size
	var mesh_instance: MeshInstance3D = $MeshInstance3D
	var box_mesh: BoxMesh = mesh_instance.mesh
	box_mesh.size = dims
	var box_material: StandardMaterial3D = box_mesh.material
	box_material.albedo_color = piece_color
	var collision: CollisionShape3D = $CollisionShape3D
	var box_shape: BoxShape3D = collision.shape
	box_shape.size = dims
	mass = maxf(dims.x * dims.y * dims.z * 4.0, 0.05)


func _ready() -> void:
	spawn_time = Time.get_ticks_msec()
	_remove_oldest_if_too_many()


func _remove_oldest_if_too_many() -> void:
	var pieces: Array = get_tree().get_nodes_in_group("trash_debris")
	while pieces.size() > MAX_PIECES:
		var oldest: TrashDebris = null
		for piece in pieces:
			if piece == self:
				continue
			if oldest == null or piece.spawn_time < oldest.spawn_time:
				oldest = piece
		if oldest == null:
			return
		pieces.erase(oldest)
		oldest.remove_from_group("trash_debris")
		oldest.queue_free()


func _physics_process(delta: float) -> void:
	if freeze:
		return
	if linear_velocity.length() < 0.1 and angular_velocity.length() < 0.1:
		_rest_time += delta
		if _rest_time >= FREEZE_AFTER:
			freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
			freeze = true
	else:
		_rest_time = 0.0
