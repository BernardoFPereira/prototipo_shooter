class_name SwordButton
extends Node3D

@export_category("Objetos que são ativados")
@export var linked_obj: Node3D

@export var pressed_mat: Material

@onready var button_geo = $button/button_geo

enum button_states {
	PRESSED,
	UNPRESSED,
}

var state = button_states.UNPRESSED

func set_state(new_state):
	print("CHANGING STATE")
	if new_state == state:
		return
		
	state = new_state
	
	match state:
		button_states.PRESSED:
			if linked_obj is Door and linked_obj.is_broken:
				print("DOOR BROKEN BRUH")
			
			linked_obj.get_node("AnimationPlayer").play("door_open")
			button_geo.material_override = pressed_mat
			pass
		button_states.UNPRESSED:
			linked_obj.get_node("AnimationPlayer").play_backwards("door_open")
			button_geo.material_override = null
			pass
	
