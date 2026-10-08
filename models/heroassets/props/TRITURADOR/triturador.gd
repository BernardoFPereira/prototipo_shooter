class_name Triturador
extends Node3D

@export_group("Animações")
@export var lift_animation: StringName = &"lift"
@export var unlift_animation: StringName = &"unlift"
@export var grinder_animation: StringName = &"grinder_on"
## Começa a fase embaixo (posição final do unlift). Desligado = fica onde foi colocado na fase.
@export var start_lowered: bool = true

@export_group("Giro")
## Segundos pra desacelerar até parar quando o botão é pressionado.
@export var spin_down_time: float = 1.5
## Segundos pra voltar à velocidade normal quando o botão é solto.
@export var spin_up_time: float = 1.0
## Volta a girar quando o botão é solto.
@export var resume_on_release: bool = true

@export_group("Dano")
@export var damage: float = 34.0
## Intervalo (s) entre danos enquanto o Player continua encostado.
@export var damage_interval: float = 0.5
## Só machuca enquanto gira (parado, dá pra encostar/subir nele). Desacelerando ainda machuca.
@export var damage_only_while_spinning: bool = true
## Abaixo dessa velocidade (0 a 1) o giro conta como "parado" pro dano.
@export_range(0.0, 1.0) var harmless_below_speed: float = 0.1

@onready var level_animations: AnimationPlayer = $LevelAnimations
@onready var self_animations: AnimationPlayer = $SelfAnimations
@onready var damage_area: Area3D = $Area3D

var is_lifted: bool = false
var _spin_tween: Tween
var _bodies_inside: Array[Player] = []
var _next_hit_time: Dictionary = {} # Player -> tempo (s) em que pode levar dano de novo
var _clock: float = 0.0 # tempo de jogo (não anda com o jogo pausado)


func _ready() -> void:
	damage_area.body_entered.connect(_on_damage_area_body_entered)
	damage_area.body_exited.connect(_on_damage_area_body_exited)
	if start_lowered and level_animations.has_animation(unlift_animation):
		level_animations.play(unlift_animation)
		level_animations.seek(level_animations.current_animation_length, true)
	if not self_animations.is_playing() and self_animations.has_animation(grinder_animation):
		self_animations.play(grinder_animation)


func _physics_process(delta: float) -> void:
	_clock += delta
	if _bodies_inside.is_empty() or not is_hurting():
		return
	var now := _clock
	for body in _bodies_inside.duplicate():
		if not is_instance_valid(body):
			_bodies_inside.erase(body)
			continue
		if now >= _next_hit_time.get(body, 0.0):
			_next_hit_time[body] = now + damage_interval
			body.take_damage(damage)


#region BOTÃO (chamado pelo SwordButton)
func on_button_pressed() -> void:
	if is_lifted:
		return
	is_lifted = true
	_play_level_animation(lift_animation)
	_tween_spin(0.0, spin_down_time)


func on_button_released() -> void:
	if not is_lifted:
		return
	is_lifted = false
	_play_level_animation(unlift_animation)
	if resume_on_release:
		_tween_spin(1.0, spin_up_time)
#endregion


#region GIRO
## true enquanto o triturador machuca quem encosta.
func is_hurting() -> bool:
	if not damage_only_while_spinning:
		return true
	return self_animations.is_playing() and self_animations.speed_scale > harmless_below_speed


## Acelera/desacelera o giro mudando a velocidade do SelfAnimations (1 = normal, 0 = parado).
func _tween_spin(target_speed: float, duration: float) -> void:
	if _spin_tween and _spin_tween.is_valid():
		_spin_tween.kill()
	if target_speed > 0.0 and not self_animations.is_playing():
		self_animations.speed_scale = 0.0
		self_animations.play(grinder_animation) # continua de onde parou
	# Tempo proporcional ao quanto falta (se apertar no meio da desaceleração, não recomeça do zero).
	var remaining := absf(target_speed - self_animations.speed_scale)
	_spin_tween = create_tween()
	if target_speed < self_animations.speed_scale:
		_spin_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT) # perde velocidade rápido e "rola" até parar
	else:
		_spin_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN) # começa devagar, como um motor pegando
	_spin_tween.tween_property(self_animations, "speed_scale", target_speed, maxf(duration * remaining, 0.01))
	if target_speed <= 0.0:
		_spin_tween.tween_callback(self_animations.pause)
#endregion


#region SUBIR / DESCER
## Toca lift/unlift começando do ponto da animação mais próximo da posição atual. Assim, se soltar
## o botão no meio da subida, ele desce dali mesmo em vez de pular pro começo da animação.
func _play_level_animation(anim_name: StringName) -> void:
	if not level_animations.has_animation(anim_name):
		push_warning("Triturador: animação '%s' não existe no LevelAnimations." % anim_name)
		return
	var anim := level_animations.get_animation(anim_name)
	var track := anim.find_track(NodePath(".:position"), Animation.TYPE_VALUE)
	level_animations.play(anim_name)
	if track == -1:
		return
	var best_time := 0.0
	var best_dist := INF
	var steps := 100
	for i in steps + 1:
		var t := anim.length * float(i) / float(steps)
		var dist := position.distance_to(anim.value_track_interpolate(track, t))
		if dist < best_dist:
			best_dist = dist
			best_time = t
	level_animations.seek(best_time, true)
#endregion


#region DANO
func _on_damage_area_body_entered(body: Node3D) -> void:
	if body is Player and not _bodies_inside.has(body):
		_bodies_inside.append(body)


func _on_damage_area_body_exited(body: Node3D) -> void:
	_bodies_inside.erase(body)
#endregion
