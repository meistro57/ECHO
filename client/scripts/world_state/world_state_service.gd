class_name WorldStateService
extends Node

var world_state_enabled: bool = true
var world_id: String = "echo_test_room"
var store_file_name: String = "echo_world_state.json"
var autosave_enabled: bool = true
var autosave_delay_seconds: float = 1.0
var save_player_position: bool = false
var save_apc_position: bool = false

var world_bounds_min: Vector3 = Vector3(-9.0, 0.0, -9.0)
var world_bounds_max: Vector3 = Vector3(9.0, 3.0, 9.0)

var active_store: WorldStateStore
var registry: WorldStateRegistry

var schema_version: int = WorldStateMigrator.CURRENT_SCHEMA_VERSION
var last_save_unix: float = 0.0
var last_load_unix: float = 0.0
var dirty: bool = false
var autosave_pending: bool = false
var last_error: String = "None"
var last_saved_count: int = 0

var _session_id: String = ""
var _session_flags: Dictionary = {}
var _poll_timer: float = 0.0
var _autosave_timer: float = 0.0
var _last_saved_signature: String = ""
var _loaded_once: bool = false
var _first_command_handled: bool = false

var _allowed_flags: Dictionary = {
	"tutorial_completed": true,
	"red_box_delivered_once": true,
	"first_voice_command_completed": true
}

signal world_state_saved(entity_count: int)
signal world_state_loaded(entity_count: int)
signal world_state_reset
signal world_state_error(message: String)

func _ready() -> void:
	add_to_group("world_state_service")
	_load_config_from_environment()
	active_store = JSONWorldStateStore.new("user://" + store_file_name)
	registry = WorldStateRegistry.new()
	call_deferred("_initialize")

func _load_config_from_environment() -> void:
	var env_enabled: String = OS.get_environment("ECHO_WORLD_STATE_ENABLED").to_lower().strip_edges()
	if env_enabled == "false" or env_enabled == "0":
		world_state_enabled = false

	var env_file: String = OS.get_environment("ECHO_WORLD_STATE_FILE").strip_edges()
	if not env_file.is_empty():
		store_file_name = env_file

	var env_world_id: String = OS.get_environment("ECHO_WORLD_ID").strip_edges()
	if not env_world_id.is_empty():
		world_id = env_world_id

	var env_autosave: String = OS.get_environment("ECHO_WORLD_AUTOSAVE").to_lower().strip_edges()
	if env_autosave == "false" or env_autosave == "0":
		autosave_enabled = false

	var env_delay: String = OS.get_environment("ECHO_WORLD_AUTOSAVE_DELAY_SECONDS").strip_edges()
	if not env_delay.is_empty() and env_delay.is_valid_float():
		autosave_delay_seconds = max(0.1, env_delay.to_float())

	var env_player: String = OS.get_environment("ECHO_SAVE_PLAYER_POSITION").to_lower().strip_edges()
	if env_player == "true" or env_player == "1":
		save_player_position = true

	var env_apc: String = OS.get_environment("ECHO_SAVE_APC_POSITION").to_lower().strip_edges()
	if env_apc == "true" or env_apc == "1":
		save_apc_position = true

	var env_bounds: String = OS.get_environment("ECHO_WORLD_BOUNDS").strip_edges()
	if not env_bounds.is_empty():
		var parts: PackedStringArray = env_bounds.split(",")
		if parts.size() == 6:
			world_bounds_min = Vector3(parts[0].to_float(), parts[1].to_float(), parts[2].to_float())
			world_bounds_max = Vector3(parts[3].to_float(), parts[4].to_float(), parts[5].to_float())

func _initialize() -> void:
	if not world_state_enabled:
		last_error = "World state persistence is disabled"
		return

	var memory_services: Array[Node] = get_tree().get_nodes_in_group("memory_service")
	if memory_services.size() > 0:
		_session_id = memory_services[0].current_session_id
	if _session_id.is_empty():
		_session_id = "wsess_%d_%d" % [int(Time.get_ticks_usec()), randi() % 100000]

	_refresh_registry()

	var apcs: Array[Node] = get_tree().get_nodes_in_group("apc")
	if apcs.size() > 0 and apcs[0] is APCController:
		var apc: APCController = apcs[0] as APCController
		if apc.task_controller and not apc.task_controller.task_completed.is_connected(_on_task_completed):
			apc.task_controller.task_completed.connect(_on_task_completed)

	var convs: Array[Node] = get_tree().get_nodes_in_group("conversation_controller")
	if convs.size() > 0 and not convs[0].transcript_received.is_connected(_on_transcript_received):
		convs[0].transcript_received.connect(_on_transcript_received)

	await get_tree().physics_frame
	await get_tree().physics_frame
	load_world_state()

