class_name Trash
extends RigidBody3D

enum ShapeType { RANDOM, BOX, SPHERE, CYLINDER }

@export_group("Forma procedural")
@export var procedural_shape: bool = true
@export var shape_type: ShapeType = ShapeType.RANDOM
@export var size_range: Vector2 = Vector2(0.6, 1.4)
@export var colors: Array[Color] = [
	Color(0.36, 0.33, 0.27), Color(0.29, 0.35, 0.24), Color(0.45, 0.38, 0.28),
	Color(0.25, 0.27, 0.30), Color(0.50, 0.44, 0.33), Color(0.33, 0.22, 0.18),
]

@export_group("Física")
@export_range(0.0, 1.0) var friction: float = 1.0
@export var rough: bool = true
@export_range(0.0, 1.0) var bounce: float = 0.05
@export var settle_angular_damp: float = 1.5
@export var settle_linear_damp: float = 0.2
@export var fix_scaled_collision: bool = true

@export_group("Esmagar")
@export var crush_fx: PackedScene = preload("res://prefabs/Level2HeroProps/Trash/TrashCrushFX.tscn")
@export var debris_color: Color = Color(0.36, 0.33, 0.27)
@export var debris_count: Vector2i = Vector2i(10, 16)

@export_group("Pedaços da mesh")
@export var shard_scenes: Array[PackedScene] = []
@export_range(0.0, 1.0) var shard_chance: float = 0.3
@export var shards_per_crush: Vector2i = Vector2i(1, 2)
@export var shard_scale: float = 1.0

@export_group("Limpeza")
@export var max_lifetime: float = 60.0

var size: float = 1.0
var _color: Color
var _age: float = 0.0
var _crushed: bool = false


func _ready() -> void:
	contact_monitor = true
	max_contacts_reported = maxi(max_contacts_reported, 8)
	_color = debris_color
	if procedural_shape:
		_build_random_shape()
	else:
		if fix_scaled_collision:
			TrashShard.bake_collision_scale(self)
		size = _estimate_size()
	_apply_physics_feel()


func _apply_physics_feel() -> void:
	if physics_material_override == null:
		var pm: PhysicsMaterial = PhysicsMaterial.new()
		pm.friction = friction
		pm.rough = rough
		pm.bounce = bounce
		physics_material_override = pm
	angular_damp = maxf(angular_damp, settle_angular_damp)
	linear_damp = maxf(linear_damp, settle_linear_damp)


func _estimate_size() -> float:
	var total: AABB = AABB()
	var first: bool = true
	for c in get_children():
		if c is CollisionShape3D and c.shape:
			var box: AABB = c.transform * c.shape.get_debug_mesh().get_aabb()
			if first:
				total = box
			else:
				total = total.merge(box)
			first = false
	if first:
		return 1.0
	return clampf((total.size.x + total.size.y + total.size.z) / 3.0 * 0.5, 0.3, 3.0)


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
	if crush_fx and crush_fx.can_instantiate():
		var fx = crush_fx.instantiate()
		fx.color = _color
		fx.source_size = size
		fx.debris_count = randi_range(debris_count.x, debris_count.y)
		fx.ignore_bodies = ignore_bodies
		fx.spawn_position = global_position
		fx.shard_scenes = _pick_shards()
		fx.shard_scale = shard_scale
		get_parent().add_child(fx)

	visible = false
	$AudioStreamPlayer3D.play()
	await get_tree().create_timer(2).timeout
	queue_free()


func _pick_shards() -> Array:
	if randf() >= shard_chance:
		return []
	var pool: Array = shard_scenes.filter(func(s): return s != null)
	if pool.is_empty():
		pool = _find_shard_scenes(scene_file_path)
	pool.shuffle()
	var n: int = mini(randi_range(shards_per_crush.x, shards_per_crush.y), pool.size())
	return pool.slice(0, n)


static var _shard_cache: Dictionary = {}

static func _find_shard_scenes(intact_path: String) -> Array:
	if intact_path == "":
		return []
	if _shard_cache.has(intact_path):
		return _shard_cache[intact_path].duplicate()
	var found: Array = []
	var base: String = intact_path.get_file().get_basename()
	var trash_dir: String = intact_path.get_base_dir().get_base_dir()
	for i in range(1, 10):
		var p: String = trash_dir + "/prefabs dos triturados/" + base + "_" + str(i) + ".tscn"
		if not ResourceLoader.exists(p):
			break
		found.append(load(p))
	_shard_cache[intact_path] = found
	return found.duplicate()


func _build_random_shape() -> void:
	size = randf_range(size_range.x, size_range.y)
	if not colors.is_empty():
		_color = colors.pick_random()

	var type: ShapeType = shape_type
	if type == ShapeType.RANDOM:
		type = [ShapeType.BOX, ShapeType.SPHERE, ShapeType.CYLINDER].pick_random()

	var mesh: Mesh
	var shape: Shape3D
	match type:
		ShapeType.BOX:
			var dims: Vector3 = Vector3(randf_range(0.6, 1.0), randf_range(0.4, 1.0), randf_range(0.6, 1.0)) * size
			var box_mesh: BoxMesh = BoxMesh.new()
			box_mesh.size = dims
			mesh = box_mesh
			var box_shape: BoxShape3D = BoxShape3D.new()
			box_shape.size = dims
			shape = box_shape
		ShapeType.SPHERE:
			var r: float = size * 0.5
			var sphere_mesh: SphereMesh = SphereMesh.new()
			sphere_mesh.radius = r
			sphere_mesh.height = r * 2.0
			sphere_mesh.radial_segments = 10
			sphere_mesh.rings = 6
			mesh = sphere_mesh
			var sphere_shape: SphereShape3D = SphereShape3D.new()
			sphere_shape.radius = r
			shape = sphere_shape
		_:
			var r: float = size * randf_range(0.25, 0.4)
			var h: float = size * randf_range(0.7, 1.2)
			var cyl_mesh: CylinderMesh = CylinderMesh.new()
			cyl_mesh.top_radius = r
			cyl_mesh.bottom_radius = r
			cyl_mesh.height = h
			cyl_mesh.radial_segments = 10
			mesh = cyl_mesh
			var cyl_shape: CylinderShape3D = CylinderShape3D.new()
			cyl_shape.radius = r
			cyl_shape.height = h
			shape = cyl_shape

	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = _color
	mat.roughness = 0.9
	mesh.surface_set_material(0, mat)

	var mesh_instance: MeshInstance3D = MeshInstance3D.new()
	mesh_instance.name = "Mesh"
	mesh_instance.mesh = mesh
	add_child(mesh_instance)
	var collision: CollisionShape3D = CollisionShape3D.new()
	collision.name = "Collision"
	collision.shape = shape
	add_child(collision)
	mass = maxf(size * size, 0.2)
