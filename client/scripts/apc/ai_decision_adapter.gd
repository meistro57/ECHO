class_name AIDecisionAdapter
extends RefCounted

const ALLOWED_ACTIONS: Array[String] = [
	"IDLE",
	"WAIT",
	"FOLLOW_PLAYER",
	"LOOK_AT_PLAYER",
	"LOOK_AT_OBJECT",
	"MOVE_TO_OBJECT",
	"PICK_UP_OBJECT",
	"DROP_HELD_OBJECT",
	"GIVE_OBJECT_TO_PLAYER"
]

const FORBIDDEN_KEYWORDS: Array[String] = [
	"RUN_CODE", "CALL_API", "READ_FILE", "WRITE_FILE",
	"PICK_UP", "DROP", "GIVE", "ATTACK", "USE", "OPEN", "SPEAK",
	"eval", "exec", "system", "os", "file"
]

class ValidationResult extends RefCounted:
	var success: bool = false
	var action_request: ActionTypes.ActionRequest = null
	var task_request: TaskRequest = null
	var error_message: String = ""
	var sanitized_reason: String = ""

static func validate_and_convert(raw_ai_content: String, raw_tool_calls: Array, perception_snapshot: Dictionary) -> ValidationResult:
	var res: ValidationResult = ValidationResult.new()

	# Extract tool call parameters
	var tool_name: String = ""
	var tool_args: Dictionary = {}

	if not raw_tool_calls.is_empty():
		var first_call: Variant = raw_tool_calls[0]
		if first_call is Dictionary:
			var fc_dict: Dictionary = first_call as Dictionary
			if fc_dict.has("function") and fc_dict["function"] is Dictionary:
				var fn_dict: Dictionary = fc_dict["function"] as Dictionary
				tool_name = String(fn_dict.get("name", ""))
				var args_raw: Variant = fn_dict.get("arguments", {})
				if args_raw is String:
					var json: JSON = JSON.new()
					if json.parse(args_raw) == OK and json.get_data() is Dictionary:
						tool_args = json.get_data() as Dictionary
					else:
						res.success = false
						res.error_message = "Malformed JSON in tool call arguments"
						return res
				elif args_raw is Dictionary:
					tool_args = args_raw as Dictionary
	else:
		# Fallback to parsing raw text content as JSON tool payload
		var json: JSON = JSON.new()
		if json.parse(raw_ai_content) == OK and json.get_data() is Dictionary:
			var dict_payload: Dictionary = json.get_data() as Dictionary
			if dict_payload.has("name"):
				tool_name = String(dict_payload.get("name", ""))
				tool_args = dict_payload.get("arguments", {}) if dict_payload.get("arguments") is Dictionary else dict_payload
			elif dict_payload.has("task_type"):
				tool_name = "submit_apc_task"
				tool_args = dict_payload
			elif dict_payload.has("action"):
				tool_name = "submit_apc_action"
				tool_args = dict_payload

	# Extract known perceived target IDs and positions from snapshot
	var known_targets: Dictionary = {} # String (id) -> Vector3 (position)
	if perception_snapshot.has("human_player"):
		var p_data: Dictionary = perception_snapshot["human_player"]
		var p_id: String = String(p_data.get("id", "human_player"))
		var last_seen: Variant = p_data.get("last_seen_position", null)
		if last_seen is Dictionary:
			known_targets[p_id] = Vector3(float(last_seen.get("x", 0.0)), float(last_seen.get("y", 0.0)), float(last_seen.get("z", 0.0)))

	if perception_snapshot.has("nearby_objects"):
		var objs: Array = perception_snapshot["nearby_objects"]
		for obj in objs:
			if obj is Dictionary:
				var obj_id: String = String(obj.get("id", ""))
				var last_seen: Variant = obj.get("last_seen_position", null)
				if not obj_id.is_empty() and last_seen is Dictionary:
					known_targets[obj_id] = Vector3(float(last_seen.get("x", 0.0)), float(last_seen.get("y", 0.0)), float(last_seen.get("z", 0.0)))

	# Handle submit_apc_task
	if tool_name == "submit_apc_task":
		# Reject raw steps if supplied by model to prevent step injection
		if tool_args.has("steps") or tool_args.has("raw_steps"):
			res.success = false
			res.error_message = "Security Violation: Model cannot supply raw task steps"
			return res

		var task_type: String = String(tool_args.get("task_type", "")).strip_edges().to_upper()
		if task_type != "BRING_OBJECT_TO_PLAYER":
			res.success = false
			res.error_message = "Invalid task_type '%s' (expected 'BRING_OBJECT_TO_PLAYER')" % task_type
			return res

		var target_id: String = String(tool_args.get("target_id", "")).strip_edges()
		if target_id.is_empty() or target_id == "human_player" or not known_targets.has(target_id):
			res.success = false
			res.error_message = "Task requires known portable object target_id (got '%s')" % target_id
			return res

		var task_req: TaskRequest = TaskRequest.new("BRING_OBJECT_TO_PLAYER", target_id, "ai")
		res.success = true
		res.task_request = task_req
		res.sanitized_reason = String(tool_args.get("reason", "AI requested BRING_OBJECT_TO_PLAYER"))
		return res

	# Handle submit_apc_action
	if tool_name != "submit_apc_action":
		res.success = false
		res.error_message = "Invalid tool name '%s' (expected 'submit_apc_action' or 'submit_apc_task')" % tool_name
		return res

	# Check for forbidden security keywords or unknown actions
	var raw_action_str: String = String(tool_args.get("action", "")).strip_edges().to_upper()
	if raw_action_str.is_empty():
		res.success = false
		res.error_message = "Missing 'action' field in submit_apc_action payload"
		return res

	for forbidden in FORBIDDEN_KEYWORDS:
		if raw_action_str == forbidden:
			res.success = false
			res.error_message = "Security Violation: Forbidden action keyword '%s'" % raw_action_str
			return res

	if not ALLOWED_ACTIONS.has(raw_action_str):
		res.success = false
		res.error_message = "Action '%s' is not in allowed actions list" % raw_action_str
		return res

	var raw_target_id: String = String(tool_args.get("target_id", "")).strip_edges()
	var action_enum: ActionTypes.Action = ActionTypes.Action.NONE
	match raw_action_str:
		"IDLE": action_enum = ActionTypes.Action.IDLE
		"WAIT": action_enum = ActionTypes.Action.WAIT
		"FOLLOW_PLAYER": action_enum = ActionTypes.Action.FOLLOW_PLAYER
		"LOOK_AT_PLAYER": action_enum = ActionTypes.Action.LOOK_AT_PLAYER
		"LOOK_AT_OBJECT": action_enum = ActionTypes.Action.LOOK_AT_OBJECT
		"MOVE_TO_OBJECT": action_enum = ActionTypes.Action.MOVE_TO_OBJECT
		"PICK_UP_OBJECT": action_enum = ActionTypes.Action.PICK_UP_OBJECT
		"DROP_HELD_OBJECT": action_enum = ActionTypes.Action.DROP_HELD_OBJECT
		"GIVE_OBJECT_TO_PLAYER": action_enum = ActionTypes.Action.GIVE_OBJECT_TO_PLAYER

	# Target rules
	if action_enum == ActionTypes.Action.FOLLOW_PLAYER or action_enum == ActionTypes.Action.LOOK_AT_PLAYER:
		if raw_target_id != "human_player":
			res.success = false
			res.error_message = "Action '%s' requires target_id 'human_player' (got '%s')" % [raw_action_str, raw_target_id]
			return res

	elif action_enum == ActionTypes.Action.LOOK_AT_OBJECT or action_enum == ActionTypes.Action.MOVE_TO_OBJECT or action_enum == ActionTypes.Action.PICK_UP_OBJECT:
		if raw_target_id.is_empty() or raw_target_id == "human_player" or not known_targets.has(raw_target_id):
			res.success = false
			res.error_message = "Action '%s' requires valid known object target_id (got '%s')" % [raw_action_str, raw_target_id]
			return res

	# Resolve target position from perception
	var resolved_target_pos: Vector3 = Vector3.ZERO
	if not raw_target_id.is_empty() and known_targets.has(raw_target_id):
		resolved_target_pos = known_targets[raw_target_id]

	# Duration validation
	var raw_duration: float = float(tool_args.get("duration", 0.0))
	var duration: float = clampf(raw_duration, 0.0, 30.0)

	# Reason sanitization
	var raw_reason: String = String(tool_args.get("reason", "AI selected " + raw_action_str)).strip_edges()
	if raw_reason.length() > 100:
		raw_reason = raw_reason.substr(0, 100) + "..."
	res.sanitized_reason = raw_reason

	# Construct validated ActionRequest
	var validated_req: ActionTypes.ActionRequest = ActionTypes.ActionRequest.new(
		action_enum,
		raw_target_id,
		resolved_target_pos,
		duration,
		res.sanitized_reason
	)

	res.success = true
	res.action_request = validated_req
	return res
