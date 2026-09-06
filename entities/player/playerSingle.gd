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
var mouse_sensitivity := 0.001
var input_mouse: Vector2
var movement_vector: Vector2
var direction: Vector3

const JUMP_VELOCITY := 18

@export_category("Combat Properties")
@export var max_health: float = 100.0
@export var melee_damage: float = 10.0
@export var impact_strength: int = 250
var current_health: float
#endregion

#region STATE_MACHINE
var is_disarmed: bool
var is_dead: bool = false
var was_in_air: bool = false
var is_next_level: bool
var is_introduction: bool

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
const sword_scene: PackedScene = preload("uid://dyngooikjw5l6")
const projectile_scene: PackedScene = preload("uid://cdu40asu3x8p7")
const menu_scene: PackedScene = preload("uid://d2rqkagxvdfhw")
var next_level_scene: PackedScene
var thrown_sword: Sword
#endregion

#region HUD
@onready var game_hud_canvas = $GameHUD
@onready var dead_canvas = $GameOverHUD
@onready var next_level_canvas = $NextLevelHUD
@onready var menu_canvas = $MenuHUD
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
#endregion

#region UI VARIABLES
const config_background = preload("uid://beg6jpulxo7uw")
const on_button_texture = preload("uid://bo5sjwobb2r68")
const off_button_texture = preload("uid://cp8sjbs1efomi")

@onready var active_background = $MenuHUD/Panel/ActiveBackground
@onready var config_group = $MenuHUD/Panel/ConfigGroup
@onready var ctrls_group = $MenuHUD/Panel/ControlsGroup
@onready var quit_group = $MenuHUD/Panel/QuitGroup
@onready var config_button = $MenuHUD/Panel/VBoxContainer/ConfigButton
@onready var ctrls_button = $MenuHUD/Panel/VBoxContainer/ControlsButton
@onready var quit_button = $MenuHUD/Panel/VBoxContainer/QuitButton

@onready var windowed_button = $MenuHUD/Panel/ConfigGroup/WindowMode/WindowedButton
@onready var fullscreen_button = $MenuHUD/Panel/ConfigGroup/WindowMode/FullscreenButton

const res_button = preload("uid://bjlxctidiwjf3")
const res_button_selected_texture = preload("uid://cev240nhyxski")
var resolution_button_group: ButtonGroup
@onready var resolutions_list = $MenuHUD/Panel/ConfigGroup/Resolution/ResolutionOptions/ResolutionVBox

@onready var music_bar = $MenuHUD/Panel/ConfigGroup/Audio/MusicBar
@onready var music_slider = $MenuHUD/Panel/ConfigGroup/Audio/MusicSlider
@onready var sfx_bar = $MenuHUD/Panel/ConfigGroup/Audio/SFXBar
@onready var sfx_slider = $MenuHUD/Panel/ConfigGroup/Audio/SFXSlider
@onready var hud_bar = $MenuHUD/Panel/ConfigGroup/Audio/HUDBar
@onready var hud_slider = $MenuHUD/Panel/ConfigGroup/Audio/HUDSlider
@onready var toggle_music_button = $MenuHUD/Panel/ConfigGroup/Audio/ToggleMusicButton
@onready var toggle_sfx_button = $MenuHUD/Panel/ConfigGroup/Audio/ToggleSFXButton
@onready var toggle_hudsfx_button = $MenuHUD/Panel/ConfigGroup/Audio/ToggleHUDSFXButton

@onready var sens_bar = $MenuHUD/Panel/ConfigGroup/MouseSens/SensBar
@onready var sens_slider = $MenuHUD/Panel/ConfigGroup/MouseSens/SensSlider

const ctrls_key_background = preload("uid://bmu1oequesbqo")
const quit_background = preload("uid://dmel4nekr0nx4")
#endregion

