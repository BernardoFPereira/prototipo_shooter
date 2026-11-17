@tool
class_name TutorialStep
extends Resource


enum CompleteWhen {
	ACTION,
	TIME,
	TEXT_FINISHED,
	MANUAL,
}

enum UnlockWhen {
	STEP_START,
	TEXT_FINISHED,
	STEP_COMPLETE,
}

@export_group("Mensagem")
@export_multiline var message: String = ""
@export var align_right: bool = true
@export var delay_before: float = 0.5
@export var close_box_on_complete: bool = false

@export_group("Habilidades")
@export_flags("Visão", "Movimento", "Pulo", "Tiro", "Braço", "Empurrão") var unlock: int = 0
@export var unlock_when: UnlockWhen = UnlockWhen.TEXT_FINISHED
@export_flags("Visão", "Movimento", "Pulo", "Tiro", "Braço", "Empurrão") var lock: int = 0

@export_group("Conclusão")
@export var complete_when: CompleteWhen = CompleteWhen.ACTION:
	set(value):
		complete_when = value
		notify_property_list_changed()
@export var required_action: Player.Action = Player.Action.LOOK
@export var required_amount: float = 1.0
@export var wait_time: float = 3.0
@export var min_time: float = 1.5
@export var timeout: float = 0.0


func get_text() -> String:
	if align_right:
		return "[right]" + message
	else:
		return message


func _validate_property(property: Dictionary) -> void:
	var prop: String = property.name
	var hide: bool = false
	match prop:
		"required_action", "required_amount":
			hide = complete_when != CompleteWhen.ACTION
		"wait_time":
			hide = complete_when != CompleteWhen.TIME
		"timeout":
			hide = complete_when != CompleteWhen.ACTION and complete_when != CompleteWhen.MANUAL
	if hide:
		property.usage &= ~PROPERTY_USAGE_EDITOR
