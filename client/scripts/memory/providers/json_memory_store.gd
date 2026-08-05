class_name JSONMemoryStore
extends MemoryStore

var file_path: String = "user://echo_memory.json"
var records: Array = []
var max_records: int = 500
var previous_session_id: String = ""

func _init(p_path: String = "user://echo_memory.json", p_max_records: int = 500) -> void:
	file_path = p_path
	max_records = max(10, p_max_records)
	load_from_disk()

func get_storage_path() -> String:
	return file_path

func get_previous_session_id() -> String:
	return previous_session_id

func set_previous_session_id(session_id: String) -> void:
	previous_session_id = session_id
	_save_to_disk_atomic()

func load_from_disk() -> bool:
	records.clear()
	last_error = "None"
	if not FileAccess.file_exists(file_path):
		return true

	var file: FileAccess = FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		last_error = "Could not open memory file"
		return false

	var content: String = file.get_as_text()
	file.close()
	if content.strip_edges().is_empty():
		return true

	var parsed: Variant = null
	if not content.strip_edges().is_empty():
		var json_parser: JSON = JSON.new()
		var parse_result: Error = json_parser.parse(content)
		if parse_result == OK:
			parsed = json_parser.data
	if parsed == null:
		last_error = "Corrupt JSON memory file"
		_backup_corrupt_file()
		return false

	var raw_records: Array = []
	if parsed is Array:
		raw_records = parsed
	elif parsed is Dictionary:
		previous_session_id = String(parsed.get("previous_session_id", ""))
		var rr: Variant = parsed.get("records", [])
		if rr is Array:
			raw_records = rr
		else:
			last_error = "Invalid records list in memory file"
			return false
	else:
		last_error = "Unexpected memory file schema"
		_backup_corrupt_file()
		return false

	var seen_ids: Dictionary = {}
	for item in raw_records:
		if item is Dictionary:
			var rec = MemoryRecord.from_dict(item)
			if rec.memory_id.is_empty() or seen_ids.has(rec.memory_id):
				continue
			seen_ids[rec.memory_id] = true
			records.append(rec)

	return true

func save_record(record) -> bool:
	if record == null:
		last_error = "Record is null"
		return false

	var updated: bool = false
	for i in range(records.size()):
		if records[i].memory_id == record.memory_id:
			records[i] = record
			updated = true
			break

	if not updated:
		records.append(record)

	_apply_pruning_policy()
	var ok: bool = _save_to_disk_atomic()
	if not ok and not updated:
		records.pop_back()
	return ok

func delete_record(memory_id: String) -> bool:
	for i in range(records.size()):
		if records[i].memory_id == memory_id:
			records.remove_at(i)
			return _save_to_disk_atomic()
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
	return _save_to_disk_atomic()

func _save_to_disk_atomic() -> bool:
	last_error = "None"
	var payload: Dictionary = {
		"version": 1,
		"previous_session_id": previous_session_id,
		"records": []
	}
	for rec in records:
		payload["records"].append(rec.to_dict())

	var content: String = JSON.stringify(payload, "\t")
	var tmp_path: String = file_path + ".tmp"

	var tmp_file: FileAccess = FileAccess.open(tmp_path, FileAccess.WRITE)
	if tmp_file == null:
		last_error = "Failed to write temporary memory file"
		return false
	tmp_file.store_string(content)
	tmp_file.close()

	var verify_file: FileAccess = FileAccess.open(tmp_path, FileAccess.READ)
	if verify_file == null:
		last_error = "Failed to verify temporary memory file"
		return false
	var verify_content: String = verify_file.get_as_text()
	verify_file.close()
	var verify_parser: JSON = JSON.new()
	if verify_parser.parse(verify_content) != OK:
		last_error = "Temporary memory file is invalid JSON"
		return false

	if FileAccess.file_exists(file_path):
		var backup_path: String = file_path + ".prev"
		DirAccess.remove_absolute(backup_path)
		DirAccess.copy_absolute(file_path, backup_path)

	DirAccess.remove_absolute(file_path)
	var rename_error: Error = DirAccess.rename_absolute(tmp_path, file_path)
	if rename_error != OK:
		last_error = "Failed to replace memory file"
		DirAccess.remove_absolute(tmp_path)
		return false
	return true

func _backup_corrupt_file() -> void:
	if not FileAccess.file_exists(file_path):
		return
	var backup_path: String = file_path + ".bak"
	DirAccess.remove_absolute(backup_path)
	DirAccess.rename_absolute(file_path, backup_path)
	records.clear()

func _apply_pruning_policy() -> void:
	if records.size() <= max_records:
		return

	var protected_records: Array = []
	var pruneable_records: Array = []
	for rec in records:
		var explicit_memory: bool = rec.source == "player_statement" or rec.memory_type == MemoryRecord.TYPE_PLAYER_PREFERENCE or rec.memory_type == MemoryRecord.TYPE_IMPORTANT_STATEMENT
		if explicit_memory:
			protected_records.append(rec)
		else:
			pruneable_records.append(rec)

	pruneable_records.sort_custom(func(a, b) -> bool:
		if a.importance == b.importance:
			return a.timestamp_unix < b.timestamp_unix
		return a.importance < b.importance
	)

	var removed_count: int = 0
	while (protected_records.size() + pruneable_records.size()) > max_records and not pruneable_records.is_empty():
		pruneable_records.remove_at(0)
		removed_count += 1

	if (protected_records.size() + pruneable_records.size()) > max_records:
		protected_records.sort_custom(func(a, b) -> bool:
			if a.importance == b.importance:
				return a.timestamp_unix < b.timestamp_unix
			return a.importance < b.importance
		)
		while (protected_records.size() + pruneable_records.size()) > max_records and not protected_records.is_empty():
			protected_records.remove_at(0)
			removed_count += 1

	records.clear()
	records.append_array(protected_records)
	records.append_array(pruneable_records)

	if removed_count > 0:
		print("[MemoryStore] Pruned %d records due to max limit" % removed_count)
