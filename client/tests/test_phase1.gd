extends SceneTree

var main_node: Node3D
var _tests_started: bool = false

func _init() -> void:
	print("\n==========================================")
	print("  ECHO Framework - Phase 1 Automated Test")
	print("==========================================\n")
	
	var main_scene = load("res://scenes/main.tscn")
	if main_scene == null:
		print("[FAIL] Could not load res://scenes/main.tscn")
		quit(1)
		return
		
	main_node = main_scene.instantiate()
	root.add_child(main_node)

func _process(_delta: float) -> bool:
	if not _tests_started:
		_tests_started = true
		run_tests()
		quit(0)
		return true
	return false

func run_tests() -> void:
	# Test 1: Verify InputMap Actions
	print("\n--- Test 1: Input Map Verification ---")
	var actions = ["move_forward", "move_backward", "move_left", "move_right", "jump", "release_mouse"]
	for act in actions:
		if not InputMap.has_action(act):
			print("[FAIL] Missing InputMap action: %s" % act)
			quit(1)
			return
	print("[PASS] All required InputMap actions registered.")

	# Test 2: Node Hierarchy & Scene Loading
	print("\n--- Test 2: Scene Hierarchy Verification ---")
	var test_room = main_node.get_node_or_null("TestRoom")
	if test_room == null:
		print("[FAIL] TestRoom node missing.")
		quit(1)
		return
		
	var player = test_room.get_node_or_null("Player")
	var apc = test_room.get_node_or_null("APC")
	var crate = test_room.find_child("CrateObstacle", true, false)
	var floor_node = test_room.find_child("Floor", true, false)
	var hud = test_room.get_node_or_null("CanvasLayer/HUD")
	
	if player == null or apc == null or crate == null or floor_node == null or hud == null:
		print("[FAIL] Missing core environment nodes. (Player: %s, APC: %s, Crate: %s, Floor: %s, HUD: %s)" % [player != null, apc != null, crate != null, floor_node != null, hud != null])
		quit(1)
		return
		
	print("[PASS] Room, Player, APC, Crate, Floor, and HUD nodes present in hierarchy.")

	# Test 3: Physical Spawn & Collision Objects
	print("\n--- Test 3: Physical Geometry & Collision Setup ---")
	if not (player is CharacterBody3D):
		print("[FAIL] Player is not a CharacterBody3D.")
		quit(1)
		return
		
	if not (apc is CharacterBody3D):
		print("[FAIL] APC is not a CharacterBody3D.")
		quit(1)
		return
		
	print("Player Spawn Position: ", player.global_position)
	print("APC Spawn Position: ", apc.global_position)
	
	if player.global_position.distance_to(apc.global_position) < 2.0:
		print("[FAIL] Player and APC spawned too close.")
		quit(1)
		return
		
	print("[PASS] Player and APC spawned at distinct locations with collision bodies intact.")

	print("\n==========================================")
	print("  PHASE 1 VERIFICATION PASSED SUCCESSFULLY [OK]")
	print("==========================================\n")
