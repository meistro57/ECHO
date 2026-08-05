class_name MemoryPolicy
extends RefCounted

const ALLOWED_TYPES: Array[String] = [
	MemoryRecord.TYPE_TASK_COMPLETION,
	MemoryRecord.TYPE_TASK_FAILURE,
	MemoryRecord.TYPE_PLAYER_PREFERENCE,
	MemoryRecord.TYPE_IMPORTANT_STATEMENT,
	MemoryRecord.TYPE_LOCATION_EVENT
]

const MAX_SUMMARY_LENGTH: int = 300
const MAX_ENTITY_COUNT: int = 12

const FORBIDDEN_SUBSTRINGS: Array[String] = [
	"openrouter_api_key",
	"deepseek_api_key",
	"echo_stt_api_key",
	"echo_tts_api_key",
	"authorization:",
	"bearer ",
	"api_key",
	"raw audio",
	"audiobuffer",
	"packedfloat32array",
	"chain of thought",
	"reasoning"
]

static func validate_record(record) -> Dictionary:
	if record == null:
		return {"valid": false, "error": "Record is null"}

	if not ALLOWED_TYPES.has(record.memory_type):
		return {"valid": false, "error": "Unsupported memory type"}

	record.summary = record.summary.strip_edges()
	if record.summary.is_empty():
		return {"valid": false, "error": "Memory summary is empty"}

	if record.summary.length() > MAX_SUMMARY_LENGTH:
		return {"valid": false, "error": "Memory summary exceeds maximum length"}

	if record.entities.size() > MAX_ENTITY_COUNT:
		return {"valid": false, "error": "Too many entities in memory record"}

	if record.memory_id.strip_edges().is_empty():
		return {"valid": false, "error": "Memory id is empty"}

	record.importance = clampf(record.importance, 0.0, 1.0)

	var combined_text: String = (record.summary + " " + JSON.stringify(record.metadata)).to_lower()
	for forbidden in FORBIDDEN_SUBSTRINGS:
		if combined_text.contains(forbidden):
			return {"valid": false, "error": "Record contains restricted content"}

	if _looks_like_secret(combined_text):
		return {"valid": false, "error": "Record may contain a secret"}

	if record.source.to_lower().contains("audio"):
		return {"valid": false, "error": "Raw audio source is not allowed"}

	if record.metadata.has("full_transcript"):
		return {"valid": false, "error": "Full transcript storage is not allowed"}

	return {"valid": true, "error": ""}

static func _looks_like_secret(text: String) -> bool:
	if text.contains("sk-"):
		return true
	if text.contains("-----begin") and text.contains("private key"):
		return true
	if text.contains("token") and text.contains("="):
		return true
	return false
