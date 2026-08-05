class_name MemoryStore
extends RefCounted

var last_error: String = "None"

func save_record(_record) -> bool:
	return false

func delete_record(_memory_id: String) -> bool:
	return false

func query_records(_query) -> Array:
	return []

func get_all_records() -> Array:
	return []

func clear_all() -> bool:
	return false

func get_storage_path() -> String:
	return ""

func get_previous_session_id() -> String:
	return ""

func set_previous_session_id(_session_id: String) -> void:
	pass
