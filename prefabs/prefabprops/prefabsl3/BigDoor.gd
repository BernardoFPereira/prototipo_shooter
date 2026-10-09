extends Node3D


@export_category("Door Settings")
@export var can_open: bool = true
@export var detect_enemies: bool = true
@export var detect_player: bool = true
## true = porta aberta (ou abrindo). Só muda quando uma animação começa.
var is_opened: bool = false
## O que a porta QUER fazer agora (aberta se tem alguém dentro). Se uma animação estiver tocando,
## a porta espera ela terminar e só então vai pro estado desejado — nunca corta a animação.
var _want_open: bool = false

@onready var anim_player: AnimationPlayer = $AnimationPlayer

var _bodies_inside: Array[Node3D] = []


func _ready() -> void:
	anim_player.animation_finished.connect(_on_animation_finished)


func _process(_delta: float) -> void:
	if _want_open and not _has_someone_inside():
		_want_open = false
		_update_door()


func _on_body_detection_area_3d_body_entered(body):
	if not _counts(body):
		return
	if not _bodies_inside.has(body):
		_bodies_inside.append(body)
	if can_open:
		_want_open = true
		_update_door()


func _on_body_detection_area_3d_body_exited(body):
	if is_instance_valid(body):
		_bodies_inside.erase(body)
	if not _has_someone_inside():
		_want_open = false
		_update_door()

func _counts(body) -> bool:
	if detect_player and body is Player:
		return true
	if detect_enemies and body is EnemyBase:
		return true
	return false


func _has_someone_inside() -> bool:
	# Reconstrói a lista (erase() de objeto já destruído num Array tipado dá erro).
	var still_inside: Array[Node3D] = []
	for body in _bodies_inside:
		if not is_instance_valid(body):
			continue
		if body is EnemyBase and body.current_state == EnemyBase.EnemyState.DEAD:
			continue
		if body is Player and body.is_dead:
			continue
		still_inside.append(body)
	_bodies_inside = still_inside
	return not _bodies_inside.is_empty()


## Toca open/close só quando nenhuma animação estiver tocando. Se o jogador sair e entrar rápido,
## a animação atual termina inteira e depois a porta vai pro estado certo.
func _update_door() -> void:
	if anim_player.is_playing():
		return # _on_animation_finished chama de novo quando terminar
	if _want_open == is_opened:
		return
	is_opened = _want_open
	anim_player.play("open" if is_opened else "close")


func _on_animation_finished(_anim_name: StringName) -> void:
	_update_door()
