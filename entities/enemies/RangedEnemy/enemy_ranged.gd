class_name EnemyRanged
extends EnemyBase

@onready var muzzle_point: Marker3D = $Armature/Skeleton3D/BoneAttachment3D/MuzzlePoint
@onready var muzze_flash: PackedScene = preload("uid://dkeqiailpja6v")
@onready var shot_sfx: AudioStreamPlayer3D = $SFX/Shot

var enemy_projectile_scene = preload("uid://bkecmbnogq48m")

func spawn_projectile() -> void:
	var projectile = enemy_projectile_scene.instantiate()
	get_parent().add_child(projectile, true)
	projectile.global_transform = muzzle_point.global_transform
	projectile.start(global_position.direction_to(target.global_position))
	shot_sfx.play()

	var muzzle_flash_inst = muzze_flash.instantiate()
	muzzle_point.add_child(muzzle_flash_inst)
	muzzle_flash_inst.global_position = muzzle_point.global_position
