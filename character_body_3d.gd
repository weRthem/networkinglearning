class_name PlayerCharacterBody extends CharacterBody3D

@export var movement_speed: float = 4.0
@onready var navigation_agent: NavigationAgent3D = get_node("NavigationAgent3D")
@onready var body: Node3D = get_node("Body")
@onready var body_ap: AnimationPlayer = get_node("Body/AnimationPlayer")

func _ready() -> void:
	navigation_agent.velocity_computed.connect(Callable(_on_velocity_computed))
	navigation_agent.target_reached.connect(Callable(_on_arrived_at_target))

func set_movement_target(movement_target: Vector3):
	navigation_agent.set_target_position(movement_target)
	body_ap.play("walk")

func _physics_process(delta):
	if navigation_agent.is_navigation_finished(): return
	
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
