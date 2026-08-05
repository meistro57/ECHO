class_name WorldStateStore
extends RefCounted

var last_error: String = "None"

func save_envelope(_envelope: Dictionary) -> bool:
	return false

func load_envelope() -> Dictionary:
	return {}

func clear() -> bool:
	return false

func get_storage_path() -> String:
	return ""
