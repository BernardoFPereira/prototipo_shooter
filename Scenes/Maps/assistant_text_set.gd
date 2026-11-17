@tool
extends Area3D


enum HideMode {
	TIME,
	OTHER_AREA,
	LEAVE_AREA,
	NEXT_MESSAGE,
}

enum TutorialAction {
	NONE,
	START,
	COMPLETE_STEP,
	STOP,
}

@export var player: Player
@export_multiline var message: String
@export var align_right: bool = true

@export_group("Hide Settings")
@export var hide_mode: HideMode = HideMode.TIME:
	set(value):
		hide_mode = value
		notify_property_list_changed()
@export var hide_after: float = 5.0
@export var hide_area: Area3D
@export var max_time: float = 0.0

@export_group("Abilities")
@export_flags("Visão", "Movimento", "Pulo", "Tiro", "Braço", "Empurrão") var unlock: int = 0

@export_group("Tutorial")
@export var tutorial: TutorialSequence
@export var tutorial_action: TutorialAction = TutorialAction.NONE

@export_group("Playback")
@export var one_shot: bool = true

var text_played: bool = false
var _target: Player = null
var _message_id: int = -1
var _timer: Timer
var _waiting_reveal_time: float = 0.0


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	_timer = Timer.new()
	_timer.one_shot = true
	_timer.timeout.connect(_on_timer_timeout)
	add_child(_timer)
	body_exited.connect(_on_body_exited)
	if hide_area:
		hide_area.body_entered.connect(_on_hide_area_body_entered)


func _on_body_entered(body) -> void:
	if Engine.is_editor_hint():
		return
	if not (body is Player):
		return
	if player != null and body != player:
		return
	if one_shot and text_played:
		return
	var target: Player = body
	if _message_id != -1 and target.is_assistant_message_showing(_message_id):
		return
	text_played = true

	if unlock != 0:
		target.unlock_abilities(unlock)
	if tutorial:
		match tutorial_action:
			TutorialAction.START:
				tutorial.start()
			TutorialAction.COMPLETE_STEP:
				tutorial.complete_step()
			TutorialAction.STOP:
				tutorial.stop()

	if message.strip_edges() == "":
		if one_shot:
			queue_free()
		return

	_show(target)


func _show(target: Player) -> void:
	_disconnect_player()
	_target = target
	if align_right:
		_message_id = target.show_assistant_message("[right]" + message, false)
	else:
		_message_id = target.show_assistant_message(message, false)
	target.assistant_message_shown.connect(_on_message_shown)
	target.assistant_message_closed.connect(_on_message_closed)

	var seconds: float
	if hide_mode == HideMode.TIME:
		seconds = hide_after
	else:
		seconds = max_time
	if seconds > 0.0:
		_waiting_reveal_time = seconds
		target.assistant_text_box.text_revealed.connect(_on_text_revealed)


func _close() -> void:
	if is_instance_valid(_target) and _message_id != -1:
		_target.hide_assistant_message(_message_id)
	_done()


func _done() -> void:
	_timer.stop()
	_waiting_reveal_time = 0.0
	_message_id = -1
	_disconnect_player()
	if one_shot:
		queue_free()


func _disconnect_player() -> void:
	if not is_instance_valid(_target):
		return
	if _target.assistant_message_shown.is_connected(_on_message_shown):
		_target.assistant_message_shown.disconnect(_on_message_shown)
	if _target.assistant_message_closed.is_connected(_on_message_closed):
		_target.assistant_message_closed.disconnect(_on_message_closed)
	if _target.assistant_text_box.text_revealed.is_connected(_on_text_revealed):
		_target.assistant_text_box.text_revealed.disconnect(_on_text_revealed)


func _on_text_revealed() -> void:
	if _waiting_reveal_time <= 0.0 or not _target.is_assistant_message_showing(_message_id):
		return
	_timer.start(_waiting_reveal_time)
	_waiting_reveal_time = 0.0
	_target.assistant_text_box.text_revealed.disconnect(_on_text_revealed)


func _on_timer_timeout() -> void:
	_close()


func _on_body_exited(body) -> void:
	if hide_mode == HideMode.LEAVE_AREA and body == _target and _message_id != -1:
		_close()


func _on_hide_area_body_entered(body) -> void:
	if hide_mode == HideMode.OTHER_AREA and body == _target and _message_id != -1:
		_close()


func _on_message_shown(id: int) -> void:
	if id != _message_id:
		_done()


func _on_message_closed(id: int) -> void:
	if id == _message_id:
		_done()


func _validate_property(property: Dictionary) -> void:
	var hidden_field: bool = false
	match property.name:
		"hide_after":
			hidden_field = hide_mode != HideMode.TIME
		"hide_area":
			hidden_field = hide_mode != HideMode.OTHER_AREA
		"max_time":
			hidden_field = hide_mode == HideMode.TIME
	if hidden_field:
		property.usage &= ~PROPERTY_USAGE_EDITOR
