extends Node3D
class_name SpawnerDoor
 
#@onready var door = $portadiorama
@onready var door_anim_player = $portadiorama/AnimationPlayer
@onready var spawn_point = $SpawnPoint
@onready var spawn_trigger_area = $SpawnTriggerArea
 
#@export var enemy_list: Array[PackedScene]
@export_category("Enemies to Spawn")
@export var melee: int
@export var ranged: int
@export var one_shot = true
@export var is_triggered: bool
@export var aggro: bool
 
@export_category("Patrol")
@export var patrol_route_name: String = ""
 
var is_spawning: bool
var enemies_spawned: int = 0
 
func spawn_enemy():
	is_spawning = true
	while(is_spawning):
		enemies_spawned += 1
		if enemies_spawned >= melee + ranged:
			is_spawning = false
	if melee:
		for melee_enemy in melee:
			var to_spawn = load("res://entities/enemies/MeleeEnemy/enemy_melee.tscn")
			var spawned = to_spawn.instantiate()
			spawned.global_transform = spawn_point.global_transform
			spawned.target = get_tree().get_first_node_in_group("Player")
			spawned.patrol_route_name = patrol_route_name
			add_sibling(spawned)
			#get_tree().root.add_child(spawned)
			if aggro:
				spawned.current_state = EnemyBase.EnemyState.SEARCHING
			door_anim_player.play("door_open")
			await get_tree().create_timer(3).timeout
			door_anim_player.play_backwards("door_open")
			await get_tree().create_timer(3).timeout
			
	if ranged:
		for ranged_enemy in ranged:
			var to_spawn = load("res://entities/enemies/RangedEnemy/enemy_ranged.tscn")
			var spawned = to_spawn.instantiate()
			spawned.global_transform = spawn_point.global_transform
			spawned.target = get_tree().get_first_node_in_group("Player")
			spawned.patrol_route_name = patrol_route_name
			add_sibling(spawned)
			#get_tree().root.add_child(spawned)
			if aggro:
				spawned.current_state = EnemyBase.EnemyState.SEARCHING
			door_anim_player.play("door_open")
			await get_tree().create_timer(3).timeout
			door_anim_player.play_backwards("door_open")
			await get_tree().create_timer(3).timeout

func _on_spawn_trigger_area_body_entered(body):
	if is_triggered:
		return
		
	if one_shot and !is_spawning:
		spawn_enemy()
		spawn_trigger_area.queue_free()
	elif !is_spawning:
		spawn_enemy()

func _on_trigger_activated():
	spawn_enemy()
