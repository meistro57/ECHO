extends SceneTree

var main_node: Node3D
var _tests_started: bool = false

func _init() -> void:
	print("\n==========================================")
	print("  ECHO Framework - Phase 3 Automated Test")
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
	var red_box: Node3D = test_room.get_node_or_null("NavigationRegion3D/RedBox") as Node3D
	var perception: APCPerception = apc.get_node_or_null("Perception") as APCPerception if apc else null

	if apc == null or player == null or red_box == null or perception == null:
		print("[FAIL] Missing required Phase 3 nodes (APC: %s, Player: %s, RedBox: %s, Perception: %s)." % [apc != null, player != null, red_box != null, perception != null])
		quit(1)
		return

	print("[PASS] APC, Player, RedBox, and Perception component present in scene tree.")

	# Test 1: Perception Snapshot Structure
	print("\n--- Test 1: Perception Snapshot Structure ---")
	var snapshot: Dictionary = perception.get_perception_snapshot()
	if not (snapshot.has("timestamp") and snapshot.has("self") and snapshot.has("human_player") and snapshot.has("nearby_objects")):
		print("[FAIL] Snapshot missing required top-level keys.")
		quit(1)
		return

	var self_data: Dictionary = snapshot["self"]
	if not (self_data.has("position") and self_data.has("forward") and self_data.has("state")):
		print("[FAIL] Self data missing required fields.")
		quit(1)
		return
	print("[PASS] Snapshot schema valid with self position, forward, and state.")

	# Test 2: Perceived Entities Identification
	print("\n--- Test 2: Perceived Entities Identification ---")
	var p_data: Dictionary = snapshot["human_player"]
	if p_data.get("id") != "human_player" or p_data.get("display_name") != "Human Player":
		print("[FAIL] Human player metadata invalid: %s" % p_data)
		quit(1)
		return

	var objects: Array = snapshot["nearby_objects"]
	var found_redbox: bool = false
	for obj in objects:
		if obj is Dictionary and obj.get("id") == "red_box":
			found_redbox = true
			if obj.get("category") != "portable_object":
				print("[FAIL] Red box category mismatch: %s" % obj.get("category"))
				quit(1)
				return
	if not found_redbox:
		print("[FAIL] Red Box entity not found in nearby_objects array.")
		quit(1)
		return
	print("[PASS] Human Player and Red Box entities correctly identified in snapshot.")

	# Test 3: Distance and Range Logic
	print("\n--- Test 3: Distance and Range Calculation ---")
	var calculated_dist: float = apc.global_position.distance_to(player.global_position)
	var snapshot_dist: float = float(p_data.get("distance", 0.0))
	if abs(calculated_dist - snapshot_dist) > 1.5:
		print("[FAIL] Snapshot distance mismatch: calculated %.2f vs snapshot %.2f" % [calculated_dist, snapshot_dist])
		quit(1)
		return
	print("[PASS] Distance calculation accurate (%.2fm)." % snapshot_dist)

	# Test 4: Field of View Rejection
	print("\n--- Test 4: Field of View Rejection ---")
	# Rotate APC to face away from player (Player at -4,1,4; APC at 4,1,-4. Facing +X +Z away from player)
	apc.rotation.y = 0.0 # Facing -Z (away from player at -4,1,4)
	perception._update_perception()
	var snapshot_fov: Dictionary = perception.get_perception_snapshot()
	var p_fov_data: Dictionary = snapshot_fov["human_player"]
	print("Player Behind APC -> Inside FOV: %s | Visible: %s" % [p_fov_data.get("inside_fov"), p_fov_data.get("visible")])
	if p_fov_data.get("inside_fov") == true or p_fov_data.get("visible") == true:
		print("[FAIL] Entity behind APC should have inside_fov = false and visible = false.")
		quit(1)
		return
	print("[PASS] Entity outside FOV correctly rejected.")

	# Test 5: Short-Term Memory Persistence & Expiration
	print("\n--- Test 5: Short-Term Memory Persistence & Expiration ---")
	# 1. Turn APC toward player to make visible
	apc.look_at(player.global_position, Vector3.UP)
	perception._update_perception()
	var visible_snapshot: Dictionary = perception.get_perception_snapshot()
	var vis_p_data: Dictionary = visible_snapshot["human_player"]
	print("Facing Player -> Visible: %s | LastSeenPos: %s" % [vis_p_data.get("visible"), vis_p_data.get("last_seen_position")])
	
	# 2. Turn APC away to hide player
	apc.rotation.y = 0.0
	perception._update_perception()
	var hidden_snapshot: Dictionary = perception.get_perception_snapshot()
	var hid_p_data: Dictionary = hidden_snapshot["human_player"]
	print("Turned Away -> Visible: %s | LastSeenPos: %s | SecondsSinceLastSeen: %s" % [
		hid_p_data.get("visible"), hid_p_data.get("last_seen_position"), hid_p_data.get("seconds_since_last_seen")
	])
	
	if hid_p_data.get("visible") == true or hid_p_data.get("last_seen_position") == null:
		print("[FAIL] Short-term memory should retain last_seen_position immediately after target becomes hidden.")
		quit(1)
		return

	# 3. Simulate memory expiration beyond memory_duration
	perception._memory_map["human_player"]["timestamp"] = (Time.get_ticks_msec() / 1000.0) - (perception.memory_duration + 1.0)
	perception._update_perception()
	var expired_snapshot: Dictionary = perception.get_perception_snapshot()
	var exp_p_data: Dictionary = expired_snapshot["human_player"]
	print("After Memory Expiry -> LastSeenPos: %s | SecondsSinceLastSeen: %s" % [
		exp_p_data.get("last_seen_position"), exp_p_data.get("seconds_since_last_seen")
	])
	
	if exp_p_data.get("last_seen_position") != null:
		print("[FAIL] Short-term memory failed to expire after memory_duration.")
		quit(1)
		return
	print("[PASS] Short-term memory correctly retained last-seen position and expired after memory_duration.")

	print("\n==========================================")
	print("  PHASE 3 PERCEPTION VERIFICATION PASSED [OK]")
	print("==========================================\n")
	quit(0)
