class_name MemoryService
extends Node

var current_session_id: String = ""
var previous_session_id: String = ""
var session_start_unix: float = 0.0

var memory_enabled: bool = true
var max_records: int = 500
var max_query_results: int = 5
var store_file_name: String = "echo_memory.json"

var active_store: MemoryStore
var last_stored_type: String = "None"
var last_stored_summary: String = "None"
var last_query_count: int = 0
var last_memory_error: String = "None"

signal memory_recorded(record)
signal memory_deleted(count: int)

func _ready() -> void:
	add_to_group("memory_service")
	session_start_unix = Time.get_unix_time_from_system()
	current_session_id = _build_session_id()
	_load_config_from_environment()
	if active_store == null:
		active_store = JSONMemoryStore.new("user://" + store_file_name, max_records)
	if active_store:
		previous_session_id = active_store.get_previous_session_id()
		active_store.set_previous_session_id(current_session_id)

func _build_session_id() -> String:
	return "sess_%d_%d" % [int(Time.get_ticks_usec()), randi() % 100000]

func _load_config_from_environment() -> void:
	var env_en: String = OS.get_environment("ECHO_MEMORY_ENABLED").to_lower().strip_edges()
	if env_en == "false" or env_en == "0":
		memory_enabled = false

	var env_max: String = OS.get_environment("ECHO_MEMORY_MAX_RECORDS").strip_edges()
	if not env_max.is_empty() and env_max.is_valid_int():
		max_records = max(10, env_max.to_int())

	var env_q: String = OS.get_environment("ECHO_MEMORY_MAX_QUERY_RESULTS").strip_edges()
	if not env_q.is_empty() and env_q.is_valid_int():
		max_query_results = clampi(env_q.to_int(), 1, 20)

	var env_f: String = OS.get_environment("ECHO_MEMORY_FILE").strip_edges()
	if not env_f.is_empty():
		store_file_name = env_f

func get_storage_path() -> String:
	if active_store == null:
		return ProjectSettings.globalize_path("user://" + store_file_name)
	return ProjectSettings.globalize_path(active_store.get_storage_path())

func save_record(record):
	if not memory_enabled:
		last_memory_error = "Memory is disabled"
		return null
	if record == null:
		last_memory_error = "Record is null"
		return null

	var validation: Dictionary = MemoryPolicy.validate_record(record)
	if not bool(validation.get("valid", false)):
		last_memory_error = String(validation.get("error", "Policy validation failed"))
		return null

	if active_store == null:
		last_memory_error = "No active memory store"
		return null

	if not active_store.save_record(record):
		last_memory_error = active_store.last_error
		return null

	last_stored_type = record.memory_type
	last_stored_summary = record.summary
	last_memory_error = "None"
	memory_recorded.emit(record)
	return record

func record_task_completion(task_type: String, target_id: String, summary: String = ""):
	if task_type.is_empty() or target_id.is_empty():
		return null
	var text_summary: String = summary.strip_edges()
	if text_summary.is_empty():
		text_summary = "The APC brought the %s to the human player." % target_id.replace("_", " ").capitalize()
	var rec = MemoryRecord.new(MemoryRecord.TYPE_TASK_COMPLETION, text_summary, task_type)
	rec.session_id = current_session_id
	rec.importance = 0.9
	rec.entities.clear()
	rec.entities.append("human_player")
	rec.entities.append(target_id)
	rec.source = "task_controller"
	rec.verified = true
	return save_record(rec)

func record_task_failure(task_type: String, target_id: String, error_msg: String):
	if task_type.is_empty() or target_id.is_empty() or error_msg.strip_edges().is_empty():
		return null
	var summary: String = "The APC failed task %s for %s: %s" % [task_type, target_id, error_msg]
	var rec = MemoryRecord.new(MemoryRecord.TYPE_TASK_FAILURE, summary, task_type)
	rec.session_id = current_session_id
	rec.importance = 0.65
	rec.entities.clear()
	rec.entities.append("human_player")
	rec.entities.append(target_id)
	rec.source = "task_controller"
	rec.verified = true
	return save_record(rec)

func record_player_statement(statement: String):
	var fact: String = _extract_memory_fact(statement)
	if fact.is_empty():
		last_memory_error = "No explicit memory fact found"
		return null

	var type_name: String = MemoryRecord.TYPE_IMPORTANT_STATEMENT
	if statement.to_lower().contains("preference") or statement.to_lower().contains("i prefer"):
		type_name = MemoryRecord.TYPE_PLAYER_PREFERENCE

	var rec = MemoryRecord.new(type_name, fact, "PLAYER_STATEMENT")
	rec.session_id = current_session_id
	rec.importance = 1.0
	rec.entities.clear()
	for entity in _extract_entities(fact):
		rec.entities.append(entity)
	if not rec.entities.has("human_player"):
		rec.entities.push_front("human_player")
	rec.source = "player_statement"
	rec.verified = true
	rec.metadata = {"explicit": true}
	return save_record(rec)

