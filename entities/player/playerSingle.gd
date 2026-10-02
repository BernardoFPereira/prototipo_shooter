class_name Player
extends CharacterBody3D
 
#region EXPORT VARS
@export_category("Move and Look Properties")
@export var camera_juice : camera_effects
@export var fall_velocity_threshhold : float = -5.0
@export var move_speed := 22
@export var drag := 25
@export var gravity := 42
 
var current_fall_velocity : float
var input_mouse: Vector2
var movement_vector: Vector2
var direction: Vector3
 
const JUMP_VELOCITY := 18
 
@export_category("Combat Properties")
@export var max_health: float = 100.0
@export var melee_damage: float = 10.0
@export var impact_strength: int = 250
var current_health: float
@onready var coyote_timer = $CoyoteTimer
var can_coyote_jump: bool = true
#endregion
 
#region STATE_MACHINE
signal change_level
var is_disarmed: bool
var is_dead: bool = false
var is_next_level: bool = false
var was_in_air: bool = false

enum PlayerStates {
	IDLE,
	RUN,
	JUMP,
	FALL,
	PUSH,
	FIRE,
}
 
var state: PlayerStates = PlayerStates.IDLE
var previous_state: PlayerStates = PlayerStates.IDLE
var is_animating_action: bool = false
 
var blend_time: float = 0.15
 
@onready var animation_player: AnimationPlayer = $Head/Weapon/PlayerArmature/AnimationPlayer
#endregion
 
#region SFX Nodes
@onready var idle_sfx = $SFX/Idle
@onready var walk_sfx = $SFX/Walk
@onready var jump_sfx = $SFX/Jump
@onready var fire_sfx = $SFX/Fire
@onready var arm_throw_sfx = $SFX/ArmThrow
@onready var arm_back_sfx = $SFX/ArmBack
#endregion
 
#region SCENE VARIABLES
@onready var get_sword_area = $GetSwordArea
@onready var sword_hit_area = $Head/SwordHitArea
 
@onready var head: Node3D = $Head
@onready var camera = $Head/Camera3D
@onready var weapon = $Head/Weapon
 
@onready var forearm_geo = $Head/Weapon/PlayerArmature/Armature/Skeleton3D/Forearm_geo
@onready var index_geo = $Head/Weapon/PlayerArmature/Armature/Skeleton3D/index_geo
@onready var middle_geo = $Head/Weapon/PlayerArmature/Armature/Skeleton3D/middle_geo
@onready var pinky_geo = $Head/Weapon/PlayerArmature/Armature/Skeleton3D/pinky_geo
@onready var ring_geo = $Head/Weapon/PlayerArmature/Armature/Skeleton3D/ring_geo
@onready var thumb_geo = $Head/Weapon/PlayerArmature/Armature/Skeleton3D/thumb_geo
 
@onready var muzzle = $Head/Weapon/PlayerArmature/Armature/Skeleton3D/BoneAttachment3D/Muzzle
 
@export var arm_projectile_scene: PackedScene
#@export var sword_scene: PackedScene = preload("uid://dyngooikjw5l6")
const sword_scene: PackedScene = preload("uid://dyngooikjw5l6")
const projectile_scene: PackedScene = preload("uid://cdu40asu3x8p7")
const menu_scene: PackedScene = preload("uid://d2rqkagxvdfhw")
var next_level_scene: PackedScene
var thrown_sword: Sword
#endregion
 
#region HUD
@onready var game_hud_canvas = $GameHUD
@onready var health_bar = $GameHUD/HealthBar
var real_value : float
@onready var activation_timer = $ActivationTimer
 
@onready var hud_animations = $GameHUD/HUDAnimations
@onready var avic_animations = $GameHUD/AVICAnimations
var enemy_detected := "res://UI/V2/HUD/Enemy/EnemyDetectedCH.png"
var enemy_health := "res://UI/V2/HUD/Enemy/EnemyHealthBar.png"
@onready var enemy_detection_range = $EnemyDetectionRange
@onready var enemy_detection_collision = $EnemyDetectionRange/EnemyDetectionCollision
@onready var detection_timer: Timer = $DetectionTimer
var enemies_in_range: Array[Node] = []
 
