extends Node

var player_scene: PackedScene = preload("uid://dgn62wgeteqw1")

@onready var multiplayer_spawner = $MultiplayerSpawner
@onready var player_spawn_position = $PlayerSpawnPosition

func _ready():
	multiplayer_spawner.spawn_function = func(data):
		var player = player_scene.instantiate() as Player
		player.name = str(data.peer_id)
		player.input_multiplayer_authority = data.peer_id
		player.transform = player_spawn_position.transform
		return player
	
	peer_ready.rpc_id(1)

@rpc("any_peer", "call_local", "reliable")
func peer_ready():
	var sender_id = multiplayer.get_remote_sender_id()
	multiplayer_spawner.spawn({ "peer_id": sender_id })
