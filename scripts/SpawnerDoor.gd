extends Node3D
class_name SpawnerDoor

#@onready var door = $portadiorama
@onready var door_anim_player = $portadiorama/AnimationPlayer
@onready var spawn_point = $SpawnPoint

#@export var enemy_list: Array[PackedScene]
@export_category("Enemies to Spawn")
@export var melee: int
@export var ranged: int

func spawn_enemy():
	door_anim_player.play("door_open")
	
	if melee:
		for melee_enemy in melee:
			var to_spawn = load("res://entities/enemies/MeleeEnemy/enemy_melee.tscn")
			var spawned = to_spawn.instantiate()
			spawned.global_transform = spawn_point.global_transform
			spawned.target = get_tree().get_first_node_in_group("Player")
			get_tree().root.add_child(spawned)
			
			await get_tree().create_timer(2).timeout
	
	if ranged:
		for ranged_enemy in ranged:
			var to_spawn = load("res://entities/enemies/RangedEnemy/enemy_ranged.tscn")
			var spawned = to_spawn.instantiate()
			spawned.global_transform = spawn_point.global_transform
			spawned.target = get_tree().get_first_node_in_group("Player")
			get_tree().root.add_child(spawned)
			
			await get_tree().create_timer(2).timeout
		
	await get_tree().create_timer(3).timeout
	door_anim_player.play_backwards("door_open")
	pass