@onready var control = $GameHUD/Control
@onready var assistant_text_box = $GameHUD/Control/AssistantTextBox
@onready var centered_assistant_text_box = $GameHUD/CenteredAssistantTextBox
var new_message: String = ""
@onready var assistant_frame = $GameHUD/AssistantFrame
@onready var assistant_iris = $GameHUD/AssistantIris
@onready var assistant_pupil = $GameHUD/AssistantPupil
@onready var assistant_text_link = $GameHUD/AssistantTextLink
@onready var loading_screen = $GameHUD/LoadingScreen
#endregion
 
#region UI VARIABLES
const config_background = preload("uid://beg6jpulxo7uw")
const on_button_texture = preload("uid://bo5sjwobb2r68")
const off_button_texture = preload("uid://cp8sjbs1efomi")
const res_button = preload("uid://bjlxctidiwjf3")
const res_button_selected_texture = preload("uid://cev240nhyxski")
const ctrls_key_background = preload("uid://bmu1oequesbqo")
const quit_background = preload("uid://dmel4nekr0nx4")
var resolution_button_group: ButtonGroup
#endregion
 
#region TUTORIAL / HABILIDADES
## Quem controla isso é o nó Tutorial (TutorialSequence) da fase. Sem Tutorial na fase, o jogador
## começa com tudo liberado e sem a animação de introdução.

## Emitido quando a introdução termina (animação "start" do HUD + popup centralizado, se tiver).
signal intro_finished
## Emitido sempre que o jogador FAZ algo. O tutorial usa isso pra saber quando avançar.
## amount = graus girados (LOOK), metros andados (MOVE) ou 1 (o resto).
signal action_performed(action: Action, amount: float)

## Habilidades que podem ser travadas/liberadas. São flags: dá pra combinar (ex: FIRE | ARM).
enum Ability { LOOK = 1, MOVE = 2, JUMP = 4, FIRE = 8, ARM = 16, PUSH = 32 }
const ALL_ABILITIES: int = 63
## Ações que o tutorial pode pedir pro jogador fazer.
enum Action { LOOK, MOVE, JUMP, FIRE, THROW_ARM, ARM_RETURNED, PUSH }

## Habilidades travadas agora (flags de Ability). 0 = tudo liberado.
var locked_abilities: int = 0
## Se true, toca o popup centralizado ("INICIANDO ROTINA...") depois da animação "start" do HUD.
var play_intro: bool = false
var intro_done: bool = false
## Enquanto true, a caixa do assistente não fecha sozinha (o tutorial controla quando fechar).
var assistant_hold_open: bool = false
var _assistant_open: bool = false
#endregion

@export_category("VFX")
@export var muzzle_flash_particles: PackedScene = preload("uid://b8edqmwpwyrwk")
@onready var muzzle_flash_position = $Head/MuzzleFlashPosition

func _ready():
	Menu.enter_gameplay_context(self)
 
	animation_player.animation_finished.connect(_on_animation_finished)
	get_sword_area.body_entered.connect(_on_sword_back)
	game_hud_canvas.visible = true
	enemy_detection_range.body_entered.connect(_on_enemy_detection_range_body_entered)
	enemy_detection_range.body_exited.connect(_on_enemy_detection_range_body_exited)
	detection_timer.timeout.connect(_check_visibility)
	assistant_text_box.message_timeout.connect(_on_assistant_message_timeout)
	detection_timer.wait_time = 0.15
	detection_timer.one_shot = false
	detection_timer.start()
	current_health = max_health
	real_value = max_health
	health_bar.value = current_health
	centered_assistant_text_box.visible = false
	assistant_frame.scale = Vector2(0,0)
	assistant_iris.scale = Vector2(0,0)
	assistant_pupil.scale = Vector2(0,0)
	assistant_text_link.scale = Vector2(0,0)
	control.scale = Vector2(0,0)

