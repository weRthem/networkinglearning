class_name NetworkManager extends Node

#region variables
## The networker for the chosen MultiplayerPeer
@export var networker : Networker
@export var network_ticks_on_seperate_thread : bool = false

## Stores all the connected players IDs and owned objects
var connected_player_data : Array[ConnectedPlayerData] = []
## The network ID of this client/server
var network_id : int
## If true this is the server. This just simplifies getting that information
var is_server : bool = false
## If the network hasn't started this will be false and no networky things will happen
var network_started : bool = false
## The current tally of object IDs that have been assigned
var current_object_id_number = 0

var tick_thread : Thread
#endregion

#region validators
## Called on server when a client requests to spawn an item.
## This is where you should validate the path so that no hacking happens.
## Should probably limit the network spawnable items to something like 
## res://Scenes/Objects/NetworkObjects
## @tutorial _validate_request_spawn(requester_id : int, )
var validate_request_spawn_callable : Callable
## Called on the client and the server when a object is trying to spawn
## Should just be used to ensure the validity of the spawn for each client 
## in case they are missing some resources
var validate_spawn_callable : Callable
#endregion

#region signals
## Emitted when the server has started or this client has connected to the server
signal on_server_started

## Emitted every network tick
signal on_tick(tick_number : int)
#endregion

#region public functions

## Call to host a server using the selected networker
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

## Call to connect a client to a server using the selected Networker
func _connect_client():
	multiplayer.multiplayer_peer = networker.connect_client()
	
	if multiplayer.multiplayer_peer == null: return
	
	multiplayer.connected_to_server.connect(_on_connected_to_server)

## Adds a network object to the owner players connected_player_data
## if the object is already owned by another player/server call 
## _switch_network_object_owner(new_owner : int, network_object : NetworkObject)
## instead
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

## Switches the owner of a network object and moves it to the correct ConnectedPlayerData.
## If the object is unowned call 
## register_network_object(network_object : NetworkObject) instead
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

## removes a network object from the owning players ConnectedPlayerData
func _remove_network_object(network_object : NetworkObject):
	for player in connected_player_data:
		if player.network_id == network_object.owner_id:
			if player.players_objects.has(network_object):
				player.players_objects.erase(network_object)
				return

## if set to true the network manager will refuse all new connections 
## even if below the max_clients. If set to false the network manager will allow
## new connections up to the max_clients number and then refuse once that is reached
func _refuse_new_connections(should_refuse : bool):
	multiplayer.multiplayer_peer.refuse_new_connections = should_refuse

## returns the current state of whether the network manager is accepting new 
## connections 
func _get_refuse_connections() -> bool:
	return multiplayer.multiplayer_peer.refuse_new_connections

## Call to disconnect from the server or shut down the server
func _disconnect():
	multiplayer.multiplayer_peer = null
	connected_player_data = []
	network_id = 0
	current_object_id_number = 0
	is_server = false
	network_started = false

#endregion

#region network signal callbacks

## Called on server when a new client connects to the server
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
	

## Called on server when a client disconnects
## Used to clean up the players data
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
		if !network_object.set_server_to_owner_on_disconnect:
			network_object._destroy_network_object.rpc()
		else:
			network_object._change_owner(1)
		
	connected_player_data.erase(disconnected_player)

## Called on clients when a connection to the server is established
func _on_connected_to_server():
	network_id = multiplayer.get_unique_id()
	connected_player_data.append(_create_data(network_id, "client"))
	print("connected to server with id %s" % network_id)
	network_started = true
	on_server_started.emit()

#endregion

#region helper functions
## created connected player data and then returns it
func _create_data(player_id : int, player_name : String) -> ConnectedPlayerData:
	var server_data : ConnectedPlayerData = ConnectedPlayerData.new()
	server_data.network_id = player_id
	server_data.player_name = player_name
	return server_data

## Helps with creating a spawn request in the desired format. Not needed, but useful
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
	
	if _verify_spawn_path(resource_path):
		push_error("Invalid resource path %s" % resource_path)
		return
	
	_request_spawn_object.rpc_id(1, dict)

## Just does a VERY basic validation of the spawn path for a object. 
## More validation should be down with the 
## _validate_request_spawn_callable(owner_id : int, spawn_args : Dictionary)
## in a production game. Fine as is for testing purposes
func _verify_spawn_path(resource_path : String) -> bool:
	return !ResourceLoader.exists(resource_path) || !resource_path.begins_with("res://")

#endregion

#region overridable functions
## Override this function to add custom spawn behaviour. 
## Such as adding a spawn arg "position" to choose the spawning position
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

#endregion

#region rpc functions
## Sends a request to spawn an object from a client to the server. 
## Can add custom spawn_args such as "position"
## You will need to override the _spawn_object(owner_id : int, spawn_args : Dictionary)
## function to use them.
@rpc("any_peer", "call_local", "reliable", 2)
func _request_spawn_object(spawn_args : Dictionary):
	var requester_id = multiplayer.get_remote_sender_id()
	
	if !spawn_args.has("resource_path"):
		push_warning("No resource path provided")
		return
	
	var resource_path = spawn_args["resource_path"]
	
	if _verify_spawn_path(resource_path):
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
	

## Called by the server to spawn a object
@rpc("authority", "call_local", "reliable", 2)
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

#endregion
