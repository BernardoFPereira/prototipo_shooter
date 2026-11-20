class_name TutorialSequence
extends Node


signal started
signal step_started(index: int, step: TutorialStep)
signal step_completed(index: int, step: TutorialStep)
signal finished

enum StartMode {
	AFTER_INTRO,
	ON_READY,
	MANUAL,
}

@export var player: Player
@export var enabled: bool = false
@export var start_mode: StartMode = StartMode.AFTER_INTRO
@export var play_intro_animation: bool = false
@export var start_delay: float = 1.0
@export_flags("Visão", "Movimento", "Pulo", "Tiro", "Braço", "Empurrão") var locked_at_start: int = 63
@export var steps: Array[TutorialStep] = []

@export_group("Ao terminar")
@export var unlock_all_at_end: bool = true
@export var close_box_at_end: bool = true

var is_running: bool = false
var current_index: int = -1
var current_step: TutorialStep = null

var _clock: float = 0.0
var _action_progress: float = 0.0
var _manual_done: bool = false
var _text_revealed: bool = false
var _stopped: bool = false


func _ready() -> void:
	if player == null:
		player = _find_player(get_tree().root)
	if player == null:
		push_warning("Tutorial: Player não encontrado, coloque o player no Inspector.")
		return
	if not player.is_node_ready():
		await player.ready
	if not enabled:
		return

	player.lock_abilities(locked_at_start)
	player.play_intro = play_intro_animation
	player.action_performed.connect(_on_action_performed)
	player.assistant_text_box.text_revealed.connect(_on_text_revealed)

	match start_mode:
		StartMode.AFTER_INTRO:
			if not player.intro_done:
				await player.intro_finished
			start()
		StartMode.ON_READY:
			start()


func _process(delta: float) -> void:
	_clock += delta


func start() -> void:
	if is_running or _stopped or player == null:
		return
	is_running = true
	if not player.action_performed.is_connected(_on_action_performed):
		player.action_performed.connect(_on_action_performed)
	if not player.assistant_text_box.text_revealed.is_connected(_on_text_revealed):
		player.assistant_text_box.text_revealed.connect(_on_text_revealed)
	started.emit()
	await _wait(start_delay)

	for i in steps.size():
		if not _can_continue():
			return
		if steps[i] == null:
			continue
		current_index = i
		current_step = steps[i]
		await _run_step(steps[i], i)

	if _can_continue():
		_finish(unlock_all_at_end)


func complete_step() -> void:
	_manual_done = true


func stop(unlock_everything: bool = true) -> void:
	if not is_running:
		return
	_stopped = true
	_finish(unlock_everything)


func _run_step(step: TutorialStep, index: int) -> void:
	await _wait(step.delay_before)
	if not _can_continue():
		return

	if step.lock != 0:
		player.lock_abilities(step.lock)
	if step.unlock_when == TutorialStep.UnlockWhen.STEP_START:
		player.unlock_abilities(step.unlock)
	_action_progress = 0.0
	_manual_done = false
	step_started.emit(index, step)

	if step.message.strip_edges() != "":
		_text_revealed = false
		player.assistant_hold_open = true
		player.show_assistant_message(step.get_text())
		var reveal_limit: float = 3.0 + float(step.message.length()) / 20.0
		await _wait_until(func(): return _text_revealed, reveal_limit)
		if not _can_continue():
			return

	if step.unlock_when == TutorialStep.UnlockWhen.TEXT_FINISHED:
		player.unlock_abilities(step.unlock)
	var shown_at: float = _clock

	match step.complete_when:
		TutorialStep.CompleteWhen.ACTION:
			await _wait_until(func(): return _action_progress >= step.required_amount, step.timeout)
		TutorialStep.CompleteWhen.TIME:
			await _wait(step.wait_time)
		TutorialStep.CompleteWhen.MANUAL:
			await _wait_until(func(): return _manual_done, step.timeout)
		TutorialStep.CompleteWhen.TEXT_FINISHED:
			pass

	await _wait(step.min_time - (_clock - shown_at))
	if not _can_continue():
		return

	if step.unlock_when == TutorialStep.UnlockWhen.STEP_COMPLETE:
		player.unlock_abilities(step.unlock)
	step_completed.emit(index, step)
	if step.close_box_on_complete:
		player.hide_assistant_message()


func _finish(unlock_everything: bool) -> void:
	is_running = false
	current_index = -1
	current_step = null
	if not is_instance_valid(player):
		return
	if unlock_everything:
		player.unlock_abilities(Player.ALL_ABILITIES)
	player.assistant_hold_open = false
	if close_box_at_end:
		player.hide_assistant_message()
	finished.emit()


func _on_action_performed(action: Player.Action, amount: float) -> void:
	if not is_running or current_step == null:
		return
	if current_step.complete_when == TutorialStep.CompleteWhen.ACTION and action == current_step.required_action:
		_action_progress += amount


func _on_text_revealed() -> void:
	_text_revealed = true


func _can_continue() -> bool:
	return is_running and not _stopped and is_instance_valid(player) and not player.is_dead


func _wait(seconds: float) -> void:
	var end_time: float = _clock + seconds
	while _clock < end_time and _can_continue():
		await get_tree().process_frame


func _wait_until(condition: Callable, limit: float = 0.0) -> void:
	var start_time: float = _clock
	while _can_continue() and not condition.call():
		if limit > 0.0 and _clock - start_time >= limit:
			return
		await get_tree().process_frame


func _find_player(node: Node) -> Player:
	if node == null:
		return null
	if node is Player:
		return node
	for child in node.get_children():
		var found: Player = _find_player(child)
		if found:
			return found
	return null