func _process(delta):
	if is_dead:
		return
	_rotate_camera()
	if global_position.y <= -70:
		global_position = Vector3.ZERO
	handle_input()
	if is_on_floor() and not is_animating_action:
		if state == PlayerStates.FALL or state == PlayerStates.JUMP:
			if movement_vector:
				set_state(PlayerStates.RUN)
			else:
				set_state(PlayerStates.IDLE)
			return
	if is_animating_action and animation_player:
		if not animation_player.is_playing():
			_on_animation_finished(animation_player.current_animation)
 
func set_state(new_state: PlayerStates):
	if state == new_state:
		return
	previous_state = state
	state = new_state
	match new_state:
		PlayerStates.IDLE:
			is_animating_action = false
			play_animation_with_blend("idle", true)
		PlayerStates.RUN:
			is_animating_action = false
			play_animation_with_blend("extra_anims_2/walk", true)
		PlayerStates.JUMP:
			is_animating_action = true
			play_animation_with_blend("jump", false)
		PlayerStates.FALL:
			print(can_coyote_jump)
			if can_coyote_jump:
				coyote_timer.start()
			is_animating_action = false
			play_animation_with_blend("extra_anims/air", true)
		PlayerStates.PUSH:
			is_animating_action = true
			play_animation_with_blend("push", false)
		PlayerStates.FIRE:
			is_animating_action = true
			play_animation_with_blend("fire", false)
 
func play_animation_with_blend(anim_name: String, loop: bool = true):
	if not animation_player or not animation_player.has_animation(anim_name):
		return
	if animation_player.current_animation == anim_name and animation_player.is_playing():
		return
	var anim = animation_player.get_animation(anim_name)
	if anim:
		anim.loop_mode = Animation.LOOP_LINEAR if loop else Animation.LOOP_NONE
	animation_player.play(anim_name, blend_time)
 
func _return_to_ground_state():
	if is_on_floor():
		if movement_vector:
			set_state(PlayerStates.RUN)
		else:
			set_state(PlayerStates.IDLE)
	else:
		set_state(PlayerStates.FALL)
 
func handle_input():
	if is_dead: #or is_next_level:
		return
	if Input.is_action_just_pressed("attack") and has_ability(Ability.PUSH):
		try_attack()
	if Input.is_action_just_pressed("fire") and has_ability(Ability.FIRE):
		try_fire()
	if Input.is_action_just_pressed("throw_sword"):
		if !is_disarmed:
			if has_ability(Ability.ARM):
				try_throw_sword()
		else:
			try_pull_sword() # recolher sempre funciona, pra nunca ficar sem o braço
	if Input.is_action_just_pressed("jump") and has_ability(Ability.JUMP):
		try_jump()
 
func _physics_process(delta):
	if is_dead: #or is_next_level:
		return
	velocity.y -= gravity * delta
	if was_in_air and is_on_floor():
		if not is_animating_action:
			walk_sfx.play()
			can_coyote_jump = true
			print("Pousou no chão!")
			if camera_juice:
				camera_juice.add_fall_kick(3.0)
		if movement_vector:
			set_state(PlayerStates.RUN)
		else:
			set_state(PlayerStates.IDLE)
	was_in_air = not is_on_floor()
	if state == PlayerStates.JUMP:
		if animation_player and (animation_player.current_animation != "jump" or not animation_player.is_playing()):
			set_state(PlayerStates.FALL)
	handle_states(delta)
	move_and_slide()
	if movement_vector:
		action_performed.emit(Action.MOVE, Vector2(velocity.x, velocity.z).length() * delta)

func _on_land():
	walk_sfx.play()
	camera_juice.add_fall_kick(3)
 
