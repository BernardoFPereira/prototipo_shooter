extends Node

@onready var main_menu = $CanvasLayer/MainMenu
@onready var adress_entry = $CanvasLayer/MainMenu/MarginContainer/VBoxContainer/AdressEntry
@onready var weapon_spawner = $WeaponsSpawner
@onready var rifle_spawn_point = $RifleSpawnPoint
@onready var pistol_spawn_point = $PistolSpawnPoint

const BATTLE_RIFLE = preload("res://weapons/battle_rifle.tscn")
const PISTOL = preload("res://weapons/pistol.tscn")
const QUAD_GUN = preload("res://weapons/quad_gun.tscn")
const UNNARMED = preload("res://weapons/unnarmed.tscn")
const Player = preload("res://MP_Player.tscn")
const PORT = 9999

var enet_peer = ENetMultiplayerPeer.new()

func _on_host_button_pressed():
	main_menu.hide()
	
	enet_peer.create_server(PORT)
	multiplayer.multiplayer_peer = enet_peer
	multiplayer.peer_connected.connect(add_player)
	
	add_player(multiplayer.get_unique_id())
	
	spawn_weapon(3, rifle_spawn_point.position)
	spawn_weapon(1, pistol_spawn_point.position)

func _on_join_button_pressed():
	main_menu.hide()
	
	enet_peer.create_client("localhost", PORT)
	multiplayer.multiplayer_peer = enet_peer

func add_player(peer_id):
	var player = Player.instantiate()
	player.name = str(peer_id)
	add_child(player)

func spawn_weapon(index: int, position: Vector3):
	var scene_path: String = weapon_spawner.get_spawnable_scene(index)
	var scene: PackedScene = load(scene_path)
	var weapon_instance = weapon_spawner.spawn(scene)
	weapon_instance.position = position

