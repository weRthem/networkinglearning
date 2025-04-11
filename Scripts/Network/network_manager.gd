extends Node

class_name NetworkManager

@export var ip : String = "127.0.0.1";
@export var port : int = 9999;
@export var status_text : RichTextLabel

var enet = ENetMultiplayerPeer.new();
var test_func : Callable;

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	var args : PackedStringArray = OS.get_cmdline_args()
	
	test_func = Callable(_dis_test)
	
	if args.has("server"):
		_create_server()
	else:
		_connect_client()

func _create_server():
	enet.create_server(port)
	multiplayer.multiplayer_peer = enet
	multiplayer.peer_connected.connect(_on_peer_connected)
	if status_text:
		status_text.clear()
		status_text.add_text("server")

func _connect_client():
	enet.create_client(ip, port)
	multiplayer.multiplayer_peer = enet;
	multiplayer.connected_to_server.connect(_on_connected_to_server);
	if status_text:
		status_text.clear()
		status_text.add_text("client")

func _on_peer_connected(peer_id):
	if test_func:
		test_func.call()
	print("%s connected" % peer_id)

func _on_connected_to_server():
	print("connected to server")

func _dis_test():
	print("it werk")