func handle_states(delta):
	if has_ability(Ability.MOVE):
		movement_vector = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	else:
		movement_vector = Vector2.ZERO
	direction = (transform.basis * Vector3(movement_vector.x, 0, movement_vector.y)).normalized()
	var horizontal_velocity = Vector3(velocity.x, 0 , velocity.z)
	var target_velocity = Vector3.ZERO
	match state:
		PlayerStates.IDLE:
			if movement_vector and is_on_floor():
				set_state(PlayerStates.RUN)
			elif !is_on_floor():
				if state != PlayerStates.JUMP:
					set_state(PlayerStates.FALL)
			horizontal_velocity = horizontal_velocity.lerp(Vector3.ZERO, delta * drag)
		PlayerStates.RUN:
			if !movement_vector and is_on_floor():
				set_state(PlayerStates.IDLE)
			elif !is_on_floor():
				if state != PlayerStates.JUMP:
					set_state(PlayerStates.FALL)
			if movement_vector:
				target_velocity = direction * move_speed
				horizontal_velocity = horizontal_velocity.lerp(target_velocity, delta * move_speed)
		PlayerStates.JUMP:
			if movement_vector:
				target_velocity = direction * move_speed
				horizontal_velocity = horizontal_velocity.lerp(target_velocity, delta * move_speed)
			else:
				horizontal_velocity = horizontal_velocity.lerp(Vector3.ZERO, delta * drag)
		PlayerStates.FALL:
			if is_on_floor():
				if movement_vector:
					set_state(PlayerStates.RUN)
				else:
					set_state(PlayerStates.IDLE)
				return
			if movement_vector:
				target_velocity = direction * move_speed
				horizontal_velocity = horizontal_velocity.lerp(target_velocity, delta * move_speed)
			else:
				horizontal_velocity = horizontal_velocity.lerp(Vector3.ZERO, delta * drag)
		PlayerStates.PUSH:
			if movement_vector:
				target_velocity = direction * move_speed
				horizontal_velocity = horizontal_velocity.lerp(target_velocity, delta * move_speed)
			else:
				horizontal_velocity = horizontal_velocity.lerp(Vector3.ZERO, delta * drag)
		PlayerStates.FIRE:
			if movement_vector:
				target_velocity = direction * move_speed
				horizontal_velocity = horizontal_velocity.lerp(target_velocity, delta * move_speed)
			else:
				horizontal_velocity = horizontal_velocity.lerp(Vector3.ZERO, delta * drag)
	velocity.x = horizontal_velocity.x
	velocity.z = horizontal_velocity.z
 
	head.rotation.z = lerp_angle(head.rotation.z, -movement_vector.x / drag, delta * 6)
 
func _rotate_camera():
	if is_dead:
		return
	if input_mouse and has_ability(Ability.LOOK):
		rotate_y(-input_mouse.x * UI.mouse_sensitivity)
		head.rotate_x(-input_mouse.y * UI.mouse_sensitivity)
		action_performed.emit(Action.LOOK, rad_to_deg(input_mouse.length() * UI.mouse_sensitivity))
	head.rotation.x = clamp(head.rotation.x, deg_to_rad(-80), deg_to_rad(80))
	head.rotation.z = clamp(head.rotation.z, -deg_to_rad(50), deg_to_rad(50))
	head.rotation.y = clamp(head.rotation.y, deg_to_rad(0), deg_to_rad(0))
	input_mouse = Vector2.ZERO
 
func _unhandled_input(event):
	if is_dead:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		input_mouse = event.relative
 
func _toggle_pause_menu():
	if get_tree().paused:
		get_tree().paused = false
		game_hud_canvas.visible = true
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	else:
		get_tree().paused = true
		game_hud_canvas.visible = false
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
 
func release_mouse_mode():
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
 
func try_pull_sword():
	if !activation_timer.is_stopped():
		return
	if !is_disarmed or !thrown_sword:
		return
	thrown_sword.set_state(thrown_sword.SwordState.PULLED_BACK)
 
