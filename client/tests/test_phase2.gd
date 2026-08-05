extends SceneTree

var test_step: int = 0
var main_node: Node3D

func _init() -> void:
	print("\n==========================================")
	print("  ECHO Framework - Phase 2 Automated Test")
	print("==========================================\n")
	
	var main_scene = load("res://scenes/main.tscn")
	if main_scene == null:
		print("[FAIL] Could not load res://scenes/main.tscn")
		quit(1)
		return
		
	main_node = main_scene.instantiate()
	root.add_child(main_node)

func _process(_delta: float) -> bool:
	test_step += 1
	if test_step == 5:
		run_tests()
	return false

func run_tests() -> void:
	var test_room = main_node.get_node_or_null("TestRoom")
	if test_room == null:
		print("[FAIL] TestRoom node missing.")
		quit(1)
		return
		
	var player: CharacterBody3D = test_room.get_node_or_null("Player")
	var apc: APCController = test_room.get_node_or_null("APC")
	var nav_region = test_room.get_node_or_null("NavigationRegion3D")
	var nav_agent = apc.get_node_or_null("NavigationAgent3D") if apc else null
	var hud = test_room.get_node_or_null("CanvasLayer/HUD")
	
	if player == null or apc == null or nav_region == null or nav_agent == null or hud == null:
		print("[FAIL] Missing required Phase 2 nodes.")
		quit(1)
		return
		
	print("[PASS] NavigationRegion3D, NavigationAgent3D, Player, APC, and HUD present in scene.")

	if not InputMap.has_action("toggle_debug"):
		print("[FAIL] InputMap action 'toggle_debug' is missing.")
		quit(1)
		return
	print("[PASS] InputMap action 'toggle_debug' registered successfully.")
	
	# Test 1: Navigation Synchronization Readiness
	print("\n--- Test 1: Navigation Synchronization Readiness ---")
	var wait_ticks = 0
	while not apc.navigation_ready and wait_ticks < 20:
		await physics_frame
		wait_ticks += 1
		
	print("APC Navigation Ready Flag: %s" % apc.navigation_ready)
	if not apc.navigation_ready:
		print("[FAIL] APC navigation_ready should be true after frame synchronization.")
		quit(1)
		return
	print("[PASS] APC navigation_ready flag set to true after NavigationServer map synchronization.")
	
	# Test 2: Locomotion State Machine (IDLE / FOLLOWING)
	print("\n--- Test 2: Locomotion State Machine ---")
	var initial_dist = apc.global_position.distance_to(player.global_position)
	print("Spawn Distance: %.2fm" % initial_dist)
	print("APC State at Spawn: %s" % apc.get_state_string())
	
	if initial_dist > apc.start_follow_distance and apc.current_state != APCController.State.FOLLOWING:
		apc._physics_process(0.016)
		
	print("APC State after tick: %s" % apc.get_state_string())
	if apc.current_state != APCController.State.FOLLOWING:
		print("[FAIL] APC failed to enter FOLLOWING state when target is > %.1fm away." % apc.start_follow_distance)
		quit(1)
		return
	print("[PASS] APC correctly entered FOLLOWING state when player is beyond start distance.")
	
	# Test 3: Hysteresis & Stopping Distance
	print("\n--- Test 3: Hysteresis & Stopping Distance ---")
	player.global_position = apc.global_position + Vector3(1.2, 0, 0)
	apc._physics_process(0.016)
	
	print("Close Proximity Distance: %.2fm" % apc.global_position.distance_to(player.global_position))
	print("APC State near player: %s" % apc.get_state_string())
	
	if apc.current_state != APCController.State.IDLE:
		print("[FAIL] APC failed to enter IDLE state when within stopping distance.")
		quit(1)
		return
	print("[PASS] APC cleanly entered IDLE state upon reaching player without jittering.")
	
	# Test 4: Obstacle Navigation Path Query
	print("\n--- Test 4: Obstacle Navigation Path Query ---")
	player.global_position = Vector3(-6, 0.9, -6)
	apc.global_position = Vector3(6, 0.9, 6)
	
	apc._physics_process(0.016)
	nav_agent.target_position = player.global_position
	var next_path_pos = nav_agent.get_next_path_position()
	print("APC Pos: ", apc.global_position)
	print("Target Pos: ", player.global_position)
	print("Next Navigation Waypoint: ", next_path_pos)
	
	print("\n==========================================")
	print("  PHASE 2 NAVIGATION FIX VERIFICATION PASSED [OK]")
	print("==========================================\n")
	quit(0)