func _process(delta: float) -> void:
	if not world_state_enabled:
		return

	_poll_timer -= delta
	if _poll_timer <= 0.0:
		_poll_timer = 0.5
		var current_signature: String = _compute_state_signature()
		if current_signature != _last_saved_signature:
			dirty = true

	if dirty and autosave_enabled and not autosave_pending:
		autosave_pending = true
		_autosave_timer = autosave_delay_seconds

	if autosave_pending:
		_autosave_timer -= delta
		if _autosave_timer <= 0.0:
			autosave_pending = false
			save_world_state()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if world_state_enabled and dirty:
			save_world_state()

func _refresh_registry() -> void:
	if registry == null:
		registry = WorldStateRegistry.new()
	registry.clear()
	var entities: Array[Node] = get_tree().get_nodes_in_group("persistent_entity")
	for node in entities:
		if node is PersistentEntity:
			var entity: PersistentEntity = node as PersistentEntity
			if entity.is_valid_for_restore():
				registry.register_entity(entity)

func save_world_state() -> bool:
	if not world_state_enabled:
		last_error = "World state persistence is disabled"
		return false
	if active_store == null:
		last_error = "No active world state store"
		return false

	var entity_records: Array = []
	var memory_services: Array[Node] = get_tree().get_nodes_in_group("memory_service")
	if memory_services.size() > 0:
		_session_id = memory_services[0].current_session_id

	for entity in registry.get_all_entities():
		var record: WorldStateRecord = entity.capture_record()
		if record != null and WorldStateRecord.is_finite_transform(record.transform):
			entity_records.append(record.to_dict())

	if save_player_position:
		var player_record: Dictionary = _capture_actor_record("human_player", "player")
		if not player_record.is_empty():
			entity_records.append(player_record)

	if save_apc_position:
		var apc_record: Dictionary = _capture_actor_record("apc", "apc")
		if not apc_record.is_empty():
			entity_records.append(apc_record)

	var envelope: Dictionary = {
		"schema_version": WorldStateMigrator.CURRENT_SCHEMA_VERSION,
		"world_id": world_id,
		"saved_at_unix": Time.get_unix_time_from_system(),
		"session_id": _session_id,
		"entities": entity_records,
		"world_flags": _collect_world_flags()
	}

	if not active_store.save_envelope(envelope):
		last_error = active_store.last_error
		world_state_error.emit(last_error)
		return false

	last_save_unix = float(envelope["saved_at_unix"])
	last_error = "None"
	dirty = false
	autosave_pending = false
	last_saved_count = entity_records.size()
	_last_saved_signature = _compute_state_signature()
	world_state_saved.emit(last_saved_count)
	return true

func load_world_state() -> bool:
	if not world_state_enabled:
		last_error = "World state persistence is disabled"
		return false
	if active_store == null:
		last_error = "No active world state store"
		return false

	_refresh_registry()

	var envelope: Dictionary = active_store.load_envelope()
	if envelope.is_empty():
		if _loaded_once:
			return true
		last_load_unix = Time.get_unix_time_from_system()
		_loaded_once = true
		_last_saved_signature = _compute_state_signature()
		world_state_loaded.emit(0)
		return true

	var migration: Dictionary = WorldStateMigrator.migrate(envelope)
	if not bool(migration.get("ok", false)):
		last_error = String(migration.get("error", "Migration failed"))
		world_state_error.emit(last_error)
		return false
	envelope = migration["envelope"]

	var saved_world_id: String = String(envelope.get("world_id", ""))
	if not saved_world_id.is_empty() and saved_world_id != world_id:
		last_error = "Save file belongs to world '%s', expected '%s'" % [saved_world_id, world_id]
		world_state_error.emit(last_error)
		return false

	_apply_world_flags(envelope.get("world_flags", {}))

	var raw_records: Array = envelope.get("entities", [])
	var applied_count: int = 0
	var applied_ids: Dictionary = {}
	for raw in raw_records:
		if not (raw is Dictionary):
			continue
		var record: WorldStateRecord = WorldStateRecord.from_dict(raw)
		if record.persistent_id.is_empty() or applied_ids.has(record.persistent_id):
			last_error = "Duplicate or empty persistent_id in save file"
			continue
		applied_ids[record.persistent_id] = true
		if _apply_record(record):
			applied_count += 1

	_restore_held_state(raw_records)

	last_load_unix = Time.get_unix_time_from_system()
	last_error = "None"
	_loaded_once = true
	_last_saved_signature = _compute_state_signature()
	world_state_loaded.emit(applied_count)

	await get_tree().physics_frame
	_verify_placement_after_load()
	return true