func try_throw_sword():
	if is_disarmed:
		return
	var sword = sword_scene.instantiate() as Sword
	sword.transform = head.global_transform
	get_parent().add_child(sword, true)
	sword.start(self, -head.global_transform.basis.z)
	is_disarmed = true
	thrown_sword = sword
	activation_timer.start()
	forearm_geo.visible = false
	index_geo.visible = false
	middle_geo.visible = false
	pinky_geo.visible = false
	ring_geo.visible = false
	thumb_geo.visible = false
	arm_throw_sfx.play()
	action_performed.emit(Action.THROW_ARM, 1.0)
	#hud_animations.play("hand_flying")
 
func try_attack():
	if is_disarmed or is_animating_action:
		return
	if state != PlayerStates.PUSH:
		previous_state = state
		set_state(PlayerStates.PUSH)
		action_performed.emit(Action.PUSH, 1.0)
 
func try_fire():
	if state == PlayerStates.PUSH:
		return
	if state != PlayerStates.FIRE:
		var projectile = projectile_scene.instantiate() as Projectile
		projectile.transform = muzzle.global_transform
		get_parent().add_child(projectile, true)
		projectile.start(-head.global_transform.basis.z)
		previous_state = state
		set_state(PlayerStates.FIRE)
		fire_sfx.play()
		action_performed.emit(Action.FIRE, 1.0)
		#camera_juice.add_weapon_kick(5, 0.5, 0.5)
		
		var muzzle_flash = muzzle_flash_particles.instantiate()
		#muzzle_flash.global_transform = muzzle_flash_position.global_transform
		muzzle_flash_position.add_child(muzzle_flash)
		#get_tree().root.add_child(muzzle_flash)
		muzzle_flash.global_position = muzzle_flash_position.global_position
		
		for child: GPUParticles3D in muzzle_flash.get_children():
			child.emitting = true 

func try_jump():
	print(can_coyote_jump)
	if !is_on_floor() and coyote_timer.is_stopped():
		return
	velocity.y = JUMP_VELOCITY
	jump_sfx.play()
	can_coyote_jump = false
	set_state(PlayerStates.JUMP)
	action_performed.emit(Action.JUMP, 1.0)
 
func check_fall_speed() -> bool:
	if current_fall_velocity < fall_velocity_threshhold:
		current_fall_velocity = 0.0
		return true
	else:
		current_fall_velocity = 0.0
		return false
 
func _on_animation_finished(anim_name):
	match anim_name:
		"push":
			is_animating_action = false
			_return_to_ground_state()
		"fire":
			is_animating_action = false
			_return_to_ground_state()
		"jump":
			if state == PlayerStates.JUMP:
				if not is_on_floor():
					set_state(PlayerStates.FALL)
				else:
					_return_to_ground_state()
		"extra_anims/air":
			if is_on_floor():
				_return_to_ground_state()
 
func _on_attack_hit():
	if sword_hit_area.collision_result:
		for collision in sword_hit_area.collision_result:
			if collision.collider is EnemyMelee:
				var enemy = collision.collider as EnemyMelee
				if enemy.current_state == enemy.EnemyState.DEAD:
					return
				enemy.spawn_blood(collision.point)
				enemy.receive_sword_impact(melee_damage, global_position, impact_strength)
			elif collision.collider is EnemyRanged:
				var enemy = collision.collider as EnemyRanged
				if enemy.current_state == enemy.EnemyState.DEAD:
					return
				enemy.spawn_blood(collision.point)
				enemy.receive_sword_impact(melee_damage, global_position, impact_strength)
 
func _on_sword_back(body):
	var sword: Sword = body.get_parent()
	if sword is Sword and sword.sword_owner == self:
		is_disarmed = false
		body.get_parent().register_impact()
		forearm_geo.visible = true
		index_geo.visible = true
		middle_geo.visible = true
		pinky_geo.visible = true
		ring_geo.visible = true
		thumb_geo.visible = true
		arm_back_sfx.play()
		action_performed.emit(Action.ARM_RETURNED, 1.0)
 
