class_name TrashDebris
extends RigidBody3D

## Pedaço de lixo esmagado. Cai por baixo do triturador e fica no chão, acumulando.
## Pra não pesar, existe um limite de pedaços na fase inteira (MAX_PIECES): quando passa,
## os mais antigos somem primeiro.

const MAX_PIECES: int = 150

static var _all_pieces: Array[TrashDebris] = []


func setup(piece_size: float, piece_color: Color) -> void:
	var dims := Vector3(randf_range(0.6, 1.0), randf_range(0.3, 0.8), randf_range(0.6, 1.0)) * piece_size
	var mesh := BoxMesh.new()
	mesh.size = dims
	var mat := StandardMaterial3D.new()
	mat.albedo_color = piece_color
	mat.roughness = 0.95
	mesh.surface_set_material(0, mat)
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.mesh = mesh
	add_child(mesh_instance)
	var shape := BoxShape3D.new()
	shape.size = dims
	var collision := CollisionShape3D.new()
	collision.shape = shape
	add_child(collision)
	mass = maxf(dims.x * dims.y * dims.z * 4.0, 0.05)


func _enter_tree() -> void:
	_all_pieces.append(self)
	while _all_pieces.size() > MAX_PIECES:
		var oldest: TrashDebris = _all_pieces.pop_front()
		if is_instance_valid(oldest) and oldest != self:
			oldest.queue_free()


func _exit_tree() -> void:
	_all_pieces.erase(self)