func _apply_record(record: WorldStateRecord) -> bool:
	if record.entity_type == "player" and save_player_position:
		return _apply_actor_position("human_player", record)
	if record.entity_type == "apc" and save_apc_position:
		return _apply_actor_position("apc", record)

	if not registry.contains_id(record.persistent_id):
		last_error = "No registered entity for persistent_id '%s'" % record.persistent_id
		return false

	var entity: PersistentEntity = registry.get_entity(record.persistent_id)
	if not entity.is_valid_for_restore():
		return false

	if entity.entity_type != record.entity_type:
		last_error = "Entity type mismatch for '%s' (saved '%s', current '%s')" % [record.persistent_id, record.entity_type, entity.entity_type]
		return false

	var target_transform: Transform3D = _validate_transform(record.transform, entity.get_default_transform())
	if target_transform != entity.get_default_transform() and record.held_by.is_empty():
		target_transform = _find_safe_transform(target_transform, entity.get_default_transform())

	entity.apply_transform(target_transform)
	entity.apply_custom_state(record)
	return true

func _restore_held_state(raw_records: Array) -> void:
	var apc_node: APCController = _find_apc()
	for raw in raw_records:
		if not (raw is Dictionary):
			continue
		var record: WorldStateRecord = WorldStateRecord.from_dict(raw)
		if record.held_by.is_empty():
			continue
		if not registry.contains_id(record.persistent_id):
			continue
		var entity: PersistentEntity = registry.get_entity(record.persistent_id)
		var target: Node3D = entity.get_target_node()
		if target is PortableObject:
			if apc_node and apc_node.interaction_controller and apc_node.interaction_controller.get_held_object() == null:
				apc_node.interaction_controller.request_pick_up((target as PortableObject).object_id)
			else:
				entity.apply_default_transform()
				entity.apply_custom_state(record)

func _find_apc() -> APCController:
	var apcs: Array[Node] = get_tree().get_nodes_in_group("apc")
	if apcs.size() > 0 and apcs[0] is APCController:
		return apcs[0] as APCController
	return null

func _capture_actor_record(group_name: String, entity_type: String) -> Dictionary:
	var nodes: Array[Node] = get_tree().get_nodes_in_group(group_name)
	if nodes.size() == 0 or not (nodes[0] is Node3D):
		return {}
	var actor: Node3D = nodes[0] as Node3D
	var record: WorldStateRecord = WorldStateRecord.new(group_name, entity_type, actor.global_transform)
	record.saved_at_unix = Time.get_unix_time_from_system()
	record.physics_mode = "character"
	return record.to_dict()

func _apply_actor_position(group_name: String, record: WorldStateRecord) -> bool:
	var nodes: Array[Node] = get_tree().get_nodes_in_group(group_name)
	if nodes.size() == 0 or not (nodes[0] is Node3D):
		return false
	var actor: Node3D = nodes[0] as Node3D
	if not WorldStateRecord.is_finite_transform(record.transform):
		return false
	if not _is_within_bounds(record.transform.origin):
		return false
	actor.global_transform = record.transform
	return true

func reset_world_state() -> bool:
	if not world_state_enabled:
		last_error = "World state persistence is disabled"
		return false
	if active_store == null:
		last_error = "No active world state store"
		return false

	active_store.clear()
	_apply_world_flags({})
	_detach_held_entities()
	for entity in registry.get_all_entities():
		entity.apply_default_transform()
		entity.apply_custom_state(WorldStateRecord.new(entity.persistent_id, entity.entity_type))
	last_save_unix = 0.0
	dirty = false
	autosave_pending = false
	last_error = "None"
	_last_saved_signature = _compute_state_signature()
	world_state_reset.emit()
	return true

func _detach_held_entities() -> void:
	var apc_node: APCController = _find_apc()
	if apc_node == null:
		return
	var world_parent: Node = get_tree().current_scene
	for entity in registry.get_all_entities():
		var target: Node3D = entity.get_target_node()
		if target is PortableObject and (target as PortableObject).is_held:
			var holder: Node = target.get_parent()
			if holder is CarriedObjectSocket:
				var socket: CarriedObjectSocket = holder as CarriedObjectSocket
				var drop_pos: Vector3 = entity.get_default_transform().origin
				socket.detach_object(world_parent, drop_pos)

func set_world_flag(flag_name: String, value: Variant) -> bool:
	if not _allowed_flags.has(flag_name):
		last_error = "Unknown world flag '%s'" % flag_name
		return false
	_session_flags[flag_name] = value
	last_error = "None"
	dirty = true
	autosave_pending = false
	return true

