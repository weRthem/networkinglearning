extends Control

@onready var network_manager : NetworkManager = get_node("/root/Network_Manager")

func _ready() -> void:
	%Girl1.pressed.connect(func():
		network_manager._request_spawn_helper("res://Scenes/Objects/girl_1.tscn")
		hide()
	)
	%Girl2.pressed.connect(func():
		network_manager._request_spawn_helper("res://Scenes/Objects/girl_2.tscn")
		hide()
	)
	%Guy1.pressed.connect(func():
		network_manager._request_spawn_helper("res://Scenes/Objects/guy_1.tscn")
		hide()
	)
	%Guy2.pressed.connect(func():
		network_manager._request_spawn_helper("res://Scenes/Objects/guy_2.tscn")
		hide()
	)
