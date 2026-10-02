extends Area3D

## Área de mensagem do assistente: quando o jogador entra, mostra uma mensagem e (opcional)
## libera habilidades e/ou conversa com um Tutorial da fase.
## Usos: dica no meio da fase, liberar o braço só numa sala específica, começar um tutorial
## MANUAL ao chegar num lugar, ou completar um passo MANUAL ("chegue até a porta").

enum TutorialAction {
	NONE,          ## Não mexe no tutorial.
	START,         ## Começa o tutorial (use com Start Mode = MANUAL no Tutorial).
	COMPLETE_STEP, ## Completa o passo atual (passos com Complete When = MANUAL).
	STOP,          ## Encerra o tutorial e libera tudo.
}

## Opcional: se ficar vazio, qualquer Player que entrar dispara a área.
@export var player: Player
## Mensagem do assistente. Vazio = não mostra nada (útil só pra liberar habilidade/avançar tutorial).
@export_multiline var message: String
## Coloca o [right] na frente da mensagem automaticamente.
@export var align_right: bool = true
## Fecha a caixa depois de X segundos com o texto completo. 0 = usa o tempo padrão da caixa.
@export var close_after: float = 0.0
## Habilidades liberadas ao entrar na área.
@export_flags("Visão", "Movimento", "Pulo", "Tiro", "Braço", "Empurrão") var unlock: int = 0

@export_group("Tutorial")
@export var tutorial: TutorialSequence
@export var tutorial_action: TutorialAction = TutorialAction.NONE

@export_group("Disparo")
## Só dispara uma vez (e a área se apaga depois).
@export var one_shot: bool = true

var text_played: bool = false


func _on_body_entered(body):
	if not (body is Player):
		return
	if player != null and body != player:
		return
	if one_shot and text_played:
		return
	text_played = true
	var target: Player = body

	if message.strip_edges() != "":
		target.show_assistant_message(("[right]" if align_right else "") + message)
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

	if close_after > 0.0 and message.strip_edges() != "":
		_close_later(target)
	elif one_shot:
		queue_free()


func _close_later(target: Player) -> void:
	# Espera o texto aparecer inteiro e mais close_after segundos (sem contar pausa).
	await target.assistant_text_box.text_revealed
	await get_tree().create_timer(close_after, false).timeout
	# Só fecha se ninguém trocou a mensagem nesse meio-tempo e o tutorial não está segurando a caixa.
	if is_instance_valid(target) and not target.assistant_hold_open and target.new_message.ends_with(message):
		target.hide_assistant_message()
	if one_shot:
		queue_free()
