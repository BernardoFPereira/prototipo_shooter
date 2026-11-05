extends Area3D

@export var next_target: Marker3D

func _on_body_entered(body):
	if body is DecompressedEnemy:
		var enemy = body as DecompressedEnemy
		enemy.current_move_target = next_target

func _on_area_entered(area):
	var area_parent = area.get_parent()
	if area_parent is DecompressedObject:
		var obj = area_parent as DecompressedObject
		obj.move_target = next_target
