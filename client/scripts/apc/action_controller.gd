class_name ActionController
extends Node3D

@export var move_speed: float = 3.5
@export var rotation_speed: float = 8.0
@export var path_update_interval: float = 0.2

var current_action_request: ActionTypes.ActionRequest
var current_execution_status: String = "IDLE"
var _apc: CharacterBody3D
var _nav_agent: NavigationAgent3D
var _path_timer: float = 0.0
var _event_log: Array[String] = []
var _last_logged_action: ActionTypes.Action = ActionTypes.Action.NONE
var _last_player_visible: bool = false

signal action_started(request: ActionTypes.ActionRequest)
signal action_completed(result: ActionTypes.ActionResult)

func _ready() -> void:
	_apc = get_parent() as CharacterBody3D
	if _apc:
		_nav_agent = _apc.get_node_or_null("NavigationAgent3D") as NavigationAgent3D

func execute_action_request(request: ActionTypes.ActionRequest, delta: float, player_visible: bool = false, player_node: Node3D = null) -> void:
	if _apc == null:
		return

	# Track visibility state changes for event log
	if player_visible != _last_player_visible:
		_last_player_visible = player_visible
		add_event_log("Player Seen" if player_visible else "Player Lost")

	# Detect action change
	if current_action_request == null or current_action_request.action != request.action:
		current_action_request = request
		_last_logged_action = request.action
		current_execution_status = "EXECUTING"
		add_event_log("Brain chose %s (%s)" % [ActionTypes.get_action_name(request.action), request.reason])
		action_started.emit(request)

	# Execute requested action behavior
	match request.action:
		ActionTypes.Action.FOLLOW_PLAYER:
			_execute_follow_player(request, delta, player_node)
		ActionTypes.Action.LOOK_AT_PLAYER:
			_execute_look_at_player(request, delta, player_node)
		ActionTypes.Action.WAIT:
			_execute_wait(delta)
		ActionTypes.Action.IDLE, ActionTypes.Action.NONE, _:
			_execute_idle(delta)

func _execute_follow_player(request: ActionTypes.ActionRequest, delta: float, player_node: Node3D) -> void:
	if _apc == null or _nav_agent == null:
		return

	var target_pos: Vector3 = request.target_position
	if player_node != null:
		target_pos = player_node.global_position

	_path_timer += delta
	if _path_timer >= path_update_interval or _nav_agent.target_position == Vector3.ZERO:
		_path_timer = 0.0
		var map_rid: RID = _nav_agent.get_navigation_map()
		var snapped_target: Vector3 = NavigationServer3D.map_get_closest_point(map_rid, target_pos)
		_nav_agent.target_position = snapped_target

	if not _nav_agent.is_navigation_finished():
		var next_path_pos: Vector3 = _nav_agent.get_next_path_position()
		var horiz_vec: Vector3 = Vector3(next_path_pos.x - _apc.global_position.x, 0.0, next_path_pos.z - _apc.global_position.z)

		if horiz_vec.length() > 0.05:
			var dir: Vector3 = horiz_vec.normalized()
			_apc.velocity.x = dir.x * move_speed
			_apc.velocity.z = dir.z * move_speed

			var target_rot: float = atan2(-dir.x, -dir.z)
			_apc.rotation.y = lerp_angle(_apc.rotation.y, target_rot, delta * rotation_speed)
		else:
			_apc.velocity.x = move_toward(_apc.velocity.x, 0.0, move_speed * delta * 5.0)
			_apc.velocity.z = move_toward(_apc.velocity.z, 0.0, move_speed * delta * 5.0)
	else:
		_apc.velocity.x = move_toward(_apc.velocity.x, 0.0, move_speed * delta * 5.0)
		_apc.velocity.z = move_toward(_apc.velocity.z, 0.0, move_speed * delta * 5.0)

func _execute_look_at_player(request: ActionTypes.ActionRequest, delta: float, player_node: Node3D) -> void:
	if _apc == null:
		return

	# Stop horizontal movement
	_apc.velocity.x = move_toward(_apc.velocity.x, 0.0, move_speed * delta * 5.0)
	_apc.velocity.z = move_toward(_apc.velocity.z, 0.0, move_speed * delta * 5.0)

	var target_pos: Vector3 = request.target_position
	if player_node != null:
		target_pos = player_node.global_position

	var horiz_vec: Vector3 = Vector3(target_pos.x - _apc.global_position.x, 0.0, target_pos.z - _apc.global_position.z)
	if horiz_vec.length() > 0.05:
		var dir: Vector3 = horiz_vec.normalized()
		var target_rot: float = atan2(-dir.x, -dir.z)
		_apc.rotation.y = lerp_angle(_apc.rotation.y, target_rot, delta * rotation_speed)

func _execute_wait(delta: float) -> void:
	if _apc == null:
		return
	# Stop horizontal movement and maintain current rotation
	_apc.velocity.x = move_toward(_apc.velocity.x, 0.0, move_speed * delta * 5.0)
	_apc.velocity.z = move_toward(_apc.velocity.z, 0.0, move_speed * delta * 5.0)

func _execute_idle(delta: float) -> void:
	if _apc == null:
		return
	_apc.velocity.x = move_toward(_apc.velocity.x, 0.0, move_speed * delta * 5.0)
	_apc.velocity.z = move_toward(_apc.velocity.z, 0.0, move_speed * delta * 5.0)

func add_event_log(event_msg: String) -> void:
	var timestamp_sec: float = Time.get_ticks_msec() / 1000.0
	var formatted_entry: String = "[%.1fs] %s" % [timestamp_sec, event_msg]
	_event_log.push_front(formatted_entry)
	if _event_log.size() > 20:
		_event_log.pop_back()

func get_event_log() -> Array[String]:
	return _event_log

func get_current_action_name() -> String:
	if current_action_request != null:
		return ActionTypes.get_action_name(current_action_request.action)
	return "NONE"
