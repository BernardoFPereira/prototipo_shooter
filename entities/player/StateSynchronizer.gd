extends MultiplayerSynchronizer

# These will be updated automatically when the server replicates the transform
var authoritative_position: Vector3
var authoritative_velocity: Vector3
var authoritative_rotation: Basis

func _ready():
	synchronized.connect(_on_synchronized)

func _on_synchronized():
	# When replication happens, cache the authoritative transform
	authoritative_velocity = get_parent().velocity
	authoritative_position = get_parent().global_transform.origin
	authoritative_rotation = get_parent().global_transform.basis.orthonormalized()
	
	apply_reconciliation(get_parent(), get_process_delta_time())

func apply_reconciliation(player: Player, delta: float):
	# Smoothly correct toward server state
	var pos_alpha = clamp(delta * 10.0, 0.0, 1.0)
	var vel_alpha = clamp(delta * 20.0, 0.0, 1.0)
	var rot_alpha = clamp(delta * 20.0, 0.0, 1.0)
	
	#if authoritative_position:
	player.velocity = player.velocity.lerp(authoritative_velocity, vel_alpha)
	
	if authoritative_position and player.global_position.distance_to(authoritative_position) > 0.05:
		player.global_position = player.global_position.lerp(authoritative_position, pos_alpha)
		
	var current_yaw = player.rotation.y
	var authoritative_yaw = authoritative_rotation.get_euler().y

	if abs(current_yaw - authoritative_yaw) > deg_to_rad(2.0):
		player.rotation.y = lerp_angle(current_yaw, authoritative_yaw, rot_alpha)
