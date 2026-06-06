class_name Projectile
extends Node3D

@onready var lifetime_timer = $LifetimeTimer
@onready var collision_area = $CollisionArea
@onready var explosion_area: ShapeCast3D = $ExplosionArea
@onready var explosion_timer = $ExplosionTimer
@onready var particles = $GPUParticles3D
@onready var mesh = $MeshInstance3D
@onready var impact_sfx = $ImpactSFX

var speed: int = 35
var direction: Vector3
var knockback: int = 16
var damage: int = 25

# Called when the node enters the scene tree for the first time.
func _ready():
	collision_area.body_entered.connect(_on_projectile_impact)
	collision_area.area_entered.connect(_on_projectile_explosion)
	lifetime_timer.timeout.connect(_on_lifetime_timer_timeout)
	explosion_timer.timeout.connect(_on_explosion_timer_timeout)
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	global_position += direction * speed * delta

func start(dir) -> void:
	direction = dir

func explode():
	explosion_timer.start()
	speed = 0
	mesh.visible = false
	particles.emitting = false
	collision_area.set_deferred("monitoring", false)
	collision_area.set_deferred("monitorable", false)
	impact_sfx.play()
	print(explosion_area.collision_result)
	
	var explosion = preload("res://entities/projectile/ProjectileExplosion.tscn").instantiate()
	explosion.global_transform = global_transform
	get_tree().root.add_child(explosion)
	
	for collision in explosion_area.collision_result:
		
		if collision.collider is Player:
			var player = collision.collider as Player
			player.velocity += (global_position.direction_to(player.global_position) * knockback)
		
		if collision.collider is EnemyMelee:
			var enemy = collision.collider as EnemyMelee
			enemy.receive_rocket_impact(global_position, damage)
		
		if collision.collider is EnemyRanged:
			var enemy = collision.collider as EnemyRanged
			enemy.receive_rocket_impact(global_position, damage)
		
func _on_lifetime_timer_timeout():
	call_deferred("queue_free")

func _on_projectile_impact(_body):
	explode()
	#call_deferred("queue_free")

func _on_projectile_explosion(_area):
	explode()
	#call_deferred("queue_free")

func _on_explosion_timer_timeout():
	call_deferred("queue_free")
