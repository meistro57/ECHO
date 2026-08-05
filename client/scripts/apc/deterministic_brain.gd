class_name DeterministicBrain
extends RefCounted

var follow_distance_threshold: float = 3.2

func decide_action(perception_snapshot: Dictionary, _apc_state: String = "IDLE", _current_action: ActionTypes.Action = ActionTypes.Action.NONE) -> ActionTypes.ActionRequest:
	# Rule 4: If no perception data exists -> IDLE
	if perception_snapshot.is_empty() or not perception_snapshot.has("human_player"):
		return ActionTypes.ActionRequest.new(
			ActionTypes.Action.IDLE,
			"",
			Vector3.ZERO,
			0.0,
			"No perception data"
		)

	var p_data: Dictionary = perception_snapshot["human_player"]
	if p_data.is_empty():
		return ActionTypes.ActionRequest.new(
			ActionTypes.Action.IDLE,
			"",
			Vector3.ZERO,
			0.0,
			"No human player perception data"
		)

	var player_visible: bool = bool(p_data.get("visible", false))
	var player_dist: float = float(p_data.get("distance", 0.0))
	var player_last_seen_dict: Variant = p_data.get("last_seen_position", null)

	var player_pos: Vector3 = Vector3.ZERO
	if player_last_seen_dict is Dictionary:
		var dict_pos: Dictionary = player_last_seen_dict as Dictionary
		player_pos = Vector3(
			float(dict_pos.get("x", 0.0)),
			float(dict_pos.get("y", 0.0)),
			float(dict_pos.get("z", 0.0))
		)

	# Rule 1: Player visible AND distance > follow_distance_threshold -> FOLLOW_PLAYER
	if player_visible and player_dist > follow_distance_threshold:
		return ActionTypes.ActionRequest.new(
			ActionTypes.Action.FOLLOW_PLAYER,
			"human_player",
			player_pos,
			0.0,
			"Player visible and beyond follow distance"
		)

	# Rule 2: Player visible AND distance <= follow_distance_threshold -> LOOK_AT_PLAYER
	if player_visible and player_dist <= follow_distance_threshold:
		return ActionTypes.ActionRequest.new(
			ActionTypes.Action.LOOK_AT_PLAYER,
			"human_player",
			player_pos,
			0.0,
			"Player visible and within close range"
		)

	# Rule 3: Player not visible -> WAIT
	if not player_visible:
		return ActionTypes.ActionRequest.new(
			ActionTypes.Action.WAIT,
			"human_player",
			player_pos,
			0.0,
			"Player not visible"
		)

	return ActionTypes.ActionRequest.new(
		ActionTypes.Action.IDLE,
		"",
		Vector3.ZERO,
		0.0,
		"Default idle fallback"
	)
