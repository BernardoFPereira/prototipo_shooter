extends Node
class_name EndCinematic

@export var player: Player
@export var blast_door: BlastDoor
@export var box_object_scene: PackedScene

#@export var objects

@export var boxes_to_replace: Array[Node3D]
@export var tubes_to_replace: Array[Node3D]

@export var box_spawn_points: Array[Marker3D]
@export var tube_spawn_points: Array[Marker3D]

@onready var decompression_move_target = $DecompressionMoveTarget
@onready var box_spawn_point = $BoxSpawnPoint
@onready var box_spawn_point_2 = $BoxSpawnPoint2

@onready var timer: Timer = $Timer
@onready var enemy_detect_area = $EnemyDetectArea

var player_is_turning: bool = false

#func _process(delta):
	#if player_is_turning and player.is_on_floor():
		#player_turn_to_door()

func start_decompression_sequence():
	timer.start()
	print("OVERLAPPING:\n")
	print(enemy_detect_area.get_overlapping_bodies())

func player_start_cinematic_states():
	player.camera_juice.add_screen_shake(0.1, 15)
	player.set_state(player.PlayerStates.DECOMPRESSING)
	#center_player_sight()
	player.is_end_cinematic = true
	#player_is_turning = true

#func center_player_sight():
	#var rot_tween = create_tween()
	#rot_tween.tween_property(player.head, "global_rotation", 0, 0.5)
	#player.head.rotation.x
	#pass

#func player_turn_to_door():
	#var target_transform = player.head.transform.looking_at(blast_door.global_position, Vector3.UP)
	#player.head.transform = player.head.transform.interpolate_with(target_transform, 0.3)

func move_player():
	var tween = create_tween()
	tween.tween_property(player, "global_position", blast_door.global_position, 2).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUINT)

func spawn_enemies():
	pass

func swap_enemy_models(enemies: Array[Node3D]):
	var enemy_melee = load("res://entities/enemies/MeleeEnemy/decompressed_enemy_melee.tscn")
	var enemy_ranged = load("res://entities/enemies/RangedEnemy/decompressed_enemy_ranged.tscn")
	
	for enemy in enemies:
		enemy.set_current_state(enemy.EnemyState.IDLE)
		var enemy_inst
		
		if enemy is EnemyMelee:
			enemy_inst = enemy_melee.instantiate()
		if enemy is EnemyRanged:
			enemy_inst = enemy_ranged.instantiate()
		
		$DecompressedEnemies.add_child(enemy_inst)
		enemy_inst.global_transform = enemy.global_transform
		enemy.call_deferred("queue_free")

func spawn_boxes():
	for box in boxes_to_replace:
		var box_to_spawn = load("res://models/level3/DecompressionCube.tscn")
		var box_inst: Node3D = box_to_spawn.instantiate()
		box_inst.global_position = box.global_position
		box_inst.scale = box.scale
		#box_inst.scale = Vector3(0.3, 0.3, 0.3)
		$MovingObjects.add_child(box_inst)
		var move_tween = box_inst.create_tween()
		move_tween.tween_property(box_inst, "global_position", decompression_move_target.global_position, 2)
		var _time = randf_range(0.4, 2.0)
		await get_tree().create_timer(_time).timeout

func spawn_tubes():
	for tube in tubes_to_replace:
		var tube_to_spawn = load("res://models/level3/DecompressedTubinho.tscn")
		var tube_inst: Node3D = tube_to_spawn.instantiate()
		tube_inst.global_position = box_spawn_point.global_position
		tube_inst.scale = tube.scale
		#tube_inst.scale = Vector3(0.3, 0.3, 0.3)
		$MovingObjects.add_child(tube_inst)
		var move_tween = tube_inst.create_tween()
		move_tween.tween_property(tube_inst, "global_position", decompression_move_target.global_position, 2)
		var _time = randf_range(0.8, 3.0)
		await get_tree().create_timer(_time).timeout

func _on_timer_timeout():
	player_start_cinematic_states()
	blast_door.open_blast_door()
	blast_door.start_decompress()
	swap_enemy_models(enemy_detect_area.get_overlapping_bodies())
	await get_tree().create_timer(1.5).timeout
	spawn_boxes()
	#await get_tree().create_timer(0.4).timeout
	spawn_tubes()
	await get_tree().create_timer(3).timeout
	move_player()
