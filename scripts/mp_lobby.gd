extends Node

@onready var multiplayer_menu = $UI/Multiplayer
@onready var room_id = $UI/Multiplayer/MarginContainer/VBoxContainer/RoomID
@onready var username_field = $UI/Multiplayer/MarginContainer/VBoxContainer/Username
@onready var multiplayer_spawner = $MultiplayerSpawner

const BATTLE_RIFLE = preload("res://weapons/battle_rifle.tscn")
const PISTOL = preload("res://weapons/pistol.tscn")
const QUAD_GUN = preload("res://weapons/quad_gun.tscn")
const UNNARMED = preload("res://weapons/unnarmed.tscn")
const PLAYER_SCENE = preload("res://MP_Player.tscn")


var peer = NodeTunnelPeer.new()
var connected_players: Dictionary = {}

var peer_username: String

func _ready():
	peer.error.connect(
		func(error_msg):
			push_error("NodeTunnel Error: ", error_msg)
	)
	
	peer.connect_to_relay("oriean.space:4224", "kwopmaderer777")
	#peer.connect_to_relay("us_east.nodetunnel.io:8080", "kowqnsa2y2l4fot")
	multiplayer.multiplayer_peer = peer
	
	print("Authenticating...")
	await peer.authenticated
	print("Authenticated!")
	
	multiplayer_spawner.spawn_function = _spawn_player

func _on_host_button_pressed():
	multiplayer_menu.hide()
	
	var entered = username_field.text.strip_edges()
	peer_username = entered if not entered.is_empty() else "Host"
	
	connected_players[multiplayer.get_unique_id()] = peer_username
	
	peer.host_room(false, "")
	print("Hosting room...")
	await peer.room_connected
	print("Connected to room: ", peer.room_id)
	
	
	room_id = peer.room_id
	
	DisplayServer.clipboard_set(str(peer.room_id))
	
	#multiplayer.peer_connected.connect(
		#func(peer_id):
			#multiplayer_spawner.spawn(multiplayer.get_unique_id())
			##add_player(peer_id)
	#)
	
	multiplayer_spawner.spawn({"peer_id": multiplayer.get_unique_id(), "username": peer_username})
	#add_player(multiplayer.get_unique_id())

func _on_join_button_pressed():
	var entered = username_field.text.strip_edges()
	peer_username = entered if not entered.is_empty() else "Player"
	
	peer.join_room(room_id.text)
	
	connected_players[multiplayer.get_unique_id()] = peer_username
	
	print("Joining room...")
	await peer.room_connected
	print("Connected to room: ", room_id.text)
	
	multiplayer_menu.hide()
	
	_send_username.rpc_id(1, peer_username)

#func add_player(peer_id):
	#var player = Player.instantiate()
	#player.name = str(peer_id)
	#player.username = peer_username
	##add_child(player)
	#return player

func _spawn_player(data: Dictionary) -> Node:
	var peer_id: int = data["peer_id"]
	var username: String = data.get("username", "Player" + str(peer_id))
	
	var player = PLAYER_SCENE.instantiate()
	player.name = str(peer_id)
	player.set_multiplayer_authority(peer_id)
	player.username = username
	
	print("Spawned player ", peer_id, " with name '", username, "' on peer ", multiplayer.get_unique_id())
	return player

@rpc("any_peer", "reliable")
func _send_username(desired: String):
	if not multiplayer.is_server():
		return
		
	var sender = multiplayer.get_remote_sender_id()
	var clean = desired.strip_edges().substr(0, 20)
	if clean == "": clean = "Anon" + str(sender)
	
	multiplayer_spawner.spawn({"peer_id": sender, "username": clean})

#func spawn_weapon(index: int, position: Vector3):
	#var scene_path: String = weapon_spawner.get_spawnable_scene(index)
	#var scene: PackedScene = load(scene_path)
	#var weapon_instance = weapon_spawner.spawn(scene)
	#weapon_instance.position = position
