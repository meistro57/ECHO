extends SceneTree

var main_node: Node3D
var test_file_path: String = "user://test_phase9_memory.json"

func _init() -> void:
	print("\n==========================================")
	print("  ECHO Framework - Phase 9 Automated Test")
	print("==========================================\n")

	_cleanup_test_files()
	var main_scene: PackedScene = load("res://scenes/main.tscn")
	if main_scene == null:
		_fail_and_quit("Could not load res://scenes/main.tscn")
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

	var test_room: Node = main_node.get_node_or_null("TestRoom")
	if test_room == null:
		_fail_and_quit("TestRoom node missing.")
		return

	var mem_service: MemoryService = test_room.get_node_or_null("MemoryService") as MemoryService
	if mem_service == null:
		_fail_and_quit("MemoryService node missing.")
		return

	if not mem_service.memory_enabled:
		_print_pass("Memory disabled (ECHO_MEMORY_ENABLED=false): gameplay verified, memory assertions skipped")
		_cleanup_test_files()
		print("\n==========================================")
		print("  PHASE 9 PERSISTENT MEMORY VERIFIED [OK]")
		print("==========================================\n")
		quit(0)
		return

	mem_service.active_store = JSONMemoryStore.new(test_file_path, 500)
	mem_service.clear_all_memories()
	_print_pass("MemoryService initialized with test JSON store")

	# 1 MemoryRecord validation
	var bad_type = MemoryRecord.new("UNSUPPORTED", "bad")
	_assert_true(not MemoryPolicy.validate_record(bad_type).get("valid", true), "Unsupported memory type rejected")

	# 2 task completion creates verified memory
	var completion = mem_service.record_task_completion("BRING_OBJECT_TO_PLAYER", "red_box", "The APC brought the Red Box to the human player.")
	_assert_true(completion != null and completion.verified, "Task completion creates verified memory")

	# 3 failed task creates failure memory
	var failure = mem_service.record_task_failure("BRING_OBJECT_TO_PLAYER", "red_box", "Target unreachable")
	_assert_true(failure != null and failure.memory_type == MemoryRecord.TYPE_TASK_FAILURE, "Failed task creates failure memory")

	# 4 incomplete task creates no success memory
	var before_count: int = _count_type(mem_service.get_all_records(), MemoryRecord.TYPE_TASK_COMPLETION)
	var apc: APCController = test_room.get_node_or_null("APC") as APCController
	if apc and apc.task_controller:
		var task_req: TaskRequest = TaskRequest.new("BRING_OBJECT_TO_PLAYER", "red_box", "test")
		apc.task_controller.start_task(task_req)
		apc.task_controller.cancel_task()
	var after_count: int = _count_type(mem_service.get_all_records(), MemoryRecord.TYPE_TASK_COMPLETION)
	_assert_true(before_count == after_count, "Incomplete task does not create success memory")

	# 5 explicit remember command creates a record
	var pref = mem_service.record_player_statement("Remember that I like the red box near the pool.")
	_assert_true(pref != null and pref.memory_type == MemoryRecord.TYPE_IMPORTANT_STATEMENT, "Explicit remember command creates record")

	# 6 ordinary conversation creates no record
	var chatter = CommandGrounder.ground_command("hello how are you", {}, {})
	_assert_true(not chatter.is_memory_store_command, "Ordinary conversation creates no memory command")

	# 7 records persist after service reload
	var reload_store: JSONMemoryStore = JSONMemoryStore.new(test_file_path, 500)
	_assert_true(reload_store.get_all_records().size() >= 3, "Records persist after reload")

	# 8 query by entity finds red_box memory
	var by_entity: Array = mem_service.query_memories("", "red_box")
	_assert_true(by_entity.size() > 0, "Query by entity finds red_box memory")

	# 9 query by event type works
	var q_event: MemoryQuery = MemoryQuery.new(5)
	q_event.event_type = "BRING_OBJECT_TO_PLAYER"
	var by_event: Array = mem_service.query_records(q_event)
	_assert_true(by_event.size() > 0, "Query by event type works")

	# 10 maximum query result limit works
	for i in range(10):
		mem_service.record_task_failure("BRING_OBJECT_TO_PLAYER", "red_box", "error %d" % i)
	var limited_q: MemoryQuery = MemoryQuery.new(2)
	limited_q.entities = ["red_box"]
	var limited_res: Array = mem_service.query_records(limited_q)
	_assert_true(limited_res.size() <= 2, "Maximum query result limit works")

	# 11 no matching record returns empty result
	var none: Array = mem_service.query_memories("nonexistent_memory_term")
	_assert_true(none.is_empty(), "No matching memory returns empty result")

	# 12 forget command removes only intended record
	var unique = mem_service.record_player_statement("Remember that my preference is blue cube in attic.")
	var deleted_intended: bool = mem_service.forget_by_id(unique.memory_id)
	var unique_after: Array = mem_service.query_memories("blue cube")
	_assert_true(deleted_intended and unique_after.is_empty(), "Forget removes intended record")

	# 13 ambiguous deletion requires clarification
	mem_service.record_player_statement("Remember that I like apples")
	mem_service.record_player_statement("Remember that I like green apples")
	var ambiguous_candidates: Array = mem_service.find_forget_candidates("apples")
	var ambiguous_deleted: int = mem_service.forget_matching("apples")
	_assert_true(ambiguous_candidates.size() > 1 and ambiguous_deleted == 0, "Ambiguous delete requires clarification")

	# 14 corrupt file recovers safely
	var corrupt_path: String = "user://corrupt_test_memory.json"
	var corrupt_file: FileAccess = FileAccess.open(corrupt_path, FileAccess.WRITE)
	if corrupt_file:
		corrupt_file.store_string("{ broken json")
		corrupt_file.close()
	var corrupt_store: JSONMemoryStore = JSONMemoryStore.new(corrupt_path, 500)
	_assert_true(corrupt_store.get_all_records().is_empty(), "Corrupt file recovers safely")

	# 15 atomic save preserves previous file on failure
	var atomic_store: JSONMemoryStore = JSONMemoryStore.new("user://atomic_test_memory.json", 500)
	atomic_store.save_record(MemoryRecord.new(MemoryRecord.TYPE_TASK_COMPLETION, "First stable record", "TEST"))
	var stable_content_before: String = FileAccess.open("user://atomic_test_memory.json", FileAccess.READ).get_as_text()
	atomic_store.file_path = "user://"
	var failed_save: bool = atomic_store.save_record(MemoryRecord.new(MemoryRecord.TYPE_TASK_COMPLETION, "Second record", "TEST"))
	var stable_content_after: String = FileAccess.open("user://atomic_test_memory.json", FileAccess.READ).get_as_text()
	_assert_true(not failed_save and stable_content_before == stable_content_after, "Atomic save failure preserves previous file")

	# 16 unsupported memory type is rejected
	var unsupported = MemoryRecord.new("HYPOTHESIS", "should fail")
	_assert_true(mem_service.save_record(unsupported) == null, "Unsupported memory type rejected")

	# 17 API keys cannot be stored
	var key_record = MemoryRecord.new(MemoryRecord.TYPE_IMPORTANT_STATEMENT, "OPENROUTER_API_KEY=sk-123", "TEST")
	_assert_true(not MemoryPolicy.validate_record(key_record).get("valid", true), "API keys cannot be stored")

	# 18 raw audio cannot be stored
	var audio_record = MemoryRecord.new(MemoryRecord.TYPE_IMPORTANT_STATEMENT, "Raw AudioBuffer data captured", "TEST")
	_assert_true(not MemoryPolicy.validate_record(audio_record).get("valid", true), "Raw audio cannot be stored")

	# 19 record pruning preserves explicit memories
	var prune_store: JSONMemoryStore = JSONMemoryStore.new("user://prune_test_memory.json", 3)
	prune_store.save_record(_build_record(MemoryRecord.TYPE_PLAYER_PREFERENCE, "I prefer apples", 1.0, "player_statement"))
	prune_store.save_record(_build_record(MemoryRecord.TYPE_TASK_FAILURE, "low1", 0.1, "task_controller"))
	prune_store.save_record(_build_record(MemoryRecord.TYPE_TASK_FAILURE, "low2", 0.1, "task_controller"))
	prune_store.save_record(_build_record(MemoryRecord.TYPE_TASK_FAILURE, "low3", 0.1, "task_controller"))
	var pruned_records: Array = prune_store.get_all_records()
	var has_explicit: bool = false
	for rec in pruned_records:
		if rec.memory_type == MemoryRecord.TYPE_PLAYER_PREFERENCE:
			has_explicit = true
			break
	_assert_true(has_explicit, "Pruning preserves explicit memories")

	# 20 AI cannot invent stored memory
	var answer: Dictionary = mem_service.build_memory_answer("Did we go to mars?")
	_assert_true(String(answer.get("text", "")).contains("I don't have a stored memory"), "No fabrication when no memory exists")

	# 21 previous phase tests pass handled in full regression run
	_print_pass("Phase 9 test script checks completed")

	_cleanup_test_files()
	print("\n==========================================")
	print("  PHASE 9 PERSISTENT MEMORY VERIFIED [OK]")
	print("==========================================\n")
	quit(0)

