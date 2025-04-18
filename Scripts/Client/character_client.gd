class_name CharacterClient extends Node

@onready var camera : PackedScene = preload("res://Scenes/Objects/camera.tscn")
@onready var cursor_dot : PackedScene = preload("res://Scenes/Objects/CursorDot.tscn");
@onready var character_network : CharacterNetwork = get_parent()

var my_camera : Camera3D
var my_body : PlayerCharacterBody
var current_cursor_dot : MeshInstance3D = null

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	print("spawning the client %s" % character_network.owner_id)
	character_network.on_owner_changed.connect(_on_ownership_changed)
	character_network.on_target_recieved.connect(_on_target_recieved)
	my_body = character_network.my_body
	
	if !is_instance_valid(my_body): return
	
	my_body.navigation_agent.navigation_finished.connect(_on_arrived_at_target)
	
	if !character_network._is_owner(): return
	
	my_camera = camera.instantiate()
	my_body.add_child(my_camera)

func _input(event: InputEvent) -> void:
	if !character_network._is_owner() || !is_instance_valid(my_camera):
		return
	
	if event is InputEventMouseButton && event.is_pressed():
		if event.button_index != MOUSE_BUTTON_LEFT:
			return
		var mousePos = get_viewport().get_mouse_position()
		var ray_origin = my_camera.project_ray_origin(mousePos)
		var ray_end = ray_origin + my_camera.project_ray_normal(mousePos) * 5000
		
		character_network._send_input_ray.rpc_id(1, ray_origin, ray_end)
		
		var space_state = my_body.get_world_3d().direct_space_state
		var intersection = space_state.intersect_ray(
			PhysicsRayQueryParameters3D.create(ray_origin, ray_end))
			
		if !intersection.is_empty():
			my_body.set_movement_target(intersection.position)
			
			if current_cursor_dot != null:
				current_cursor_dot.queue_free()
				
			current_cursor_dot = cursor_dot.instantiate()
			get_node("/root").add_child(current_cursor_dot)
			current_cursor_dot.position = intersection.position
		

func _on_ownership_changed(old_owner : int, new_owner : int):
	if new_owner == character_network.network_manager.network_id:
		my_camera = camera.instantiate()
		add_child(my_camera)
	elif old_owner == character_network.network_manager.network_id:
		my_camera.queue_free()
		my_camera = null

func _on_arrived_at_target():
	if current_cursor_dot != null:
		current_cursor_dot.queue_free()

func _on_target_recieved(target : Vector3):
	my_body.set_movement_target(target)
