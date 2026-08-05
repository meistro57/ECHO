class_name WorldStateMigrator
extends RefCounted

const CURRENT_SCHEMA_VERSION: int = 1
const OLDEST_SUPPORTED_VERSION: int = 1

static func migrate(envelope: Dictionary) -> Dictionary:
	if not envelope.has("schema_version"):
		return {"ok": false, "error": "Save file has no schema version", "envelope": envelope}

	var version: int = int(envelope.get("schema_version", -1))
	if version > CURRENT_SCHEMA_VERSION:
		return {"ok": false, "error": "Save file schema version %d is newer than supported %d" % [version, CURRENT_SCHEMA_VERSION], "envelope": envelope}

	if version < OLDEST_SUPPORTED_VERSION:
		return {"ok": false, "error": "Save file schema version %d is older than supported %d" % [version, OLDEST_SUPPORTED_VERSION], "envelope": envelope}

	var migrated: Dictionary = envelope.duplicate(true)
	migrated["schema_version"] = CURRENT_SCHEMA_VERSION

	if not migrated.has("world_id"):
		migrated["world_id"] = ""
	if not migrated.has("saved_at_unix"):
		migrated["saved_at_unix"] = 0.0
	if not migrated.has("session_id"):
		migrated["session_id"] = ""
	if not migrated.has("entities"):
		migrated["entities"] = []
	if not migrated.has("world_flags"):
		migrated["world_flags"] = {}

	return {"ok": true, "error": "", "envelope": migrated}