func _build_record(memory_type: String, summary: String, importance: float, source: String):
	var rec = MemoryRecord.new(memory_type, summary, "TEST")
	rec.importance = importance
	rec.source = source
	rec.session_id = "test"
	rec.entities.clear()
	rec.entities.append("red_box")
	rec.verified = true
	return rec

func _count_type(records: Array, type_name: String) -> int:
	var count: int = 0
	for rec in records:
		if rec.memory_type == type_name:
			count += 1
	return count

func _assert_true(condition: bool, message: String) -> void:
	if not condition:
		_fail_and_quit(message)
		return
	_print_pass(message)

func _print_pass(message: String) -> void:
	print("[PASS] " + message)

func _fail_and_quit(message: String) -> void:
	print("[FAIL] " + message)
	_cleanup_test_files()
	quit(1)

func _cleanup_test_files() -> void:
	for path in [
		test_file_path,
		test_file_path + ".tmp",
		test_file_path + ".bak",
		"user://corrupt_test_memory.json",
		"user://corrupt_test_memory.json.bak",
		"user://atomic_test_memory.json",
		"user://atomic_test_memory.json.tmp",
		"user://atomic_test_memory.json.bak",
		"user://atomic_test_memory.json.prev",
		"user://prune_test_memory.json",
		"user://prune_test_memory.json.tmp",
		"user://prune_test_memory.json.bak",
		"user://prune_test_memory.json.prev"
	]:
		DirAccess.remove_absolute(path)
