extends Node3D
class_name Door

@export var is_broken: bool
@export var is_open: bool

@onready var animation_player = $AnimationPlayer


func _ready():
	if is_broken:
		animation_player.play("break_open")
	if is_open:
		animation_player.play("door_open")
