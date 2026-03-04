class_name Projectile
extends Node3D

@onready var lifetime_timer = $LifetimeTimer

var speed: int = 35
var direction: Vector3

# Called when the node enters the scene tree for the first time.
func _ready():
	#collision_area.body_entered.connect(_on_projectile_impact)
	lifetime_timer.timeout.connect(_on_lifetime_timer_timeout)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	global_position += direction * speed * delta

func start(dir) -> void:
	direction = dir

func _on_lifetime_timer_timeout():
	call_deferred("queue_free")

#func _on_projectile_impact():
	#pass
