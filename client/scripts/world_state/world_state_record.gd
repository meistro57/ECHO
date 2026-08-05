class_name WorldStateRecord
extends RefCounted

var persistent_id: String = ""
var entity_type: String = ""
var transform: Transform3D = Transform3D.IDENTITY
var linear_velocity: Vector3 = Vector3.ZERO
var angular_velocity: Vector3 = Vector3.ZERO
var sleeping: bool = false
var physics_mode: String = "static"
var held_by: String = ""
var parent_persistent_id: String = ""
var custom_state: Dictionary = {}
var saved_at_unix: float = 0.0

func _init(p_persistent_id: String = "", p_entity_type: String = "", p_transform: Transform3D = Transform3D.IDENTITY) -> void:
	persistent_id = p_persistent_id
	entity_type = p_entity_type
	transform = p_transform

static func is_finite_transform(t: Transform3D) -> bool:
	if not is_finite(t.origin.x) or not is_finite(t.origin.y) or not is_finite(t.origin.z):
		return false
	for basis_row in [t.basis.x, t.basis.y, t.basis.z]:
		if not is_finite(basis_row.x) or not is_finite(basis_row.y) or not is_finite(basis_row.z):
			return false
	return true

static func is_finite(v: float) -> bool:
	return not is_nan(v) and not is_inf(v)

func to_dict() -> Dictionary:
	return {
		"persistent_id": persistent_id,
		"entity_type": entity_type,
		"transform": _transform_to_dict(transform),
		"linear_velocity": _vector_to_array(linear_velocity),
		"angular_velocity": _vector_to_array(angular_velocity),
		"sleeping": sleeping,
		"physics_mode": physics_mode,
		"held_by": held_by,
		"parent_persistent_id": parent_persistent_id,
		"custom_state": custom_state.duplicate(true),
		"saved_at_unix": saved_at_unix
	}

static func from_dict(dict: Dictionary):
	var rec: WorldStateRecord = WorldStateRecord.new()
	rec.persistent_id = String(dict.get("persistent_id", ""))
	rec.entity_type = String(dict.get("entity_type", ""))
	rec.transform = _transform_from_dict(dict.get("transform", {}))
	rec.linear_velocity = _vector_from_array(dict.get("linear_velocity", []))
	rec.angular_velocity = _vector_from_array(dict.get("angular_velocity", []))
	rec.sleeping = bool(dict.get("sleeping", false))
	rec.physics_mode = String(dict.get("physics_mode", "static"))
	rec.held_by = String(dict.get("held_by", ""))
	rec.parent_persistent_id = String(dict.get("parent_persistent_id", ""))
	var raw_custom: Variant = dict.get("custom_state", {})
	rec.custom_state = raw_custom.duplicate(true) if raw_custom is Dictionary else {}
	rec.saved_at_unix = float(dict.get("saved_at_unix", 0.0))
	return rec

static func _transform_to_dict(t: Transform3D) -> Dictionary:
	return {
		"basis_x": _vector_to_array(t.basis.x),
		"basis_y": _vector_to_array(t.basis.y),
		"basis_z": _vector_to_array(t.basis.z),
		"origin": _vector_to_array(t.origin)
	}

static func _transform_from_dict(d: Dictionary) -> Transform3D:
	var t: Transform3D = Transform3D.IDENTITY
	var origin: Vector3 = _vector_from_array(d.get("origin", []))
	var basis_x: Vector3 = _vector_from_array(d.get("basis_x", [1.0, 0.0, 0.0]))
	var basis_y: Vector3 = _vector_from_array(d.get("basis_y", [0.0, 1.0, 0.0]))
	var basis_z: Vector3 = _vector_from_array(d.get("basis_z", [0.0, 0.0, 1.0]))
	t.basis = Basis(basis_x, basis_y, basis_z)
	t.origin = origin
	return t

static func _vector_to_array(v: Vector3) -> Array:
	return [v.x, v.y, v.z]

static func _vector_from_array(raw: Variant) -> Vector3:
	if raw is Array and (raw as Array).size() >= 3:
		return Vector3(float(raw[0]), float(raw[1]), float(raw[2]))
	return Vector3.ZERO
