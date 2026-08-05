class_name TaskRequest
extends RefCounted

var task_id: String = ""
var task_type: String = "BRING_OBJECT_TO_PLAYER"
var target_id: String = "red_box"
var requested_by: String = "human"
var created_at: float = 0.0
var steps: Array[ActionTypes.ActionRequest] = []

func _init(p_type: String = "BRING_OBJECT_TO_PLAYER", p_target_id: String = "red_box", p_requested_by: String = "human") -> void:
	task_id = "task_%d_%d" % [int(Time.get_ticks_msec()), randi() % 1000]
	task_type = p_type
	target_id = p_target_id
	requested_by = p_requested_by
	created_at = Time.get_ticks_msec() / 1000.0

	# Trusted Step Expansion
	if task_type == "BRING_OBJECT_TO_PLAYER":
		steps = [
			ActionTypes.ActionRequest.new(ActionTypes.Action.MOVE_TO_OBJECT, target_id, Vector3.ZERO, 0.0, "Approach " + target_id),
			ActionTypes.ActionRequest.new(ActionTypes.Action.PICK_UP_OBJECT, target_id, Vector3.ZERO, 0.0, "Pick up " + target_id),
			ActionTypes.ActionRequest.new(ActionTypes.Action.FOLLOW_PLAYER, "human_player", Vector3.ZERO, 0.0, "Bring " + target_id + " to player"),
			ActionTypes.ActionRequest.new(ActionTypes.Action.GIVE_OBJECT_TO_PLAYER, "human_player", Vector3.ZERO, 0.0, "Give " + target_id + " to player")
		]
