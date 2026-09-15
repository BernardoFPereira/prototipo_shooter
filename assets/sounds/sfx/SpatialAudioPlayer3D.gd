class_name SpatialAudioPlayer3D
extends AudioStreamPlayer3D

@export var max_raycast_distance: float = 50.0
@export var update_frequency_seconds: float = 0.3
@export var max_reverb_wetness: float = 0.5
@export var wall_lowpass_amount: int = 350   
@export var fade_in_time: float = 0.5
@export var air_absorption_cutoff: float = 12000.0

var _raycast_array: Array = []
var _distance_array: Array = [0,0,0,0,0,0,0,0,0,0]
var _last_update_time: float = 0.0
var _update_distances: bool = true
var _current_raycast_index: int = 0
var _fade_timer: float = 0.0
var _is_fading_in: bool = true

var _reverb_effect: AudioEffectReverb
var _lowpass_filter: AudioEffectLowPassFilter

var _target_lowpass_cutoff: float = 20000
var _target_reverb_wetness: float = 0.0
var _target_reverb_room_size: float = 0.0
var _target_volume_db: float = 0.0

func _ready():
	doppler_tracking = AudioStreamPlayer3D.DOPPLER_TRACKING_PHYSICS_STEP
	max_distance = max_raycast_distance + 5.0
	
	_setup_audio_effects()
	_setup_raycasts()
	
	_target_volume_db = volume_db
	volume_db = -80
	_fade_timer = 0.0
	_is_fading_in = true

func _setup_audio_effects():
	var sfx_bus_idx = AudioServer.get_bus_index("SFX")
	
	var reverb_exists = false
	var lowpass_exists = false
	
	for i in range(AudioServer.get_bus_effect_count(sfx_bus_idx)):
		var effect = AudioServer.get_bus_effect(sfx_bus_idx, i)
		if effect is AudioEffectReverb:
			_reverb_effect = effect
			reverb_exists = true
		elif effect is AudioEffectLowPassFilter:
			_lowpass_filter = effect
			lowpass_exists = true
	
	if not reverb_exists:
		AudioServer.add_bus_effect(sfx_bus_idx, AudioEffectReverb.new(), 0)
		_reverb_effect = AudioServer.get_bus_effect(sfx_bus_idx, 0)
	
	if not lowpass_exists:
		var lowpass_index = 1 if not reverb_exists else 0
		AudioServer.add_bus_effect(sfx_bus_idx, AudioEffectLowPassFilter.new(), lowpass_index)
		_lowpass_filter = AudioServer.get_bus_effect(sfx_bus_idx, lowpass_index)
	
	_reverb_effect.wet = 0.0
	_reverb_effect.room_size = 0.0
	_lowpass_filter.cutoff_hz = 20000

func _setup_raycasts():
	$RaycastDown.target_position = Vector3(0, -max_raycast_distance, 0)
	$RaycastLeft.target_position = Vector3(-max_raycast_distance, 0, 0)
	$RaycastRight.target_position = Vector3(max_raycast_distance, 0, 0)
	$RaycastForward.target_position = Vector3(0, 0, max_raycast_distance)
	$RaycastForwardLeft.target_position = Vector3(-max_raycast_distance, 0, max_raycast_distance)
	$RaycastForwardRight.target_position = Vector3(max_raycast_distance, 0, max_raycast_distance)
	$RaycastBackwardRight.target_position = Vector3(max_raycast_distance, 0, -max_raycast_distance)
	$RaycastBackwardLeft.target_position = Vector3(-max_raycast_distance, 0, -max_raycast_distance)
	$RaycastBackward.target_position = Vector3(0, 0, -max_raycast_distance)
	$RaycastUp.target_position = Vector3(0, max_raycast_distance, 0)
	$RaycastPlayer.target_position = Vector3(0, 0, max_raycast_distance)
	
	_raycast_array = [
		$RaycastDown, $RaycastLeft, $RaycastRight, $RaycastForward, 
		$RaycastForwardLeft, $RaycastForwardRight, $RaycastBackwardRight, 
		$RaycastBackwardLeft, $RaycastBackward, $RaycastUp
	]

