class_name APCController
extends CharacterBody3D

enum State { IDLE, FOLLOWING }

@export var target: Node3D
@export var move_speed: float = 3.5
@export var stop_distance: float = 2.0
@export var start_follow_distance: float = 3.2
@export var rotation_speed: float = 8.0

@onready var nav_agent: NavigationAgent3D = $NavigationAgent3D

var current_state: State = State.IDLE
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)
var navigation_ready: bool = false

signal state_changed(new_state: State)

func _ready() -> void:
	add_to_group("apc")
	if nav_agent:
		nav_agent.path_desired_distance = 0.5
		nav_agent.target_desired_distance = stop_distance
	_setup_navigation_map()

func _setup_navigation_map() -> void:
	navigation_ready = false
	# Wait for physics frame to ensure world 3D and navigation map are active
	await get_tree().physics_frame
	
	var world_3d = get_world_3d()
	if world_3d:
		var map_rid = world_3d.get_navigation_map()
		while NavigationServer3D.map_get_iteration_id(map_rid) == 0:
			await get_tree().physics_frame
			
	navigation_ready = true

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta

	# Guard: Keep APC stationary and IDLE until navigation map is fully synchronized
	if not navigation_ready:
		velocity.x = move_toward(velocity.x, 0.0, move_speed * delta * 5.0)
		velocity.z = move_toward(velocity.z, 0.0, move_speed * delta * 5.0)
		move_and_slide()
		return

	if target == null:
		var players = get_tree().get_nodes_in_group("human_player")
		if players.size() > 0:
			target = players[0]

	if target != null:
		_process_locomotion(delta)

	move_and_slide()

func _process_locomotion(delta: float) -> void:
	var dist_to_target = global_position.distance_to(target.global_position)

	# State transition logic with hysteresis buffer
	match current_state:
		State.IDLE:
			if dist_to_target > start_follow_distance:
				_change_state(State.FOLLOWING)
		State.FOLLOWING:
			if dist_to_target <= stop_distance:
				_change_state(State.IDLE)

	# Execute behavior based on current state
	match current_state:
		State.IDLE:
			velocity.x = move_toward(velocity.x, 0.0, move_speed * delta * 5.0)
			velocity.z = move_toward(velocity.z, 0.0, move_speed * delta * 5.0)
		State.FOLLOWING:
			nav_agent.target_position = target.global_position

			if nav_agent.is_navigation_finished():
				velocity.x = move_toward(velocity.x, 0.0, move_speed * delta * 5.0)
				velocity.z = move_toward(velocity.z, 0.0, move_speed * delta * 5.0)
				return

			var next_path_pos = nav_agent.get_next_path_position()
			var dir = global_position.direction_to(next_path_pos)
			dir.y = 0.0
			dir = dir.normalized()

			velocity.x = dir.x * move_speed
			velocity.z = dir.z * move_speed

			# Rotate smoothly toward movement direction
			if dir.length() > 0.1:
				var target_rot = atan2(-dir.x, -dir.z)
				rotation.y = lerp_angle(rotation.y, target_rot, delta * rotation_speed)

func _change_state(new_state: State) -> void:
	if current_state != new_state:
		current_state = new_state
		state_changed.emit(new_state)

func get_state_string() -> String:
	match current_state:
		State.IDLE: return "IDLE"
		State.FOLLOWING: return "FOLLOWING"
	return "UNKNOWN"