func _ready():
	animation_player.animation_finished.connect(_on_animation_finished)
	get_sword_area.body_entered.connect(_on_sword_back)
	dead_canvas.visible = false
	next_level_canvas.visible = false
	game_hud_canvas.visible = true
	is_next_level = false
	
	enemy_detection_range.body_entered.connect(_on_enemy_detection_range_body_entered)
	enemy_detection_range.body_exited.connect(_on_enemy_detection_range_body_exited)
	
	detection_timer.timeout.connect(_check_visibility)
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
	active_background.texture = null
	
	add_resolutions()
	update_button_values()
	
	setup_window_mode_buttons()
	setup_audio_buttons()
	
	config_group.visible = false
	ctrls_group.visible = false
	
	is_introduction = true

func _process(delta):
	if is_dead or is_next_level:
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
			play_animation_with_blend("walk", true)
		
		PlayerStates.JUMP:
			is_animating_action = true
			play_animation_with_blend("jump", false)
		
		PlayerStates.FALL:
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
	if is_dead or is_next_level or is_introduction:
		return
	
	if Input.is_action_just_pressed("attack"):
		try_attack()
	
	if Input.is_action_just_pressed("fire"):
		try_fire()
		
	if Input.is_action_just_pressed("throw_sword"): 
		if !is_disarmed:
			try_throw_sword()
		else:
			try_pull_sword()
		
	if Input.is_action_just_pressed("jump"):
		try_jump()

func _physics_process(delta):
	if is_dead or is_next_level:
		return
	
	velocity.y -= gravity * delta
	
	if was_in_air and is_on_floor():
		if not is_animating_action:
			walk_sfx.play()
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

func _on_land():
	walk_sfx.play()
	
	camera_juice.add_fall_kick(3)

func handle_states(delta):
	if is_introduction:
		return
	movement_vector = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	direction = (transform.basis * Vector3(movement_vector.x, 0, movement_vector.y)).normalized()
	
	var horizontal_velocity = Vector3(velocity.x, 0 , velocity.z)
	var target_velocity = Vector3.ZERO
	
	match state:
		PlayerStates.IDLE:
			if movement_vector and is_on_floor():
				set_state(PlayerStates.RUN)
			elif !is_on_floor():
				# Se não estiver no chão e não estiver pulando, vai para FALL
				if state != PlayerStates.JUMP:
					set_state(PlayerStates.FALL)
			
			horizontal_velocity = horizontal_velocity.lerp(Vector3.ZERO, delta * drag)
			
		PlayerStates.RUN:
			if !movement_vector and is_on_floor():
				set_state(PlayerStates.IDLE)
			elif !is_on_floor():
				# Se não estiver no chão e não estiver pulando, vai para FALL
				if state != PlayerStates.JUMP:
					set_state(PlayerStates.FALL)
			
			if movement_vector:
				target_velocity = direction * move_speed
				horizontal_velocity = horizontal_velocity.lerp(target_velocity, delta * move_speed)
		
		PlayerStates.JUMP:
			# Movimento horizontal durante o pulo
			if movement_vector:
				target_velocity = direction * move_speed
				horizontal_velocity = horizontal_velocity.lerp(target_velocity, delta * move_speed)
			else:
				horizontal_velocity = horizontal_velocity.lerp(Vector3.ZERO, delta * drag)
			
			# Verificar se o personagem já está caindo E a animação de jump terminou
			# A transição será feita pelo _on_animation_finished
		
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
	if is_dead or is_next_level:
		return
		
	if input_mouse:
		rotate_y(-input_mouse.x * mouse_sensitivity)
		head.rotate_x(-input_mouse.y * mouse_sensitivity)
		
	head.rotation.x = clamp(head.rotation.x, deg_to_rad(-80), deg_to_rad(80))
	head.rotation.z = clamp(head.rotation.z, -deg_to_rad(50), deg_to_rad(50))
	head.rotation.y = clamp(head.rotation.y, deg_to_rad(0), deg_to_rad(0))
	input_mouse = Vector2.ZERO

func _unhandled_input(event):
	if is_dead or is_next_level:
		return
	
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		input_mouse = event.relative

func _toggle_pause_menu():
	if get_tree().paused:
		get_tree().paused = false
		menu_canvas.visible = false
		game_hud_canvas.visible = true
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	else:
		get_tree().paused = true
		menu_canvas.visible = true
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
	hud_animations.play("hand_flying")

