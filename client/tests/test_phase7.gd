extends SceneTree

var main_node: Node3D
var _tests_started: bool = false

func _init() -> void:
	print("\n==========================================")
	print("  ECHO Framework - Phase 7 Automated Test")
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
	var red_box: PortableObject = test_room.find_child("RedBox", true, false) as PortableObject
	var interaction_ctrl: InteractionController = apc.get_node_or_null("InteractionController") as InteractionController if apc else null
	var task_ctrl: TaskController = apc.get_node_or_null("TaskController") as TaskController if apc else null
	var carry_socket: CarriedObjectSocket = apc.get_node_or_null("CarrySocket") as CarriedObjectSocket if apc else null

	if apc == null or player == null or red_box == null or interaction_ctrl == null or task_ctrl == null or carry_socket == null:
		print("[FAIL] Missing Phase 7 required nodes (APC: %s, Player: %s, RedBox: %s, Interaction: %s, Task: %s, Socket: %s)." % [
			apc != null, player != null, red_box != null, interaction_ctrl != null, task_ctrl != null, carry_socket != null
		])
		quit(1)
		return

	print("[PASS] APC, Player, RedBox, InteractionController, TaskController, and CarrySocket present.")

	# Test 1: Portable Object Contract
	print("\n--- Test 1: Portable Object Contract ---")
	if not (red_box is PortableObject):
		print("[FAIL] RedBox does not extend PortableObject.")
		quit(1)
		return
	if red_box.object_id != "red_box" or not red_box.is_portable:
		print("[FAIL] RedBox metadata invalid.")
		quit(1)
		return
	if not red_box.is_in_group("perceivable") or not red_box.is_in_group("portable_object"):
		print("[FAIL] RedBox missing required groups.")
		quit(1)
		return
	print("[PASS] RedBox correctly implements PortableObject contract.")

	# Test 2 & 3: Pickup Validation (Range & Unknown Target)
	print("\n--- Test 2 & 3: Pickup Validation ---")
	# 3a: Pickup outside range
	apc.global_position = Vector3(10.0, 1.0, 10.0)
	red_box.global_position = Vector3(0.0, 0.5, 0.0)
	var res_far: ActionTypes.ActionResult = interaction_ctrl.request_pick_up("red_box")
	if res_far.success:
		print("[FAIL] Pickup outside range should have failed!")
		quit(1)
		return
	print("Far pickup rejection message: ", res_far.message)

	# 3b: Pickup unknown target
	var res_unknown: ActionTypes.ActionResult = interaction_ctrl.request_pick_up("nonexistent_alien_object")
	if res_unknown.success:
		print("[FAIL] Pickup unknown target should have failed!")
		quit(1)
		return
	print("Unknown target rejection message: ", res_unknown.message)

	# 3c: Pickup within range
	apc.global_position = Vector3(0.0, 1.0, 0.5) # 0.5m from red_box
	var res_near: ActionTypes.ActionResult = interaction_ctrl.request_pick_up("red_box")
	if not res_near.success:
		print("[FAIL] Pickup within range failed: ", res_near.message)
		quit(1)
		return
	print("[PASS] Pickup within range succeeded.")

	# Test 4 & 5: Held Object State & Double Pickup Protection
	print("\n--- Test 4 & 5: Carry Socket Attachment & Double Pickup Protection ---")
	if not red_box.is_held or red_box.current_holder_id != "apc":
		print("[FAIL] RedBox held state was not updated.")
		quit(1)
		return
	if red_box.get_parent() != carry_socket:
		print("[FAIL] RedBox was not reparented to CarrySocket.")
		quit(1)
		return

	var res_double: ActionTypes.ActionResult = interaction_ctrl.request_pick_up("red_box")
	if res_double.success:
		print("[FAIL] Pickup while already carrying should have failed!")
		quit(1)
		return
	print("[PASS] CarrySocket attachment and double pickup protection verified.")

	# Test 6: Safe Drop Execution
	print("\n--- Test 6: Safe Drop Execution ---")
	var res_drop: ActionTypes.ActionResult = interaction_ctrl.request_drop()
	if not res_drop.success:
		print("[FAIL] Drop held object failed: ", res_drop.message)
		quit(1)
		return
	if red_box.is_held or red_box.get_parent() == carry_socket:
		print("[FAIL] RedBox state not restored after drop.")
		quit(1)
		return
	print("[PASS] Safe drop executed and physics/state restored.")

	# Test 7: Give Object to Player Execution
	print("\n--- Test 7: Give Object to Player Execution ---")
	# Pickup again
	apc.global_position = red_box.global_position + Vector3(0, 0.5, 0.5)
	interaction_ctrl.request_pick_up("red_box")

	# Move near player
	apc.global_position = player.global_position + Vector3(0, 0, 1.0)
	var res_give: ActionTypes.ActionResult = interaction_ctrl.request_give_to_player()
	if not res_give.success:
		print("[FAIL] Give to player failed: ", res_give.message)
		quit(1)
		return
	if red_box.is_held:
		print("[FAIL] RedBox still held after give.")
		quit(1)
		return
	print("[PASS] Give to player executed successfully.")

	# Test 8: Task Request & Trusted Step Expansion
	print("\n--- Test 8: Task Request & Trusted Step Expansion ---")
	var task_req: TaskRequest = TaskRequest.new("BRING_OBJECT_TO_PLAYER", "red_box", "test")
	if task_req.steps.size() != 4:
		print("[FAIL] Task request step expansion invalid (expected 4 steps, got %d)." % task_req.steps.size())
		quit(1)
		return
	print("Expanded Task Steps: ", task_req.steps.map(func(s): return ActionTypes.get_action_name(s.action)))
	print("[PASS] Trusted task step expansion verified.")

	# Test 9: Task Controller Step Execution & Cancellation
	print("\n--- Test 9: Task Controller Step Execution & Cancellation ---")
	task_ctrl.start_task(task_req)
	if not task_ctrl.is_running_task:
		print("[FAIL] TaskController failed to start task.")
		quit(1)
		return
	task_ctrl.cancel_task()
	if task_ctrl.is_running_task or task_ctrl.get_task_status_string() != "CANCELLED":
		print("[FAIL] Task cancellation failed.")
		quit(1)
		return
	print("[PASS] Task starting and cancellation verified.")

	# Test 10: AI Task Validation & Raw Step Injection Guard
	print("\n--- Test 10: AI Task Validation & Raw Step Injection Guard ---")
	var snapshot: Dictionary = {
		"human_player": { "id": "human_player", "visible": true, "distance": 4.0, "last_seen_position": { "x": -4.0, "y": 1.0, "z": 4.0 } },
		"nearby_objects": [{ "id": "red_box", "visible": true, "distance": 2.0, "last_seen_position": { "x": 3.0, "y": 0.5, "z": 2.0 } }]
	}

	# 10a: Valid task call
	var valid_task_tool: Array = [{
		"function": {
			"name": "submit_apc_task",
			"arguments": { "task_type": "BRING_OBJECT_TO_PLAYER", "target_id": "red_box", "reason": "Player requested box" }
		}
	}]
	var val_task: AIDecisionAdapter.ValidationResult = AIDecisionAdapter.validate_and_convert("", valid_task_tool, snapshot)
	if not val_task.success or val_task.task_request == null:
		print("[FAIL] Valid submit_apc_task was rejected: ", val_task.error_message)
		quit(1)
		return

	# 10b: Injected raw steps rejection
	var injected_task_tool: Array = [{
		"function": {
			"name": "submit_apc_task",
			"arguments": { "task_type": "BRING_OBJECT_TO_PLAYER", "target_id": "red_box", "steps": ["RUN_CODE"] }
		}
	}]
	var val_injected: AIDecisionAdapter.ValidationResult = AIDecisionAdapter.validate_and_convert("", injected_task_tool, snapshot)
	if val_injected.success:
		print("[FAIL] Injected raw steps should have been rejected!")
		quit(1)
		return
	print("Injected raw steps error: ", val_injected.error_message)
	print("[PASS] AI task tool validation and step injection guard verified.")

	print("\n==========================================")
	print("  PHASE 7 PHYSICAL INTERACTION VERIFIED [OK]")
	print("==========================================\n")
	quit(0)
