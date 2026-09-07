extends Node3D
class_name Door

@export var is_broken: bool

@onready var animation_player = $AnimationPlayer

# Called when the node enters the scene tree for the first time.
func _ready():
	if is_broken:
		animation_player.play("broken")
