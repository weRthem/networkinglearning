class_name CharacterServer extends Node

@onready var character_network : CharacterNetwork = get_parent()

var my_body : PlayerCharacterBody 

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	character_network.on_player_input_recieved.connect(_on_player_input_recieved)
	character_network.validate_input_ray_callable
	
	my_body = character_network.my_body
	
	

func validate_input_ray(origin : Vector3, end : Vector3) -> bool:
	return false

func _on_player_input_recieved(origin : Vector3, end : Vector3):
	var space_state = my_body.get_world_3d().direct_space_state
	var intersection = space_state.intersect_ray(
		PhysicsRayQueryParameters3D.create(origin, end))
		
	if !intersection.is_empty():
		character_network._set_target.rpc(intersection.position)
