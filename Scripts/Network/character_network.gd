class_name CharacterNetwork extends NetworkObject

@export var spawn_client_on_server : bool = false

@onready var my_body : PlayerCharacterBody = get_node("CharacterBody3D")

var validate_input_ray_callable : Callable

## Called on server when player input is recieved
## @tutorial: send_input_ray(ray_origin : Vector3, ray_end : Vector3)
signal on_player_input_recieved

## Called on the clients and server after the server has validated the inputs
## @tutorial: set_target(target : Vector3)
signal on_target_recieved

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	print("child ready")
	on_network_ready.connect(_on_network_ready)
	super()

func _on_network_ready():
	print("on network ready")
	if network_manager.is_server:
		var server_script = CharacterServer.new()
		add_child(server_script)
		
		if spawn_client_on_server:
			var client_script = CharacterClient.new()
			add_child(client_script)
	else:
		var client_script = CharacterClient.new()
		add_child(client_script)
	

@rpc("any_peer", "call_local", "unreliable", 0)
func _send_input_ray(ray_origin : Vector3, ray_end : Vector3):
	if network_manager.multiplayer.get_remote_sender_id() != owner_id: return
	
	if validate_input_ray_callable:
		if validate_input_ray_callable.call(ray_origin, ray_end):
			on_player_input_recieved.emit(ray_origin, ray_end)
	else:
		on_player_input_recieved.emit(ray_origin, ray_end)

@rpc("authority", "call_local", "unreliable", 0)
func _set_target(target : Vector3):
	on_target_recieved.emit(target)
