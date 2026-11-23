extends Node3D

@onready var muzzle_flash = $ManualActivation/muzzle_flash
@onready var player_projectile = $ManualActivation/PlayerProjectile
@onready var blood_spatter = $ManualActivation/BloodSpatter

const LEVEL_01_LAB = preload("res://Scenes/Maps/Level01_Lab.tscn")

func _ready():
	blood_spatter.emitting = true
	await get_tree().create_timer(1.0).timeout
	player_projectile.explode()
	await get_tree().create_timer(0.5).timeout
	for child in muzzle_flash.get_children():
		child.emitting = true
	await get_tree().create_timer(0.5).timeout

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass

func _on_next_level_timer_timeout():
	SceneLoader.change_scene(LEVEL_01_LAB)
	pass # Replace with function body.
