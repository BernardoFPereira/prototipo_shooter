class_name SwordButton
extends Node3D
@export_category("Objetos que são ativados")
@export var linked_obj: Node3D
enum button_states {
	PRESSED,
	UNPRESSED,
}
var state = button_states.UNPRESSED
# Called when the node enters the scene tree for the first time.
func _ready():
	
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	
	pass
func set_state(new_state):
	if new_state == state:
		return
		
	state = new_state
	
	match state:
		button_states.PRESSED:
			linked_obj.get_node("AnimationPlayer").play("door_open")
			pass
		button_states.UNPRESSED:
			linked_obj.get_node("AnimationPlayer").play_backwards("door_open")
			pass
	
