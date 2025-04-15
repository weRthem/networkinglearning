extends Node

class_name NetworkObject

@onready var network_manager : NetworkManager = get_node("/root/Network_Manager")

var owner_id : int = 1
var object_id : int = -1
var has_initialized : bool = false
var resource_path : String
var spawn_args : Dictionary

var on_network_ready_callable : Callable

var validate_ownership_change_callable : Callable
var validate_destroy_request_callable : Callable

signal on_owner_changed(old_owner, new_owner)
signal on_network_ready()
signal on_network_destroy()

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	on_network_ready_callable = Callable(_on_network_start)
	if !network_manager.network_started:
		network_manager.on_server_started.connect(on_network_ready_callable)
	else:
		_on_network_start()

func _on_network_start():
	if has_initialized:
		return
	
	has_initialized = true
	network_manager.register_network_object(self)
	
	if network_manager.on_server_started.is_connected(on_network_ready_callable):
		network_manager.on_server_started.disconnect(on_network_ready_callable)

func _is_owner() -> bool:
	if owner_id == network_manager.network_id:
		return true
	
	return false

func _get_transforms() -> Dictionary:
	var dict : Dictionary = {}
	
	var children := _get_all_children_transforms(self)
	
	for child in children:
		dict.set(child.get_path(), child.transform)
	
	return dict

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

@rpc("authority", "call_local", "reliable", 10)
func _change_owner(new_owner : int):
	if network_manager.is_server || new_owner == network_manager.network_id:
		network_manager._switch_network_object_owner(new_owner, self)
	set_multiplayer_authority(new_owner)
	on_owner_changed.emit(owner_id, new_owner)
	print("old owner: %s new owner: %s" % [owner_id, new_owner])
	owner_id = new_owner

@rpc("authority", "call_remote", "reliable", 10)
func _initialize_network_object(object_id : int, owner_id : int, transforms : Dictionary):
	self.object_id = object_id
	self.owner_id = owner_id
	
	print("setting transforms")
	
	var children_transforms := _get_all_children_transforms(self)
	
	for child in children_transforms:
		var child_path = child.get_path()
		if transforms.has(child_path):
			child.transform = transforms[child_path]
	
	on_network_ready.emit()
	

@rpc("any_peer", "call_local", "reliable", 10)
func _request_destroy_network_object():
	var sender_id : int = network_manager.multiplayer.get_remote_sender_id()
	if validate_destroy_request_callable:
		if validate_destroy_request_callable.call(sender_id):
			_destroy_network_object.rpc()
	else:
		_destroy_network_object.rpc()


@rpc("authority", "call_local", "reliable", 10)
func _destroy_network_object():
	if _is_owner() || network_manager.is_server:
		network_manager._remove_network_object(self)
	
	on_network_destroy.emit()
	queue_free()