func take_damage(amount: float):
	if current_health > 0:
		current_health -= clampf(amount, 0, max_health)
		bar_take_damage(clampf(amount, 0, max_health))
		camera_juice.add_screen_shake(2.0, 0.3)
		hud_animations.play("hit_vfx")
		await get_tree().create_timer(.47).timeout
		if current_health <= max_health/3:
			idle_sfx.play()
		if current_health <= 0:
			current_health = 0
			is_dead = true
			game_hud_canvas.visible = false
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
 
func bar_take_damage(damage: float):
	real_value -= damage
	var percent = real_value / max_health
	var new_color = Color(1.0 - percent, percent, 0.0, health_bar.tint_progress.a)
 
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(health_bar, "value", real_value, 0.4)
	tween.tween_property(health_bar, "tint_progress", new_color, 0.4)
	tween.tween_property(health_bar, "glow_tint", new_color, 0.4)
 
func _on_enemy_detection_range_body_entered(body):
	if body is EnemyMelee or body is EnemyRanged:
		if not body in enemies_in_range:
			enemies_in_range.append(body)
 
func _on_enemy_detection_range_body_exited(body):
	if body is EnemyMelee or body is EnemyRanged:
		body.detected = false
		enemies_in_range.erase(body)
 
func _check_visibility():
	if enemies_in_range.is_empty():
		return
	var space_state = get_world_3d().direct_space_state
	var from = global_position + Vector3(0, 1.5, 0)
	for enemy in enemies_in_range:
		if not is_instance_valid(enemy):
			enemies_in_range.erase(enemy)
			continue
		var to = enemy.global_position + Vector3(0, 1.5, 0)
		var ray_params = PhysicsRayQueryParameters3D.create(from, to)
		ray_params.exclude = [self, enemy]
		ray_params.collision_mask = 1
		var result = space_state.intersect_ray(ray_params)
		if result.is_empty():
			if enemy.detected == false:
				enemy.hud_animations.play("detected")
				enemy.detected = true
 
func _on_hud_animations_animation_finished(anim_name):
	match anim_name:
		"start":
			if play_intro:
				avic_animations.play("avic/centered_assistant_popup")
			else:
				_finish_intro()
		#"loading_screen_in":
			#change_level.emit()
		#"loading_screen_out":
			#is_next_level = false
 
func _on_avic_animations_animation_finished(anim_name):
	match anim_name:
		"avic/assistant_popup":
			_assistant_open = true
			avic_animations.play("avic/assistant_idle")
			assistant_text_box.set_message(new_message, true)
		"avic/centered_assistant_popup":
			avic_animations.play("avic/centered_assistant_idle")
		"avic/centered_assistant_idle":
			avic_animations.play("avic/centered_assistant_popout")
		"avic/centered_assistant_popout":
			_finish_intro()

func _finish_intro():
	if intro_done:
		return
	intro_done = true
	intro_finished.emit()

func _on_assistant_message_timeout():
	if not assistant_hold_open:
		hide_assistant_message()

#region HABILIDADES / MENSAGENS (usado pelo Tutorial e pelas áreas de mensagem)
func has_ability(ability: int) -> bool:
	return (locked_abilities & ability) == 0

func lock_abilities(abilities: int) -> void:
	locked_abilities |= abilities

func unlock_abilities(abilities: int) -> void:
	locked_abilities &= ~abilities

## Mostra uma mensagem na caixa do assistente (canto direito), com a animação de popup.
## A mensagem aparece de fato quando o popup termina (_on_avic_animations_animation_finished).
func show_assistant_message(message: String) -> void:
	get_message_data(message)
	_assistant_open = true
	avic_animations.play("avic/assistant_popup")

## Fecha a caixa do assistente (se estiver aberta).
func hide_assistant_message() -> void:
	assistant_hold_open = false
	if not _assistant_open:
		return
	_assistant_open = false
	avic_animations.play("avic/assistant_popout")
#endregion

func get_message_data(message: String):
	new_message = message
	if assistant_text_box:
		assistant_text_box.visible = false
