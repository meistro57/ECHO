class_name CommandGrounder
extends RefCounted

class GroundingResult extends RefCounted:
	var success: bool = false
	var action_request: ActionTypes.ActionRequest = null
	var task_request: TaskRequest = null
	var is_cancel: bool = false
	var is_memory_query: bool = false
	var is_memory_store_command: bool = false
	var is_memory_forget_command: bool = false
	var is_memory_clear_all_command: bool = false
	var memory_query_term: String = ""
	var memory_fact_text: String = ""
	var needs_confirmation: bool = false
	var needs_clarification: bool = false
	var clarification_prompt: String = ""
	var resolved_target_id: String = ""
	var error_message: String = ""

static func ground_command(
	raw_text: String,
	perception_snapshot: Dictionary,
	attention_snapshot: Dictionary,
	held_object: PortableObject = null,
	pending_clarification_target: String = ""
) -> GroundingResult:
	var result: GroundingResult = GroundingResult.new()
	var normalized_text: String = _normalize_text(raw_text)

	if normalized_text.is_empty():
		result.error_message = "Empty input text"
		return result

	if _ground_memory_commands(raw_text, normalized_text, result):
		return result

	if normalized_text == "cancel" or normalized_text == "cancel task" or normalized_text == "stop task" or normalized_text == "stop":
		result.success = true
		result.is_cancel = true
		return result

	if not pending_clarification_target.is_empty():
		if normalized_text.contains("red") or normalized_text.contains("box"):
			result.success = true
			result.resolved_target_id = "red_box"
			result.task_request = TaskRequest.new("BRING_OBJECT_TO_PLAYER", "red_box", "human_voice")
			return result

	if normalized_text.contains("follow me") or normalized_text.contains("come here") or normalized_text.contains("come over here"):
		result.success = true
		result.action_request = ActionTypes.ActionRequest.new(ActionTypes.Action.FOLLOW_PLAYER, "human_player", Vector3.ZERO, 0.0, "Spoken follow request")
		return result

	if normalized_text == "wait" or normalized_text == "wait there" or normalized_text == "hold on":
		result.success = true
		result.action_request = ActionTypes.ActionRequest.new(ActionTypes.Action.WAIT, "human_player", Vector3.ZERO, 0.0, "Spoken wait request")
		return result

	if normalized_text.contains("look at me"):
		result.success = true
		result.action_request = ActionTypes.ActionRequest.new(ActionTypes.Action.LOOK_AT_PLAYER, "human_player", Vector3.ZERO, 0.0, "Spoken look at player request")
		return result

	if normalized_text.contains("look at the red box") or normalized_text.contains("look at red box"):
		result.success = true
		result.resolved_target_id = "red_box"
		result.action_request = ActionTypes.ActionRequest.new(ActionTypes.Action.LOOK_AT_OBJECT, "red_box", Vector3.ZERO, 0.0, "Spoken look at object request")
		return result

	if normalized_text.contains("go to the red box") or normalized_text.contains("move to red box"):
		result.success = true
		result.resolved_target_id = "red_box"
		result.action_request = ActionTypes.ActionRequest.new(ActionTypes.Action.MOVE_TO_OBJECT, "red_box", Vector3.ZERO, 0.0, "Spoken move to object request")
		return result

	if normalized_text.contains("drop the box") or normalized_text.contains("drop it") or normalized_text == "drop":
		if held_object != null:
			result.success = true
			result.action_request = ActionTypes.ActionRequest.new(ActionTypes.Action.DROP_HELD_OBJECT, held_object.object_id, Vector3.ZERO, 0.0, "Spoken drop request")
			return result
		result.error_message = "Cannot drop: APC is not holding any object"
		return result

	if normalized_text.contains("give me the box") or normalized_text.contains("give it to me") or normalized_text == "give it":
		if held_object != null:
			result.success = true
			result.action_request = ActionTypes.ActionRequest.new(ActionTypes.Action.GIVE_OBJECT_TO_PLAYER, "human_player", Vector3.ZERO, 0.0, "Spoken give request")
			return result
		result.error_message = "Cannot give: APC is not holding any object"
		return result

	if normalized_text.contains("pick up the red box") or normalized_text.contains("pick up the box") or normalized_text.contains("pick up red box"):
		result.success = true
		result.resolved_target_id = "red_box"
		result.action_request = ActionTypes.ActionRequest.new(ActionTypes.Action.PICK_UP_OBJECT, "red_box", Vector3.ZERO, 0.0, "Spoken pickup request")
		return result

	if normalized_text.contains("bring me the red box") or normalized_text.contains("bring me that red box") or normalized_text.contains("bring red box"):
		result.success = true
		result.resolved_target_id = "red_box"
		result.task_request = TaskRequest.new("BRING_OBJECT_TO_PLAYER", "red_box", "human_voice")
		return result

	if normalized_text.contains("bring me that") or normalized_text.contains("bring it to me") or normalized_text == "bring me the box":
		var aim_target: String = String(attention_snapshot.get("aim_target_id", ""))
		if aim_target == "red_box":
			result.success = true
			result.resolved_target_id = "red_box"
			result.task_request = TaskRequest.new("BRING_OBJECT_TO_PLAYER", "red_box", "human_voice")
			return result

		var candidate_objects: Array[String] = []
		if perception_snapshot.has("nearby_objects"):
			var nearby: Variant = perception_snapshot.get("nearby_objects", [])
			if nearby is Array:
				for obj in nearby:
					if obj is Dictionary and obj.has("id"):
						candidate_objects.append(String(obj["id"]))

		if candidate_objects.size() > 1:
			result.success = false
			result.needs_clarification = true
			result.clarification_prompt = "Which object do you mean?"
			return result

		if candidate_objects.size() == 1:
			var single_id: String = candidate_objects[0]
			result.success = true
			result.resolved_target_id = single_id
			result.task_request = TaskRequest.new("BRING_OBJECT_TO_PLAYER", single_id, "human_voice")
			return result

	result.error_message = "Command not recognized: '%s'" % raw_text
	return result

