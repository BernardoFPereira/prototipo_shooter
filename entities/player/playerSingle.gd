class_name Player
extends CharacterBody3D

var move_speed := 22
var drag := 25
var gravity := 42

#sensibilidade da camera pelo joystick
var look_sensitivity_horizontal : = 75
var look_sensitivity_vertical : = 30

const JUMP_VELOCITY := 16
const JUMP_JOYSTICK_VELOCITY: = 5

enum PlayerStates {
	IDLE,
	RUN,
	JUMP,
	FALL,
	ATTACK,
	BLOCK,
}

@onready var get_sword_area = $GetSwordArea
@onready var sword_hit_area = $Head/SwordHitArea

@onready var head: Node3D = $Head
@onready var camera = $Head/Camera3D
@onready var weapon = $Head/Weapon
@onready var muzzle = $Head/Cannon/Muzzle

@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var game_hud_canvas = $GameHUD
@onready var dead_canvas = $GameOverHUD
@onready var next_level_canvas = $NextLevelHUD
@onready var menu_canvas = $MenuHUD
@onready var health_label = $GameHUD/HealthLabel
@onready var activation_timer = $ActivationTimer

var menu_scene: PackedScene = preload("uid://d2rqkagxvdfhw")
var next_level_scene: PackedScene

var mouse_sensitivity := 0.001
var input_mouse: Vector2
var movement_vector: Vector2

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

var sword_scene: PackedScene = preload("uid://dyngooikjw5l6")
var projectile_scene: PackedScene = preload("uid://cdu40asu3x8p7")

var is_blocking: bool
var is_disarmed: bool
var is_dead: bool = false
var is_next_level
var thrown_sword: Sword

@export_category("Camera Properties")
@export var camera_juice : camera_effects
@export var fall_velocity_threshhold : float = -5.0
var current_fall_velocity : float

@export_category("Combat Properties")
var current_health: float
@export var max_health: float = 100.0
@export var melee_damage: float = 50.0

@export var sword_impact_strength: int = 250

func _ready():
	animation_player.animation_finished.connect(_on_animation_finished)
	get_sword_area.body_entered.connect(_on_sword_back)
	dead_canvas.visible = false
	next_level_canvas.visible = false
	game_hud_canvas.visible = true
	is_next_level = false
	
	current_health = max_health
	health_label.text = str(current_health)
	
	active_background.texture = null
	
	add_resolutions()
	update_button_values()
	
	setup_window_mode_buttons()
	setup_audio_buttons()
	
	config_group.visible = false
	ctrls_group.visible = false

func _process(delta):
	if is_dead or is_next_level:
		return
	
	_rotate_camera()
	#vinculando rotate da câmera com joystick
	_rotate_camera_joystick()
	if global_position.y <= -70: # if que coloca o player na area inicial do mapa
		global_position = Vector3.ZERO

func _physics_process(delta):
	if is_dead or is_next_level:
		return
	
	movement_vector = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction = (transform.basis * Vector3(movement_vector.x, 0, movement_vector.y)).normalized()
	if movement_vector:
		velocity.z = lerpf(direction.z * move_speed, 0, delta * move_speed)
		velocity.x = lerpf(direction.x * move_speed, 0, delta * move_speed)
	else:
		velocity.z = move_toward(velocity.z, 0, delta * (drag * 4))
		velocity.x = move_toward(velocity.x, 0, delta * (drag * 4))
		
	if not is_on_floor():
		velocity.y -= gravity * delta
	
	head.rotation.z = lerp_angle(head.rotation.z, -movement_vector.x / drag, delta * 6)
	
	move_and_slide()

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

func _input(event):
	if is_dead or is_next_level:
		return
		
	if Input.is_action_just_pressed("attack"):
		try_attack()
	
	if Input.is_action_just_pressed("fire"):
		try_fire()
	
	if Input.is_action_just_pressed("block"):
		if !is_blocking:
			try_block()
		
	if Input.is_action_just_released("block"):
		release_block()
		
	if Input.is_action_just_pressed("throw_sword"): 
		if !is_disarmed:
			try_throw_sword()
		else:
			try_pull_sword()
		
	if Input.is_action_just_pressed("jump"):
		try_jump()
		
	if Input.is_action_just_pressed("jump_joystick"):
		try_jump_joystick()

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
		
	print("Pulling sword back!")
	thrown_sword.set_state(thrown_sword.SwordState.PULLED_BACK)

func try_throw_sword():
	if is_disarmed:
		return
	
	print("Throwing Sword!")
	var sword = sword_scene.instantiate() as Sword
	
	sword.transform = head.global_transform
	get_parent().add_child(sword, true)
	sword.start(-head.global_transform.basis.z)
	sword.sword_owner = self
	
	is_disarmed = true
	thrown_sword = sword
	activation_timer.start()
	
	weapon.visible = false

func try_attack():
	if animation_player.current_animation != "attack" and !is_disarmed:
		animation_player.play("attack")
		print("Attacking!")

