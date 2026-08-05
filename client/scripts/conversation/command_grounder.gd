class_name CommandGrounder
extends RefCounted

class GroundingResult extends RefCounted:
	var success: bool = false
	var action_request: ActionTypes.ActionRequest = null
	var task_request: TaskRequest = null
	var is_cancel: bool = false
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
	var res: GroundingResult = GroundingResult.new()
	var text: String = raw_text.to_lower().strip_edges()

	# Strip punctuation
	for p in [".", ",", "!", "?", ";", ":", "'", "\""]:
		text = text.replace(p, "")
	text = text.strip_edges()

	if text.is_empty():
		res.error_message = "Empty input text"
		return res

	# 1. Cancel commands
	if text == "cancel" or text == "cancel task" or text == "stop task" or text == "stop":
		res.success = true
		res.is_cancel = true
		return res

	# 2. Check pending clarification resolution
	if not pending_clarification_target.is_empty():
		if text.contains("red") or text.contains("box"):
			res.success = true
			res.resolved_target_id = "red_box"
			res.task_request = TaskRequest.new("BRING_OBJECT_TO_PLAYER", "red_box", "human_voice")
			return res

	# 3. Direct deterministic commands
	# 3a: FOLLOW_PLAYER
	if text.contains("follow me") or text.contains("come here") or text.contains("come over here"):
		res.success = true
		res.action_request = ActionTypes.ActionRequest.new(ActionTypes.Action.FOLLOW_PLAYER, "human_player", Vector3.ZERO, 0.0, "Spoken follow request")
		return res

	# 3b: WAIT
	if text == "wait" or text == "wait there" or text == "hold on":
		res.success = true
		res.action_request = ActionTypes.ActionRequest.new(ActionTypes.Action.WAIT, "human_player", Vector3.ZERO, 0.0, "Spoken wait request")
		return res

	# 3c: LOOK_AT_PLAYER
	if text.contains("look at me"):
		res.success = true
		res.action_request = ActionTypes.ActionRequest.new(ActionTypes.Action.LOOK_AT_PLAYER, "human_player", Vector3.ZERO, 0.0, "Spoken look at player request")
		return res

	# 3d: LOOK_AT_OBJECT
	if text.contains("look at the red box") or text.contains("look at red box"):
		res.success = true
		res.resolved_target_id = "red_box"
		res.action_request = ActionTypes.ActionRequest.new(ActionTypes.Action.LOOK_AT_OBJECT, "red_box", Vector3.ZERO, 0.0, "Spoken look at object request")
		return res

	# 3e: MOVE_TO_OBJECT
	if text.contains("go to the red box") or text.contains("move to red box"):
		res.success = true
		res.resolved_target_id = "red_box"
		res.action_request = ActionTypes.ActionRequest.new(ActionTypes.Action.MOVE_TO_OBJECT, "red_box", Vector3.ZERO, 0.0, "Spoken move to object request")
		return res

	# 3f: DROP_HELD_OBJECT
	if text.contains("drop the box") or text.contains("drop it") or text == "drop":
		if held_object != null:
			res.success = true
			res.action_request = ActionTypes.ActionRequest.new(ActionTypes.Action.DROP_HELD_OBJECT, held_object.object_id, Vector3.ZERO, 0.0, "Spoken drop request")
			return res
		else:
			res.error_message = "Cannot drop: APC is not holding any object"
			return res

	# 3g: GIVE_OBJECT_TO_PLAYER
	if text.contains("give me the box") or text.contains("give it to me") or text == "give it":
		if held_object != null:
			res.success = true
			res.action_request = ActionTypes.ActionRequest.new(ActionTypes.Action.GIVE_OBJECT_TO_PLAYER, "human_player", Vector3.ZERO, 0.0, "Spoken give request")
			return res
		else:
			res.error_message = "Cannot give: APC is not holding any object"
			return res

	# 3h: PICK_UP_OBJECT
	if text.contains("pick up the red box") or text.contains("pick up the box") or text.contains("pick up red box"):
		res.success = true
		res.resolved_target_id = "red_box"
		res.action_request = ActionTypes.ActionRequest.new(ActionTypes.Action.PICK_UP_OBJECT, "red_box", Vector3.ZERO, 0.0, "Spoken pickup request")
		return res

	# 3i: BRING_OBJECT_TO_PLAYER
	if text.contains("bring me the red box") or text.contains("bring me that red box") or text.contains("bring red box"):
		res.success = true
		res.resolved_target_id = "red_box"
		res.task_request = TaskRequest.new("BRING_OBJECT_TO_PLAYER", "red_box", "human_voice")
		return res

	# 4. Reference Grounding ("that", "it", "this", "the box")
	if text.contains("bring me that") or text.contains("bring it to me") or text == "bring me the box":
		# Check player attention aim target
		var aim_target: String = String(attention_snapshot.get("aim_target_id", ""))
		if aim_target == "red_box":
			res.success = true
			res.resolved_target_id = "red_box"
			res.task_request = TaskRequest.new("BRING_OBJECT_TO_PLAYER", "red_box", "human_voice")
			return res

		# Check if multiple candidates or ambiguous reference
		var candidate_objects: Array[String] = []
		if perception_snapshot.has("nearby_objects"):
			var objs: Array = perception_snapshot["nearby_objects"]
			for obj in objs:
				if obj is Dictionary and obj.has("id"):
					candidate_objects.append(String(obj["id"]))

		if candidate_objects.size() > 1:
			res.success = false
			res.needs_clarification = true
			res.clarification_prompt = "Which object do you mean?"
			return res
		elif candidate_objects.size() == 1:
			var single_id: String = candidate_objects[0]
			res.success = true
			res.resolved_target_id = single_id
			res.task_request = TaskRequest.new("BRING_OBJECT_TO_PLAYER", single_id, "human_voice")
			return res

	res.error_message = "Command not recognized: '%s'" % raw_text
	return res
