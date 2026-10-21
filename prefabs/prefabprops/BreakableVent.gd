extends Node3D
class_name BreakableVent

@export var is_breakable: bool = false
@onready var collision_shape_3d = $CollisionShape3D
@onready var break_audio = $BreakAudio

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass

func break_vent():
	collision_shape_3d.disabled = true
	visible = false
	break_audio.play()
	await get_tree().create_timer(1.5).timeout
	call_deferred("queue_free")
