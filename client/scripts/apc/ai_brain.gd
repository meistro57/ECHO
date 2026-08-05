class_name AIBrain
extends Node3D

@export var decision_interval_seconds: float = 1.0
@export var min_event_interval_seconds: float = 0.25

var ai_service: AIService
var current_ai_action_request: ActionTypes.ActionRequest
var current_ai_task_request: TaskRequest
var last_validation_error: String = "None"
var last_requested_action_name: String = "None"
var last_accepted_action_name: String = "None"
var last_rejected_action_name: String = "None"
var decision_status: String = "IDLE"
var fallback_active: bool = false
var decision_latency_ms: float = 0.0

var _decision_timer: float = 0.0
var _event_timer: float = 0.0
var _last_in_flight_request_id: String = ""
var _last_player_visible: bool = false

signal ai_decision_accepted(request: ActionTypes.ActionRequest)
signal ai_task_accepted(task_req: TaskRequest)
signal ai_decision_rejected(error_msg: String)

func _ready() -> void:
	var env_interval: String = OS.get_environment("ECHO_AI_DECISION_INTERVAL_SECONDS").strip_edges()
	if not env_interval.is_empty() and env_interval.is_valid_float():
		decision_interval_seconds = max(0.1, env_interval.to_float())
	var env_event_interval: String = OS.get_environment("ECHO_AI_MIN_EVENT_INTERVAL_SECONDS").strip_edges()
	if not env_event_interval.is_empty() and env_event_interval.is_valid_float():
		min_event_interval_seconds = max(0.0, env_event_interval.to_float())
	call_deferred("_connect_ai_service")

func _connect_ai_service() -> void:
	var services: Array[Node] = get_tree().get_nodes_in_group("ai_service")
	if services.size() > 0 and services[0] is AIService:
		ai_service = services[0] as AIService
	else:
		var found: Node = get_tree().root.find_child("AIService", true, false)
		if found is AIService:
			ai_service = found as AIService

func process_ai_tick(delta: float, perception_snapshot: Dictionary, apc_state: String, current_action: ActionTypes.Action) -> void:
	_decision_timer += delta
	_event_timer += delta

	# Detect visibility changes to trigger immediate event-driven re-evaluation
	var current_player_vis: bool = false
	if perception_snapshot.has("human_player"):
		current_player_vis = bool(perception_snapshot["human_player"].get("visible", false))

	var visibility_changed: bool = (current_player_vis != _last_player_visible)
	if visibility_changed:
		_last_player_visible = current_player_vis

	var should_trigger: bool = false
	if _event_timer >= min_event_interval_seconds and visibility_changed:
		should_trigger = true
	elif _decision_timer >= decision_interval_seconds:
		should_trigger = true

	if should_trigger:
		_decision_timer = 0.0
		_event_timer = 0.0
		request_ai_decision(perception_snapshot, apc_state, current_action)

func request_ai_decision(perception_snapshot: Dictionary, apc_state: String, current_action: ActionTypes.Action) -> void:
	if ai_service == null:
		_connect_ai_service()

	if ai_service == null or not ai_service.is_ai_enabled() or not ai_service.is_provider_configured():
		fallback_active = true
		decision_status = "FALLBACK"
		last_validation_error = "AI service disabled or unconfigured"
		return

	if ai_service.is_request_in_flight:
		return

	# Build compact context JSON
	var context: Dictionary = _build_input_context(perception_snapshot, apc_state, current_action)

	var messages: Array[Dictionary] = [
		{
			"role": "system",
			"content": "You are the decision module for an embodied AI Player Character in ECHO.\nChoose exactly one legal action using only the supplied perception data.\nYou do not control the world directly.\nYou may call submit_apc_action or submit_apc_task.\nDo not invent entities, positions, abilities, or facts.\nIf information is missing or uncertain, choose WAIT."
		},
		{
			"role": "user",
			"content": JSON.stringify(context)
		}
	]

	var request: AIRequest = AIRequest.new(ai_service.get_provider_name(), ai_service.get_model_name(), messages, ai_service.timeout_seconds)
	_last_in_flight_request_id = request.request_id
	decision_status = "REQUESTING"
	fallback_active = false

	# Connect completion signal once
	if not ai_service.request_completed.is_connected(_on_ai_request_completed):
		ai_service.request_completed.connect(_on_ai_request_completed)
	if not ai_service.request_failed.is_connected(_on_ai_request_failed):
		ai_service.request_failed.connect(_on_ai_request_failed)

	# Execute asynchronous request via AIService
	ai_service.current_request = request
	ai_service.current_status = "REQUESTING"
	ai_service.is_request_in_flight = true
	ai_service.request_started.emit(request.request_id)

	var endpoint: String = ai_service.active_provider.get_endpoint_url()
	var headers: PackedStringArray = ai_service.active_provider.build_headers()

	# Build request payload with tool schemas
	var action_tool_def: Dictionary = {
		"type": "function",
		"function": {
			"name": "submit_apc_action",
			"description": "Submit exactly one legal action for the APC to execute.",
			"parameters": {
				"type": "object",
				"properties": {
					"action": {
						"type": "string",
						"enum": ["IDLE", "WAIT", "FOLLOW_PLAYER", "LOOK_AT_PLAYER", "LOOK_AT_OBJECT", "MOVE_TO_OBJECT", "PICK_UP_OBJECT", "DROP_HELD_OBJECT", "GIVE_OBJECT_TO_PLAYER"]
					},
					"target_id": {
						"type": "string",
						"description": "Target entity ID (e.g. human_player or red_box)"
					},
					"duration": {
						"type": "number",
						"description": "Action duration in seconds"
					},
					"reason": {
						"type": "string",
						"description": "Short explanation for decision"
					}
				},
				"required": ["action"],
				"additionalProperties": false
			}
		}
	}

	var task_tool_def: Dictionary = {
		"type": "function",
		"function": {
			"name": "submit_apc_task",
			"description": "Request a trusted multi-step task (e.g. BRING_OBJECT_TO_PLAYER).",
			"parameters": {
				"type": "object",
				"properties": {
					"task_type": {
						"type": "string",
						"enum": ["BRING_OBJECT_TO_PLAYER"]
					},
					"target_id": {
						"type": "string",
						"description": "Target object ID (e.g. red_box)"
					},
					"reason": {
						"type": "string",
						"description": "Short explanation for task request"
					}
				},
				"required": ["task_type", "target_id"],
				"additionalProperties": false
			}
		}
	}

	var payload: Dictionary = {
		"model": ai_service.get_model_name(),
		"messages": messages,
		"tools": [action_tool_def, task_tool_def],
		"temperature": 0.0,
		"max_tokens": 100,
		"stream": false
	}

	var err: Error = ai_service._http_request.request(endpoint, headers, HTTPClient.METHOD_POST, JSON.stringify(payload))
	if err != OK:
		ai_service.is_request_in_flight = false
		_on_ai_request_failed(null)

