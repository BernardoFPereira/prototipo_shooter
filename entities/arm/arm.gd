class_name Arm
extends Node3D

enum ArmState {
	THROWN,
	PULLED_BACK,
	STUCK,
}

@onready var flying_sfx = $SFX/Flying
@onready var impact_sfx = $SFX/Impact

@onready var animation_player = $AnimationPlayer
@onready var collision_area = $CollisionArea
@onready var flying_collision = $CollisionArea/FlyingCollision

@onready var arm_model = $ArmProjectile

@onready var impact_particle_marker = $ArmProjectile/Armature/ImpactParticleMarker
@export var impact_particles: PackedScene = preload("uid://c6v2dvvgckrgt")

var state: ArmState

var speed: int = 35
var direction: Vector3
var damage: float = 25.0
var attached_to: Node3D

var is_on_button: bool
var pressed_button: ArmButton
var arm_owner: Player

func _physics_process(delta):
	match state:
		ArmState.THROWN:
			global_position += direction * speed * delta

			var velocity_vector = direction * speed * delta
			var collision_result = collision_area.move_and_collide(velocity_vector)

			if collision_result:
				_on_arm_impact(collision_result)

		ArmState.PULLED_BACK:
			global_position = lerp(global_position, arm_owner.head.global_position, 0.3)
		ArmState.STUCK:
			pass

func start(player: Player, dir: Vector3) -> void:
	arm_owner = player
	direction = dir
	set_as_top_level(true)
	set_state(ArmState.THROWN)

func set_state(new_state: ArmState):
	match new_state:
		ArmState.THROWN:
			flying_collision.disabled = false
			collision_area.set_collision_layer_value(2, false)
			collision_area.set_collision_layer_value(4, false)
			collision_area.set_collision_layer_value(10, false)


		ArmState.PULLED_BACK:
			flying_collision.disabled = false
			collision_area.set_collision_mask_value(5, false)
			collision_area.set_collision_layer_value(2, false)
			collision_area.set_collision_layer_value(4, true)
			collision_area.set_collision_layer_value(10, false)
			if is_on_button:
				pressed_button.set_state(pressed_button.button_states.UNPRESSED)
				pressed_button = null
				is_on_button = false


		ArmState.STUCK:
			flying_collision.disabled = true
			collision_area.set_collision_layer_value(2, true)
			collision_area.set_collision_layer_value(4, false)
			collision_area.set_collision_layer_value(10, true)


	state = new_state

func register_impact():
	queue_free()

func _on_arm_impact(result: KinematicCollision3D):
	var collider = result.get_collider()

	if collider.is_in_group("Unstuckable"):
		_alert_enemies()
		set_state(ArmState.PULLED_BACK)
		return

	if collider is Player and state == ArmState.PULLED_BACK:
		if arm_owner == collider:
			collision_area.set_collision_layer_value(4, true)
			flying_sfx.stop()
		return

	var collision_parent = collider.get_parent()

	if collision_parent.is_in_group("Unstuckable"):
		_alert_enemies()
		set_state(ArmState.PULLED_BACK)
		return

	if collision_parent is ArmButton:
		print("HIT BUTTON")
		collision_parent.set_state(collision_parent.button_states.PRESSED)
		is_on_button = true
		pressed_button = collision_parent

	var collision_normal = result.get_normal()
	var collision_pos = result.get_position()

	global_position = collision_pos + (collision_normal * 0.2)

	var up_vector = Vector3.UP
	if abs(collision_normal.dot(Vector3.UP)) > 0.9:
		up_vector = Vector3.FORWARD

	look_at(global_position + collision_normal, up_vector)

	var impact_particle_instance = impact_particles.instantiate()
	impact_particle_instance.global_transform = impact_particle_marker.global_transform
	impact_particle_instance.emitting = true

	for child: GPUParticles3D in impact_particle_instance.get_children():
		child.emitting = true
	impact_sfx.play()

	get_tree().root.add_child(impact_particle_instance)
	_alert_enemies()

	set_state(ArmState.STUCK)

func _alert_enemies() -> void:
	for enemy in get_tree().get_nodes_in_group("Enemies"):
		if enemy is EnemyBase:
			enemy.hear_noise(global_position)

func _on_old_arm_impact(result: KinematicCollision3D):
	var collider = result.get_collider()
	if collider is Player and state == ArmState.PULLED_BACK:
		if arm_owner == collider:
			collision_area.set_collision_layer_value(4, true)
		return

	var forward_motion = -global_transform.basis.z * 0.5
	var collision_result: KinematicCollision3D = collision_area.move_and_collide(forward_motion)
	if collision_result:
		var collision_parent = collision_result.get_collider().get_parent()
		if collision_parent is ArmButton:
			collision_parent.set_state(collision_parent.button_states.PRESSED)
			is_on_button = true
			pressed_button = collision_parent
		var collision_normal = collision_result.get_normal()
		var collision_pos = collision_result.get_position()


		global_position = collision_pos + (collision_normal / 4)
		look_at(global_position + collision_normal)
		impact_particles.emitting = true


	call_deferred("set_state", ArmState.STUCK)
