extends Node3D

## Porta grande: abre quando um Player ou inimigo entra na BodyDetectionArea3D e só fecha
## quando não sobra ninguém (vivo) dentro da área.

@export_category("Door Settings")
@export var can_open: bool = true
@export var detect_enemies: bool = true
@export var detect_player: bool = true
var is_opened: bool = false

@onready var anim_player: AnimationPlayer = $AnimationPlayer

# Quem está dentro da área agora (em vez de um contador, que podia ficar negativo ou errado).
var _bodies_inside: Array[Node3D] = []


func _process(_delta: float) -> void:
	# Inimigo que morre dentro da área continua "dentro", mas não deve segurar a porta aberta.
	if is_opened and not _has_someone_inside():
		_close()


func _on_body_detection_area_3d_body_entered(body):
	if not _counts(body):
		return
	if not _bodies_inside.has(body):
		_bodies_inside.append(body)
	if can_open and not is_opened:
		_open()


func _on_body_detection_area_3d_body_exited(body):
	_bodies_inside.erase(body)
	if is_opened and not _has_someone_inside():
		_close()


## Só Player e inimigos (conforme os checkboxes) abrem a porta.
## Atenção: tem que ser `body is Player` — `body == Player` compara o objeto com a CLASSE e
## nunca é verdadeiro (era por isso que a animação não tocava).
func _counts(body) -> bool:
	if detect_player and body is Player:
		return true
	if detect_enemies and body is EnemyBase:
		return true
	return false


func _has_someone_inside() -> bool:
	for body in _bodies_inside.duplicate():
		if not is_instance_valid(body):
			_bodies_inside.erase(body)
		elif body is EnemyBase and body.current_state == EnemyBase.EnemyState.DEAD:
			_bodies_inside.erase(body)
		elif body is Player and body.is_dead:
			_bodies_inside.erase(body)
	return not _bodies_inside.is_empty()


func _open() -> void:
	is_opened = true
	_play_from_mirror("open", "close")


func _close() -> void:
	is_opened = false
	_play_from_mirror("close", "open")


## Se a outra animação ainda estiver no meio (ex: fechando e alguém entra), começa esta do ponto
## equivalente em vez do início, pra porta não dar um pulo.
func _play_from_mirror(anim_name: String, opposite: String) -> void:
	var start_at := 0.0
	if anim_player.is_playing() and anim_player.current_animation == opposite:
		var progress := anim_player.current_animation_position / anim_player.current_animation_length
		start_at = (1.0 - progress) * anim_player.get_animation(anim_name).length
	anim_player.play(anim_name)
	anim_player.seek(start_at, true)
