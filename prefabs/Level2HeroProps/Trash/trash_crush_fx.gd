extends Node3D

## Efeito de lixo esmagado — mesma ideia dos gibs dos inimigos (enemy_gibs.gd): a cena é criada
## no lugar do objeto, liga todas as partículas (poeira e lascas) e se apaga sozinha depois.
## A diferença: além das partículas, solta pedaços com FÍSICA (TrashDebris) que caem por baixo
## do triturador e ficam acumulados no chão.

## Preenchidos por quem cria o efeito (Trash.crush()).
var color: Color = Color(0.36, 0.33, 0.27)
var source_size: float = 1.0
var debris_count: int = 5
var ignore_bodies: Array = []
## Onde o lixo foi esmagado (posição global).
var spawn_position: Vector3 = Vector3.ZERO

@export_group("Pedaços com física")
## Tamanho de cada pedaço, proporcional ao tamanho do lixo (sorteado entre x e y).
@export var debris_size_ratio: Vector2 = Vector2(0.18, 0.38)
## Velocidade horizontal máxima com que os pedaços se espalham.
@export var debris_spread_speed: float = 2.5
## Velocidade vertical inicial (negativo = já sai indo pra baixo).
@export var debris_vertical_speed: Vector2 = Vector2(-3.0, 1.0)
## Layer dos pedaços (padrão 19). Eles colidem com as layers de `debris_mask`.
@export_flags_3d_physics var debris_layer: int = 1 << 18
## Padrão: layers 1 e 5 (chão/paredes) e 19 (outros pedaços, pra empilhar).
@export_flags_3d_physics var debris_mask: int = 1 | (1 << 4) | (1 << 18)

@export_group("Partículas")
## Quanto tempo (s) o efeito fica vivo antes de se apagar (os pedaços com física continuam).
@export var lifetime: float = 3.0


func _ready() -> void:
	# Posiciona ANTES de soltar pedaços/partículas. Antes, a posição só era aplicada depois do
	# add_child — e o _ready roda dentro do add_child, então tudo saía na origem da fase.
	global_position = spawn_position
	for child in get_children():
		if child is GPUParticles3D:
			_tint_particles(child)
			child.emitting = true
	_spawn_debris()
	get_tree().create_timer(lifetime, false).timeout.connect(queue_free)


## A poeira/lascas pegam a cor do lixo (um pouco mais clara pra poeira).
func _tint_particles(particles: GPUParticles3D) -> void:
	var mat := particles.process_material as ParticleProcessMaterial
	if mat == null:
		return
	mat = mat.duplicate()
	if particles.name == "Dust":
		mat.color = color.lerp(Color(0.6, 0.58, 0.52), 0.6)
	else:
		mat.color = color
	particles.process_material = mat


func _spawn_debris() -> void:
	var holder := get_parent()
	for i in debris_count:
		var piece := TrashDebris.new()
		var piece_size := source_size * randf_range(debris_size_ratio.x, debris_size_ratio.y)
		piece.setup(piece_size, color.darkened(randf_range(0.0, 0.25)))
		piece.collision_layer = debris_layer
		piece.collision_mask = debris_mask
		for body in ignore_bodies:
			if body is PhysicsBody3D and is_instance_valid(body):
				piece.add_collision_exception_with(body)
		holder.add_child(piece)
		var offset := Vector3(randf_range(-0.5, 0.5), randf_range(-0.3, 0.3), randf_range(-0.5, 0.5)) * source_size
		piece.global_position = global_position + offset
		piece.rotation = Vector3(randf() * TAU, randf() * TAU, randf() * TAU)
		var dir := Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)).limit_length(1.0) * debris_spread_speed
		piece.linear_velocity = Vector3(dir.x, randf_range(debris_vertical_speed.x, debris_vertical_speed.y), dir.y)
		piece.angular_velocity = Vector3(randf_range(-8, 8), randf_range(-8, 8), randf_range(-8, 8))
