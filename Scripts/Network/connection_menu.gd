extends Control

@onready var ip_field : LineEdit = get_node("IP Field")
@onready var port_field : LineEdit = get_node("Port Field")
@onready var connect_btn : Button = get_node("ConnectBtn")
@onready var host_btn : Button = get_node("HostBtn")
@onready var network_manager : NetworkManager = get_node("/root/Network_Manager")
@onready var text : RichTextLabel = get_node("RichTextLabel")

func _ready() -> void:
	network_manager.on_server_started.connect(_on_connected_to_server)
	connect_btn.button_up.connect(_connect)
	host_btn.button_up.connect(_host)

func _on_connected_to_server():
	text.clear()
	var status_text = "client"
	if network_manager.is_server:
		status_text = "server"
	
	text.add_text(status_text)
	hide()

func _host():
	network_manager.port = port_field.text as int
	network_manager._create_server()

func _connect():
	network_manager.ip = ip_field.text
	network_manager.port = port_field.text as int
	
	network_manager._connect_client()
