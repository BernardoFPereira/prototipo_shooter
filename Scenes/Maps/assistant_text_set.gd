extends Area3D

@export var player: Player
@export_multiline var message: String
var text_played: bool = false

func _on_body_entered(body):
	if body == player and !text_played:
		player.avic_animations.play("avic/assistant_popup")
		player.get_message_data("[right]" + message)
		text_played = true
		queue_free()
