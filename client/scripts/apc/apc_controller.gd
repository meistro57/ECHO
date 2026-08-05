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
var navigation_ready: bool = false

var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)
var _path_timer: float = 0.0
var _last_slide_collision_count: int = 0

signal state_changed(new_state: State)

func _ready() -> void:
	add_to_group("apc")
	if nav_agent:
		nav_agent.path_desired_distance = 1.0
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

func _physics_process(delta: float) -> void:
	# 1. Apply gravity
	if not is_on_floor():
		velocity.y -= _gravity * delta

	# 2. Resolve player target
	if target == null:
		var players: Array[Node] = get_tree().get_nodes_in_group("human_player")
		if players.size() > 0:
			target = players[0] as Node3D

	# 3. Wait for navigation readiness
	if not navigation_ready or target == null:
		velocity.x = move_toward(velocity.x, 0.0, move_speed * delta * 5.0)
		velocity.z = move_toward(velocity.z, 0.0, move_speed * delta * 5.0)
		move_and_slide()
		_last_slide_collision_count = get_slide_collision_count()
		return

	# 4. Update state with hysteresis buffer
	var dist_to_target: float = global_position.distance_to(target.global_position)
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
			_path_timer = 0.0
		State.FOLLOWING:
			# 5a. Update navigation target periodically using map snapping
			_path_timer += delta
			if _path_timer >= path_update_interval or nav_agent.target_position == Vector3.ZERO:
				_path_timer = 0.0
				var map_rid: RID = nav_agent.get_navigation_map()
				var snapped_target: Vector3 = NavigationServer3D.map_get_closest_point(map_rid, target.global_position)
				nav_agent.target_position = snapped_target

			# 5b. Query next path position & calculate velocity
			if not nav_agent.is_navigation_finished():
				var next_path_pos: Vector3 = nav_agent.get_next_path_position()
				var horiz_vec: Vector3 = Vector3(next_path_pos.x - global_position.x, 0.0, next_path_pos.z - global_position.z)

				if horiz_vec.length() > 0.05:
					var dir: Vector3 = horiz_vec.normalized()
					velocity.x = dir.x * move_speed
					velocity.z = dir.z * move_speed

					var target_rot: float = atan2(-dir.x, -dir.z)
					rotation.y = lerp_angle(rotation.y, target_rot, delta * rotation_speed)
				else:
					velocity.x = move_toward(velocity.x, 0.0, move_speed * delta * 5.0)
					velocity.z = move_toward(velocity.z, 0.0, move_speed * delta * 5.0)
			else:
				velocity.x = move_toward(velocity.x, 0.0, move_speed * delta * 5.0)
				velocity.z = move_toward(velocity.z, 0.0, move_speed * delta * 5.0)

	# 6. Apply physical movement
	move_and_slide()
	_last_slide_collision_count = get_slide_collision_count()

func _change_state(new_state: State) -> void:
	if current_state != new_state:
		current_state = new_state
		state_changed.emit(new_state)

func get_state_string() -> String:
	match current_state:
		State.IDLE: return "IDLE"
		State.FOLLOWING: return "FOLLOWING"
	return "UNKNOWN"

func get_last_slide_collision_count() -> int:
	return _last_slide_collision_count
