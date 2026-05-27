class_name SpatialAudioPlayer3D
extends AudioStreamPlayer3D

@export var max_raycast_distance: float = 30.0
@export var update_frequency_seconds: float = 0.3
@export var max_reverb_wetness: float = 0.25  # REDUZIDO de 0.5
@export var wall_lowpass_amount: int = 600   # AUMENTADO para menos filtragem
@export var fade_in_time: float = 1.5        # Tempo para fade-in

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
	# Configurar bus uma única vez (evitar duplicação)
	_setup_audio_effects()
	
	# Configurar raycasts
	_setup_raycasts()
	
	# Iniciar com volume zero e fade-in
	_target_volume_db = volume_db
	volume_db = -80  # Mais silencioso que -60
	_fade_timer = 0.0
	_is_fading_in = true

func _setup_audio_effects():
	# Verificar se já existe o efeito para não adicionar múltiplas vezes
	var sfx_bus_idx = AudioServer.get_bus_index("SFX")
	
	# Buscar ou criar efeito de reverb
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
	
	# Configurar valores iniciais seguros
	_reverb_effect.wet = 0.0  # COMEÇA COM ZERO
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
	_on_update_reverb(player)  # Reverb por último

func _on_update_reverb(_player: Node3D):
	if _reverb_effect != null:
		# CORREÇÃO: Quanto mais paredes próximas, MENOS reverb
		var open_space_ratio = 0.0
		var walls_detected = 0
		
		for dist in _distance_array:
			if dist >= 0:
				walls_detected += 1
				# Espaço aberto = distância máxima (mais longe da parede)
				open_space_ratio += (dist / max_raycast_distance)
		
		if walls_detected > 0:
			open_space_ratio /= float(walls_detected)
		else:
			open_space_ratio = 1.0  # Espaço completamente aberto
		
		# Reverb aumenta em espaços abertos, diminui em espaços fechados
		_target_reverb_wetness = (1.0 - open_space_ratio) * max_reverb_wetness
		_target_reverb_room_size = 1.0 - open_space_ratio

func _on_update_lowpass_filter(player: Node3D):
	if _lowpass_filter != null:
		# Atualizar direção do raycast para o player
		var direction = (player.global_position - global_position).normalized()
		$RaycastPlayer.target_position = direction * max_raycast_distance
		$RaycastPlayer.force_raycast_update()
		
		var collider = $RaycastPlayer.get_collider()
		var lowpass_cutoff = 20000.0
		
		if collider != null:
			var hit_point = $RaycastPlayer.get_collision_point()
			var ray_distance = global_position.distance_to(hit_point)
			var distance_to_player = global_position.distance_to(player.global_position)
			
			# CORREÇÃO: Só aplica filtro se a parede está entre a fonte e o player
			if ray_distance < distance_to_player and distance_to_player > 0.1:
				var wall_ratio = ray_distance / distance_to_player
				# Quanto mais grossa a parede, mais filtragem
				lowpass_cutoff = max(wall_lowpass_amount, 2000) * (1.0 - wall_ratio) + 2000
		
		_target_lowpass_cutoff = clamp(lowpass_cutoff, 200.0, 20000.0)

func _lerp_paramaters(delta):
	# Fade-in suave para evitar estouros
	if _is_fading_in:
		_fade_timer += delta
		var fade_progress = _fade_timer / fade_in_time
		if fade_progress >= 1.0:
			_is_fading_in = false
			volume_db = _target_volume_db
		else:
			# Curva de fade-in suave (ease out)
			var ease_value = 1.0 - pow(1.0 - fade_progress, 2)
			volume_db = lerp(-80.0, _target_volume_db, ease_value)
	else:
		volume_db = lerp(volume_db, _target_volume_db, delta * 5.0)
	
	# Limitar valores máximos para evitar distorção
	_lowpass_filter.cutoff_hz = lerp(_lowpass_filter.cutoff_hz, _target_lowpass_cutoff, delta * 8.0)
	
	# Limitar reverb para não estourar
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

# Opção para debug (opcional)
func _input(event):
	if event.is_action_pressed("ui_home") and OS.is_debug_build():
		print("=== Audio Debug ===")
		print("Reverb Wet: ", _reverb_effect.wet)
		print("Lowpass Cutoff: ", _lowpass_filter.cutoff_hz)
		print("Volume: ", volume_db)
		print("Open Space Ratio: ", 1.0 - _target_reverb_wetness / max_reverb_wetness)