func try_attack():
	if is_disarmed or is_animating_action:
		return
	
	if state != PlayerStates.PUSH:
		previous_state = state
		set_state(PlayerStates.PUSH)

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
		camera_juice.add_weapon_kick(5, 0.5, 0.5)

func try_jump():
	if !is_on_floor():
		return
	
	velocity.y = JUMP_VELOCITY
	jump_sfx.play()
	set_state(PlayerStates.JUMP)

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
			dead_canvas.visible = true
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

#region UI _ SCRIPTS
func next_level(level_scene: PackedScene):
	get_tree().paused = false
	next_level_canvas.visible = true
	game_hud_canvas.visible = false
	is_next_level = true
	next_level_scene = level_scene
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _on_menu_button_pressed():
	get_tree().paused = false
	UI.save_settings()
	get_tree().change_scene_to_packed(menu_scene)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _on_retry_button_pressed():
	get_tree().paused = false
	menu_canvas.visible = false
	get_tree().reload_current_scene()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _on_next_button_pressed():
	get_tree().change_scene_to_packed(next_level_scene)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _on_resume_button_pressed():
	get_tree().paused = false
	menu_canvas.visible = false
	game_hud_canvas.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

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

#region CONFIGS
func setup_window_mode_buttons() -> void:
	var window_mode_group = ButtonGroup.new()
	windowed_button.button_group = window_mode_group
	fullscreen_button.button_group = window_mode_group
	
	windowed_button.button_pressed = not UI.is_fullscreen
	fullscreen_button.button_pressed = UI.is_fullscreen

func setup_audio_buttons() -> void:
	var music_slider_value = UI.db_to_slider(UI.music_volume) if not UI.music_muted else 0
	var sfx_slider_value = UI.db_to_slider(UI.sfx_volume) if not UI.sfx_muted else 0
	var hud_slider_value = UI.db_to_slider(UI.hud_volume) if not UI.hud_muted else 0
	
	music_slider.value = music_slider_value
	sfx_slider.value = sfx_slider_value
	hud_slider.value = hud_slider_value
	
	toggle_music_button.button_pressed = not UI.music_muted
	toggle_sfx_button.button_pressed = not UI.sfx_muted
	toggle_hudsfx_button.button_pressed = not UI.hud_muted
	
	_on_music_slider_value_changed(music_slider_value)
	_on_sfx_slider_value_changed(sfx_slider_value)
	_on_hud_slider_value_changed(hud_slider_value)

func _on_config_button_toggled(toggled_on: bool) -> void:
	if toggled_on:
		config_group.visible = true
		ctrls_group.visible = false
		ctrls_button.button_pressed = false
		quit_group.visible = false
		quit_button.button_pressed = false
		active_background.texture = config_background
		UI.play_sound("confirm_button")
	else:
		config_group.visible = false
		active_background.texture = null
		UI.play_sound("back_button")
		UI.save_settings()

func _on_music_slider_value_changed(value: float) -> void:
	var mapped_db = UI.slider_to_db(value)
	
	music_bar.value = value
	
	if value <= 0:
		if not UI.music_muted:
			toggle_music_button.button_pressed = false
			_on_toggle_music_button_toggled(false)
	else:
		if UI.music_muted:
			toggle_music_button.button_pressed = true
			_on_toggle_music_button_toggled(true)
		
		if toggle_music_button.button_pressed:
			UI.music_volume = mapped_db
			AudioServer.set_bus_volume_db(UI.AudioBus.MUSIC, mapped_db)
		else:
			UI.music_volume = mapped_db

func _on_sfx_slider_value_changed(value: float) -> void:
	var mapped_db = UI.slider_to_db(value)
	
	sfx_bar.value = value
	
	if value <= 0:
		if not UI.sfx_muted:
			toggle_sfx_button.button_pressed = false
			_on_toggle_sfx_button_toggled(false)
	else:
		if UI.sfx_muted:
			toggle_sfx_button.button_pressed = true
			_on_toggle_sfx_button_toggled(true)
		
		if toggle_sfx_button.button_pressed:
			UI.sfx_volume = mapped_db
			AudioServer.set_bus_volume_db(UI.AudioBus.SFX, mapped_db)
		else:
			UI.sfx_volume = mapped_db