func _on_ai_request_completed(response: AIResponse) -> void:
	if response == null or response.request_id != _last_in_flight_request_id:
		return

	decision_latency_ms = response.latency_ms

	# Extract tool calls from raw response if available
	var raw_tool_calls: Array = []
	var json: JSON = JSON.new()
	if json.parse(response.content) == OK and json.get_data() is Dictionary:
		var root_dict: Dictionary = json.get_data() as Dictionary
		if root_dict.has("choices") and root_dict["choices"] is Array:
			var choices: Array = root_dict["choices"] as Array
			if not choices.is_empty() and choices[0] is Dictionary:
				var choice0: Dictionary = choices[0] as Dictionary
				if choice0.has("message") and choice0["message"] is Dictionary:
					var msg: Dictionary = choice0["message"] as Dictionary
					if msg.has("tool_calls") and msg["tool_calls"] is Array:
						raw_tool_calls = msg["tool_calls"] as Array

	var snapshot: Dictionary = {}
	var apc: Node = get_parent().get_parent() if get_parent() else null
	if apc and apc.has_method("get_perception_snapshot"):
		snapshot = apc.get_perception_snapshot()

	var val_result: AIDecisionAdapter.ValidationResult = AIDecisionAdapter.validate_and_convert(response.content, raw_tool_calls, snapshot)

	if val_result.success:
		decision_status = "ACCEPTED"
		fallback_active = false
		last_validation_error = "None"

		if val_result.task_request != null:
			current_ai_task_request = val_result.task_request
			current_ai_action_request = null
			last_accepted_action_name = "TASK: " + val_result.task_request.task_type
			last_requested_action_name = last_accepted_action_name
			ai_task_accepted.emit(val_result.task_request)
		elif val_result.action_request != null:
			current_ai_action_request = val_result.action_request
			current_ai_task_request = null
			last_accepted_action_name = ActionTypes.get_action_name(val_result.action_request.action)
			last_requested_action_name = last_accepted_action_name
			ai_decision_accepted.emit(val_result.action_request)
	else:
		current_ai_action_request = null
		current_ai_task_request = null
		decision_status = "REJECTED"
		fallback_active = true
		last_validation_error = val_result.error_message
		last_rejected_action_name = response.content.substr(0, 30)
		ai_decision_rejected.emit(val_result.error_message)

func _on_ai_request_failed(response: AIResponse) -> void:
	current_ai_action_request = null
	current_ai_task_request = null
	decision_status = "FALLBACK"
	fallback_active = true
	if response != null:
		last_validation_error = response.error_message
		decision_latency_ms = response.latency_ms
	else:
		last_validation_error = "Request transport failed"
	ai_decision_rejected.emit(last_validation_error)

func _build_input_context(snapshot: Dictionary, apc_state: String, current_action: ActionTypes.Action) -> Dictionary:
	var current_action_name: String = ActionTypes.get_action_name(current_action)
	
	var human_player_ctx: Dictionary = {}
	if snapshot.has("human_player"):
		var p_data: Dictionary = snapshot["human_player"]
		human_player_ctx = {
			"id": "human_player",
			"visible": bool(p_data.get("visible", false)),
			"distance": float(p_data.get("distance", 0.0)),
			"relative_direction": String(p_data.get("relative_direction", "unknown"))
		}

	var nearby_objects_ctx: Array = []
	var valid_target_ids: Array[String] = ["human_player"]

	if snapshot.has("nearby_objects"):
		var objs: Array = snapshot["nearby_objects"]
		for obj in objs:
			if obj is Dictionary:
				var obj_id: String = String(obj.get("id", ""))
				if not obj_id.is_empty():
					valid_target_ids.append(obj_id)
					nearby_objects_ctx.append({
						"id": obj_id,
						"visible": bool(obj.get("visible", false)),
						"distance": float(obj.get("distance", 0.0)),
						"relative_direction": String(obj.get("relative_direction", "unknown"))
					})

	return {
		"self": {
			"state": apc_state,
			"current_action": current_action_name
		},
		"human_player": human_player_ctx,
		"nearby_objects": nearby_objects_ctx,
		"available_actions": AIDecisionAdapter.ALLOWED_ACTIONS,
		"valid_target_ids": valid_target_ids
	}
