extends StaticBody3D
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
	#collision_shape_3d.disabled = true
	set_collision_layer_value(1, false)
	set_collision_layer_value(5, false)
	set_collision_layer_value(9, false)
	
	visible = false
	break_audio.play()
	#clean_up_vent()
	await get_tree().create_timer(1.5).timeout
	call_deferred("queue_free")

#func clean_up_vent():
