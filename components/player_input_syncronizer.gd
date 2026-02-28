class_name PlayerInputSynchronizerComponent
extends MultiplayerSynchronizer

@onready var animation_player: AnimationPlayer = get_parent().get_node("AnimationPlayer")

var movement_vector: Vector2 = Vector2.ZERO
var input_mouse: Vector2 = Vector2.ZERO

var is_jump_pressed: bool

var is_attack_pressed: bool
var is_throw_pressed: bool
var is_pull_pressed: bool

var is_disarmed: bool = false:
	set(value):
		is_disarmed = value
		get_parent().weapon.visible = !value

var thrown_sword: Sword

var current_animation: String :
	set(value):
		current_animation = value
		if animation_player:
			animation_player.play(value)
		else:
			print("Animation Player is likely null!!")

func _process(_delta: float) -> void:
	if is_multiplayer_authority():
		gather_input()
		input_mouse = Vector2.ZERO

func _input(event):
	if is_multiplayer_authority():
		if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			input_mouse = event.relative

func gather_input():
	movement_vector = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	is_jump_pressed = Input.is_action_just_pressed("jump")
	is_attack_pressed = Input.is_action_just_pressed("attack")
	is_throw_pressed = Input.is_action_just_pressed("throw_sword")
