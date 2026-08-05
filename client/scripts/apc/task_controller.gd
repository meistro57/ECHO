class_name TaskController
extends Node3D

signal task_started(request: TaskRequest)
signal task_step_advanced(step_index: int, action_req: ActionTypes.ActionRequest)
signal task_completed(result: TaskResult)
signal task_failed(result: TaskResult)

var current_task_request: TaskRequest = null
var current_task_result: TaskResult = null
var is_running_task: bool = false
var last_task_error: String = "None"

var _apc: CharacterBody3D
var _interaction_ctrl: InteractionController
var _action_ctrl: ActionController

func _ready() -> void:
	_apc = get_parent() as CharacterBody3D
	if _apc:
		_interaction_ctrl = _apc.get_node_or_null("InteractionController") as InteractionController
		_action_ctrl = _apc.get_node_or_null("ActionController") as ActionController

func start_task(request: TaskRequest) -> bool:
	if is_running_task:
		cancel_task()

	if request == null or request.steps.is_empty():
		last_task_error = "Invalid or empty task request"
		return false

	current_task_request = request
	current_task_result = TaskResult.new(request.task_id)
	current_task_result.status = "RUNNING"
	is_running_task = true
	last_task_error = "None"

	task_started.emit(request)
	return true

func cancel_task() -> void:
	if is_running_task and current_task_result:
		current_task_result.status = "CANCELLED"
		current_task_result.success = false
		current_task_result.message = "Task cancelled by user or system"
		current_task_result.time_completed = Time.get_ticks_msec() / 1000.0
		is_running_task = false
		last_task_error = "Task cancelled"
		task_failed.emit(current_task_result)

func process_task_tick(delta: float, player_node: Node3D = null) -> ActionTypes.ActionRequest:
	if not is_running_task or current_task_request == null or current_task_result == null:
		return null

	if _apc == null:
		_apc = get_parent() as CharacterBody3D
	if _apc and _interaction_ctrl == null:
		_interaction_ctrl = _apc.get_node_or_null("InteractionController") as InteractionController

	var step_idx: int = current_task_result.current_step
	if step_idx >= current_task_request.steps.size():
		# All steps completed!
		current_task_result.status = "COMPLETED"
		current_task_result.success = true
		current_task_result.message = "Task '%s' completed successfully" % current_task_request.task_type
		current_task_result.time_completed = Time.get_ticks_msec() / 1000.0
		is_running_task = false
		task_completed.emit(current_task_result)
		return null

	var step_req: ActionTypes.ActionRequest = current_task_request.steps[step_idx]

	match step_req.action:
		ActionTypes.Action.MOVE_TO_OBJECT:
			# Check if reached object
			var target_obj: Node3D = _find_perceivable_target(step_req.target_id)
			if target_obj:
				step_req.target_position = target_obj.global_position
				var dist: float = _apc.global_position.distance_to(target_obj.global_position) if _apc else 999.0
				if dist <= (_interaction_ctrl.interaction_range if _interaction_ctrl else 1.5):
					_advance_step()
					return process_task_tick(delta, player_node)
			return step_req

		ActionTypes.Action.PICK_UP_OBJECT:
			if _interaction_ctrl:
				var res: ActionTypes.ActionResult = _interaction_ctrl.request_pick_up(step_req.target_id)
				if res.success:
					_advance_step()
					return process_task_tick(delta, player_node)
				else:
					_fail_current_task("Pickup failed: " + res.message)
					return null
			else:
				_fail_current_task("InteractionController missing")
				return null

		ActionTypes.Action.FOLLOW_PLAYER:
			if player_node:
				var dist: float = _apc.global_position.distance_to(player_node.global_position) if _apc else 999.0
				if dist <= (_interaction_ctrl.giving_distance if _interaction_ctrl else 2.0):
					_advance_step()
					return process_task_tick(delta, player_node)
			return step_req

		ActionTypes.Action.GIVE_OBJECT_TO_PLAYER:
			if _interaction_ctrl:
				var res: ActionTypes.ActionResult = _interaction_ctrl.request_give_to_player()
				if res.success:
					_advance_step()
					return process_task_tick(delta, player_node)
				else:
					_fail_current_task("Give failed: " + res.message)
					return null
			else:
				_fail_current_task("InteractionController missing")
				return null

		ActionTypes.Action.DROP_HELD_OBJECT:
			if _interaction_ctrl:
				var res: ActionTypes.ActionResult = _interaction_ctrl.request_drop()
				if res.success:
					_advance_step()
					return process_task_tick(delta, player_node)
				else:
					_fail_current_task("Drop failed: " + res.message)
					return null
			return step_req

		_:
			_advance_step()
			return step_req

	return step_req

func _advance_step() -> void:
	if current_task_result:
		current_task_result.completed_steps += 1
		current_task_result.current_step += 1
		if current_task_request and current_task_result.current_step < current_task_request.steps.size():
			task_step_advanced.emit(current_task_result.current_step, current_task_request.steps[current_task_result.current_step])

func _fail_current_task(err_msg: String) -> void:
	if current_task_result:
		current_task_result.status = "FAILED"
		current_task_result.success = false
		current_task_result.failed_step = current_task_result.current_step
		current_task_result.error_code = "STEP_FAILED"
		current_task_result.message = err_msg
		current_task_result.time_completed = Time.get_ticks_msec() / 1000.0
		last_task_error = err_msg
		is_running_task = false
		task_failed.emit(current_task_result)

func _find_perceivable_target(obj_id: String) -> Node3D:
	var perceivables: Array[Node] = get_tree().get_nodes_in_group("perceivable")
	for node in perceivables:
		if node is Node3D:
			var n3d: Node3D = node as Node3D
			var n_id: String = n3d.get("object_id") if n3d.get("object_id") != null else n3d.get("entity_id")
			if n_id == obj_id or n3d.name.to_lower() == obj_id:
				return n3d
	return null

func get_task_status_string() -> String:
	if current_task_result:
		return current_task_result.status
	return "IDLE"

func get_current_step_string() -> String:
	if is_running_task and current_task_request and current_task_result:
		var step_idx: int = current_task_result.current_step
		var total: int = current_task_request.steps.size()
		if step_idx < total:
			var action_name: String = ActionTypes.get_action_name(current_task_request.steps[step_idx].action)
			return "%d/%d (%s)" % [step_idx + 1, total, action_name]
	return "None"
