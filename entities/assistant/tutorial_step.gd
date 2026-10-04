@tool
class_name TutorialStep
extends Resource

## Um passo do tutorial. O nó Tutorial (TutorialSequence) roda os passos em ordem; cada passo:
##   1. espera `delay_before`;
##   2. mostra `message` na caixa do assistente (se tiver mensagem);
##   3. libera as habilidades de `unlock` (no momento escolhido em `unlock_when`);
##   4. espera a condição de `complete_when` (fazer uma ação, tempo, ou alguém mandar avançar);
##   5. avança pro próximo passo.
## Um passo sem mensagem serve pra só liberar/travar habilidades ou esperar algo acontecer.

enum CompleteWhen {
	ACTION,        ## Espera o jogador fazer `required_action` até somar `required_amount`.
	TIME,          ## Espera `wait_time` segundos depois do texto terminar de aparecer.
	TEXT_FINISHED, ## Avança assim que o texto termina de aparecer (só respeita o `min_time`).
	MANUAL,        ## Espera alguém chamar complete_step() no Tutorial (área de mensagem, porta, inimigo...).
}

enum UnlockWhen {
	STEP_START,    ## Assim que o passo começa (antes da mensagem aparecer).
	TEXT_FINISHED, ## Quando o texto termina de aparecer na caixa.
	STEP_COMPLETE, ## Só quando o passo termina (recompensa).
}

@export_group("Mensagem")
## Texto da caixa do assistente. Pode quebrar linha com Enter. Vazio = passo sem mensagem.
@export_multiline var message: String = ""
## Coloca o [right] na frente da mensagem automaticamente.
@export var align_right: bool = true
## Pausa (s) antes do passo começar.
@export var delay_before: float = 0.5
## Fecha a caixa do assistente quando o passo termina. Desligado = a próxima mensagem substitui esta.
@export var close_box_on_complete: bool = false

@export_group("Habilidades")
## Habilidades liberadas neste passo.
@export_flags("Visão", "Movimento", "Pulo", "Tiro", "Braço", "Empurrão") var unlock: int = 0
## Quando as habilidades de `unlock` são liberadas.
@export var unlock_when: UnlockWhen = UnlockWhen.TEXT_FINISHED
## Habilidades TRAVADAS quando este passo começa (normalmente vazio; útil pra tutoriais no meio da fase).
@export_flags("Visão", "Movimento", "Pulo", "Tiro", "Braço", "Empurrão") var lock: int = 0

@export_group("Conclusão")
## O que faz o passo terminar.
@export var complete_when: CompleteWhen = CompleteWhen.ACTION:
	set(value):
		complete_when = value
		notify_property_list_changed()
## Ação que o jogador precisa fazer (só no modo ACTION).
@export var required_action: Player.Action = Player.Action.LOOK
## Quanto da ação: graus girados (Visão), metros andados (Movimento) ou nº de vezes (o resto).
@export var required_amount: float = 1.0
## Segundos de espera depois do texto aparecer (só no modo TIME).
@export var wait_time: float = 3.0
## Tempo mínimo (s) que a mensagem fica na tela depois de aparecer inteira, mesmo se o jogador
## já tiver feito a ação. Evita mensagens piscando.
@export var min_time: float = 1.5
## Se o jogador não completar em X segundos, avança sozinho (modos ACTION e MANUAL). 0 = espera pra sempre.
@export var timeout: float = 0.0


## Texto final que vai pra caixa (com o [right], se ligado).
func get_text() -> String:
	return ("[right]" if align_right else "") + message


## Esconde no Inspector os campos que não valem pro modo escolhido.
func _validate_property(property: Dictionary) -> void:
	var prop: String = property.name
	var hide := false
	match prop:
		"required_action", "required_amount":
			hide = complete_when != CompleteWhen.ACTION
		"wait_time":
			hide = complete_when != CompleteWhen.TIME
		"timeout":
			hide = complete_when != CompleteWhen.ACTION and complete_when != CompleteWhen.MANUAL
	if hide:
		property.usage &= ~PROPERTY_USAGE_EDITOR
