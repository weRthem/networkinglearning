extends CharacterBody3D

@export var movement_speed: float = 4.0
@onready var navigation_agent: NavigationAgent3D = get_node("NavigationAgent3D")
@onready var body: Node3D = get_node("Body")
@onready var body_ap: AnimationPlayer = get_node("Body/AnimationPlayer")
@onready var network_manager: NetworkManager = get_node("/root/Network_Manager");
@export var cursor_dot : PackedScene;

var current_cursor_dot : MeshInstance3D = null

func _ready() -> void:
	navigation_agent.velocity_computed.connect(Callable(_on_velocity_computed))
	navigation_agent.target_reached.connect(Callable(_on_arrived_at_target))

@rpc("authority", "call_local", "unreliable")
func set_movement_target(movement_target: Vector3):
	navigation_agent.set_target_position(movement_target)
	body_ap.play("walk")

func _physics_process(delta):
	if navigation_agent.is_navigation_finished():
		return
	var next_path_position: Vector3 = navigation_agent.get_next_path_position()
	var new_velocity: Vector3 = global_position.direction_to(next_path_position) * movement_speed
	
	next_path_position.y = 0
	body.look_at(next_path_position)
	body.rotate_y(3.14)
	
	if navigation_agent.avoidance_enabled:
		navigation_agent.set_velocity(new_velocity)
	else:
		_on_velocity_computed(new_velocity)

func _on_velocity_computed(safe_velocity: Vector3):
	velocity = safe_velocity
	move_and_slide()

func _on_arrived_at_target():
	body_ap.play("idle")
	if current_cursor_dot != null:
		current_cursor_dot.queue_free()

func _input(event: InputEvent) -> void:
	if !network_manager.multiplayer.is_server():
		return
	
	if event is InputEventMouseButton && event.is_pressed():
		if event.button_index != MOUSE_BUTTON_LEFT:
			return
		var mousePos=get_viewport().get_mouse_position()
		var camera = get_viewport().get_camera_3d()
		var ray_origin = camera.project_ray_origin(mousePos)
		var ray_end = ray_origin + camera.project_ray_normal(mousePos) * 5000
		
		var space_state = get_world_3d().direct_space_state
		var intersection = space_state.intersect_ray(
			PhysicsRayQueryParameters3D.create(ray_origin, ray_end))
			
		if !intersection.is_empty():
			set_movement_target.rpc(intersection.position)
			
			if current_cursor_dot != null:
				current_cursor_dot.queue_free()
				
			current_cursor_dot = cursor_dot.instantiate()
			get_node("/root").add_child(current_cursor_dot)
			current_cursor_dot.position = intersection.position
		
