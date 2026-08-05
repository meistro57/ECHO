class_name MockMemoryStore
extends MemoryStore

var records: Array = []
var previous_session_id: String = ""

func save_record(record) -> bool:
	if record == null:
		last_error = "Record is null"
		return false
	for i in range(records.size()):
		if records[i].memory_id == record.memory_id:
			records[i] = record
			return true
	records.append(record)
	return true

func delete_record(memory_id: String) -> bool:
	for i in range(records.size()):
		if records[i].memory_id == memory_id:
			records.remove_at(i)
			return true
	last_error = "Memory id not found"
	return false

func query_records(query) -> Array:
	var scored: Array = []
	var now_unix: float = Time.get_unix_time_from_system()
	for rec in records:
		if query.min_importance > 0.0 and rec.importance < query.min_importance:
			continue
		if not query.memory_types.is_empty() and not query.memory_types.has(rec.memory_type):
			continue
		if not query.event_type.is_empty() and rec.event_type != query.event_type:
			continue
		if not query.session_id.is_empty() and rec.session_id != query.session_id:
			continue
		if query.time_range_min > 0.0 and rec.timestamp_unix < query.time_range_min:
			continue
		if query.time_range_max > 0.0 and rec.timestamp_unix > query.time_range_max:
			continue

		var score: float = rec.importance
		if not query.entities.is_empty():
			var entity_match_count: int = 0
			for entity in query.entities:
				if rec.entities.has(entity):
					entity_match_count += 1
				elif rec.summary.to_lower().contains(entity.to_lower()):
					entity_match_count += 1
			if entity_match_count == 0:
				continue
			score += float(entity_match_count) * 2.0

		if not query.event_type.is_empty() and rec.event_type == query.event_type:
			score += 1.5

		if not query.query_text.is_empty() and rec.summary.to_lower().contains(query.query_text.to_lower()):
			score += 1.0

		var age_seconds: float = max(1.0, now_unix - rec.timestamp_unix)
		score += 1.0 / (1.0 + (age_seconds / 86400.0))

		scored.append({"record": rec, "score": score})

	scored.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a["score"] == b["score"]:
			return a["record"].timestamp_unix > b["record"].timestamp_unix
		return a["score"] > b["score"]
	)

	var limit: int = max(1, query.max_results)
	var result: Array = []
	for row in scored:
		if result.size() >= limit:
			break
		result.append(row["record"])
	return result

func get_all_records() -> Array:
	return records.duplicate()

func clear_all() -> bool:
	records.clear()
	return true

func get_storage_path() -> String:
	return "mock://memory"

func get_previous_session_id() -> String:
	return previous_session_id

func set_previous_session_id(session_id: String) -> void:
	previous_session_id = session_id
