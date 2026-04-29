extends Node3D

@export var linked_obj: Node3D

var animation_player:AnimationPlayer

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass


func _on_area_3d_body_entered(body):
	animation_player = linked_obj.find_child("AnimationPlayer")
	animation_player.play("trigger_animation")
	pass # Replace with function body.
