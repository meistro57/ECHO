class_name APCController
extends CharacterBody3D

enum State { IDLE, FOLLOWING }

@export var target: Node3D
@export var move_speed: float = 3.5
@export var stop_distance: float = 2.0
@export var start_follow_distance: float = 3.2
@export var rotation_speed: float = 8.0
@export var path_update_interval: float = 0.2

@onready var nav_agent: NavigationAgent3D = $NavigationAgent3D

var current_state: State = State.IDLE
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)
var navigation_ready: bool = false
var path_timer: float = 0.0
var diagnostics_printed: bool = false

signal state_changed(new_state: State)

func _ready() -> void:
	add_to_group("apc")
	if nav_agent:
		nav_agent.path_desired_distance = 0.5
		nav_agent.target_desired_distance = 0.5
	call_deferred("_wait_for_navigation_ready")

func _wait_for_navigation_ready() -> void:
	await get_tree().physics_frame
	if nav_agent == null:
		return
	var map_rid: RID = nav_agent.get_navigation_map()

	while NavigationServer3D.map_get_iteration_id(map_rid) == 0:
		await get_tree().physics_frame

	# Await extra physics frames for NavigationServer region geometry linking
	await get_tree().physics_frame
	await get_tree().physics_frame

	navigation_ready = true
	print("[APC] Navigation map ready.")

func _physics_process(delta: float) -> void:
	# 1. Apply gravity
	if not is_on_floor():
		velocity.y -= gravity * delta

	# 2. Resolve player target
	if target == null:
		var players = get_tree().get_nodes_in_group("human_player")
		if players.size() > 0:
			target = players[0]
			print("[APC] Player target found: ", target.name)

	# 3. Wait for navigation readiness
	if not navigation_ready or target == null:
		velocity.x = move_toward(velocity.x, 0.0, move_speed * delta * 5.0)
		velocity.z = move_toward(velocity.z, 0.0, move_speed * delta * 5.0)
		move_and_slide()
		return

	# Print temporary one-shot diagnostics once map is ready & target found
	if not diagnostics_printed:
		_print_one_shot_diagnostics()

	# 4. Update state with hysteresis buffer
	var dist_to_target = global_position.distance_to(target.global_position)
	match current_state:
		State.IDLE:
			if dist_to_target > start_follow_distance:
				_change_state(State.FOLLOWING)
		State.FOLLOWING:
			if dist_to_target <= stop_distance:
				_change_state(State.IDLE)

	# 5. Process state behavior
	match current_state:
		State.IDLE:
			velocity.x = move_toward(velocity.x, 0.0, move_speed * delta * 5.0)
			velocity.z = move_toward(velocity.z, 0.0, move_speed * delta * 5.0)
			path_timer = 0.0
		State.FOLLOWING:
			# 5a. Update navigation target periodically using map snapping
			path_timer += delta
			if path_timer >= path_update_interval or nav_agent.target_position == Vector3.ZERO:
				path_timer = 0.0
				var map_rid: RID = nav_agent.get_navigation_map()
				var snapped_target: Vector3 = NavigationServer3D.map_get_closest_point(map_rid, target.global_position)
				nav_agent.target_position = snapped_target

			# 5b. Query next path position & calculate velocity
			if not nav_agent.is_navigation_finished():
				var next_path_pos = nav_agent.get_next_path_position()
				var dir = global_position.direction_to(next_path_pos)
				dir.y = 0.0
				dir = dir.normalized()

				velocity.x = dir.x * move_speed
				velocity.z = dir.z * move_speed

				# Smooth rotation toward movement direction
				if dir.length() > 0.1:
					var target_rot = atan2(-dir.x, -dir.z)
					rotation.y = lerp_angle(rotation.y, target_rot, delta * rotation_speed)
			else:
				velocity.x = move_toward(velocity.x, 0.0, move_speed * delta * 5.0)
				velocity.z = move_toward(velocity.z, 0.0, move_speed * delta * 5.0)

	# 6. Apply physical movement
	move_and_slide()

func _print_one_shot_diagnostics() -> void:
	diagnostics_printed = true
	var map_rid: RID = nav_agent.get_navigation_map()
	var apc_pos = global_position
	var player_pos = target.global_position
	var iteration_id = NavigationServer3D.map_get_iteration_id(map_rid)
	var closest_apc = NavigationServer3D.map_get_closest_point(map_rid, apc_pos)
	var closest_player = NavigationServer3D.map_get_closest_point(map_rid, player_pos)
	
	nav_agent.target_position = closest_player
	var next_path = nav_agent.get_next_path_position()
	var is_finished = nav_agent.is_navigation_finished()
	
	print("\n--- [APC ONE-SHOT DIAGNOSTICS] ---")
	print("APC Global Pos: ", apc_pos)
	print("Player Global Pos: ", player_pos)
	print("Nav Map Iteration ID: ", iteration_id)
	print("Closest Nav Point to APC: ", closest_apc)
	print("Closest Nav Point to Player: ", closest_player)
	print("Next Path Pos: ", next_path)
	print("Is Navigation Finished: ", is_finished)
	print("APC Velocity: ", velocity)
	print("----------------------------------\n")

func _change_state(new_state: State) -> void:
	if current_state != new_state:
		current_state = new_state
		state_changed.emit(new_state)
		print("[APC] State changed to: ", get_state_string())

func get_state_string() -> String:
	match current_state:
		State.IDLE: return "IDLE"
		State.FOLLOWING: return "FOLLOWING"
	return "UNKNOWN"
