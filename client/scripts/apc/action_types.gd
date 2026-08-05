class_name ActionTypes
extends RefCounted

enum Action {
	NONE,
	IDLE,
	FOLLOW_PLAYER,
	LOOK_AT_PLAYER,
	LOOK_AT_OBJECT,
	MOVE_TO_POSITION,
	MOVE_TO_OBJECT,
	WAIT
}

static func get_action_name(action: Action) -> String:
	match action:
		Action.NONE: return "NONE"
		Action.IDLE: return "IDLE"
		Action.FOLLOW_PLAYER: return "FOLLOW_PLAYER"
		Action.LOOK_AT_PLAYER: return "LOOK_AT_PLAYER"
		Action.LOOK_AT_OBJECT: return "LOOK_AT_OBJECT"
		Action.MOVE_TO_POSITION: return "MOVE_TO_POSITION"
		Action.MOVE_TO_OBJECT: return "MOVE_TO_OBJECT"
		Action.WAIT: return "WAIT"
	return "UNKNOWN"

class ActionRequest extends RefCounted:
	var action: ActionTypes.Action = ActionTypes.Action.NONE
	var target_id: String = ""
	var target_position: Vector3 = Vector3.ZERO
	var duration: float = 0.0
	var reason: String = ""

	func _init(p_action: ActionTypes.Action = ActionTypes.Action.NONE, p_target_id: String = "", p_target_position: Vector3 = Vector3.ZERO, p_duration: float = 0.0, p_reason: String = "") -> void:
		action = p_action
		target_id = p_target_id
		target_position = p_target_position
		duration = p_duration
		reason = p_reason

class ActionResult extends RefCounted:
	var success: bool = true
	var status: String = "COMPLETED"
	var message: String = ""
	var time_started: float = 0.0
	var time_completed: float = 0.0

	func _init(p_success: bool = true, p_status: String = "COMPLETED", p_message: String = "", p_time_started: float = 0.0, p_time_completed: float = 0.0) -> void:
		success = p_success
		status = p_status
		message = p_message
		time_started = p_time_started
		time_completed = p_time_completed
