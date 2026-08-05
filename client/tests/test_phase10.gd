extends SceneTree

var main_node: Node3D
var test_file_path: String = "user://test_phase10_world.json"
var _tests_started: bool = false

func _init() -> void:
	print("\n==========================================")
	print("  ECHO Framework - Phase 10 Automated Test")
	print("==========================================\n")

	_cleanup_test_files()
	var main_scene: PackedScene = load("res://scenes/main.tscn")
	if main_scene == null:
		_fail_and_quit("Could not load res://scenes/main.tscn")
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
	await physics_frame

	var test_room: Node = main_node.get_node_or_null("TestRoom")
	if test_room == null:
		_fail_and_quit("TestRoom node missing.")
		return

	var world_service: WorldStateService = test_room.get_node_or_null("WorldStateService") as WorldStateService
	if world_service == null:
		_fail_and_quit("WorldStateService node missing.")
		return

	var red_box: PortableObject = test_room.find_child("RedBox", true, false) as PortableObject
	var apc: APCController = test_room.get_node_or_null("APC") as APCController
	if red_box == null or apc == null:
		_fail_and_quit("RedBox or APC missing.")
		return

	# Point service at an isolated test store and disable autosave for determinism
	world_service.active_store = JSONWorldStateStore.new(test_file_path)
	world_service.registry = WorldStateRegistry.new()
	world_service.autosave_enabled = false
	world_service._session_id = "test_session_10"
	world_service._refresh_registry()
	world_service.load_world_state()
	await physics_frame

	var registry: WorldStateRegistry = world_service.registry
	_assert_true(registry.contains_id("red_box"), "PersistentEntity 'red_box' registered in registry")

	# Test 2: duplicate ID rejection
	var entity: PersistentEntity = registry.get_entity("red_box")
	_assert_true(not registry.register_entity(entity), "Duplicate persistent_id registration rejected")

	# Test 3: transform save/load round-trip
	print("\n--- Transform Save/Load Round-Trip ---")
	red_box.global_position = Vector3(2.0, 0.5, 3.0)
	red_box.rotation_degrees = Vector3(0.0, 90.0, 0.0)
	await physics_frame
	var saved_ok: bool = world_service.save_world_state()
	_assert_true(saved_ok, "Manual save succeeded")

	var reload_store: JSONWorldStateStore = JSONWorldStateStore.new(test_file_path)
	var envelope: Dictionary = reload_store.load_envelope()
	var entities: Array = envelope.get("entities", [])
	_assert_true(entities.size() >= 1, "Save envelope contains entity records")

	var red_record: WorldStateRecord = null
	for raw in entities:
		var rec: WorldStateRecord = WorldStateRecord.from_dict(raw)
		if rec.persistent_id == "red_box":
			red_record = rec
	_assert_true(red_record != null, "Red Box record present in save file")
	_assert_true(red_record.transform.origin.distance_to(Vector3(2.0, 0.5, 3.0)) < 0.01, "Transform origin round-trips")
	_assert_true(WorldStateRecord.is_finite_transform(red_record.transform), "Serialized transform is finite")

	# Test 4: Red Box position persists across a fresh load
	print("\n--- Red Box Persistence ---")
	red_box.global_position = Vector3(0.0, 0.5, 0.0)
	await physics_frame
	world_service.load_world_state()
	await physics_frame
	await physics_frame
	_assert_true(red_box.global_position.distance_to(Vector3(2.0, 0.5, 3.0)) < 0.2, "Red Box restored to saved position")
	var yaw_basis_x: float = absf(red_box.global_transform.basis.x.x)
	_assert_true(absf(yaw_basis_x) < 0.05, "Red Box orientation restored (rotated 90 degrees)")

	# Test 5: held-state restoration
	print("\n--- Held-State Restoration ---")
	red_box.global_position = apc.global_position + Vector3(0.5, 0.5, 0.0)
	await physics_frame
	var pick_result: ActionTypes.ActionResult = apc.interaction_controller.request_pick_up("red_box")
	_assert_true(pick_result.success, "Pickup succeeded for held-state test")
	await physics_frame
	_assert_true(world_service.save_world_state(), "Save with held Red Box succeeded")

	var held_store: JSONWorldStateStore = JSONWorldStateStore.new(test_file_path)
	var held_envelope: Dictionary = held_store.load_envelope()
	var held_found: bool = false
	for raw in held_envelope.get("entities", []):
		var rec: WorldStateRecord = WorldStateRecord.from_dict(raw)
		if rec.persistent_id == "red_box" and rec.held_by == "apc":
			held_found = true
	_assert_true(held_found, "Held Red Box saved with held_by=apc")

	apc.interaction_controller.request_drop()
	red_box.global_position = Vector3(5.0, 0.5, 5.0)
	await physics_frame
	world_service.load_world_state()
	await physics_frame
	await physics_frame
	_assert_true(apc.interaction_controller.get_held_object() == red_box, "Held Red Box restored to CarrySocket")
	apc.interaction_controller.request_drop()
	await physics_frame

	# Test 6: invalid (out-of-bounds) coordinates rejected
	print("\n--- Invalid Coordinates ---")
	var invalid_record: WorldStateRecord = WorldStateRecord.new("red_box", "portable_object")
	invalid_record.transform.origin = Vector3(500.0, 500.0, 500.0)
	var invalid_envelope: Dictionary = _make_envelope(world_service, [invalid_record.to_dict()], {})
	world_service.active_store.save_envelope(invalid_envelope)
	var default_origin: Vector3 = registry.get_entity("red_box").get_default_transform().origin
	red_box.global_position = Vector3(0.0, 0.5, 0.0)
	await physics_frame
	world_service.load_world_state()
	await physics_frame
	_assert_true(red_box.global_position.distance_to(default_origin) < 0.2, "Out-of-bounds transform falls back to default")

	# Test 6b: wrong world id rejected safely
	print("\n--- Wrong World ID ---")
	var wrong_world: Dictionary = _make_envelope(world_service, [], {})
	wrong_world["world_id"] = "some_other_world"
	world_service.active_store.save_envelope(wrong_world)
	world_service.load_world_state()
	_assert_true(world_service.last_error.contains("world"), "Wrong world id reported safely")

	# Test 7: corruption recovery (no backup)
	print("\n--- Corruption Recovery ---")
	var corrupt_file: FileAccess = FileAccess.open(test_file_path, FileAccess.WRITE)
	if corrupt_file:
		corrupt_file.store_string("{ corrupted json !!!")
		corrupt_file.close()
	DirAccess.remove_absolute(_backup_path())
	var corrupt_store: JSONWorldStateStore = JSONWorldStateStore.new(test_file_path)
	var corrupt_envelope: Dictionary = corrupt_store.load_envelope()
	_assert_true(corrupt_envelope.is_empty(), "Corrupt active file recovers to default without crashing")

	# Test 8: backup recovery
	print("\n--- Backup Recovery ---")
	var backup_origin: Vector3 = Vector3(1.0, 0.5, 1.0)
	var backup_record: WorldStateRecord = WorldStateRecord.new("red_box", "portable_object")
	backup_record.transform.origin = backup_origin
	var good_store: JSONWorldStateStore = JSONWorldStateStore.new(test_file_path)
	good_store.save_envelope(_make_envelope(world_service, [backup_record.to_dict()], {}))
	good_store.save_envelope(_make_envelope(world_service, [backup_record.to_dict()], {}))
	corrupt_file = FileAccess.open(test_file_path, FileAccess.WRITE)
	if corrupt_file:
		corrupt_file.store_string("{ corrupted again !!!")
		corrupt_file.close()
	var backup_store: JSONWorldStateStore = JSONWorldStateStore.new(test_file_path)
	var backup_envelope: Dictionary = backup_store.load_envelope()
	var backup_restored: bool = false
	for raw in backup_envelope.get("entities", []):
		var rec: WorldStateRecord = WorldStateRecord.from_dict(raw)
		if rec.persistent_id == "red_box" and rec.transform.origin.distance_to(backup_origin) < 0.01:
			backup_restored = true
	_assert_true(backup_restored, "Valid backup recovered when active file corrupt")

	# Test 9: world reset preserves memory
	print("\n--- World Reset ---")
	var memory_service: MemoryService = test_room.get_node_or_null("MemoryService") as MemoryService
	var memory_before: int = memory_service.get_total_record_count() if memory_service else 0
	if memory_service:
		memory_service.record_player_statement("Remember that I like the red box")
	world_service.set_world_flag("red_box_delivered_once", true)
	world_service.save_world_state()
	red_box.global_position = Vector3(4.0, 0.5, 4.0)
	await physics_frame
	world_service.reset_world_state()
	await physics_frame
	_assert_true(red_box.global_position.distance_to(default_origin) < 0.2, "Reset restores Red Box default transform")
	_assert_true(not FileAccess.file_exists(test_file_path), "Reset deletes world state save file")
	_assert_true(bool(world_service.get_world_flag("red_box_delivered_once")) == false, "Reset clears world flags")
	if memory_service:
		_assert_true(memory_service.get_total_record_count() > memory_before, "Reset preserves APC memory")

	# Test 10: persistence disabled
	print("\n--- Persistence Disabled ---")
	world_service.world_state_enabled = false
	_assert_true(not world_service.save_world_state(), "Save rejected when persistence disabled")
	world_service.load_world_state()
	_assert_true(world_service.last_error.contains("disabled"), "Load reports disabled state safely")
	world_service.world_state_enabled = true

	_cleanup_test_files()
	print("\n==========================================")
	print("  PHASE 10 PERSISTENT WORLD STATE [OK]")
	print("==========================================\n")
	quit(0)

func _make_envelope(world_service: WorldStateService, entity_records: Array, flags: Dictionary) -> Dictionary:
	return {
		"schema_version": 1,
		"world_id": world_service.world_id,
		"saved_at_unix": Time.get_unix_time_from_system(),
		"session_id": "test_session_10",
		"entities": entity_records,
		"world_flags": flags
	}

func _assert_true(condition: bool, message: String) -> void:
	if not condition:
		_fail_and_quit(message)
		return
	print("[PASS] " + message)

func _fail_and_quit(message: String) -> void:
	print("[FAIL] " + message)
	_cleanup_test_files()
	quit(1)

func _backup_path() -> String:
	var base: String = test_file_path.get_basename()
	var ext: String = test_file_path.get_extension()
	return "%s.backup.%s" % [base, ext]

func _cleanup_test_files() -> void:
	for path in [
		test_file_path,
		test_file_path + ".tmp",
		_backup_path(),
		"user://echo_world_state.json",
		"user://echo_world_state.json.tmp",
		"user://echo_world_state.backup.json"
	]:
		DirAccess.remove_absolute(path)
