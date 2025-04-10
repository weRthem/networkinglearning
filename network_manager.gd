extends RichTextLabel

@export var ip : String = "127.0.0.1";
@export var port : int = 9999;

var enet = ENetMultiplayerPeer.new();

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	if Engine.is_embedded_in_editor():
		_create_server()
	else:
		_connect_client()

func _create_server():
	enet.create_server(port)
	multiplayer.multiplayer_peer = enet
	multiplayer.peer_connected.connect(_on_peer_connected)
	clear()
	add_text("server")

func _connect_client():
	enet.create_client(ip, port)
	multiplayer.multiplayer_peer = enet;
	multiplayer.connected_to_server.connect(_on_connected_to_server);
	clear()
	add_text("client");

func _on_peer_connected(peer_id):
	print("%s connected" % peer_id)
	_log_the_debugs("sent from server")

func _on_connected_to_server():
	print("connected to server")
	_log_the_debugs("sent from client")

@rpc("any_peer", "call_remote", "unreliable", 0)
func _log_the_debugs(log : String):
	print(log);
