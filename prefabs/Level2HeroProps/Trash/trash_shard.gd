class_name TrashShard
extends RigidBody3D


const MAX_SHARDS: int = 30
const FREEZE_AFTER: float = 1.5

static var _all: Array = []
static var _shape_cache: Dictionary = {}

var _rest_time: float = 0.0


static func create(scene: PackedScene, scale_factor: float = 1.0) -> TrashShard:
	var shard: TrashShard = TrashShard.new()
	var visual: Node3D = scene.instantiate()
	visual.scale = Vector3.ONE * scale_factor
	shard.add_child(visual)
	var key: String = scene.resource_path + "@" + str(scale_factor)
	if not _shape_cache.has(key):
		_shape_cache[key] = _build_shapes(visual)
	for entry in _shape_cache[key]:
		var cs: CollisionShape3D = CollisionShape3D.new()
		cs.transform = entry[0]
		cs.shape = entry[1]
		shard.add_child(cs)
	var volume: float = 0.0
	for entry in _shape_cache[key]:
		var s: Vector3 = entry[1].get_debug_mesh().get_aabb().size
		volume += s.x * s.y * s.z
	shard.mass = clampf(volume * 2.0, 0.5, 8.0)
	var pm: PhysicsMaterial = PhysicsMaterial.new()
	pm.friction = 1.0
	pm.rough = true
	pm.bounce = 0.05
	shard.physics_material_override = pm
	shard.angular_damp = 1.5
	shard.linear_damp = 0.2
	return shard


static func _build_shapes(visual: Node3D) -> Array:
	var result: Array = []
	var meshes: Array = visual.find_children("*", "MeshInstance3D", true, false)
	if visual is MeshInstance3D:
		meshes.append(visual)
	for mi: MeshInstance3D in meshes:
		if mi.mesh == null:
			continue
		var convex: ConvexPolygonShape3D = mi.mesh.create_convex_shape(true, true) as ConvexPolygonShape3D
		if convex == null:
			continue
		var xf: Transform3D = visual.transform
		var n: Node = mi
		var chain: Array = []
		while n != visual:
			chain.push_front((n as Node3D).transform)
			n = n.get_parent()
		for t in chain:
			xf = xf * t
		var baked: ConvexPolygonShape3D = ConvexPolygonShape3D.new()
		var pts: PackedVector3Array = PackedVector3Array()
		for p in convex.points:
			pts.append(xf.basis * p)
		baked.points = pts
		result.append([Transform3D(Basis(), xf.origin), baked])
	return result


static func bake_collision_scale(body: CollisionObject3D) -> void:
	for c in body.get_children():
		if not (c is CollisionShape3D) or c.shape == null:
			continue
		var cs: CollisionShape3D = c
		var sc: Vector3 = cs.transform.basis.get_scale()
		if sc.is_equal_approx(Vector3.ONE):
			continue
		if cs.shape is ConvexPolygonShape3D:
			var baked: ConvexPolygonShape3D = ConvexPolygonShape3D.new()
			var pts: PackedVector3Array = PackedVector3Array()
			for p in (cs.shape as ConvexPolygonShape3D).points:
				pts.append(cs.transform.basis * p)
			baked.points = pts
			cs.shape = baked
			cs.transform = Transform3D(Basis(), cs.transform.origin)
		else:
			push_warning(str(body.name) + ": colisão '" + str(cs.name) + "' com escala " + str(sc) + " não foi corrigida (só ConvexPolygonShape3D).")


func _enter_tree() -> void:
	_all.append(self)
	while _all.size() > MAX_SHARDS:
		var oldest: TrashShard = _all.pop_front()
		if is_instance_valid(oldest) and oldest != self:
			oldest.queue_free()


func _exit_tree() -> void:
	_all.erase(self)


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
