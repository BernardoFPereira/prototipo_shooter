class_name TrashDebris
extends RigidBody3D


const MAX_PIECES: int = 250
const FREEZE_AFTER: float = 1.0

static var _all_pieces: Array = []
static var _materials: Dictionary = {}

var _rest_time: float = 0.0


func setup(piece_size: float, piece_color: Color) -> void:
	var dims: Vector3 = Vector3(randf_range(0.6, 1.0), randf_range(0.3, 0.8), randf_range(0.6, 1.0)) * piece_size
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = dims
	mesh.surface_set_material(0, _material_for(piece_color))
	var mesh_instance: MeshInstance3D = MeshInstance3D.new()
	mesh_instance.mesh = mesh
	add_child(mesh_instance)
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = dims
	var collision: CollisionShape3D = CollisionShape3D.new()
	collision.shape = shape
	add_child(collision)
	mass = maxf(dims.x * dims.y * dims.z * 4.0, 0.05)
	var pm: PhysicsMaterial = PhysicsMaterial.new()
	pm.friction = 1.0
	pm.rough = true
	physics_material_override = pm
	angular_damp = 2.0


static func _material_for(c: Color) -> StandardMaterial3D:
	var key: String = Color(snappedf(c.r, 0.05), snappedf(c.g, 0.05), snappedf(c.b, 0.05)).to_html(false)
	if not _materials.has(key):
		var mat: StandardMaterial3D = StandardMaterial3D.new()
		mat.albedo_color = Color.html(key)
		mat.roughness = 0.95
		_materials[key] = mat
	return _materials[key]


func _enter_tree() -> void:
	_all_pieces.append(self)
	while _all_pieces.size() > MAX_PIECES:
		var oldest: TrashDebris = _all_pieces.pop_front()
		if is_instance_valid(oldest) and oldest != self:
			oldest.queue_free()


func _exit_tree() -> void:
	_all_pieces.erase(self)


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