func get_world_flag(flag_name: String) -> Variant:
	if not _allowed_flags.has(flag_name):
		return null
	if _session_flags.has(flag_name):
		return _session_flags[flag_name]
	var envelope: Dictionary = active_store.load_envelope() if active_store else {}
	var flags: Dictionary = envelope.get("world_flags", {})
	return flags.get(flag_name, false)

func _collect_world_flags() -> Dictionary:
	var envelope: Dictionary = active_store.load_envelope() if active_store else {}
	var flags: Dictionary = {}
	var previous: Dictionary = envelope.get("world_flags", {})
	for flag_name in _allowed_flags.keys():
		if _session_flags.has(flag_name):
			flags[flag_name] = _session_flags[flag_name]
		elif previous.has(flag_name):
			flags[flag_name] = previous[flag_name]
	return flags

func _apply_world_flags(flags: Dictionary) -> void:
	_session_flags.clear()
	for flag_name in _allowed_flags.keys():
		if flags.has(flag_name):
			_session_flags[flag_name] = flags[flag_name]

func _on_task_completed(result) -> void:
	if result != null and result.success and result.task_type == "BRING_OBJECT_TO_PLAYER":
		if not bool(get_world_flag("red_box_delivered_once")):
			set_world_flag("red_box_delivered_once", true)
		dirty = true
		autosave_pending = false

func _on_transcript_received(_text: String) -> void:
	if not _first_command_handled:
		_first_command_handled = true
		if not bool(get_world_flag("first_voice_command_completed")):
			set_world_flag("first_voice_command_completed", true)
		dirty = true
		autosave_pending = false

func _compute_state_signature() -> String:
	var parts: PackedStringArray = []
	for entity in registry.get_all_entities():
		var parent_3d: Node3D = entity.get_target_node()
		if parent_3d == null:
			continue
		parts.append(entity.persistent_id)
		parts.append(str(parent_3d.global_transform))
		parts.append(str(entity.capture_record().held_by))
	parts.append(str(_collect_world_flags()))
	return "\n".join(parts)

func _validate_transform(t: Transform3D, default_transform: Transform3D) -> Transform3D:
	if not WorldStateRecord.is_finite_transform(t):
		last_error = "Invalid (non-finite) transform in save file"
		return default_transform
	if not _is_within_bounds(t.origin):
		last_error = "Transform out of world bounds"
		return default_transform
	return t

func _is_within_bounds(point: Vector3) -> bool:
	return point.x >= world_bounds_min.x and point.x <= world_bounds_max.x \
		and point.y >= world_bounds_min.y and point.y <= world_bounds_max.y \
		and point.z >= world_bounds_min.z and point.z <= world_bounds_max.z

func _find_safe_transform(candidate: Transform3D, default_transform: Transform3D) -> Transform3D:
	var world: Node3D = get_tree().current_scene
	if world == null:
		return candidate

	if _raycast_floor_hit(candidate.origin):
		if not _overlaps_obstacle(candidate):
			return candidate
	return default_transform

func _verify_placement_after_load() -> void:
	for entity in registry.get_all_entities():
		var record: WorldStateRecord = entity.capture_record()
		if not record.held_by.is_empty():
			continue
		var parent_3d: Node3D = entity.get_target_node()
		if parent_3d == null:
			continue
		if not _raycast_floor_hit(parent_3d.global_position) or _overlaps_obstacle(parent_3d.global_transform):
			entity.apply_default_transform()
			last_error = "Post-load verification corrected entity '%s'" % entity.persistent_id

func _raycast_floor_hit(point: Vector3) -> bool:
	var world: Node3D = get_tree().current_scene
	if world == null:
		return true
	var space: PhysicsDirectSpaceState3D = world.get_world_3d().direct_space_state
	var from: Vector3 = point + Vector3(0.0, 1.0, 0.0)
	var to: Vector3 = point - Vector3(0.0, 1.5, 0.0)
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, to)
	var hit: Dictionary = space.intersect_ray(query)
	return not hit.is_empty()

func _overlaps_obstacle(transform: Transform3D) -> bool:
	var world: Node3D = get_tree().current_scene
	if world == null:
		return false
	var space: PhysicsDirectSpaceState3D = world.get_world_3d().direct_space_state
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = Vector3(0.7, 0.7, 0.7)
	var params: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
	params.shape = shape
	params.transform = transform
	params.collision_mask = 1
	var results: Array[Dictionary] = space.intersect_shape(params, 16)
	for result in results:
		var collider: Object = result.get("collider")
		if collider is Node:
			var node_name: String = (collider as Node).name
			if node_name.contains("Wall") or node_name.contains("Crate"):
				return true
			if collider is CharacterBody3D:
				return true
	return false

func get_total_registered_count() -> int:
	if registry:
		return registry.get_count()
	return 0
