class_name PersistentEntity
extends Node

enum SpawnPolicy {
	EXISTING_SCENE_ENTITY
}

@export var persistent_id: String = ""
@export var entity_type: String = "portable_object"
@export var persistence_enabled: bool = true
@export var save_transform: bool = true
@export var save_physics_state: bool = false
@export var save_custom_state: bool = true
@export var spawn_policy: SpawnPolicy = SpawnPolicy.EXISTING_SCENE_ENTITY

var default_transform: Transform3D = Transform3D.IDENTITY
var _default_captured: bool = false

func _ready() -> void:
	add_to_group("persistent_entity")
	_capture_default_transform()

func _capture_default_transform() -> void:
	if _default_captured:
		return
	var parent_3d: Node3D = get_parent() as Node3D
	if parent_3d:
		default_transform = parent_3d.global_transform
		_default_captured = true

func get_default_transform() -> Transform3D:
	_capture_default_transform()
	return default_transform

func is_valid_for_restore() -> bool:
	return persistence_enabled and not persistent_id.is_empty() and spawn_policy == SpawnPolicy.EXISTING_SCENE_ENTITY

func get_target_node() -> Node3D:
	return get_parent() as Node3D

func capture_record() -> WorldStateRecord:
	var parent_3d: Node3D = get_target_node()
	var record: WorldStateRecord = WorldStateRecord.new(persistent_id, entity_type)
	if parent_3d:
		record.transform = parent_3d.global_transform
	record.saved_at_unix = Time.get_unix_time_from_system()
	record.physics_mode = _detect_physics_mode(parent_3d)
	record.held_by = _detect_held_by(parent_3d)
	if parent_3d is PortableObject:
		record.custom_state["collision_disabled"] = _is_collision_disabled(parent_3d)
	if not save_physics_state:
		record.linear_velocity = Vector3.ZERO
		record.angular_velocity = Vector3.ZERO
		record.sleeping = false
	return record

func apply_transform(t: Transform3D) -> void:
	if not save_transform:
		return
	var parent_3d: Node3D = get_target_node()
	if parent_3d:
		parent_3d.global_transform = t

func apply_custom_state(record: WorldStateRecord) -> void:
	var parent_3d: Node3D = get_target_node()
	if parent_3d == null or not save_custom_state:
		return
	if record.custom_state.has("collision_disabled"):
		var disabled: bool = bool(record.custom_state.get("collision_disabled", false))
		_set_collision_disabled(parent_3d, disabled)

func apply_default_transform() -> void:
	apply_transform(get_default_transform())

func _detect_physics_mode(parent_3d: Node3D) -> String:
	if parent_3d is RigidBody3D:
		return "rigid"
	if parent_3d is CharacterBody3D:
		return "character"
	return "static"

func _detect_held_by(parent_3d: Node3D) -> String:
	if parent_3d is PortableObject:
		var obj: PortableObject = parent_3d as PortableObject
		return obj.current_holder_id if obj.is_held else ""
	return ""

func _is_collision_disabled(parent_3d: Node3D) -> bool:
	for child in parent_3d.get_children():
		if child is CollisionShape3D and (child as CollisionShape3D).disabled:
			return true
	return false

func _set_collision_disabled(parent_3d: Node3D, disabled: bool) -> void:
	for child in parent_3d.get_children():
		if child is CollisionShape3D:
			(child as CollisionShape3D).disabled = disabled