func try_fire():
	if animation_player.current_animation != "fire":
		var projectile = projectile_scene.instantiate() as Projectile
		projectile.transform = muzzle.global_transform
		get_parent().add_child(projectile, true)
		projectile.start(-head.global_transform.basis.z)
		animation_player.play("fire")
		print("Firing gun!")

func try_block():
	if animation_player.current_animation == "idle":
		animation_player.play("block")
		print("Blocking!")
	
	is_blocking = true

func release_block():
	#if animation_player.current_animation == "block":
	animation_player.play("idle")
	print("Stopped blocking!")
		
	is_blocking = false

func try_jump():
	if !is_on_floor():
		return
		
	print("Jumping!")
	velocity.y += JUMP_VELOCITY

func try_jump_joystick():
	if !is_on_floor():
		return
		
	print("Jumping!")
	velocity.y += JUMP_JOYSTICK_VELOCITY

#mais uma func do camera juice
func check_fall_speed() -> bool:
	if current_fall_velocity < fall_velocity_threshhold:
		current_fall_velocity = 0.0
		return true
	else:
		current_fall_velocity = 0.0
		return false
		
		

#Camera Juice pra quando o player cair, por favor implementem se conseguirem organizar a state machine
#func _on_airborne_state_physics_processing(delta : float) -> void:
#	if Player.is_on_floor():
#		if Player.check_fall_speed():
#			Player.camera_effects.add_fall_kick(2.0)
		#Player.PlayerStates.send_event("onGrounded")
	
	#Player.current_fall_velocity = Player.velocity.y

func _on_animation_finished(anim_name):
	match anim_name:
		"attack":
			animation_player.play("idle")
		_:
			pass

func _on_sword_hit():
	print(sword_hit_area.collision_result)
	if sword_hit_area.collision_result:
		for collision in sword_hit_area.collision_result:
			if collision.collider is EnemyMelee:
				print("Enemy hit")
				var enemy = collision.collider as EnemyMelee
				if enemy.current_state == enemy.EnemyState.DEAD:
					return
				enemy.spawn_blood(collision.point)
				enemy.receive_sword_impact(melee_damage, global_position, sword_impact_strength)
				
			elif collision.collider is EnemyRanged:
				var enemy = collision.collider as EnemyRanged
				if enemy.current_state == enemy.EnemyState.DEAD:
					return
				enemy.spawn_blood(collision.point)
				enemy.receive_sword_impact(melee_damage, global_position, sword_impact_strength)

func _on_sword_back(body):
	var sword: Sword = body.get_parent()
	if sword is Sword and sword.sword_owner == self:
		is_disarmed = false
		body.get_parent().register_impact()
		weapon.visible = true

func take_damage(amount: float):
	if current_health > 0:
		current_health -= clampf(amount, 0, max_health)
		health_label.text = str(current_health)
		camera_juice.add_screen_shake(2.0, 0.3)
		game_hud_canvas.find_child("HitVignette").visible = true #ativa o shader de reação de hit
		await get_tree().create_timer(.47).timeout # define o tempo antes de desligar o efeito
		game_hud_canvas.find_child("HitVignette").visible = false
		if current_health <= 0:
			current_health = 0
			is_dead = true
			dead_canvas.visible = true
			game_hud_canvas.visible = false
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _rotate_camera_joystick():
	
	#______________________________
	#Código para vincular visão do player com L3 do joystick
	
	var look_x = Input.get_action_strength("look_right") - Input.get_action_strength("look_left")
	var look_y = Input.get_action_strength("look_down") - Input.get_action_strength("look_up")
	
	var look_delta = Vector2(look_x, look_y)
	
	if look_delta.length() > 0:
		# --- Yaw (left/right) ---
		rotate_y(-look_delta.x * mouse_sensitivity * look_sensitivity_horizontal)

		# --- Pitch (up/down) ---
		head.rotate_x(-look_delta.y * mouse_sensitivity * look_sensitivity_vertical)
		head.rotation.x = clamp(head.rotation.x, deg_to_rad(-80), deg_to_rad(80))

		# --- Roll (optional tilt) ---
		head.rotation.z = clamp(head.rotation.z, -deg_to_rad(50), deg_to_rad(50))
	
	#_______________________________

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

#region CONFIGS
func setup_window_mode_buttons() -> void:
	var window_mode_group = ButtonGroup.new()
	windowed_button.button_group = window_mode_group
	fullscreen_button.button_group = window_mode_group
	
	windowed_button.button_pressed = not UI.is_fullscreen
	fullscreen_button.button_pressed = UI.is_fullscreen
	
	windowed_button.toggled.connect(_on_windowed_button_toggled)
	fullscreen_button.toggled.connect(_on_fullscreen_button_toggled)

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

#region AUDIO
func play_step_sound():
	$SFX/Walk.play()

func play_jump_sound():
	$SFX/Jump.play()

func play_fire_sound():
	$SFX/Fire.play()

#endregion