func _on_update_raycast_distance(raycast: RayCast3D, raycast_index: int):
	raycast.force_raycast_update()
	var collider = raycast.get_collider()
	if collider != null:
		_distance_array[raycast_index] = global_position.distance_to(raycast.get_collision_point())
	else:
		_distance_array[raycast_index] = -1

func _on_update_spatial_audio(player: Node3D):
	_on_update_lowpass_filter(player)
	_on_update_reverb(player)

func _on_update_reverb(_player: Node3D):
	if _reverb_effect != null:
		
		var open_space_ratio = 0.0
		var walls_detected = 0
		var total_wall_distance = 0.0
		
		for dist in _distance_array:
			if dist >= 0:
				walls_detected += 1
				open_space_ratio += (dist / max_raycast_distance)
				total_wall_distance += dist
		
		if walls_detected > 0:
			open_space_ratio /= float(walls_detected)
			var avg_wall_distance = total_wall_distance / float(walls_detected)
			# room_size reflete o tamanho FÍSICO médio do ambiente, não só a proporção de abertura
			_target_reverb_room_size = clamp(avg_wall_distance / max_raycast_distance, 0.0, 1.0)
		else:
			open_space_ratio = 1.0
			_target_reverb_room_size = 1.0
			
		_target_reverb_wetness = (1.0 - open_space_ratio) * max_reverb_wetness

func _on_update_lowpass_filter(player: Node3D):
	if _lowpass_filter != null:
		
		var direction = (player.global_position - global_position).normalized()
		$RaycastPlayer.target_position = direction * max_raycast_distance
		$RaycastPlayer.force_raycast_update()
		
		var collider = $RaycastPlayer.get_collider()
		var distance_to_player = global_position.distance_to(player.global_position)
		var lowpass_cutoff = 20000.0
		
		if collider != null:
			var hit_point = $RaycastPlayer.get_collision_point()
			var ray_distance = global_position.distance_to(hit_point)
			
			if ray_distance < distance_to_player and distance_to_player > 0.1:
				var wall_ratio = ray_distance / distance_to_player
				lowpass_cutoff = max(wall_lowpass_amount, 2000) * (1.0 - wall_ratio) + 2000
		
		# absorção atmosférica: reduz frequências altas gradualmente com a distância pura,
		# mesmo sem obstáculos no caminho (efeito sutil, mas perceptível em distâncias grandes)
		var atmospheric_cutoff = lerp(20000.0, air_absorption_cutoff, clamp(distance_to_player / max_raycast_distance, 0.0, 1.0))
		lowpass_cutoff = min(lowpass_cutoff, atmospheric_cutoff)
		
		_target_lowpass_cutoff = clamp(lowpass_cutoff, 200.0, 20000.0)

func _lerp_paramaters(delta):
	
	if _is_fading_in:
		_fade_timer += delta
		var fade_progress = _fade_timer / fade_in_time
		if fade_progress >= 1.0:
			_is_fading_in = false
			volume_db = _target_volume_db
		else:
			
			var ease_value = 1.0 - pow(1.0 - fade_progress, 2)
			volume_db = lerp(-80.0, _target_volume_db, ease_value)
	else:
		volume_db = lerp(volume_db, _target_volume_db, delta * 5.0)
	
	_lowpass_filter.cutoff_hz = lerp(_lowpass_filter.cutoff_hz, _target_lowpass_cutoff, delta * 8.0)
	
	var target_wet = clamp(_target_reverb_wetness, 0.0, max_reverb_wetness)
	_reverb_effect.wet = lerp(_reverb_effect.wet, target_wet, delta * 8.0)
	_reverb_effect.room_size = lerp(_reverb_effect.room_size, _target_reverb_room_size, delta * 8.0)

func _physics_process(delta):
	_last_update_time += delta
	
	if _update_distances:
		_on_update_raycast_distance(_raycast_array[_current_raycast_index], _current_raycast_index)
		_current_raycast_index += 1
		if _current_raycast_index >= _distance_array.size():
			_current_raycast_index = 0
			_update_distances = false
	
	if _last_update_time > update_frequency_seconds:
		var player_camera = get_viewport().get_camera_3d()
		if player_camera != null:
			_on_update_spatial_audio(player_camera)
		_update_distances = true
		_last_update_time = 0.0
	
	_lerp_paramaters(delta)
