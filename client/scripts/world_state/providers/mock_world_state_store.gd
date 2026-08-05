class_name MockWorldStateStore
extends WorldStateStore

var envelope: Dictionary = {}

func save_envelope(p_envelope: Dictionary) -> bool:
	last_error = "None"
	envelope = p_envelope.duplicate(true)
	return true

func load_envelope() -> Dictionary:
	last_error = "None"
	return envelope.duplicate(true)

func clear() -> bool:
	last_error = "None"
	envelope = {}
	return true

func get_storage_path() -> String:
	return "mock://world_state"
