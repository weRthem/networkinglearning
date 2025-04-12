extends Node

class_name NetworkObject

@onready var network_manager : NetworkManager = get_node("/root/Network_Manager")

var owner_id : int = 1;
var has_initialized : bool = false
var on_network_ready_callable : Callable
var validate_ownership_change_callable : Callable

signal on_owner_changed(old_owner, new_owner)
signal on_network_ready()
signal on_network_destroy()

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	on_network_ready_callable = Callable(_on_network_ready)
	if !network_manager.network_started:
		network_manager.on_server_started.connect(on_network_ready_callable)
	else:
		_on_network_ready()

func _on_network_ready():
	if has_initialized:
		return
	
	has_initialized = true
	network_manager.register_network_object(self)
	on_network_ready.emit()
	
	if !network_manager.is_server:
		print(network_manager.network_id)
		_request_ownership.rpc_id(1)
	
	if network_manager.on_server_started.is_connected(on_network_ready_callable):
		network_manager.on_server_started.disconnect(on_network_ready_callable)

func _is_owner() -> bool:
	if owner_id == network_manager.network_id:
		return true
	
	return false

@rpc("any_peer", "reliable", "call_local")
func _request_ownership():
	var sender_id : int = network_manager.multiplayer.get_remote_sender_id()
	print("requested ownership change by %s" % sender_id)
	
	if !network_manager.is_server:
		return
	
	if owner_id == sender_id:
		return
	
	if validate_ownership_change_callable:
		if validate_ownership_change_callable.call():
			_change_owner.rpc(sender_id)
	else:
		_change_owner.rpc(sender_id)

@rpc("authority", "call_local", "reliable")
func _change_owner(new_owner : int):
	if network_manager.is_server || new_owner == network_manager.network_id:
		network_manager._switch_network_object_owner(new_owner, self)
	set_multiplayer_authority(new_owner)
	on_owner_changed.emit(owner_id, new_owner)
	print("old owner: %s new owner: %s" % [owner_id, new_owner])
	owner_id = new_owner
