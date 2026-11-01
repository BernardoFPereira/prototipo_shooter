extends Node
class_name EndCinematic

@export var player: Player
@export var blast_door: BlastDoor
@export var box_object_scene: PackedScene

@onready var decompression_move_target = $DecompressionMoveTarget
@onready var box_spawn_point = $BoxSpawnPoint
@onready var timer: Timer = $Timer
@onready var enemy_detect_area = $EnemyDetectArea

#func _process():
	#for obj in $MovingObjects:
		#obj.

func start_decompression_sequence():
	timer.start()
	print("OVERLAPPING:\n")
	print(enemy_detect_area.get_overlapping_bodies())

func player_look_at_door():
	player.is_end_cinematic = true
	player.camera_juice.add_screen_shake(0.1, 15)
	player.rotation.y = lerp_angle(player.rotation.y, -player.global_position.angle_to(blast_door.global_position), 0.2)
	#player.head.look_at(blast_door.global_position)

func move_player():
	player.set_state(player.PlayerStates.DECOMPRESSING)
	var tween = create_tween()
	tween.tween_property(player, "global_position", blast_door.global_position, 2)
	#player.global_position = player.global_position.lerp(blast_door.global_position, 0.3)

func spawn_enemies():
	pass

func swap_enemy_models(enemies: Array[Node3D]):
	var enemy_melee = load("res://entities/enemies/MeleeEnemy/decompressed_enemy_melee.tscn")
	#var enemy_ranged = load("res://entities/enemies/MeleeEnemy/decompressed_enemy_melee.tscn")
	for enemy in enemies:
		enemy.set_current_state(enemy.EnemyState.IDLE)
		var enemy_inst = enemy_melee.instantiate()
		$DecompressedEnemies.add_child(enemy_inst)
		enemy_inst.global_transform = enemy.global_transform
		enemy.call_deferred("queue_free")
	pass

func spawn_objects():
	var box_to_spawn = load("res://models/level3/DecompressionCube.tscn")
	var box_inst: Node3D = box_to_spawn.instantiate()
	box_inst.global_position = box_spawn_point.global_position
	box_inst.scale = Vector3(0.3, 0.3, 0.3)
	$MovingObjects.add_child(box_inst)
	var move_tween = box_inst.create_tween()
	move_tween.tween_property(box_inst, "global_position", decompression_move_target.global_position, 2)


func _on_timer_timeout():
	player_look_at_door()
	blast_door.open_blast_door()
	blast_door.start_decompress()
	swap_enemy_models(enemy_detect_area.get_overlapping_bodies())
	await get_tree().create_timer(1.5).timeout
	spawn_objects()
	await get_tree().create_timer(3).timeout
	move_player()