static func _ground_memory_commands(raw_text: String, normalized_text: String, result: GroundingResult) -> bool:
	if normalized_text.contains("what did you help me with") or normalized_text.contains("what did you do last time") or normalized_text.contains("did you bring me the red box before") or normalized_text.contains("what do you remember"):
		result.success = true
		result.is_memory_query = true
		if normalized_text.contains("red box"):
			result.memory_query_term = "red_box"
		elif normalized_text.contains("me"):
			result.memory_query_term = "human_player"
		else:
			result.memory_query_term = ""
		return true

	if normalized_text.begins_with("remember that") or normalized_text.begins_with("remember i") or normalized_text.begins_with("my preference is"):
		result.success = true
		result.is_memory_store_command = true
		result.memory_fact_text = raw_text.strip_edges()
		if normalized_text.contains("password") or normalized_text.contains("secret"):
			result.needs_confirmation = true
		return true

	if normalized_text == "clear all memory" or normalized_text == "clear memory":
		result.success = true
		result.is_memory_clear_all_command = true
		result.needs_confirmation = true
		return true

	if normalized_text.begins_with("forget"):
		result.success = true
		result.is_memory_forget_command = true
		var forget_term: String = raw_text.strip_edges()
		var lower: String = forget_term.to_lower()
		if lower.begins_with("forget that "):
			forget_term = forget_term.substr(12).strip_edges()
		elif lower == "forget that":
			forget_term = ""
		elif lower.begins_with("forget "):
			forget_term = forget_term.substr(7).strip_edges()
		result.memory_query_term = forget_term
		return true

	return false

static func _normalize_text(raw_text: String) -> String:
	var text: String = raw_text.to_lower().strip_edges()
	for punct in [".", ",", "!", "?", ";", ":", "'", "\""]:
		text = text.replace(punct, "")
	return text.strip_edges()
