extends StaticBody3D
class_name BreakableVent

@export var is_breakable: bool = false
@onready var collision_shape_3d = $CollisionShape3D
@onready var break_audio = $BreakAudio
@onready var vent_mesh = $vent
@onready var break_fx = $BreakFX

@onready var main_flash = $BreakFX/MainFlash
@onready var impact_flash = $BreakFX/ImpactFlash
@onready var smoke = $BreakFX/Smoke
@onready var sparks = $BreakFX/Sparks
@onready var piece_1 = $BreakFX/Piece1
@onready var piece_2 = $BreakFX/Piece2
@onready var piece_3 = $BreakFX/Piece3

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass

func break_vent():
	#collision_shape_3d.disabled = true
	set_collision_layer_value(1, false)
	set_collision_layer_value(5, false)
	set_collision_layer_value(9, false)
	
	for child in break_fx.get_children():
		var fx = child as GPUParticles3D
		var p_mat = fx.process_material as ParticleProcessMaterial
		#print(fx.name)
		if self.scale < Vector3(1, 1, 1):
			print("small vent")
			p_mat.scale_min = 1
			p_mat.scale_max = 1
			
			if fx.name == "Piece1" || fx.name == "Piece2" || fx.name == "Piece3":
				p_mat.scale_min = 2
				p_mat.scale_max = 2
			if fx.name == "Sparks":
				p_mat.scale_min = 0.5
				p_mat.scale_max = 0.5
			if fx.name == "Smoke":
				p_mat.scale_min = 1
				p_mat.scale_max = 1
		else:
			p_mat.scale_min = 2
			p_mat.scale_max = 2
			if fx.name == "Piece1" || fx.name == "Piece2" || fx.name == "Piece3":
				p_mat.scale_min = 4
				p_mat.scale_max = 4
		fx.emitting = true
	
	vent_mesh.visible = false
	break_audio.play()
	#clean_up_vent()
	await get_tree().create_timer(1.5).timeout
	call_deferred("queue_free")

#func clean_up_vent():
