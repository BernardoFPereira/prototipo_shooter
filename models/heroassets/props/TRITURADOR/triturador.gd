class_name Triturador
extends Node3D

## Emitido toda vez que as lâminas se encostam (segundo `crush_time` da grinder_on).
## crushed_count = quantos objetos foram esmagados nessa batida.
signal blades_closed(crushed_count: int)

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

@export_group("Esmagar")
## Momento (s) da grinder_on em que as lâminas se encostam. A cada volta da animação, ao passar
## por esse ponto, tudo que estiver em cima do triturador (com função crush()) é esmagado.
@export var crush_time: float = 1.9
## Layers dos objetos que podem ser esmagados (padrão: 18, a do lixo).
@export_flags_3d_physics var crush_mask: int = 1 << 17
## Só esmaga enquanto gira (parado/levantado não esmaga).
@export var crush_only_while_spinning: bool = true
## Quanto (m, no espaço do triturador) a área de esmagar é maior que o bloqueio, pra pegar o lixo
## que está apoiado em cima dos rolos.
@export var crush_area_margin: float = 0.6
## Só esmaga o que está ENCOSTADO nos rolos (Blocker). Sem isso, lixo caindo que só passou pela
## área na hora da batida explodia no ar, acima do triturador.
@export var require_contact: bool = true

@onready var level_animations: AnimationPlayer = $LevelAnimations
@onready var self_animations: AnimationPlayer = $SelfAnimations
@onready var damage_area: Area3D = $Area3D

var is_lifted: bool = false
var _spin_tween: Tween
var _bodies_inside: Array[Player] = []
var _next_hit_time: Dictionary = {} # Player -> tempo (s) em que pode levar dano de novo
var _clock: float = 0.0 # tempo de jogo (não anda com o jogo pausado)
var _crush_area: Area3D
var _last_grinder_pos: float = -1.0


func _ready() -> void:
	damage_area.body_entered.connect(_on_damage_area_body_entered)
	damage_area.body_exited.connect(_on_damage_area_body_exited)
	_setup_crush_area()
	if start_lowered and level_animations.has_animation(unlift_animation):
		level_animations.play(unlift_animation)
		level_animations.seek(level_animations.current_animation_length, true)
	if not self_animations.is_playing() and self_animations.has_animation(grinder_animation):
		self_animations.play(grinder_animation)


func _process(_delta: float) -> void:
	_check_blades_closed()


func _physics_process(delta: float) -> void:
	_clock += delta
	if _bodies_inside.is_empty() or not is_hurting():
		return
	var now := _clock
	for body in _bodies_inside.duplicate():
		if not is_instance_valid(body):
			_remove_invalid_bodies()
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


#region ESMAGAR
## Detecta quando a grinder_on passa pelo `crush_time` (funciona com qualquer velocidade e na volta
## do loop) e esmaga tudo que está em cima.
func _check_blades_closed() -> void:
	if not self_animations.is_playing() or self_animations.current_animation != grinder_animation:
		_last_grinder_pos = -1.0
		return
	var pos := self_animations.current_animation_position
	var last := _last_grinder_pos
	_last_grinder_pos = pos
	if last < 0.0:
		return
	var crossed := false
	if pos >= last:
		crossed = last < crush_time and pos >= crush_time
	else: # deu a volta no loop
		crossed = last < crush_time or pos >= crush_time
	if crossed:
		crush_now()


## Esmaga tudo que está encostado no triturador agora. Pode ser chamado de fora também.
func crush_now() -> int:
	if crush_only_while_spinning and not is_hurting():
		return 0
	var count := 0
	var ignore := get_crush_exceptions()
	for body in _crush_area.get_overlapping_bodies():
		if not body.has_method("crush"):
			continue
		if require_contact and not _is_touching_blades(body, ignore):
			continue
		body.crush(ignore)
		count += 1
	blades_closed.emit(count)
	return count


## true se o corpo está encostado nos rolos. RigidBody com contact_monitor (o Trash liga sozinho)
## informa com quem está colidindo; outros objetos com crush() usam só a área.
func _is_touching_blades(body: Node, blade_bodies: Array) -> bool:
	if body is RigidBody3D and body.contact_monitor:
		for other in body.get_colliding_bodies():
			if blade_bodies.has(other):
				return true
		return false
	return true


## Corpos do próprio triturador: os pedaços do lixo esmagado atravessam eles e caem por baixo.
func get_crush_exceptions() -> Array:
	var bodies: Array = []
	for child in find_children("*", "PhysicsBody3D", true, false):
		bodies.append(child)
	return bodies


## Cria (em tempo de jogo) uma área igual à de dano, só que um pouco maior e procurando as layers
## de `crush_mask` — assim não precisa mexer na cena.
func _setup_crush_area() -> void:
	_crush_area = Area3D.new()
	_crush_area.name = "CrushArea"
	_crush_area.collision_layer = 0
	_crush_area.collision_mask = crush_mask
	_crush_area.monitorable = false
	for shape_node in damage_area.get_children():
		if not (shape_node is CollisionShape3D) or shape_node.shape == null:
			continue
		var copy := CollisionShape3D.new()
		copy.transform = shape_node.transform
		copy.shape = _grown_shape(shape_node.shape)
		_crush_area.add_child(copy)
	damage_area.add_sibling(_crush_area)
	_crush_area.transform = damage_area.transform


func _grown_shape(shape: Shape3D) -> Shape3D:
	var grown: Shape3D = shape.duplicate()
	if grown is CylinderShape3D:
		grown.radius += crush_area_margin
	elif grown is SphereShape3D:
		grown.radius += crush_area_margin
	elif grown is CapsuleShape3D:
		grown.radius += crush_area_margin
	elif grown is BoxShape3D:
		grown.size += Vector3.ONE * crush_area_margin * 2.0
	return grown
#endregion


#region DANO
func _on_damage_area_body_entered(body: Node3D) -> void:
	if body is Player and not _bodies_inside.has(body):
		_bodies_inside.append(body)


func _on_damage_area_body_exited(body: Node3D) -> void:
	if is_instance_valid(body):
		_bodies_inside.erase(body)
	else:
		_remove_invalid_bodies()


# Array tipado não aceita erase() de objeto já destruído (dá erro), então reconstrói a lista.
func _remove_invalid_bodies() -> void:
	var valid: Array[Player] = []
	for body in _bodies_inside:
		if is_instance_valid(body):
			valid.append(body)
	_bodies_inside = valid
#endregion
