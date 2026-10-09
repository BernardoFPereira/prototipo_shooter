class_name Trash
extends RigidBody3D

## Lixo que cai no triturador. Quando as lâminas se encostam, o Triturador chama crush() em
## tudo que está em cima dele: o lixo some e no lugar aparece o efeito de esmagar (poeira +
## pedaços com física que caem por baixo do triturador e se acumulam no chão).
##
## Lixo procedural (padrão): cria sozinho uma forma aleatória (cubo, esfera, cilindro) com
## tamanho e cor aleatórios. Pra usar um modelo do Blender: crie uma cena herdada de Trash.tscn
## (ou um RigidBody3D com este script), coloque o MeshInstance3D + CollisionShape3D do modelo
## e desligue `procedural_shape`.

enum ShapeType { RANDOM, BOX, SPHERE, CYLINDER }

@export_group("Forma procedural")
## Gera a forma sozinho. Desligue quando o lixo tiver modelo próprio.
@export var procedural_shape: bool = true
@export var shape_type: ShapeType = ShapeType.RANDOM
## Tamanho (m) sorteado entre x e y.
@export var size_range: Vector2 = Vector2(0.6, 1.4)
## Cores sorteadas (também viram a cor dos pedaços).
@export var colors: Array[Color] = [
	Color(0.36, 0.33, 0.27), Color(0.29, 0.35, 0.24), Color(0.45, 0.38, 0.28),
	Color(0.25, 0.27, 0.30), Color(0.50, 0.44, 0.33), Color(0.33, 0.22, 0.18),
]

@export_group("Esmagar")
## Efeito criado quando é esmagado.
@export var crush_fx: PackedScene = preload("res://prefabs/Level2HeroProps/Trash/TrashCrushFX.tscn")
## Cor dos pedaços quando o lixo tem modelo próprio (no procedural usa a cor sorteada).
@export var debris_color: Color = Color(0.36, 0.33, 0.27)
## Quantos pedaços com física saem (sorteado entre x e y).
@export var debris_count: Vector2i = Vector2i(4, 7)

@export_group("Limpeza")
## Some sozinho depois de X segundos se nunca for esmagado (ex: caiu fora do triturador). 0 = nunca.
@export var max_lifetime: float = 60.0

var size: float = 1.0
var _color: Color
var _age: float = 0.0
var _crushed: bool = false


func _ready() -> void:
	# O Triturador só esmaga o que está encostado nos rolos — pra isso o corpo precisa reportar contatos.
	contact_monitor = true
	max_contacts_reported = maxi(max_contacts_reported, 8)
	_color = debris_color
	if procedural_shape:
		_build_random_shape()


func _physics_process(delta: float) -> void:
	if max_lifetime <= 0.0:
		return
	_age += delta
	if _age >= max_lifetime:
		queue_free()


## Chamado pelo Triturador quando as lâminas se encostam.
## ignore_bodies: corpos que os pedaços atravessam (o bloqueio do triturador), pra caírem por baixo.
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
		fx.spawn_position = global_position # posição do lixo AGORA (o efeito se posiciona sozinho)
		get_parent().add_child(fx)
	queue_free()


func _build_random_shape() -> void:
	size = randf_range(size_range.x, size_range.y)
	if not colors.is_empty():
		_color = colors.pick_random()

	var type := shape_type
	if type == ShapeType.RANDOM:
		type = [ShapeType.BOX, ShapeType.SPHERE, ShapeType.CYLINDER].pick_random()

	var mesh: Mesh
	var shape: Shape3D
	match type:
		ShapeType.BOX:
			# Caixas um pouco achatadas/esticadas ficam com mais cara de lixo.
			var dims := Vector3(randf_range(0.6, 1.0), randf_range(0.4, 1.0), randf_range(0.6, 1.0)) * size
			var box_mesh := BoxMesh.new(); box_mesh.size = dims; mesh = box_mesh
			var box_shape := BoxShape3D.new(); box_shape.size = dims; shape = box_shape
		ShapeType.SPHERE:
			var r := size * 0.5
			var sphere_mesh := SphereMesh.new(); sphere_mesh.radius = r; sphere_mesh.height = r * 2.0
			sphere_mesh.radial_segments = 10; sphere_mesh.rings = 6; mesh = sphere_mesh
			var sphere_shape := SphereShape3D.new(); sphere_shape.radius = r; shape = sphere_shape
		_:
			var r := size * randf_range(0.25, 0.4)
			var h := size * randf_range(0.7, 1.2)
			var cyl_mesh := CylinderMesh.new(); cyl_mesh.top_radius = r; cyl_mesh.bottom_radius = r
			cyl_mesh.height = h; cyl_mesh.radial_segments = 10; mesh = cyl_mesh
			var cyl_shape := CylinderShape3D.new(); cyl_shape.radius = r; cyl_shape.height = h; shape = cyl_shape

	var mat := StandardMaterial3D.new()
	mat.albedo_color = _color
	mat.roughness = 0.9
	mesh.surface_set_material(0, mat)

	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "Mesh"
	mesh_instance.mesh = mesh
	add_child(mesh_instance)
	var collision := CollisionShape3D.new()
	collision.name = "Collision"
	collision.shape = shape
	add_child(collision)
	mass = maxf(size * size, 0.2)
