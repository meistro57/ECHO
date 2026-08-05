class_name JSONWorldStateStore
extends WorldStateStore

var file_path: String = "user://echo_world_state.json"
var backup_path: String = "user://echo_world_state.backup.json"

func _init(p_path: String = "user://echo_world_state.json") -> void:
	file_path = p_path
	var base: String = p_path.get_basename()
	var ext: String = p_path.get_extension()
	backup_path = "%s.backup.%s" % [base, ext]

func get_storage_path() -> String:
	return file_path

func save_envelope(envelope: Dictionary) -> bool:
	last_error = "None"
	var content: String = JSON.stringify(envelope, "\t")
	var tmp_path: String = file_path + ".tmp"

	var tmp_file: FileAccess = FileAccess.open(tmp_path, FileAccess.WRITE)
	if tmp_file == null:
		last_error = "Failed to write temporary world state file"
		return false
	tmp_file.store_string(content)
	tmp_file.close()

	var verify_file: FileAccess = FileAccess.open(tmp_path, FileAccess.READ)
	if verify_file == null:
		last_error = "Failed to verify temporary world state file"
		return false
	var verify_content: String = verify_file.get_as_text()
	verify_file.close()
	var parser: JSON = JSON.new()
	if parser.parse(verify_content) != OK:
		last_error = "Temporary world state file is invalid JSON"
		return false

	# Preserve previous known-good active file as backup before replacing.
	if FileAccess.file_exists(file_path) and _is_valid_envelope_file(file_path):
		DirAccess.remove_absolute(backup_path)
		DirAccess.copy_absolute(file_path, backup_path)

	DirAccess.remove_absolute(file_path)
	var rename_error: Error = DirAccess.rename_absolute(tmp_path, file_path)
	if rename_error != OK:
		last_error = "Failed to replace world state file"
		DirAccess.remove_absolute(tmp_path)
		return false
	return true

func load_envelope() -> Dictionary:
	last_error = "None"
	if FileAccess.file_exists(file_path):
		var envelope: Dictionary = _read_envelope_file(file_path)
		if not envelope.is_empty():
			return envelope
		if last_error == "None":
			last_error = "Active world state file is empty"
		else:
			last_error = "Active world state file invalid"

	if FileAccess.file_exists(backup_path):
		var backup: Dictionary = _read_envelope_file(backup_path)
		if not backup.is_empty():
			last_error = "Loaded world state from backup"
			return backup
		last_error = "Backup world state file invalid"

	last_error = "No valid world state file; using default scene state"
	return {}

func clear() -> bool:
	last_error = "None"
	DirAccess.remove_absolute(file_path)
	DirAccess.remove_absolute(file_path + ".tmp")
	DirAccess.remove_absolute(backup_path)
	return true

func _read_envelope_file(path: String) -> Dictionary:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		last_error = "Could not open world state file"
		return {}
	var content: String = file.get_as_text()
	file.close()
	if content.strip_edges().is_empty():
		return {}
	var parser: JSON = JSON.new()
	if parser.parse(content) != OK:
		return {}
	var data: Variant = parser.data
	if data is Dictionary:
		return (data as Dictionary).duplicate(true)
	return {}

func _is_valid_envelope_file(path: String) -> bool:
	return not _read_envelope_file(path).is_empty()
