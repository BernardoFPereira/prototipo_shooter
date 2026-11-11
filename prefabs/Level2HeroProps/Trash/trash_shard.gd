class_name TrashShard
extends RigidBody3D

## Pedaço quebrado do modelo do lixo (as cenas de "prefabs dos triturados", ex: amasso_1.tscn).
## Essas cenas são só a mesh (Node3D + MeshInstance3D); aqui ela vira um corpo com física:
## a colisão é um casco convexo gerado da própria mesh (calculado uma vez por cena e reaproveitado).
## Como os pedacinhos (TrashDebris), passam por baixo do triturador e ficam no chão; quando param,
## congelam (ficam estáticos, sem custo). Limite de MAX_SHARDS na fase — os mais antigos somem.

const MAX_SHARDS: int = 30
## Segundos parado antes de congelar.
const FREEZE_AFTER: float = 1.5

static var _all: Array[TrashShard] = []
static var _shape_cache: Dictionary = {} # caminho da cena -> Array[[Transform3D, Shape3D]]

var _rest_time: float = 0.0


## Cria o pedaço a partir de uma cena de "prefabs dos triturados".
static func create(scene: PackedScene, scale_factor: float = 1.0) -> TrashShard:
	var shard := TrashShard.new()
	var visual: Node3D = scene.instantiate()
	visual.scale = Vector3.ONE * scale_factor
	shard.add_child(visual)
	var key := "%s@%s" % [scene.resource_path, scale_factor]
	if not _shape_cache.has(key):
		_shape_cache[key] = _build_shapes(visual)
	for entry in _shape_cache[key]:
		var cs := CollisionShape3D.new()
		cs.transform = entry[0]
		cs.shape = entry[1]
		shard.add_child(cs)
	var volume := 0.0
	for entry in _shape_cache[key]:
		var s: Vector3 = entry[1].get_debug_mesh().get_aabb().size
		volume += s.x * s.y * s.z
	shard.mass = clampf(volume * 2.0, 0.5, 8.0)
	var pm := PhysicsMaterial.new()
	pm.friction = 1.0
	pm.rough = true
	pm.bounce = 0.05
	shard.physics_material_override = pm
	shard.angular_damp = 1.5
	shard.linear_damp = 0.2
	return shard


## Uma forma convexa por MeshInstance3D, já com a escala aplicada nos pontos.
static func _build_shapes(visual: Node3D) -> Array:
	var result: Array = []
	var meshes: Array = visual.find_children("*", "MeshInstance3D", true, false)
	if visual is MeshInstance3D:
		meshes.append(visual)
	for mi: MeshInstance3D in meshes:
		if mi.mesh == null:
			continue
		var convex := mi.mesh.create_convex_shape(true, true) as ConvexPolygonShape3D
		if convex == null:
			continue
		# transform da mesh relativa ao corpo (a cena do pedaço é filha direta do corpo)
		var xf := visual.transform
		var n: Node = mi
		var chain: Array[Transform3D] = []
		while n != visual:
			chain.push_front((n as Node3D).transform)
			n = n.get_parent()
		for t in chain:
			xf = xf * t
		var baked := ConvexPolygonShape3D.new()
		var pts := PackedVector3Array()
		for p in convex.points:
			pts.append(xf.basis * p)
		baked.points = pts
		result.append([Transform3D(Basis(), xf.origin), baked])
	return result


## Passa a escala dos CollisionShape3D (filhos diretos) pros pontos da forma convexa.
## O Godot ignora a escala da colisão ao calcular a inércia: com escala 0.01 (Blender) o corpo
## fica com inércia de um objeto 100x maior, quase não gira e desliza pelo chão.
static func bake_collision_scale(body: CollisionObject3D) -> void:
	for c in body.get_children():
		if not (c is CollisionShape3D) or c.shape == null:
			continue
		var cs: CollisionShape3D = c
		var sc := cs.transform.basis.get_scale()
		if sc.is_equal_approx(Vector3.ONE):
			continue
		if cs.shape is ConvexPolygonShape3D:
			var baked := ConvexPolygonShape3D.new()
			var pts := PackedVector3Array()
			for p in (cs.shape as ConvexPolygonShape3D).points:
				pts.append(cs.transform.basis * p)
			baked.points = pts
			cs.shape = baked
			cs.transform = Transform3D(Basis(), cs.transform.origin)
		else:
			push_warning("%s: colisão '%s' com escala %s não foi corrigida (só ConvexPolygonShape3D)." % [body.name, cs.name, sc])


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
