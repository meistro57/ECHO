extends SceneTree

var main_node: Node3D

func _init() -> void:
	print("\n==========================================")
	print("  ECHO Framework - Phase 6 Automated Test")
	print("==========================================\n")

	var main_scene = load("res://scenes/main.tscn")
	if main_scene == null:
		print("[FAIL] Could not load res://scenes/main.tscn")
		quit(1)
		return

	main_node = main_scene.instantiate() as Node3D
	root.add_child(main_node)

func _process(_delta: float) -> bool:
	run_tests()
	return false

func run_tests() -> void:
	await physics_frame
	await physics_frame
	await physics_frame

	var test_room = main_node.get_node_or_null("TestRoom")
	if test_room == null:
		print("[FAIL] TestRoom node missing.")
		quit(1)
		return

	var apc: APCController = test_room.get_node_or_null("APC") as APCController
	var brain: APCBrain = apc.get_node_or_null("Brain") as APCBrain if apc else null
	var ai_brain: AIBrain = brain.ai_brain if brain else null
	var action_ctrl: ActionController = apc.get_node_or_null("ActionController") as ActionController if apc else null

	if apc == null or brain == null or ai_brain == null or action_ctrl == null:
		print("[FAIL] Missing required Phase 6 nodes (APC: %s, Brain: %s, AIBrain: %s, ActionController: %s)." % [
			apc != null, brain != null, ai_brain != null, action_ctrl != null
		])
		quit(1)
		return

	print("[PASS] APC, Brain, AIBrain, and ActionController nodes present in scene tree.")

	# Test 1: Deterministic Mode Default
	print("\n--- Test 1: Deterministic Mode Default ---")
	if brain.get_mode_string() != "DETERMINISTIC":
		print("[FAIL] Expected default brain mode to be DETERMINISTIC.")
		quit(1)
		return
	print("[PASS] Deterministic brain mode is active by default.")

	# Test 2: Input Context Schema Verification
	print("\n--- Test 2: Input Context Schema Verification ---")
	var mock_snapshot: Dictionary = {
		"timestamp": 10.0,
		"human_player": {
			"id": "human_player",
			"visible": true,
			"distance": 6.4,
			"relative_direction": "front_left",
			"last_seen_position": { "x": -4.0, "y": 1.0, "z": 4.0 }
		},
		"nearby_objects": [
			{
				"id": "red_box",
				"visible": true,
				"distance": 4.2,
				"relative_direction": "right",
				"last_seen_position": { "x": 3.0, "y": 0.5, "z": 2.0 }
			}
		]
	}
	var ctx: Dictionary = ai_brain._build_input_context(mock_snapshot, "IDLE", ActionTypes.Action.WAIT)
	print("Context Keys: ", ctx.keys())
	if not (ctx.has("self") and ctx.has("human_player") and ctx.has("nearby_objects") and ctx.has("available_actions") and ctx.has("valid_target_ids")):
		print("[FAIL] Context missing required top-level schema keys.")
		quit(1)
		return
	print("[PASS] Input context schema contains expected perception and action metadata.")

	# Test 3: AIDecisionAdapter Validation - Valid Tool Calls
	print("\n--- Test 3: Valid Action Validation ---")
	var tool_calls_follow: Array = [{
		"function": {
			"name": "submit_apc_action",
			"arguments": {
				"action": "FOLLOW_PLAYER",
				"target_id": "human_player",
				"reason": "Player is far and visible"
			}
		}
	}]
	var val_follow: AIDecisionAdapter.ValidationResult = AIDecisionAdapter.validate_and_convert("", tool_calls_follow, mock_snapshot)
	if not val_follow.success or val_follow.action_request.action != ActionTypes.Action.FOLLOW_PLAYER:
		print("[FAIL] Valid FOLLOW_PLAYER tool call was rejected: ", val_follow.error_message)
		quit(1)
		return
	print("[PASS] Valid FOLLOW_PLAYER tool call correctly accepted.")

	var tool_calls_box: Array = [{
		"function": {
			"name": "submit_apc_action",
			"arguments": {
				"action": "MOVE_TO_OBJECT",
				"target_id": "red_box",
				"reason": "Approaching red box object"
			}
		}
	}]
	var val_box: AIDecisionAdapter.ValidationResult = AIDecisionAdapter.validate_and_convert("", tool_calls_box, mock_snapshot)
	if not val_box.success or val_box.action_request.action != ActionTypes.Action.MOVE_TO_OBJECT:
		print("[FAIL] Valid MOVE_TO_OBJECT for red_box was rejected: ", val_box.error_message)
		quit(1)
		return
	print("[PASS] Valid MOVE_TO_OBJECT for red_box correctly accepted.")

	# Test 4: AIDecisionAdapter Validation - Rejections
	print("\n--- Test 4: Invalid Action & Invented Target Rejections ---")

	# Rejection 4a: Invented Target
	var tool_calls_invented: Array = [{
		"function": {
			"name": "submit_apc_action",
			"arguments": {
				"action": "MOVE_TO_OBJECT",
				"target_id": "unknown_alien_ship"
			}
		}
	}]
	var val_invented: AIDecisionAdapter.ValidationResult = AIDecisionAdapter.validate_and_convert("", tool_calls_invented, mock_snapshot)
	if val_invented.success:
		print("[FAIL] Invented target_id 'unknown_alien_ship' should have been rejected!")
		quit(1)
		return
	print("Invented Target Error: ", val_invented.error_message)

	# Rejection 4b: Forbidden Action
	var tool_calls_forbidden: Array = [{
		"function": {
			"name": "submit_apc_action",
			"arguments": {
				"action": "RUN_CODE",
				"target_id": "human_player"
			}
		}
	}]
	var val_forbidden: AIDecisionAdapter.ValidationResult = AIDecisionAdapter.validate_and_convert("", tool_calls_forbidden, mock_snapshot)
	if val_forbidden.success:
		print("[FAIL] Forbidden action 'RUN_CODE' should have been rejected!")
		quit(1)
		return
	print("Forbidden Action Error: ", val_forbidden.error_message)

	# Rejection 4c: Target Type Mismatch (FOLLOW_PLAYER with red_box)
	var tool_calls_mismatch: Array = [{
		"function": {
			"name": "submit_apc_action",
			"arguments": {
				"action": "FOLLOW_PLAYER",
				"target_id": "red_box"
			}
		}
	}]
	var val_mismatch: AIDecisionAdapter.ValidationResult = AIDecisionAdapter.validate_and_convert("", tool_calls_mismatch, mock_snapshot)
	if val_mismatch.success:
		print("[FAIL] Target mismatch (FOLLOW_PLAYER with red_box) should have been rejected!")
		quit(1)
		return
	print("Target Mismatch Error: ", val_mismatch.error_message)
	print("[PASS] Invented targets, forbidden actions, and target mismatches cleanly rejected.")

	# Test 5: Fallback Behavior Verification
	print("\n--- Test 5: Fallback Behavior Verification ---")
	brain.set_brain_mode(APCBrain.BrainMode.AI)
	ai_brain.fallback_active = true
	var fallback_req: ActionTypes.ActionRequest = brain.decide_action_with_delta(0.016, mock_snapshot, "IDLE", ActionTypes.Action.NONE)
	print("Fallback Decision: ", ActionTypes.get_action_name(fallback_req.action))
	if fallback_req.action != ActionTypes.Action.FOLLOW_PLAYER:
		print("[FAIL] Expected fallback to DeterministicBrain (FOLLOW_PLAYER for far player).")
		quit(1)
		return
	print("[PASS] AI fallback seamlessly activated DeterministicBrain decision logic.")

	print("\n==========================================")
	print("  PHASE 6 AI DECISION BRIDGE VERIFIED [OK]")
	print("==========================================\n")
	quit(0)
