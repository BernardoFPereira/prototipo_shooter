extends Control

#const PORT := 8081

@onready var play_button = $VBoxContainer/PlayButton
@onready var quit_button = $VBoxContainer/QuitButton

var level_scene = preload("uid://yusjlgf3x7bm")

#var peer = NodeTunnelPeer.new()
#var connected_players: Dictionary = {}
#var peer_username: String

func _ready() -> void:
	play_button.pressed.connect(_on_play_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	#peer.error.connect(
		#func(error_msg):
			#push_error("NodeTunnel Error: ", error_msg)
	#)
	#
	##peer.connect_to_relay("us_east.nodetunnel.io:8080", "kowqnsa2y2l4fot")
	#peer.connect_to_relay("oriean.space:4224", "kwopmaderer777")
	#
	#host_button.pressed.connect(_on_host_pressed)
	#join_button.pressed.connect(_on_join_pressed)
	#multiplayer.connected_to_server.connect(_on_connected_to_server)
	#
	#multiplayer.multiplayer_peer = peer
	#
	#print("Authenticating...")
	#await peer.authenticated
	#print("Authenticated!")

func _on_play_pressed() -> void:
	get_tree().change_scene_to_packed(level_scene)
	#var entered = username_field.text.strip_edges()
	#peer_username = entered if not entered.is_empty() else "Host"
	#
	#connected_players[multiplayer.get_unique_id()] = peer_username
	#
	#peer.host_room(false, "")
	#print("Hosting room...")
	#await peer.room_connected
	#print("Connected to room: ", peer.room_id)
	#
	#room_id = peer.room_id
	#
	#DisplayServer.clipboard_set(str(peer.room_id))
	
	#multiplayer.multiplayer_peer = peer
	

func _on_quit_pressed() -> void:
	get_tree().quit(0)
	#var entered = username_field.text.strip_edges()
	#peer_username = entered if not entered.is_empty() else "Player"
	#
	#peer.join_room(room_id.text)
	#
	#connected_players[multiplayer.get_unique_id()] = peer_username
	#
	#print("Joining room...")
	#await peer.room_connected
	#print("Connected to room: ", room_id.text)
	#
	##multiplayer_menu.hide()
	#
	##_send_username.rpc_id(1, peer_username)
	#
	##multiplayer.multiplayer_peer = peer
#
#func _on_connected_to_server() -> void:
	#get_tree().change_scene_to_packed(level_scene)
#
#@rpc("any_peer", "reliable")
#func _send_username(desired: String):
	#if not multiplayer.is_server():
		#return
		#
	#var sender = multiplayer.get_remote_sender_id()
	#var clean = desired.strip_edges().substr(0, 20)
	#if clean == "": clean = "Anon" + str(sender)
	#
	##multiplayer_spawner.spawn({"peer_id": sender, "username": clean})
