class_name NetworkManager extends Node

@export var networker : Networker
@export var max_clients : int = 4

var connected_player_data : Array[ConnectedPlayerData] = []
var network_id : int
var is_server : bool = false
var network_started : bool = false
var current_object_id_number = 0

var validate_request_spawn_callable : Callable
var validate_spawn_callable : Callable

## Emitted when the server has started or this client has connected to the server
signal on_server_started

func _create_server():
	multiplayer.multiplayer_peer = networker.host()
	
	if multiplayer.multiplayer_peer == null: return
	
	connected_player_data.append(_create_data(1, "server"))
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	network_started = true
	is_server = multiplayer.is_server()
	on_server_started.emit()
	network_id = multiplayer.get_unique_id()

func _connect_client():
	multiplayer.multiplayer_peer = networker.connect_client()
	
	if multiplayer.multiplayer_peer == null: return
	
	multiplayer.connected_to_server.connect(_on_connected_to_server)

func _on_peer_connected(peer_id):
	if !is_server: return
	
	for player in connected_player_data:
		if !is_instance_valid(player):
			connected_player_data.erase(player)
			continue
		
		if player.network_id == peer_id:
			for network_object in player.players_objects:
				if !is_instance_valid(network_object):
					continue
				network_object._destroy_network_object.rpc()
			connected_player_data.erase(player)
			continue
			
		if connected_player_data.size() >= max_clients:
			multiplayer.multiplayer_peer.refuse_new_connections = true
		
		for network_object in player.players_objects:
			if network_object.resource_path.is_empty():
				network_object._initialize_network_object.rpc_id(peer_id, network_object.object_id,
				 network_object.owner_id,
				 network_object._get_transforms())
			elif ResourceLoader.exists(network_object.resource_path):
				_network_spawn_object.rpc_id(peer_id,
				network_object.owner_id,
				network_object.spawn_args
				)
				network_object._initialize_network_object.rpc_id(peer_id, network_object.object_id,
				 network_object.owner_id,
				 network_object._get_transforms())
	
	connected_player_data.append(_create_data(peer_id, "client"))
	print("%s connected" % peer_id)
	

func _on_peer_disconnected(peer_id):
	var disconnected_player : ConnectedPlayerData
	for player in connected_player_data:
		print(player.network_id)
		if player.network_id == peer_id:
			disconnected_player = player
			break;
	
	if !is_instance_valid(disconnected_player):
		print("no disconnected player object")
		return 
		
	for network_object in disconnected_player.players_objects:
		network_object._destroy_network_object.rpc()
		
	connected_player_data.erase(disconnected_player)
	
	if connected_player_data.size() < max_clients:
			multiplayer.multiplayer_peer.refuse_new_connections = false

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
	if !is_instance_valid(network_object):
		return
	
	if !multiplayer.is_server() && network_object.owner_id != network_id:
		return
	
	if is_server:
		network_object.object_id = current_object_id_number
		current_object_id_number += 1
		network_object._initialize_network_object.rpc(network_object.object_id,
		 network_object.owner_id,
		 network_object._get_transforms())
	
	for player in connected_player_data:
		if player.network_id != network_object.owner_id:
			continue
		
		if player.players_objects.has(network_object):
			print("player already owns this object")
			return
		
		player.players_objects.append(network_object)
		
	print("added network object to %s" % network_object.owner_id)

func _switch_network_object_owner(new_owner : int, network_object : NetworkObject):
	if !is_instance_valid(network_object):
		return
		
	for player in connected_player_data:
		if player.network_id == network_object.owner_id:
			if player.players_objects.has(network_object):
				player.players_objects.erase(network_object)
		if player.network_id == new_owner:
			player.players_objects.append(network_object)
			
	print("switched network object")

func _remove_network_object(network_object : NetworkObject):
	for player in connected_player_data:
		if player.network_id == network_object.owner_id:
			if player.players_objects.has(network_object):
				player.players_objects.erase(network_object)
				return

#overridable function
func _spawn_object(owner_id : int, spawn_args : Dictionary):
	var resource_path : String = spawn_args["resource_path"]
	
	var obj = load(resource_path).instantiate()
	
	if !is_instance_valid(obj):
		push_error("Failed to instantiate: %s" % resource_path)
		return
	
	if obj is NetworkObject:
		obj.resource_path = resource_path
		obj.owner_id = owner_id
		obj.spawn_args = spawn_args
	
	get_tree().current_scene.add_child(obj)
	
func _request_spawn_helper(
	resource_path : String,
	args : Dictionary = {}):
	
	if !resource_path.begins_with("res://"):
		push_error("Invalid resource path %s" % resource_path)
		return
	
	var dict := {
		"resource_path" : resource_path,
		"args" : args
	}
	
	if !ResourceLoader.exists(resource_path) || !resource_path.begins_with("res://"):
		push_error("Invalid resource path %s" % resource_path)
		return
	
	_request_spawn_object.rpc_id(1, dict)

@rpc("any_peer", "call_local", "reliable", 10)
func _request_spawn_object(spawn_args : Dictionary):
	var requester_id = multiplayer.get_remote_sender_id()
	
	if !spawn_args.has("resource_path"):
		push_warning("No resource path provided")
		return
	
	var resource_path = spawn_args["resource_path"]
	
	if !ResourceLoader.exists(resource_path) || !resource_path.begins_with("res://"):
		push_error("Invalid resource path %s" % resource_path)
		return
	
	if resource_path is not String:
		push_warning("either resource_path(%s) is not a String" % resource_path)
		return
	
	
	if validate_request_spawn_callable:
		if validate_request_spawn_callable.call(requester_id, spawn_args):
			_network_spawn_object.rpc(requester_id, spawn_args)
	else:
		_network_spawn_object.rpc(requester_id, spawn_args)
	

@rpc("authority", "call_local", "reliable", 10)
func _network_spawn_object(
	owner_id : int,
	spawn_args : Dictionary):
	
	var resource_path = spawn_args["resource_path"]
	
	if resource_path is not String:
		push_warning("either resource_path(%s) is not a String" % resource_path)
		return
	
	if !ResourceLoader.exists(resource_path) || !resource_path.begins_with("res://"):
		push_error("Invalid resource path %s" % resource_path)
		return
	
	if validate_spawn_callable:
		if validate_spawn_callable.call(owner_id, spawn_args):
			_spawn_object(owner_id, spawn_args)
	else:
		_spawn_object(owner_id, spawn_args)
