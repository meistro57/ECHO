extends SceneTree

var main_node: Node3D
var _tests_started: bool = false

func _init() -> void:
	print("\n==========================================")
	print("  ECHO Framework - Phase 4 Automated Test")
	print("==========================================\n")

	var main_scene = load("res://scenes/main.tscn")
	if main_scene == null:
		print("[FAIL] Could not load res://scenes/main.tscn")
		quit(1)
		return

	main_node = main_scene.instantiate() as Node3D
	root.add_child(main_node)

func _process(_delta: float) -> bool:
	if not _tests_started:
		_tests_started = true
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
	var player: Node3D = test_room.get_node_or_null("Player") as Node3D
	var brain: APCBrain = apc.get_node_or_null("Brain") as APCBrain if apc else null
	var action_ctrl: ActionController = apc.get_node_or_null("ActionController") as ActionController if apc else null

	if apc == null or player == null or brain == null or action_ctrl == null:
		print("[FAIL] Missing required Phase 4 nodes (APC: %s, Player: %s, Brain: %s, ActionController: %s)." % [apc != null, player != null, brain != null, action_ctrl != null])
		quit(1)
		return

	print("[PASS] APC, Player, Brain, and ActionController components present in scene tree.")

	# Test 1: Brain Decision Rule 1 - FOLLOW_PLAYER
	print("\n--- Test 1: Brain Rule 1 (FOLLOW_PLAYER) ---")
	var perc_far: Dictionary = {
		"timestamp": 1.0,
		"human_player": {
			"id": "human_player",
			"distance": 8.0,
			"visible": true,
			"last_seen_position": { "x": -4.0, "y": 1.0, "z": 4.0 }
		}
	}
	var req_far: ActionTypes.ActionRequest = brain.decide_action(perc_far)
	print("Far Player (8.0m) -> Brain Decision: %s" % ActionTypes.get_action_name(req_far.action))
	if req_far.action != ActionTypes.Action.FOLLOW_PLAYER:
		print("[FAIL] Expected FOLLOW_PLAYER when player is visible and > 3.2m away.")
		quit(1)
		return
	print("[PASS] Brain correctly chose FOLLOW_PLAYER when player is far and visible.")

	# Test 2: Brain Decision Rule 2 - LOOK_AT_PLAYER
	print("\n--- Test 2: Brain Rule 2 (LOOK_AT_PLAYER) ---")
	var perc_near: Dictionary = {
		"timestamp": 2.0,
		"human_player": {
			"id": "human_player",
			"distance": 2.0,
			"visible": true,
			"last_seen_position": { "x": 1.0, "y": 1.0, "z": 1.0 }
		}
	}
	var req_near: ActionTypes.ActionRequest = brain.decide_action(perc_near)
	print("Near Player (2.0m) -> Brain Decision: %s" % ActionTypes.get_action_name(req_near.action))
	if req_near.action != ActionTypes.Action.LOOK_AT_PLAYER:
		print("[FAIL] Expected LOOK_AT_PLAYER when player is visible and <= 3.2m away.")
		quit(1)
		return
	print("[PASS] Brain correctly chose LOOK_AT_PLAYER when player is near and visible.")

	# Test 3: Brain Decision Rule 3 - WAIT
	print("\n--- Test 3: Brain Rule 3 (WAIT) ---")
	var perc_hidden: Dictionary = {
		"timestamp": 3.0,
		"human_player": {
			"id": "human_player",
			"distance": 5.0,
			"visible": false,
			"last_seen_position": { "x": -4.0, "y": 1.0, "z": 4.0 }
		}
	}
	var req_hidden: ActionTypes.ActionRequest = brain.decide_action(perc_hidden)
	print("Hidden Player -> Brain Decision: %s" % ActionTypes.get_action_name(req_hidden.action))
	if req_hidden.action != ActionTypes.Action.WAIT:
		print("[FAIL] Expected WAIT when player is not visible.")
		quit(1)
		return
	print("[PASS] Brain correctly chose WAIT when player is hidden.")

	# Test 4: Brain Decision Rule 4 - IDLE
	print("\n--- Test 4: Brain Rule 4 (IDLE) ---")
	var req_empty: ActionTypes.ActionRequest = brain.decide_action({})
	print("Empty Perception -> Brain Decision: %s" % ActionTypes.get_action_name(req_empty.action))
	if req_empty.action != ActionTypes.Action.IDLE:
		print("[FAIL] Expected IDLE when perception snapshot is empty.")
		quit(1)
		return
	print("[PASS] Brain correctly chose IDLE when perception is empty.")

	# Test 5: ActionController Execution & Event Logging
	print("\n--- Test 5: ActionController Execution & Rolling Event Log ---")
	action_ctrl.execute_action_request(req_far, 0.016, true, player)
	action_ctrl.execute_action_request(req_near, 0.016, true, player)
	action_ctrl.execute_action_request(req_hidden, 0.016, false, player)

	var log_entries: Array[String] = action_ctrl.get_event_log()
	print("Event Log Entries Count: %d" % log_entries.size())
	if log_entries.size() == 0:
		print("[FAIL] Event log is empty.")
		quit(1)
		return

	print("Latest Log Entry: ", log_entries[0])
	print("[PASS] ActionController correctly recorded action transitions in rolling event log.")

	print("\n==========================================")
	print("  PHASE 4 BRAIN & ACTION PIPELINE VERIFIED [OK]")
	print("==========================================\n")
	quit(0)
