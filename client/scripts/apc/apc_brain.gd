class_name APCBrain
extends Node3D

enum BrainMode { DETERMINISTIC, AI }

@export var brain_mode: BrainMode = BrainMode.DETERMINISTIC
@export var follow_distance_threshold: float = 3.2

var deterministic_brain: DeterministicBrain
var ai_brain: AIBrain

signal mode_changed(new_mode: BrainMode)

func _ready() -> void:
	deterministic_brain = DeterministicBrain.new()
	deterministic_brain.follow_distance_threshold = follow_distance_threshold

	ai_brain = get_node_or_null("AIBrain") as AIBrain
	if ai_brain == null:
		ai_brain = AIBrain.new()
		ai_brain.name = "AIBrain"
		add_child(ai_brain)

	var env_mode: String = OS.get_environment("ECHO_BRAIN_MODE").to_lower().strip_edges()
	if env_mode == "ai":
		set_brain_mode(BrainMode.AI)
	else:
		set_brain_mode(BrainMode.DETERMINISTIC)

func set_brain_mode(new_mode: BrainMode) -> void:
	if new_mode == BrainMode.AI:
		if ai_brain == null:
			_connect_ai_brain()
		if ai_brain and ai_brain.ai_service and not ai_brain.ai_service.is_provider_configured():
			print("[APCBrain] Cannot switch to AI mode: AI Provider not configured.")
			brain_mode = BrainMode.DETERMINISTIC
			mode_changed.emit(brain_mode)
			return
		brain_mode = BrainMode.AI
	else:
		brain_mode = BrainMode.DETERMINISTIC
		if ai_brain and ai_brain.ai_service:
			ai_brain.ai_service.cancel_request()

	mode_changed.emit(brain_mode)

func toggle_brain_mode() -> String:
	if brain_mode == BrainMode.DETERMINISTIC:
		set_brain_mode(BrainMode.AI)
	else:
		set_brain_mode(BrainMode.DETERMINISTIC)
	return get_mode_string()

func decide_action_with_delta(delta: float, perception_snapshot: Dictionary, apc_state: String = "IDLE", current_action: ActionTypes.Action = ActionTypes.Action.NONE) -> ActionTypes.ActionRequest:
	if brain_mode == BrainMode.AI and ai_brain != null:
		ai_brain.process_ai_tick(delta, perception_snapshot, apc_state, current_action)
		
		if ai_brain.current_ai_action_request != null and not ai_brain.fallback_active:
			return ai_brain.current_ai_action_request
		else:
			# Fallback to Deterministic Brain
			return deterministic_brain.decide_action(perception_snapshot, apc_state, current_action)

	return deterministic_brain.decide_action(perception_snapshot, apc_state, current_action)

# Backward-compatible decide_action signature for test suite
func decide_action(perception_snapshot: Dictionary, apc_state: String = "IDLE", current_action: ActionTypes.Action = ActionTypes.Action.NONE) -> ActionTypes.ActionRequest:
	return decide_action_with_delta(0.016, perception_snapshot, apc_state, current_action)

func get_mode_string() -> String:
	match brain_mode:
		BrainMode.DETERMINISTIC: return "DETERMINISTIC"
		BrainMode.AI: return "AI"
	return "DETERMINISTIC"

func _connect_ai_brain() -> void:
	if ai_brain:
		ai_brain._connect_ai_service()
