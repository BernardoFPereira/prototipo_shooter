extends Node3D
class_name Door

@export var is_broken: bool
@export var is_open: bool

@onready var animation_player = $AnimationPlayer

# Called when the node enters the scene tree for the first time.

func _ready():
	if is_broken:
		animation_player.play("broken")
	if is_open:
		animation_player.play("door_open")