func _extract_memory_fact(statement: String) -> String:
	var original: String = statement.strip_edges()
	var lower: String = original.to_lower()
	if lower.begins_with("remember that"):
		return original.substr(12).strip_edges()
	if lower.begins_with("remember i"):
		return original.substr(8).strip_edges()
	if lower.begins_with("my preference is"):
		return original.substr(16).strip_edges()
	return ""

func _extract_entities(text: String) -> Array[String]:
	var entities: Array[String] = []
	var normalized: String = text.to_lower()
	if normalized.contains("red box") or normalized.contains("red_box"):
		entities.append("red_box")
	if normalized.contains("pool"):
		entities.append("pool")
	if normalized.contains("player") or normalized.contains("me"):
		entities.append("human_player")
	return entities

func query_records(query: MemoryQuery) -> Array:
	if not memory_enabled or active_store == null:
		last_query_count = 0
		return []
	query.max_results = clampi(query.max_results, 1, max_query_results)
	var results: Array = active_store.query_records(query)
	last_query_count = results.size()
	return results

func query_memories(query_term: String = "", target_entity: String = "") -> Array:
	var query: MemoryQuery = MemoryQuery.new(max_query_results)
	query.query_text = query_term
	if not target_entity.is_empty():
		query.entities.append(target_entity)
	elif not query_term.is_empty():
		if query_term == "red_box" or query_term.contains("red box"):
			query.entities.append("red_box")
		elif query_term == "me":
			query.entities.append("human_player")
		else:
			query.entities.append(query_term.to_lower())
	return query_records(query)

func get_compact_context_for_ai(query_term: String = "") -> Dictionary:
	var records_found: Array = query_memories(query_term)
	var compact: Array = []
	for rec in records_found:
		compact.append(rec.to_compact_dict())
	return {"relevant_memories": compact}

func get_total_record_count() -> int:
	if active_store == null:
		return 0
	return active_store.get_all_records().size()

func get_all_records() -> Array:
	if active_store == null:
		return []
	return active_store.get_all_records()

func forget_by_id(memory_id: String) -> bool:
	if not memory_enabled or active_store == null:
		last_memory_error = "Memory is unavailable"
		return false
	var ok: bool = active_store.delete_record(memory_id)
	if ok:
		last_memory_error = "None"
		memory_deleted.emit(1)
		return true
	last_memory_error = active_store.last_error
	return false

func find_forget_candidates(term: String) -> Array:
	var q: MemoryQuery = MemoryQuery.new(max_query_results)
	q.query_text = term.strip_edges()
	if q.query_text.is_empty():
		return []
	q.entities.append(q.query_text.to_lower())
	q.max_results = 20
	return query_records(q)

func forget_matching(term: String) -> int:
	var candidates: Array = find_forget_candidates(term)
	if candidates.size() != 1:
		return 0
	if forget_by_id(candidates[0].memory_id):
		return 1
	return 0

func clear_all_memories() -> bool:
	if not memory_enabled or active_store == null:
		last_memory_error = "Memory is unavailable"
		return false
	var ok: bool = active_store.clear_all()
	if ok:
		last_stored_type = "None"
		last_stored_summary = "None"
		last_query_count = 0
		last_memory_error = "None"
		memory_deleted.emit(999)
		return true
	last_memory_error = active_store.last_error
	return false

func build_memory_answer(question: String) -> Dictionary:
	var q_text: String = question.to_lower().strip_edges()
	var result: Dictionary = {"text": "I don't have a stored memory of that.", "records": []}

	if q_text.contains("last time") or q_text.contains("help me with"):
		if previous_session_id.is_empty():
			return result
		var q_prev: MemoryQuery = MemoryQuery.new(max_query_results)
		q_prev.session_id = previous_session_id
		q_prev.memory_types = [MemoryRecord.TYPE_TASK_COMPLETION]
		var prev_records: Array = query_records(q_prev)
		result.records = prev_records
		if prev_records.is_empty():
			return result
		result.text = prev_records[0].summary
		return result

	if q_text.contains("did you bring") and q_text.contains("red box"):
		var bring_query: MemoryQuery = MemoryQuery.new(max_query_results)
		bring_query.memory_types = [MemoryRecord.TYPE_TASK_COMPLETION]
		bring_query.event_type = "BRING_OBJECT_TO_PLAYER"
		bring_query.entities = ["red_box"]
		var bring_records: Array = query_records(bring_query)
		result.records = bring_records
		if bring_records.is_empty():
			return result
		result.text = "Yes. " + bring_records[0].summary
		return result

	if q_text.contains("remember about the red box") or q_text.contains("remember about red box"):
		var red_records: Array = query_memories("red_box", "red_box")
		result.records = red_records
		if red_records.is_empty():
			return result
		result.text = red_records[0].summary
		return result

	if q_text.contains("remember about me"):
		var me_records: Array = query_memories("human_player", "human_player")
		result.records = me_records
		if me_records.is_empty():
			return result
		result.text = me_records[0].summary
		return result

	var generic_records: Array = query_memories(q_text)
	result.records = generic_records
	if generic_records.is_empty():
		return result
	result.text = generic_records[0].summary
	return result