func _on_hud_slider_value_changed(value: float) -> void:
	var mapped_db = UI.slider_to_db(value)
	
	hud_bar.value = value
	
	if value <= 0:
		if not UI.hud_muted:
			toggle_hudsfx_button.button_pressed = false
			_on_toggle_hudsfx_button_toggled(false)
	else:
		if UI.hud_muted:
			toggle_hudsfx_button.button_pressed = true
			_on_toggle_hudsfx_button_toggled(true)
		
		if toggle_hudsfx_button.button_pressed:
			UI.hud_volume = mapped_db
			AudioServer.set_bus_volume_db(UI.AudioBus.HUD, mapped_db)
		else:
			UI.hud_volume = mapped_db

func _on_toggle_music_button_toggled(toggled_on: bool) -> void:
	if toggled_on:
		var current_slider_value = music_slider.value
		if current_slider_value <= 0:
			music_slider.value = 1
			current_slider_value = 1
		
		AudioServer.set_bus_volume_db(UI.AudioBus.MUSIC, UI.slider_to_db(current_slider_value))
		toggle_music_button.icon = on_button_texture
		UI.music_muted = false
		UI.play_sound("confirm_button")
	else:
		UI.music_volume = AudioServer.get_bus_volume_db(UI.AudioBus.MUSIC)
		AudioServer.set_bus_volume_db(UI.AudioBus.MUSIC, UI.MIN_DB)
		toggle_music_button.icon = off_button_texture
		UI.music_muted = true
		UI.play_sound("back_button")

func _on_toggle_sfx_button_toggled(toggled_on: bool) -> void:
	if toggled_on:
		var current_slider_value = sfx_slider.value
		if current_slider_value <= 0:
			sfx_slider.value = 1
			current_slider_value = 1
		
		AudioServer.set_bus_volume_db(UI.AudioBus.SFX, UI.slider_to_db(current_slider_value))
		toggle_sfx_button.icon = on_button_texture
		UI.sfx_muted = false
		UI.play_sound("confirm_button")
	else:
		UI.sfx_volume = AudioServer.get_bus_volume_db(UI.AudioBus.SFX)
		AudioServer.set_bus_volume_db(UI.AudioBus.SFX, UI.MIN_DB)
		toggle_sfx_button.icon = off_button_texture
		UI.sfx_muted = true
		UI.play_sound("back_button")

func _on_toggle_hudsfx_button_toggled(toggled_on: bool) -> void:
	if toggled_on:
		var current_slider_value = hud_slider.value
		if current_slider_value <= 0:
			hud_slider.value = 1
			current_slider_value = 1
		
		AudioServer.set_bus_volume_db(UI.AudioBus.HUD, UI.slider_to_db(current_slider_value))
		toggle_hudsfx_button.icon = on_button_texture
		UI.hud_muted = false
		UI.play_sound("confirm_button")
	else:
		UI.hud_volume = AudioServer.get_bus_volume_db(UI.AudioBus.HUD)
		AudioServer.set_bus_volume_db(UI.AudioBus.HUD, UI.MIN_DB)
		toggle_hudsfx_button.icon = off_button_texture
		UI.hud_muted = true
		UI.play_sound("back_button")

func _on_windowed_button_toggled(toggled_on: bool) -> void:
	if toggled_on:
		UI.is_fullscreen = false
		get_window().mode = Window.MODE_WINDOWED
		get_window().size = UI.current_resolution
		UI.play_sound("confirm_button")
		windowed_button.mouse_filter = Control.MOUSE_FILTER_IGNORE
		UI.center_window()
		update_button_values()
		set_resolution_buttons_enabled(true)
	else:
		windowed_button.mouse_filter = Control.MOUSE_FILTER_PASS

