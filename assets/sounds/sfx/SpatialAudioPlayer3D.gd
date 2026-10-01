class_name SpatialAudioPlayer3D
extends AudioStreamPlayer3D


@export var max_raycast_distance: float = 50.0
@export var update_frequency_seconds: float = 0.15
@export var max_reverb_wetness: float = 0.5
@export var wall_lowpass_amount: int = 900
@export var occlusion_volume_db: float = -6.0
@export var fade_in_time: float = 0.5
@export var air_absorption_cutoff: float = 6000.0
@export var air_absorption_db: float = -12.0
@export var max_hear_distance: float = 80.0

var _raycast_array: Array = []
var _distance_array: Array = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
var _last_update_time: float = 0.0
var _update_distances: bool = true
var _current_raycast_index: int = 0
var _fade_timer: float = 0.0
var _is_fading_in: bool = true

var _reverb_effect: AudioEffectReverb

var _base_volume_db: float = 0.0
var _occlusion: float = 0.0
var _target_occlusion: float = 0.0
var _target_reverb_wetness: float = 0.0
var _target_reverb_room_size: float = 0.0

static var _reverb_leader: SpatialAudioPlayer3D = null
static var _reverb_leader_distance: float = INF


func _ready():
	doppler_tracking = AudioStreamPlayer3D.DOPPLER_TRACKING_PHYSICS_STEP
	max_distance = max_hear_distance
	attenuation_filter_cutoff_hz = air_absorption_cutoff
	attenuation_filter_db = air_absorption_db

	_setup_audio_effects()
	_setup_raycasts()

	_base_volume_db = volume_db
	volume_db = -80
	_fade_timer = 0.0
	_is_fading_in = true


func _exit_tree():
	if _reverb_leader == self:
		_reverb_leader = null
		_reverb_leader_distance = INF


func _setup_audio_effects():
	var sfx_bus_idx = AudioServer.get_bus_index("SFX")
	if sfx_bus_idx == -1:
		return
	for i in range(AudioServer.get_bus_effect_count(sfx_bus_idx)):
		var effect = AudioServer.get_bus_effect(sfx_bus_idx, i)
		if effect is AudioEffectReverb:
			_reverb_effect = effect
			return
	var reverb := AudioEffectReverb.new()
	reverb.wet = 0.0
	reverb.room_size = 0.0
	AudioServer.add_bus_effect(sfx_bus_idx, reverb, 0)
	_reverb_effect = reverb


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
	if raycast.get_collider() != null:
		_distance_array[raycast_index] = global_position.distance_to(raycast.get_collision_point())
	else:
		_distance_array[raycast_index] = -1


#region OCLUSÃO (por som)
func _update_occlusion(camera: Node3D):
	var to_camera := camera.global_position - global_position
	var distance_to_camera := to_camera.length()
	if distance_to_camera < 0.1:
		_target_occlusion = 0.0
		return
	$RaycastPlayer.target_position = $RaycastPlayer.to_local(camera.global_position)
	$RaycastPlayer.force_raycast_update()
	var blocked := false
	if $RaycastPlayer.get_collider() != null:
		var hit_distance: float = global_position.distance_to($RaycastPlayer.get_collision_point())
		blocked = hit_distance < distance_to_camera - 0.2
	_target_occlusion = 1.0 if blocked else 0.0


func _apply_occlusion(delta: float):
	_occlusion = lerpf(_occlusion, _target_occlusion, clampf(delta * 8.0, 0.0, 1.0))
	attenuation_filter_cutoff_hz = lerpf(air_absorption_cutoff, float(wall_lowpass_amount), _occlusion)
	attenuation_filter_db = lerpf(air_absorption_db, minf(air_absorption_db * 1.75, -36.0), _occlusion)
#endregion


#region REVERB
func _update_reverb_leadership(camera: Node3D):
	var my_distance := global_position.distance_to(camera.global_position)
	var leader_valid := _reverb_leader != null and is_instance_valid(_reverb_leader) and _reverb_leader.playing
	if not leader_valid or _reverb_leader == self or my_distance < _reverb_leader_distance:
		_reverb_leader = self
		_reverb_leader_distance = my_distance


func _compute_reverb_targets():
	var open_space_ratio := 0.0
	var walls_detected := 0
	var total_wall_distance := 0.0

	for dist in _distance_array:
		if dist >= 0:
			walls_detected += 1
			open_space_ratio += (dist / max_raycast_distance)
			total_wall_distance += dist

	if walls_detected > 0:
		open_space_ratio /= float(walls_detected)
		var avg_wall_distance := total_wall_distance / float(walls_detected)
		_target_reverb_room_size = clampf(avg_wall_distance / max_raycast_distance, 0.0, 1.0)
	else:
		open_space_ratio = 1.0
		_target_reverb_room_size = 1.0

	_target_reverb_wetness = (1.0 - open_space_ratio) * max_reverb_wetness


func _apply_reverb(delta: float):
	if _reverb_effect == null or _reverb_leader != self:
		return
	var t := clampf(delta * 8.0, 0.0, 1.0)
	_reverb_effect.wet = lerpf(_reverb_effect.wet, clampf(_target_reverb_wetness, 0.0, max_reverb_wetness), t)
	_reverb_effect.room_size = lerpf(_reverb_effect.room_size, _target_reverb_room_size, t)
#endregion


func _update_volume(delta: float):
	var target_db := _base_volume_db + occlusion_volume_db * _occlusion
	if _is_fading_in:
		_fade_timer += delta
		var fade_progress := _fade_timer / fade_in_time if fade_in_time > 0.0 else 1.0
		if fade_progress >= 1.0:
			_is_fading_in = false
			volume_db = target_db
		else:
			var ease_value := 1.0 - pow(1.0 - fade_progress, 2)
			volume_db = lerpf(-80.0, target_db, ease_value)
	else:
		volume_db = lerpf(volume_db, target_db, clampf(delta * 5.0, 0.0, 1.0))


func _physics_process(delta):
	_update_volume(delta)

	if not playing:
		if _reverb_leader == self:
			_reverb_leader = null
			_reverb_leader_distance = INF
		return

	if _update_distances and _reverb_leader == self:
		_on_update_raycast_distance(_raycast_array[_current_raycast_index], _current_raycast_index)
		_current_raycast_index += 1
		if _current_raycast_index >= _distance_array.size():
			_current_raycast_index = 0
			_update_distances = false

	_last_update_time += delta
	if _last_update_time > update_frequency_seconds:
		_last_update_time = 0.0
		var camera := get_viewport().get_camera_3d()
		if camera != null:
			_update_occlusion(camera)
			_update_reverb_leadership(camera)
			if _reverb_leader == self:
				_compute_reverb_targets()
				_update_distances = true

	_apply_occlusion(delta)
	_apply_reverb(delta)
