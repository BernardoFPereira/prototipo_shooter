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

var disabled: bool = false
var state = button_states.UNPRESSED

func set_state(new_state):
	if disabled:
		return
	
	if new_state == state:
		return
		
	state = new_state
	
	match state:
		button_states.PRESSED:
			if linked_obj is Door and linked_obj.is_broken:
				print("DOOR BROKEN BRUH")
				var moving_blocks = get_tree().get_first_node_in_group("ExplosionBlocks")
				moving_blocks.get_node("AnimationPlayer").play("explosion_aftermath")
				linked_obj.get_node("AnimationPlayer").play("break_apart")
				disabled = true
				return
			
			linked_obj.get_node("AnimationPlayer").play("door_open")
			button_geo.material_override = pressed_mat
		button_states.UNPRESSED:
			linked_obj.get_node("AnimationPlayer").play_backwards("door_open")
			button_geo.material_override = null
