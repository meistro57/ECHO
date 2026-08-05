class_name MemoryRecord
extends RefCounted

const TYPE_TASK_COMPLETION: String = "TASK_COMPLETION"
const TYPE_TASK_FAILURE: String = "TASK_FAILURE"
const TYPE_PLAYER_PREFERENCE: String = "PLAYER_PREFERENCE"
const TYPE_IMPORTANT_STATEMENT: String = "IMPORTANT_STATEMENT"
const TYPE_LOCATION_EVENT: String = "LOCATION_EVENT"

var memory_id: String = ""
var memory_type: String = TYPE_TASK_COMPLETION
var summary: String = ""
var timestamp_unix: float = 0.0
var session_id: String = ""
var importance: float = 0.5
var entities: Array[String] = []
var event_type: String = ""
var source: String = "system"
var verified: bool = false
var metadata: Dictionary = {}

func _init(p_type: String = TYPE_TASK_COMPLETION, p_summary: String = "", p_event_type: String = "") -> void:
	memory_id = "mem_%d_%d" % [int(Time.get_ticks_usec()), randi() % 10000]
	memory_type = p_type
	summary = p_summary
	event_type = p_event_type
	timestamp_unix = Time.get_unix_time_from_system()

func to_dict() -> Dictionary:
	return {
		"memory_id": memory_id,
		"memory_type": memory_type,
		"summary": summary,
		"timestamp_unix": timestamp_unix,
		"session_id": session_id,
		"importance": importance,
		"entities": entities,
		"event_type": event_type,
		"source": source,
		"verified": verified,
		"metadata": metadata
	}

func to_compact_dict() -> Dictionary:
	return {
		"type": memory_type,
		"summary": summary,
		"timestamp": timestamp_unix,
		"entities": entities
	}

static func from_dict(dict: Dictionary):
	var rec = MemoryRecord.new()
	rec.memory_id = String(dict.get("memory_id", ""))
	rec.memory_type = String(dict.get("memory_type", TYPE_TASK_COMPLETION))
	rec.summary = String(dict.get("summary", ""))
	rec.timestamp_unix = float(dict.get("timestamp_unix", 0.0))
	rec.session_id = String(dict.get("session_id", ""))
	rec.importance = float(dict.get("importance", 0.5))

	var raw_entities: Variant = dict.get("entities", [])
	rec.entities.clear()
	if raw_entities is Array:
		for entity in raw_entities:
			rec.entities.append(String(entity))

	rec.event_type = String(dict.get("event_type", ""))
	rec.source = String(dict.get("source", "system"))
	rec.verified = bool(dict.get("verified", false))

	var raw_metadata: Variant = dict.get("metadata", {})
	rec.metadata = raw_metadata.duplicate(true) if raw_metadata is Dictionary else {}
	return rec
