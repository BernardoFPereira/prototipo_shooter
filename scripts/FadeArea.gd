extends Area3D

func _on_body_entered(body):
	if body is Player:
		var player = body as Player
		if player.state != player.PlayerStates.DECOMPRESSING:
			return
		player.finale_canvas.visible = true
		player.end_anim_player.play("fade_to_end")
		await get_tree().create_timer(2).timeout
		player.end_anim_player.play("show_title")
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
