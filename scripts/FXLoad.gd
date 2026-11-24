extends Node3D

@onready var muzzle_flash = $ManualActivation/muzzle_flash
@onready var player_projectile = $ManualActivation/PlayerProjectile
@onready var blood_spatter = $ManualActivation/BloodSpatter
@onready var loading_screen = $LoadingScreen

const LEVEL_01_LAB = preload("res://Scenes/Maps/Level01_Lab.tscn")

func _ready():
	loading_screen._run(LEVEL_01_LAB, "", Input.MOUSE_MODE_CAPTURED)
	blood_spatter.emitting = true
	await get_tree().create_timer(1.0).timeout
	player_projectile.explode()
	await get_tree().create_timer(0.5).timeout
	for child in muzzle_flash.get_children():
		child.emitting = true
	await get_tree().create_timer(0.5).timeout

func _on_next_level_timer_timeout():
	loading_screen._end(Input.MOUSE_MODE_CAPTURED)
	get_tree().change_scene_to_packed(LEVEL_01_LAB)
