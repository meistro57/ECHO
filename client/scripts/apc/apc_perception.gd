class_name APCPerception
extends Node3D

@export var max_view_distance: float = 15.0
@export var field_of_view_degrees: float = 110.0
@export var memory_duration: float = 3.0
@export var perception_update_interval: float = 0.1
@export var eye_height: float = 1.4
@export var target_height_offset: float = 0.8
@export var debug_visualization: bool = false

var _apc: CharacterBody3D
var _update_timer: float = 0.0
var _recent_snapshot: Dictionary = {}
var _memory_map: Dictionary = {} # String (entity_id) -> Dictionary { "position": Vector3, "timestamp": float }

func _ready() -> void:
	_apc = get_parent() as CharacterBody3D

func _physics_process(delta: float) -> void:
	if _apc == null:
		return

	_update_timer += delta
	if _update_timer >= perception_update_interval:
		_update_timer = 0.0
		_update_perception()

func get_perception_snapshot() -> Dictionary:
	if _recent_snapshot.is_empty() and _apc != null:
		_update_perception()
	return _recent_snapshot

func _update_perception() -> void:
	if _apc == null:
		return

	var current_time: float = Time.get_ticks_msec() / 1000.0
	var eye_pos: Vector3 = _apc.global_position + Vector3(0.0, eye_height, 0.0)
	var forward_dir: Vector3 = -_apc.global_transform.basis.z.normalized()
	var apc_state: String = _apc.get_state_string() if _apc.has_method("get_state_string") else "UNKNOWN"

	var self_data: Dictionary = {
		"position": _vector3_to_dict(_apc.global_position),
		"forward": _vector3_to_dict(forward_dir),
		"state": apc_state
	}

	# 1. Perceive Human Player
	var human_player_data: Dictionary = {}
	var players: Array[Node] = get_tree().get_nodes_in_group("human_player")
	if players.size() > 0 and players[0] is Node3D:
		var player_node: Node3D = players[0] as Node3D
		human_player_data = _perceive_entity("human_player", "Human Player", "player", player_node, eye_pos, forward_dir, current_time)

	# 2. Perceive Nearby Objects
	var nearby_objects: Array = []
	var perceivables: Array[Node] = get_tree().get_nodes_in_group("perceivable")
	for node in perceivables:
		if node is Node3D and node != _apc:
			var entity_id: String = node.get("entity_id") if node.get("entity_id") != null else node.name.to_lower()
			var display_name: String = node.get("display_name") if node.get("display_name") != null else node.name
			var category: String = node.get("category") if node.get("category") != null else "object"
			
			var obj_data: Dictionary = _perceive_entity(entity_id, display_name, category, node as Node3D, eye_pos, forward_dir, current_time)
			nearby_objects.append(obj_data)

	_recent_snapshot = {
		"timestamp": current_time,
		"self": self_data,
		"human_player": human_player_data,
		"nearby_objects": nearby_objects
	}

func _perceive_entity(entity_id: String, display_name: String, category: String, target_node: Node3D, eye_pos: Vector3, forward_dir: Vector3, current_time: float) -> Dictionary:
	var target_pos: Vector3 = target_node.global_position
	var target_check_pos: Vector3 = target_pos + Vector3(0.0, target_height_offset, 0.0)
	
	var dist: float = eye_pos.distance_to(target_check_pos)
	var within_range: bool = (dist <= max_view_distance)
	
	# FOV Check
	var dir_to_target: Vector3 = (target_check_pos - eye_pos).normalized()
	var angle_deg: float = rad_to_deg(forward_dir.angle_to(dir_to_target))
	var inside_fov: bool = (angle_deg <= (field_of_view_degrees * 0.5))
	
	# Line of Sight Raycast
	var line_of_sight: bool = false
	if within_range:
		line_of_sight = _check_line_of_sight(eye_pos, target_check_pos, target_node)

	var visible: bool = (within_range and inside_fov and line_of_sight)
	var relative_direction: String = _compute_relative_direction(target_pos)

	# Short-term memory handling
	var last_seen_pos_dict: Variant = null
	var seconds_since_last_seen: Variant = null

	if visible:
		_memory_map[entity_id] = {
			"position": target_pos,
			"timestamp": current_time
		}
		last_seen_pos_dict = _vector3_to_dict(target_pos)
		seconds_since_last_seen = 0.0
	else:
		if _memory_map.has(entity_id):
			var mem: Dictionary = _memory_map[entity_id]
			var elapsed: float = current_time - float(mem["timestamp"])
			if elapsed <= memory_duration:
				last_seen_pos_dict = _vector3_to_dict(mem["position"])
				seconds_since_last_seen = snappedf(elapsed, 0.1)
			else:
				_memory_map.erase(entity_id)

	var result: Dictionary = {
		"id": entity_id,
		"display_name": display_name,
		"distance": snappedf(dist, 0.01),
		"relative_direction": relative_direction,
		"within_range": within_range,
		"inside_fov": inside_fov,
		"line_of_sight": line_of_sight,
		"visible": visible,
		"last_seen_position": last_seen_pos_dict,
		"seconds_since_last_seen": seconds_since_last_seen
	}

	if category != "player":
		result["category"] = category

	return result

func _check_line_of_sight(from_pos: Vector3, to_pos: Vector3, target_node: Node3D) -> bool:
	if _apc == null:
		return false

	var world_3d: World3D = _apc.get_world_3d()
	if world_3d == null:
		return false

	var space_state: PhysicsDirectSpaceState3D = world_3d.direct_space_state
	if space_state == null:
		return false

	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from_pos, to_pos)
	query.exclude = [_apc.get_rid()]
	query.collision_mask = 1 # Environment geometry & objects

	var ray_result: Dictionary = space_state.intersect_ray(query)
	if ray_result.is_empty():
		return true

	var hit_collider: Object = ray_result.get("collider")
	if hit_collider == target_node or (hit_collider is Node and target_node.is_ancestor_of(hit_collider as Node)):
		return true

	var hit_pos: Vector3 = ray_result.get("position", Vector3.ZERO)
	if hit_pos.distance_to(to_pos) < 0.4:
		return true

	return false

func _compute_relative_direction(target_pos: Vector3) -> String:
	if _apc == null:
		return "unknown"

	var local_vec: Vector3 = _apc.global_transform.basis.inverse() * (target_pos - _apc.global_position)
	var horiz: Vector2 = Vector2(local_vec.x, local_vec.z)
	if horiz.length() < 0.01:
		return "front"

	# Local forward in Godot basis is -Z, right is +X
	# Angle relative to forward (-Z): 0 deg = front, +90 deg = right, -90 deg = left, +-180 deg = behind
	var angle_deg: float = rad_to_deg(atan2(horiz.x, -horiz.y))

	if angle_deg >= -22.5 and angle_deg <= 22.5:
		return "front"
	elif angle_deg > 22.5 and angle_deg <= 67.5:
		return "front_right"
	elif angle_deg > 67.5 and angle_deg <= 112.5:
		return "right"
	elif angle_deg < -22.5 and angle_deg >= -67.5:
		return "front_left"
	elif angle_deg < -67.5 and angle_deg >= -112.5:
		return "left"
	else:
		return "behind"

func _vector3_to_dict(v: Vector3) -> Dictionary:
	return {
		"x": snappedf(v.x, 0.01),
		"y": snappedf(v.y, 0.01),
		"z": snappedf(v.z, 0.01)
	}
