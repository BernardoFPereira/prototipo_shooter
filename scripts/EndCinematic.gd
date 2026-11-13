extends Node
class_name EndCinematic

@export var player: Player
@export var blast_door: BlastDoor

@export var boxes_to_replace: Array[Node3D]
@export var tubes_to_replace: Array[Node3D]

@export var spawn_doors: Array[SpawnerDoor]

@onready var decompression_move_target = $DecompressionMoveTarget1

@onready var timer: Timer = $Timer
@onready var enemy_detect_area = $EnemyDetectArea

@onready var klaxon_timer = $AlarmSFX/KlaxonTimer
@onready var alarm_loop = $AlarmSFX/AlarmLoop
@onready var klaxon_sfx = $AlarmSFX/KlaxonSFX

@onready var alarm_lights = $AlarmLights

func start_decompression_sequence():
	timer.start()
	klaxon_timer.start()
	alarm_loop.play()
	
	turn_on_lights()
	
	for door in spawn_doors:
		door._on_trigger_activated()

func player_start_cinematic_states():
	player.camera_juice.add_screen_shake(0.1, 15)
	player.set_state(player.PlayerStates.DECOMPRESSING)
	player.is_end_cinematic = true

func move_player():
	var tween = create_tween()
	tween.tween_property(player, "global_position", blast_door.global_position, 2).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUINT)

func turn_on_lights():
	for child in alarm_lights.get_children():
		for subchild in child.get_children():
			if subchild is SpotLight3D:
				subchild.visible = true
			if subchild is AnimationPlayer:
				subchild.play("loop")
			
		if child is OmniLight3D:
			child.light_energy = lerpf(0.0, 98.0, 0.2)

func swap_enemy_models(enemies: Array[Node3D]):
	print("Enemies Detected:")
	print(enemy_detect_area.get_overlapping_bodies())
	print("---")
	
	var enemy_melee = load("res://entities/enemies/MeleeEnemy/decompressed_enemy_melee.tscn")
	var enemy_ranged = load("res://entities/enemies/RangedEnemy/decompressed_enemy_ranged.tscn")
	
	for enemy in enemies:
		#enemy = enemy as EnemyBase
		#enemy.current_state = EnemyBase.EnemyState.IDLE
		enemy.set_current_state(enemy.EnemyState.IDLE)
		enemy.target = null
	
	for enemy in enemies:
		var enemy_inst
		
		if enemy is EnemyMelee:
			enemy_inst = enemy_melee.instantiate()
		if enemy is EnemyRanged:
			enemy_inst = enemy_ranged.instantiate()
		
		$DecompressedEnemies.add_child(enemy_inst)
		enemy_inst.global_transform = enemy.global_transform
		enemy.call_deferred("queue_free")
		var _time = randf_range(0.2, 0.7)
		await get_tree().create_timer(_time).timeout

func spawn_boxes():
	for box in boxes_to_replace:
		var box_to_spawn = load("res://models/level3/DecompressionCube.tscn")
		var box_inst: Node3D = box_to_spawn.instantiate()
		box_inst.global_position = box.global_position
		box_inst.scale = box.scale
		$MovingObjects.add_child(box_inst)
		var _time = randf_range(0.4, 2.0)
		await get_tree().create_timer(_time).timeout

func spawn_tubes():
	for tube in tubes_to_replace:
		var tube_to_spawn = load("res://models/level3/DecompressedTubinho.tscn")
		var tube_inst: Node3D = tube_to_spawn.instantiate()
		tube_inst.global_position = tube.global_position
		tube_inst.scale = tube.scale
		$MovingObjects.add_child(tube_inst)
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

func _on_klaxon_timer_timeout():
	klaxon_sfx.play()
