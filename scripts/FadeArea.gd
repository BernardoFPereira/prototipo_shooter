extends Area3D


# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass


func _on_body_entered(body):
	if body is Player:
		var player = body as Player
		if player.state != player.PlayerStates.DECOMPRESSING:
			return
		player.finale_canvas.visible = true
		player.end_anim_player.play("fade_to_end")
	pass # Replace with function body.