func _on_fullscreen_button_toggled(toggled_on: bool) -> void:
	if toggled_on:
		UI.is_fullscreen = true
		UI.play_sound("confirm_button")
		fullscreen_button.mouse_filter = Control.MOUSE_FILTER_IGNORE
		get_window().mode = Window.MODE_EXCLUSIVE_FULLSCREEN
		set_resolution_buttons_enabled(false)
	else:
		fullscreen_button.mouse_filter = Control.MOUSE_FILTER_PASS

func _on_resolution_button_pressed(resolution_key: String) -> void:
	if get_window().mode == Window.MODE_EXCLUSIVE_FULLSCREEN:
		return
	
	if UI.resolutions.has(resolution_key):
		UI.current_resolution = UI.resolutions[resolution_key]
		get_window().size = UI.current_resolution
		UI.center_window()
		UI.play_sound("confirm_button")
		update_button_values()

func add_resolutions() -> void:
	resolution_button_group = ButtonGroup.new()
	
	var index = 0
	for r in UI.resolutions:
		var new_button = res_button.instantiate()
		new_button.text = r
		new_button.name = "ResolutionButton" + str(index)
		new_button.button_group = resolution_button_group
		new_button.pressed.connect(_on_resolution_button_pressed.bind(r))
		new_button.mouse_entered.connect(_on_button_hovered)
		resolutions_list.add_child(new_button)
		index += 1
	update_button_values()
	set_resolution_buttons_enabled(!UI.is_fullscreen)

func update_button_values() -> void:
	var window_size_str = str(get_window().size.x, "x", get_window().size.y)
	var resolutions_index = UI.resolutions.keys().find(window_size_str)
	
	if resolutions_index == -1:
		window_size_str = "1920x1080"
		resolutions_index = UI.resolutions.keys().find(window_size_str)

	var button_name = "ResolutionButton" + str(resolutions_index)
	var selected_button = resolutions_list.get_node(button_name)
	
	if selected_button:
		selected_button.button_pressed = true

func set_resolution_buttons_enabled(enabled: bool) -> void:
	for button in resolutions_list.get_children():
		button.disabled = not enabled
		if enabled:
			button.mouse_filter = Control.MOUSE_FILTER_PASS
		else:
			button.mouse_filter = Control.MOUSE_FILTER_IGNORE

func _on_sens_slider_value_changed(value):
	sens_bar.value = value
	mouse_sensitivity = value * 0.0001
#endregion

func _on_button_hovered():
	UI.play_sound("hover_button")

#region CONTROLS
func _on_ctrls_button_toggled(toggled_on: bool) -> void:
	if toggled_on:
		ctrls_group.visible = true
		config_group.visible = false
		config_button.button_pressed = false
		quit_group.visible = false
		quit_button.button_pressed = false
		active_background.texture = ctrls_key_background
		UI.play_sound("confirm_button")
	else:
		ctrls_group.visible = false
		active_background.texture = null
		UI.play_sound("back_button")
#endregion

#region QUIT
func _on_quit_button_toggled(toggled_on: bool) -> void:
	if toggled_on:
		quit_group.visible = true
		config_group.visible = false
		config_button.button_pressed = false
		ctrls_group.visible = false
		ctrls_button.button_pressed = false
		active_background.texture = quit_background
		UI.play_sound("confirm_button")
	else:
		quit_group.visible = false
		active_background.texture = null
		UI.play_sound("back_button")
		UI.save_settings()
#endregion

func _on_hud_animations_animation_finished(anim_name):
	match anim_name:
		"start":
			if is_introduction:
				avic_animations.play("avic/centered_assistant_popup")

func _on_avic_animations_animation_finished(anim_name):
	match anim_name:
		"avic/assistant_popup":
			avic_animations.play("avic/assistant_idle")
			assistant_text_box.set_message(new_message, true)
		
		"avic/centered_assistant_popup":
			avic_animations.play("avic/centered_assistant_idle")
		
		"avic/centered_assistant_idle":
			avic_animations.play("avic/centered_assistant_popout")
			is_introduction = false

func get_message_data(message: String):
	new_message = message
