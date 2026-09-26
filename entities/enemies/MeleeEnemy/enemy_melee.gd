class_name EnemyMelee
extends EnemyBase
 
@onready var attack_collision: CollisionShape3D = $Armature/Skeleton3D/BoneAttachment3D/AttackArea/AttackCollision
@onready var attack_area: Area3D = $Armature/Skeleton3D/BoneAttachment3D/AttackArea
 
@export_category("Combat Properties")
@export var attack_damage: int = 55
 
func _pre_state_change(new_state: EnemyState) -> void:
	if new_state != EnemyState.ATTACKING:
		attack_area.set_collision_mask_value(10, false)
 
func turn_attack_collision_on() -> void:
	attack_area.set_collision_mask_value(10, true)
 
func turn_attack_collision_off() -> void:
	attack_area.set_collision_mask_value(10, false)
 
func _on_attack_area_entered(area: Area3D) -> void:
	var parent = area.get_parent()
	if parent == target:
		target.take_damage(attack_damage)
