extends Node

class_name NetworkManager

@export var ip : String = "127.0.0.1"
@export var port : int = 9999
@export var max_clients : int = 4

var enet = ENetMultiplayerPeer.new();
var connected_player_data : Array[ConnectedPlayerData] = []
var network_id : int
var is_server : bool = false
var network_started : bool = false

signal on_server_started

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	var args : PackedStringArray = OS.get_cmdline_args()
	
	if args.has("server"):
		_create_server()
	else:
		_connect_client()

func _create_server():
	var err : Error = enet.create_server(port)
	
	if err != OK:
		return
	
	multiplayer.multiplayer_peer = enet
	connected_player_data.append(_create_data(1, "server"))
	multiplayer.peer_connected.connect(_on_peer_connected)
	network_started = true
	is_server = multiplayer.is_server()

func _connect_client():
	var err : Error = enet.create_client(ip, port)
	
	if err != OK:
		return
	
	multiplayer.multiplayer_peer = enet;
	multiplayer.connected_to_server.connect(_on_connected_to_server)

func _on_peer_connected(peer_id):
	connected_player_data.append(_create_data(peer_id, "client"))
	print("%s connected" % peer_id)

func _on_connected_to_server():
	network_id = multiplayer.get_unique_id()
	connected_player_data.append(_create_data(network_id, "client"))
	print("connected to server with id %s" % network_id)
	network_started = true
	on_server_started.emit()

func _create_data(player_id : int, player_name : String) -> ConnectedPlayerData:
	var server_data : ConnectedPlayerData = ConnectedPlayerData.new()
	server_data.network_id = player_id
	server_data.player_name = player_name
	return server_data

func register_network_object(network_object : NetworkObject) -> void:
	if !network_object:
		return
	
	if !multiplayer.is_server() && network_object.owner_id != network_id:
		return
	
	for player in connected_player_data:
		if player.network_id != network_object.owner_id:
			continue
		
		if player.players_objects.has(network_object):
			print("player already owns this object")
			return
		
		player.players_objects.append(network_object)
		
	print("added network object")

func _switch_network_object_owner(new_owner : int, network_object : NetworkObject):
	if !network_object:
		return
		
	for player in connected_player_data:
		if player.network_id == network_object.owner_id:
			if player.players_objects.has(network_object):
				player.players_objects.erase(network_object)
		if player.network_id == new_owner:
			player.players_objects.append(network_object)
			
	print("switched network object")
