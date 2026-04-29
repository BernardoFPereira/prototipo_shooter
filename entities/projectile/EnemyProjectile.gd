extends Node3D

@onready var lifetime_timer = $LifetimeTimer
@onready var collision_area = $CollisionArea

@export var damage: int = 15
var speed: int = 35
var direction: Vector3

func _ready():
	collision_area.area_entered.connect(_on_collision_area_area_entered)
	collision_area.body_entered.connect(_on_collision_area_body_entered)
	lifetime_timer.timeout.connect(_on_lifetime_timer_timeout)

func _physics_process(delta):
	global_position += direction * speed * delta

func start(dir) -> void:
	direction = dir


func _on_lifetime_timer_timeout():
	queue_free()

func _on_collision_area_area_entered(area):
	var parent = area.get_parent()
	
	if parent is Player:
		parent.take_damage(damage)
		queue_free()

func _on_collision_area_body_entered(body):
	if body.get_parent() != Player:
		queue_free()
