class_name NetworkObject extends Node

## grabs the autoloaded network manager
@onready var network_manager : NetworkManager = get_node("/root/Network_Manager")

## The network id of the connection that owns this object
var owner_id : int = 1
## the id of this object. Increases in order 0 to N
var object_id : int = -1
## is true if this network object has started its initialization
var has_initialized : bool = false

## The resource path that this network object was loaded from
var resource_path : String

## The arguments that this network object used to spawn 
## e.g. position, rotation, color
var spawn_args : Dictionary

## Gets called on the server when a player requests ownership of an object
##
## @tutorial validate_request_ownership(sender_id : int) -> bool:
var validate_ownership_change_callable : Callable

## Gets emitted when the network object finishes initializing
signal on_network_ready()

## Gets called on the server when a player requests to destroy an object
##
## @tutorial validate_request_destroy(sender_id : int) -> bool:
var validate_destroy_request_callable : Callable

## Gets emitted when the server changes the owner of an object
##
## @tutorial _on_ownership_change(old_owner_id : int, new_owner_id):
signal on_owner_changed(old_owner : int, new_owner : int)


## Gets emitted when the server destroys a network object
signal on_network_destroy()

func _ready() -> void:
	if !network_manager.network_started:
		network_manager.on_server_started.connect(_on_network_start)
	else:
		_on_network_start()
		

## Do not override. Used for internal logic
func _on_network_start():
	if has_initialized:
		return
	
	has_initialized = true
	network_manager.register_network_object(self)
	
	if network_manager.on_server_started.is_connected(_on_network_start):
		network_manager.on_server_started.disconnect(_on_network_start)

## Returns true if this client owns this network object
func _is_owner() -> bool:
	if owner_id == network_manager.network_id:
		return true
	
	return false

## returns all children transforms of this network object as a dictionary
func _get_transforms() -> Dictionary:
	var dict : Dictionary = {}
	
	var children := _get_all_children_transforms(self)
	
	for child in children:
		dict.set(child.get_path(), child.transform)
	
	return dict

## returns all immediate child transforms of a node as an array
func _get_all_children_transforms(node : Node) -> Array[Node]:
	var nodes : Array[Node] = []

	for N in node.get_children():

		if N.get_child_count() > 0:
			if N is Node2D || N is Node3D:
				nodes.append(N)

			nodes.append_array(_get_all_children_transforms(N))
		elif N is Node2D || N is Node3D:
			nodes.append(N)

	return nodes

## Requests ownership of this network object from the server. 
## 
## @tutorial _request_ownership.rpc_id(1)
@rpc("any_peer", "reliable", "call_local", 10)
func _request_ownership():
	var sender_id : int = network_manager.multiplayer.get_remote_sender_id()
	print("requested ownership change by %s" % sender_id)
	
	if !network_manager.is_server:
		return
	
	if owner_id == sender_id:
		return
	
	if validate_ownership_change_callable:
		if validate_ownership_change_callable.call(sender_id):
			_change_owner.rpc(sender_id)
	else:
		_change_owner.rpc(sender_id)

## Called from the server when it changes the ownership of this network object
@rpc("authority", "call_local", "reliable", 10)
func _change_owner(new_owner : int):
	if network_manager.is_server || new_owner == network_manager.network_id:
		network_manager._switch_network_object_owner(new_owner, self)
	on_owner_changed.emit(owner_id, new_owner)
	print("old owner: %s new owner: %s" % [owner_id, new_owner])
	owner_id = new_owner

## does the preliminary setup of an object such as syncing its position when
## spawned or connected to the network
@rpc("authority", "call_local", "reliable", 10)
func _initialize_network_object(objects_id : int, owners_id : int, transforms : Dictionary):
	if !network_manager.is_server:
		self.object_id = objects_id
		self.owner_id = owners_id
		
		print("setting transforms")
		
		var children_transforms := _get_all_children_transforms(self)
		
		for child in children_transforms:
			var child_path = child.get_path()
			if transforms.has(child_path):
				child.transform = transforms[child_path]
	
	print("calling on network ready")
	on_network_ready.emit()
	

## Used to request the server to destroy this network object
@rpc("any_peer", "call_local", "reliable", 10)
func _request_destroy_network_object():
	var sender_id : int = network_manager.multiplayer.get_remote_sender_id()
	if validate_destroy_request_callable:
		if validate_destroy_request_callable.call(sender_id):
			_destroy_network_object.rpc()
	else:
		_destroy_network_object.rpc()

## Called by the server when it want's to destroy this network object
@rpc("authority", "call_local", "reliable", 10)
func _destroy_network_object():
	if _is_owner() || network_manager.is_server:
		network_manager._remove_network_object(self)
	
	on_network_destroy.emit()
	queue_free()
