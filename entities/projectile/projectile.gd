class_name Projectile
extends Node3D

@onready var lifetime_timer = $LifetimeTimer
@onready var collision_area = $CollisionArea
@onready var explosion_area: ShapeCast3D = $ExplosionArea

var speed: int = 35
var direction: Vector3
var knockback: int = 16

# Called when the node enters the scene tree for the first time.
func _ready():
	collision_area.body_entered.connect(_on_projectile_impact)
	collision_area.area_entered.connect(_on_projectile_explosion)
	lifetime_timer.timeout.connect(_on_lifetime_timer_timeout)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	global_position += direction * speed * delta

func start(dir) -> void:
	direction = dir

func explode():
	print(explosion_area.collision_result)
	
	for collision in explosion_area.collision_result:
		# DEBUG PRINT
		#print(collision)
		
		if collision.collider is Player:
			var player = collision.collider as Player
			player.velocity += (global_position.direction_to(player.global_position) * knockback)
		
		if collision.collider is Enemy:
			var enemy = collision.collider as Enemy
			enemy.linear_velocity += (global_position.direction_to(enemy.global_position) * knockback)
			enemy.spawn_blood(enemy.global_position) 
		
func _on_lifetime_timer_timeout():
	call_deferred("queue_free")

func _on_projectile_impact(_body):
	explode()
	call_deferred("queue_free")

func _on_projectile_explosion(_area):
	explode()
	call_deferred("queue_free")
