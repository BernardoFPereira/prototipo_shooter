class_name Projectile
extends Node3D

@onready var lifetime_timer = $LifetimeTimer
@onready var collision_area = $CollisionArea
@onready var explosion_area: ShapeCast3D = $ExplosionArea
@onready var explosion_timer = $ExplosionTimer

@onready var propulsion_mesh = $propulsion_mesh
@onready var propulsion_mesh_2 = $propulsion_mesh2
@onready var tail = $Tail
@onready var impact_fx = $ImpactFX
@onready var impact_wave_fx = $ImpactWaveFX

@onready var particles = $GPUParticles3D
@onready var mesh = $MeshInstance3D
@onready var impact_sfx = $ImpactSFX
@onready var projectile_light = $ProjectileLight

@export var max_jump_height: float = 10

var speed: int = 35
var direction: Vector3
var knockback: int = 16
var damage: int = 25

func _ready():
	collision_area.body_entered.connect(_on_projectile_impact)
	lifetime_timer.timeout.connect(_on_lifetime_timer_timeout)
	explosion_timer.timeout.connect(_on_explosion_timer_timeout)

func _process(delta):
	global_position += direction * speed * delta

func start(dir) -> void:
	direction = dir

func explode():
	var shot_direction: Vector3 = direction
	explosion_timer.start()
	projectile_light.visible = false
	speed = 0
	direction = Vector3.ZERO
	mesh.visible = false
	propulsion_mesh.visible = false
	propulsion_mesh_2.visible = false
	tail.visible = false
	impact_fx.emitting = true
	impact_wave_fx.emitting = true
	collision_area.set_deferred("monitoring", false)
	collision_area.set_deferred("monitorable", false)
	impact_sfx.play()
	remove_from_group("PlayerAttacks")
	_alert_enemies()
	var explosion = preload("res://entities/projectile/ProjectileExplosion.tscn").instantiate()
	explosion.global_transform = global_transform
	get_tree().root.add_child(explosion)

	for collision in explosion_area.collision_result:

		if collision.collider is Player:
			var player = collision.collider as Player
			var knockback_force = global_position.direction_to(player.global_position) * knockback
			print(knockback_force)
			knockback_force.y = min(knockback_force.y, max_jump_height)
			player.velocity += knockback_force
			print(player.velocity)

		if collision.collider is EnemyMelee:
			var enemy = collision.collider as EnemyMelee
			enemy.receive_rocket_impact(global_position, damage, shot_direction)

		if collision.collider is EnemyRanged:
			var enemy = collision.collider as EnemyRanged
			enemy.receive_rocket_impact(global_position, damage, shot_direction)

		if collision.collider is BreakableVent:
			var vent = collision.collider as BreakableVent
			vent.break_vent()


func _alert_enemies() -> void:
	for enemy in get_tree().get_nodes_in_group("Enemies"):
		if enemy is EnemyBase:
			enemy.hear_noise(global_position)

func _on_lifetime_timer_timeout():
	call_deferred("queue_free")

func _on_projectile_impact(_body):
	explode()


func _on_explosion_timer_timeout():
	call_deferred("queue_free")
