extends Node3D

@onready var area_3d = $Area3D
var menu_scene: PackedScene = preload("uid://d2rqkagxvdfhw")
@onready var player = $Player

func _ready():
	pass


func _process(delta):
	pass


func _on_area_3d_area_entered(area):
	var parent = area.get_parent()
	print(area)
	print(parent)
	if parent == player:
		parent.next_level(menu_scene)
