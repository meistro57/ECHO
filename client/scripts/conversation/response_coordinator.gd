class_name ResponseCoordinator
extends RefCounted

static func select_response_text(ground_res: CommandGrounder.GroundingResult) -> String:
	if ground_res == null:
		return "I couldn't complete that."

	if ground_res.is_cancel:
		return "Cancelled."

	if ground_res.needs_clarification:
		return ground_res.clarification_prompt if not ground_res.clarification_prompt.is_empty() else "Which object do you mean?"

	if not ground_res.success:
		return "I couldn't complete that."

	if ground_res.task_request != null:
		match ground_res.task_request.task_type:
			"BRING_OBJECT_TO_PLAYER":
				return "I'll bring it to you."
			_:
				return "Starting task."

	if ground_res.action_request != null:
		match ground_res.action_request.action:
			ActionTypes.Action.FOLLOW_PLAYER:
				return "Coming."
			ActionTypes.Action.WAIT:
				return "I'll wait here."
			ActionTypes.Action.LOOK_AT_PLAYER:
				return "Looking at you."
			ActionTypes.Action.LOOK_AT_OBJECT:
				return "I see it."
			ActionTypes.Action.MOVE_TO_OBJECT:
				return "Moving to object."
			ActionTypes.Action.PICK_UP_OBJECT:
				return "I've got it."
			ActionTypes.Action.DROP_HELD_OBJECT:
				return "Dropping it."
			ActionTypes.Action.GIVE_OBJECT_TO_PLAYER:
				return "Here you go."
			_:
				return "Understood."

	return "Understood."
