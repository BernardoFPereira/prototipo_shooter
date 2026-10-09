class_name TrashSpawner
extends Node3D

## Duto que despeja lixo no triturador. Arraste TrashSpawner.tscn pra fase, posicione acima do
## triturador e ajuste no Inspector. O lixo sai na posição do nó, caindo pra baixo.
## Para sozinho enquanto o triturador está levantado (lift) e volta quando ele desce.
## A seta laranja só aparece no editor.

## Cenas de lixo sorteadas a cada spawn. Vazio = usa o lixo procedural (Trash.tscn).
@export var trash_scenes: Array[PackedScene] = []
## Triturador que controla este duto. Vazio = procura o primeiro Triturador da fase.
@export var triturador: Triturador
## Liga/desliga o duto manualmente (ex: por um botão ou evento da fase).
@export var enabled: bool = true

@export_group("Ritmo")
## Segundos entre um lixo e outro (sorteado entre x e y).
@export var interval: Vector2 = Vector2(1.5, 4.0)
## Espera antes do primeiro lixo (bom pra dutos diferentes não soltarem juntos).
@export var start_delay: float = 0.5
## Máximo de lixos vivos deste duto ao mesmo tempo (os esmagados não contam).
@export var max_alive: int = 8

@export_group("Saída")
## Raio (m) em volta do duto onde o lixo pode aparecer.
@export var spawn_radius: float = 0.6
## Velocidade inicial do lixo (padrão: pra baixo).
@export var initial_velocity: Vector3 = Vector3(0, -3, 0)
## Giro inicial máximo (rad/s), pra o lixo não cair sempre igual.
@export var max_spin: float = 3.0

const DEFAULT_TRASH := preload("res://prefabs/Level2HeroProps/Trash/Trash.tscn")

var _timer: float = 0.0
var _alive: Array[Node3D] = []


func _ready() -> void:
	var marker := get_node_or_null("EditorMarker")
	if marker:
		marker.visible = false
	if triturador == null:
		triturador = _find_triturador(get_tree().current_scene)
	_timer = start_delay


func _physics_process(delta: float) -> void:
	if not is_active():
		return
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = randf_range(interval.x, interval.y)
	var still_alive: Array[Node3D] = []
	for n in _alive:
		if is_instance_valid(n):
			still_alive.append(n)
	_alive = still_alive
	if _alive.size() >= max_alive:
		return
	spawn_trash()


## true quando o duto pode soltar lixo (ligado e o triturador não está levantado).
func is_active() -> bool:
	if not enabled:
		return false
	if triturador and triturador.is_lifted:
		return false
	return true


func spawn_trash() -> Node3D:
	var scene: PackedScene = trash_scenes.pick_random() if not trash_scenes.is_empty() else DEFAULT_TRASH
	if scene == null or not scene.can_instantiate():
		return null
	var trash: Node3D = scene.instantiate()
	var holder := get_tree().current_scene if get_tree().current_scene else get_parent()
	holder.add_child(trash)
	var offset := Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)).limit_length(1.0) * spawn_radius
	trash.global_position = global_position + Vector3(offset.x, 0.0, offset.y)
	trash.rotation = Vector3(randf() * TAU, randf() * TAU, randf() * TAU)
	if trash is RigidBody3D:
		trash.linear_velocity = initial_velocity
		trash.angular_velocity = Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * max_spin
	_alive.append(trash)
	return trash


func _find_triturador(node: Node) -> Triturador:
	if node == null:
		return null
	if node is Triturador:
		return node
	for child in node.get_children():
		var found := _find_triturador(child)
		if found:
			return found
	return null
